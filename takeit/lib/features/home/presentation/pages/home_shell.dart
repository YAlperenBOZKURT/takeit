import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../discovery/presentation/pages/device_list_page.dart';
import '../../../quick_send/presentation/pages/quick_send_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

/// Currently selected bottom-nav tab: 0 Nearby · 1 Chat · 2 Send · 3 Settings.
final homeTabProvider = StateProvider<int>((ref) => 0);

/// App shell hosting the persistent bottom navigation. The tab bodies keep
/// their own scaffolds/app-bars; this shell only owns the nav bar, so the
/// structure is identical across every theme.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = [
    DeviceListPage(),
    ChatPage(),
    QuickSendPage(),
    SettingsPage(),
  ];

  // Stable per-tab identity. These must not be GlobalKeys because all tab
  // scaffolds stay mounted in the IndexedStack and can rebuild together.
  static const _tabKeys = [
    ValueKey('nearby-tab'),
    ValueKey('chat-tab'),
    ValueKey('send-tab'),
    ValueKey('settings-tab'),
  ];

  // Tabs are built lazily, on first visit, then kept alive — not eagerly for
  // all four on the very first frame. App start-up still has async state in
  // flight then (e.g. ThemeModeNotifier re-emitting once settings.json loads
  // off disk), and racing that against building every tab's full widget tree
  // — including ones nobody has opened yet — is what corrupts a build pass
  // and cascades into GlobalKey/RenderFlex errors. Deferring a tab's build
  // until it's actually selected sidesteps the race and avoids pointless work.
  late final Set<int> _builtTabs = {ref.read(homeTabProvider)};

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabProvider);
    _builtTabs.add(index);
    final s = AppStrings.of(context);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            if (_builtTabs.contains(i))
              KeyedSubtree(
                key: _tabKeys[i],
                child: ScaffoldMessenger(child: _tabs[i]),
              )
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(homeTabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sensors_outlined),
            selectedIcon: const Icon(Icons.sensors),
            label: s.nearbyTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: s.chat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.upload_outlined),
            selectedIcon: const Icon(Icons.upload),
            label: s.send,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s.settings,
          ),
        ],
      ),
    );
  }
}
