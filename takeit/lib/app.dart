import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/l10n/app_strings.dart';
import 'core/network/http_server.dart';
import 'core/theme/classic_theme.dart';
import 'core/theme/modern_dark_theme.dart';
import 'core/theme/terra_theme.dart';
import 'core/services/background_transfer_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/update_service.dart';
import 'core/widgets/update_dialog.dart';
import 'main.dart';
import 'features/home/presentation/pages/home_shell.dart';
import 'features/clipboard/presentation/providers/clipboard_provider.dart';
import 'features/quick_send/presentation/providers/quick_send_provider.dart';
import 'features/discovery/presentation/providers/discovery_provider.dart';
import 'features/nickname/presentation/pages/nickname_page.dart';
import 'features/nickname/presentation/providers/nickname_provider.dart';
import 'features/room/presentation/providers/room_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

GoRouter createRouter(WidgetRef ref) => GoRouter(
  initialLocation: '/nickname',
  redirect: (context, state) {
    final hasNickname = ref.read(nicknameProvider).isNotEmpty;
    final isOnNickname = state.matchedLocation == '/nickname';

    if (!hasNickname && !isOnNickname) return '/nickname';
    if (hasNickname && isOnNickname) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/nickname',
      builder: (context, state) => const NicknamePage(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
  ],
);

class TakeItApp extends ConsumerStatefulWidget {
  const TakeItApp({super.key});

  @override
  ConsumerState<TakeItApp> createState() => _TakeItAppState();
}

class _TakeItAppState extends ConsumerState<TakeItApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  // Captured up front so teardown never reads providers after disposal.
  late final AppHttpServer _httpServer;
  late final DiscoveryController _discovery;
  DateTime? _pausedAt;
  static const _longBackgroundThreshold = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _router = createRouter(ref);
    WidgetsBinding.instance.addObserver(this);
    _httpServer = ref.read(httpServerProvider);
    _discovery = ref.read(discoveryControllerProvider.notifier);
    ref.read(clipboardProvider);
    ref.read(quickTransfersProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    unawaited(UpdateService.cleanupStaleInstallers());

    final info = await UpdateService.checkForUpdate();
    if (info == null || !mounted) return;
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    _router.dispose();
    super.dispose();
  }

  Future<void> _handleResume() async {
    final paused = _pausedAt;
    _pausedAt = null;
    final longBackground =
        paused != null &&
        DateTime.now().difference(paused) > _longBackgroundThreshold;

    try {
      if (longBackground) {
        // UDP sockets may have been closed by the OS — full restart.
        _discovery.stopDiscovery();
        await _discovery.startDiscovery();
      } else {
        _discovery.reAnnounce();
      }
    } catch (e) {
      debugPrint('Discovery resume failed: $e');
    }

    // Immediately verify room member reachability — host may have
    // died while we were backgrounded.
    try {
      ref.read(roomProvider.notifier).checkConnectionsNow();
    } catch (e) {
      debugPrint('Room connection check failed: $e');
    }
  }

  Future<void> _cleanup() async {
    try {
      _discovery.stopDiscovery();
    } catch (e) {
      debugPrint('Discovery stop failed: $e');
    }
    try {
      await _httpServer.stop();
    } catch (e) {
      debugPrint('HTTP server stop failed: $e');
    }
    try {
      await BackgroundTransferService.stop();
    } catch (e) {
      debugPrint('Background service stop failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        NotificationService.setAppForeground(true);
        _handleResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        NotificationService.setAppForeground(false);
        _pausedAt ??= DateTime.now();
        break;
      case AppLifecycleState.detached:
        _cleanup();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appThemeMode = ref.watch(themeModeProvider);
    final themeMode = switch (appThemeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.terra => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.modern => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    // Terra is the warm light theme; otherwise fall back to the plain teal
    // one. These are pre-built, cached ThemeData instances (see the theme
    // files) so their identity stays stable across rebuilds.
    final lightTheme = appThemeMode == AppThemeMode.terra
        ? terraTheme
        : classicLightTheme;

    final darkTheme = switch (appThemeMode) {
      AppThemeMode.dark => classicDarkTheme,
      _ => modernDarkTheme,
    };

    final appLanguage = ref.watch(languageProvider);
    final locale = switch (appLanguage) {
      AppLanguage.en => const Locale('en'),
      AppLanguage.tr => const Locale('tr'),
      AppLanguage.system => null,
    };

    return MaterialApp.router(
      title: 'TakeIt',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: _router,
    );
  }
}
