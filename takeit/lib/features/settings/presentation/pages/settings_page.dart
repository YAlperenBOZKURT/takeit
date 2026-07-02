import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/network/local_ip.dart';
import '../../../../core/services/notification_service.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../../main.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = ref.watch(nicknameProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appLanguage = ref.watch(languageProvider);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          _SectionHeader(title: s.profile),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(s.nickname),
            subtitle: Text(nickname),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _editNickname(context, ref, nickname),
          ),
          ListTile(
            leading: const Icon(Icons.casino_outlined),
            title: Text(s.resetToRandom),
            onTap: () => _resetToRandom(context, ref),
          ),

          const Divider(),

          _SectionHeader(title: s.appearance),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(s.appearance),
            trailing: _SettingsDropdownContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AppThemeMode>(
                  value: themeMode,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  alignment: Alignment.centerLeft,
                  focusColor: Colors.transparent,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: AppThemeMode.system,
                      child: Text(s.systemDefault),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.light,
                      child: Text(s.light),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.dark,
                      child: Text(s.dark),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.modern,
                      child: Text(s.modern),
                    ),
                    const DropdownMenuItem(
                      value: AppThemeMode.terra,
                      child: Text('Terra'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(),

          _SectionHeader(title: s.language),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(s.language),
            trailing: _SettingsDropdownContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AppLanguage>(
                  value: appLanguage,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  alignment: Alignment.centerLeft,
                  focusColor: Colors.transparent,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  onChanged: (lang) {
                    if (lang != null) {
                      ref.read(languageProvider.notifier).setLanguage(lang);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: AppLanguage.system,
                      child: Text(s.systemDefault),
                    ),
                    const DropdownMenuItem(
                      value: AppLanguage.en,
                      child: Text('English'),
                    ),
                    const DropdownMenuItem(
                      value: AppLanguage.tr,
                      child: Text('Türkçe'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(),

          _SectionHeader(title: s.notificationSound),
          _NotificationSoundTile(),
          _NotificationVibrationTile(),

          const Divider(),

          _SectionHeader(title: s.downloadLocation),
          _DownloadLocationTile(),

          const Divider(),

          _SectionHeader(title: s.network),
          const _LocalIpTile(),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(s.restartServer),
            subtitle: Text(s.restartServerDesc),
            onTap: () => _restartServer(context, ref),
          ),
          _ClearTempFilesTile(),

          const Divider(),

          _SectionHeader(title: s.about),
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/logo.png', width: 40, height: 40),
            ),
            title: const Text('TakeIt'),
            subtitle: Text('v1.0.0 — ${s.appDesc}'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Yusuf Alperen Bozkurt'),
            subtitle: Text(s.developer),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://www.linkedin.com/in/yalperenbozkurt/'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }

  void _editNickname(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    final s = AppStrings.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.changeNickname),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: s.enterNewNickname,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
          onSubmitted: (_) {
            _applyNickname(ctx, ref, controller.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => _applyNickname(ctx, ref, controller.text),
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  void _applyNickname(BuildContext context, WidgetRef ref, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    ref.read(nicknameProvider.notifier).setNickname(trimmed);
    ref.read(discoveryControllerProvider.notifier).reAnnounce();
    ref.read(roomProvider.notifier).notifyAliasChange();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).nicknameChanged(trimmed))),
    );
  }

  void _resetToRandom(BuildContext context, WidgetRef ref) {
    ref.read(nicknameProvider.notifier).generateRandom();
    final newName = ref.read(nicknameProvider);
    ref.read(discoveryControllerProvider.notifier).reAnnounce();
    ref.read(roomProvider.notifier).notifyAliasChange();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).nicknameRandomized(newName)),
      ),
    );
  }

  Future<void> _restartServer(BuildContext context, WidgetRef ref) async {
    try {
      final server = ref.read(httpServerProvider);
      await server.stop();
      await server.start();
      ref.read(discoveryControllerProvider.notifier).stopDiscovery();
      await ref.read(discoveryControllerProvider.notifier).startDiscovery();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).serverRestarted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).restartFailed(e.toString())),
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsDropdownContainer extends StatelessWidget {
  final Widget child;
  const _SettingsDropdownContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: child,
        ),
      ),
    );
  }
}

class _DownloadLocationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPath = ref.watch(downloadPathProvider);
    final s = AppStrings.of(context);

    // Android's SAF directory picker returns content:// URIs that can't be
    // used as a File path, so on mobile we only show the default location
    // (public Download/TakeIt) and hide the folder picker.
    final allowCustomPicker = !Platform.isAndroid && !Platform.isIOS;

    final effectivePath =
        customPath ??
        (Platform.isAndroid
            ? '/storage/emulated/0/Download/TakeIt'
            : s.defaultLocation);

    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(s.downloadLocationDesc),
      subtitle: Text(
        effectivePath,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customPath != null && allowCustomPicker)
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 20),
              tooltip: s.resetToDefault,
              onPressed: () {
                ref.read(downloadPathProvider.notifier).setPath(null);
              },
            ),
          if (allowCustomPicker)
            IconButton(
              icon: const Icon(Icons.folder_open, size: 20),
              tooltip: s.changeFolder,
              onPressed: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  ref.read(downloadPathProvider.notifier).setPath(result);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _NotificationSoundTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationSoundProvider);
    final s = AppStrings.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.volume_up_outlined),
      title: Text(s.notificationSound),
      subtitle: Text(s.notificationSoundDesc),
      value: enabled,
      onChanged: (_) {
        ref.read(notificationSoundProvider.notifier).toggle();
        final sound = !enabled;
        final vibration = ref.read(notificationVibrationProvider);
        NotificationService.updateSettings(sound: sound, vibration: vibration);
      },
    );
  }
}

class _NotificationVibrationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationVibrationProvider);
    final s = AppStrings.of(context);

    return SwitchListTile(
      secondary: const Icon(Icons.vibration),
      title: Text(s.notificationVibration),
      subtitle: Text(s.notificationVibrationDesc),
      value: enabled,
      onChanged: (_) {
        ref.read(notificationVibrationProvider.notifier).toggle();
        final sound = ref.read(notificationSoundProvider);
        final vibration = !enabled;
        NotificationService.updateSettings(sound: sound, vibration: vibration);
      },
    );
  }
}

class _LocalIpTile extends StatefulWidget {
  const _LocalIpTile();

  @override
  State<_LocalIpTile> createState() => _LocalIpTileState();
}

class _LocalIpTileState extends State<_LocalIpTile>
    with WidgetsBindingObserver {
  late Future<List<String>> _ipsFuture;

  @override
  void initState() {
    super.initState();
    _ipsFuture = listUsableLocalIps();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // IPs change when the user switches networks; refresh on resume.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    setState(() {
      _ipsFuture = listUsableLocalIps();
    });
  }

  bool get _isTurkish => Localizations.localeOf(context).languageCode == 'tr';

  String get _title => _isTurkish ? 'Bu cihazın IP adresi' : 'This device IP';
  String get _empty => _isTurkish ? 'Bulunamadı' : 'Not available';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _ipsFuture,
      builder: (context, snap) {
        final ips = snap.data ?? const <String>[];
        final subtitle = ips.isEmpty
            ? (snap.connectionState == ConnectionState.waiting ? '…' : _empty)
            : ips.join(' · ');
        final canCopy = ips.isNotEmpty;
        return ListTile(
          leading: const Icon(Icons.lan_outlined),
          title: Text(_title),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: _isTurkish ? 'Yenile' : 'Refresh',
                onPressed: _refresh,
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: AppStrings.of(context).copy,
                onPressed: canCopy
                    ? () {
                        Clipboard.setData(ClipboardData(text: ips.first));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.of(context).copied),
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClearTempFilesTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);

    return ListTile(
      leading: const Icon(Icons.cleaning_services_outlined),
      title: Text(s.clearTempFiles),
      subtitle: Text(s.clearTempFilesDesc),
      onTap: () => _clearTemp(context),
    );
  }

  Future<void> _clearTemp(BuildContext context) async {
    final s = AppStrings.of(context);
    final dir = await getTemporaryDirectory();
    var count = 0;
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        try {
          if (entity is File) {
            entity.deleteSync();
            count++;
          } else if (entity is Directory) {
            entity.deleteSync(recursive: true);
            count++;
          }
        } catch (_) {}
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0 ? s.tempFilesCleared(count) : s.noTempFiles),
        ),
      );
    }
  }
}
