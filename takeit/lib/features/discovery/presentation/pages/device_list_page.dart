import 'dart:io';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../../../../main.dart';
import '../../../room/domain/entities/room_member.dart';
import '../../../room/presentation/pages/create_room_sheet.dart';
import '../../../room/presentation/pages/room_invite_sheet.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../room/presentation/utils/room_switch_guard.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../domain/entities/device.dart';
import '../providers/discovery_provider.dart';
import '../widgets/device_tile.dart';
import '../../../history/presentation/pages/history_page.dart';
import '../../../../core/services/transfer_queue_service.dart';
import '../../../quick_send/presentation/providers/quick_send_provider.dart';
import '../../../quick_send/presentation/widgets/quick_send_sheet.dart';
import '../../../quick_send/presentation/widgets/quick_text_popup.dart';
import '../../../transfer/presentation/widgets/transfer_approval_sheet.dart';
import '../../../transfer/domain/entities/transfer_session.dart';
import '../../../transfer/presentation/providers/session_transfers_provider.dart';
import '../../../transfer/presentation/widgets/transfers_fab.dart';

class DeviceListPage extends ConsumerStatefulWidget {
  const DeviceListPage({super.key});

  @override
  ConsumerState<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends ConsumerState<DeviceListPage> {
  /// Single-popup mutex. Only one of invite/approval/quickText is visible at
  /// a time. Priority: invite > approval > quickText.
  String? _activePopup;

  /// Desktop drag & drop state for file quick-send.
  bool _isDragging = false;

  /// Session IDs for which a failure/decline toast has already been shown.
  final _notifiedIds = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(discoveryControllerProvider.notifier).startDiscovery();
    });
    // Drain any queued popups from when this page wasn't mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPopupQueue();
      _showServerErrorIfAny();
    });
  }

  void _showServerErrorIfAny() {
    final error = ref.read(serverErrorProvider);
    if (error == null || !mounted) return;
    final s = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: Text(s.portBusyTitle),
        content: Text(s.portBusyMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }

  void _checkPopupQueue() {
    if (!mounted || _activePopup != null) return;

    final invites = ref.read(roomInvitesProvider);
    if (invites.isNotEmpty) {
      _showInvite(invites.last);
      return;
    }

    final approval = ref.read(currentApprovalProvider);
    if (approval != null) {
      _showApproval(approval);
      return;
    }

    final quickText = ref.read(incomingQuickTextProvider);
    if (quickText != null) {
      _showQuickText(quickText);
    }
  }

  bool get _isTurkish => Localizations.localeOf(context).languageCode == 'tr';

  Future<void> _showJoinByIp() async {
    final ok = await confirmRoomSwitch(context, ref);
    if (!ok || !mounted) return;

    final controller = TextEditingController();
    final s = AppStrings.of(context);
    final ip = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isTurkish ? 'IP ile bağlan' : 'Connect by IP'),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: '192.168.1.42',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 8),
            Text(
              _isTurkish
                  ? 'Karşı cihaz aynı ağda olmalı ve TakeIt açık olmalı.'
                  : 'The other device must be on the same network with TakeIt open.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(_isTurkish ? 'Davet Gönder' : 'Send Invite'),
          ),
        ],
      ),
    );

    if (ip == null || ip.isEmpty || !mounted) return;
    if (!_isValidIpv4(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTurkish ? 'Geçersiz IP adresi' : 'Invalid IP address',
          ),
        ),
      );
      return;
    }

    await ref.read(roomProvider.notifier).createRoomByIp(ip);
  }

  bool _isValidIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  Future<void> _showCreateRoom() async {
    final ok = await confirmRoomSwitch(context, ref);
    if (!ok || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateRoomSheet(),
    );
  }

  void _showQuickSend(Device? device, {List<File>? initialFiles}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          QuickSendSheet(preselectedDevice: device, initialFiles: initialFiles),
    );
  }

  Future<void> _startQuickChat(Device device) async {
    final room = ref.read(roomProvider);
    if (room != null) {
      final isMember = room.members.any(
        (m) =>
            m.fingerprint == device.fingerprint &&
            m.status == MemberStatus.accepted,
      );
      if (isMember) {
        ref.read(homeTabProvider.notifier).state = 1;
        return;
      }
      final ok = await confirmRoomSwitch(context, ref);
      if (!ok || !mounted) return;
    }
    ref.read(roomProvider.notifier).createRoom([device]);
  }

  void _showTransferToast(SessionTransferView t) {
    if (!mounted) return;
    final s = AppStrings.of(context);
    final isDeclined = t.session.status == TransferStatus.declined;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isDeclined ? Icons.block_rounded : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDeclined ? s.transferDeclinedToast : s.transferFailedToast,
              ),
            ),
          ],
        ),
        backgroundColor: isDeclined
            ? const Color(0xFFEF4444)
            : const Color(0xFFE67E22),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _restartServer(BuildContext ctx) async {
    final s = AppStrings.of(ctx);
    try {
      final server = ref.read(httpServerProvider);
      await server.stop();
      await server.start();
      ref.read(discoveryControllerProvider.notifier).stopDiscovery();
      await ref.read(discoveryControllerProvider.notifier).startDiscovery();
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(s.serverRestarted)));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text(s.restartFailed(e.toString()))));
      }
    }
  }

  void _showInvite(Map<String, dynamic> invite) {
    _activePopup = 'invite';
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => RoomInviteSheet(invite: invite),
    ).then((accepted) {
      _activePopup = null;
      if (accepted == true && mounted) {
        ref.read(homeTabProvider.notifier).state = 1;
        return;
      }
      _checkPopupQueue();
    });
  }

  void _showApproval(TransferBatch batch) {
    _activePopup = 'approval';
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => TransferApprovalSheet(batch: batch),
    ).then((_) {
      _activePopup = null;
      _checkPopupQueue();
    });
  }

  void _showQuickText(QuickTextMessage message) {
    _activePopup = 'quickText';
    ref.read(incomingQuickTextProvider.notifier).state = null;
    showDialog(
      context: context,
      builder: (_) => QuickTextPopup(message: message),
    ).then((_) {
      _activePopup = null;
      _checkPopupQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(discoveryControllerProvider);
    final theme = Theme.of(context);

    // Prioritized popup queue: invite > approval > quickText.
    // Only trigger on additions, not removals.
    ref.listen(roomInvitesProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) _checkPopupQueue();
    });
    ref.listen(currentApprovalProvider, (prev, next) {
      if (next != null) _checkPopupQueue();
    });
    ref.listen(incomingQuickTextProvider, (prev, next) {
      if (next != null) _checkPopupQueue();
    });

    // Show toast on transfer decline / failure
    ref.listen(sessionTransfersProvider, (prev, next) {
      if (!mounted) return;
      for (final t in next) {
        if (_notifiedIds.contains(t.sessionId)) continue;
        if (t.isFailed) {
          _notifiedIds.add(t.sessionId);
          _showTransferToast(t);
        }
      }
    });

    // Navigate to chat when first member accepts (host side)
    ref.listen(roomProvider, (prev, next) {
      if (next != null) {
        final notifier = ref.read(roomProvider.notifier);
        if (notifier.isHost && notifier.isRoomActive) {
          // Only navigate if we weren't active before
          final wasActive =
              prev != null &&
              prev.members.any((m) => m.status == MemberStatus.accepted);
          if (!wasActive) {
            ref.read(homeTabProvider.notifier).state = 1;
          }
        }
      }
    });

    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            SvgPicture.asset('assets/takeit_logo_emblem.svg', height: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'TakeIt',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Color(0xFF3E6D52),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
            icon: const Icon(Icons.history),
            tooltip: s.transferHistory,
          ),
          IconButton(
            onPressed: devices.isEmpty ? null : () => _showQuickSend(null),
            icon: const Icon(Icons.send_rounded),
            tooltip: s.quickSend,
          ),
          IconButton(
            onPressed: _showJoinByIp,
            icon: const Icon(Icons.link),
            tooltip: _isTurkish ? 'IP ile bağlan' : 'Connect by IP',
          ),
          IconButton(
            onPressed: devices.isEmpty ? null : _showCreateRoom,
            icon: const Icon(Icons.group_add),
            tooltip: s.newRoom,
          ),
        ],
      ),
      body: _wrapWithDropTarget(
        devices: devices,
        theme: theme,
        child: Stack(
          children: [
            Column(
              children: [
                const ConnectivityBanner(),
                _ActiveRoomCard(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref
                          .read(discoveryControllerProvider.notifier)
                          .reAnnounce();
                      await Future.delayed(const Duration(seconds: 2));
                    },
                    child: devices.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildDeviceList(devices, theme),
                  ),
                ),
              ],
            ),
            const Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(child: TransfersFab()),
            ),
            // Drag overlay — blurred scrim that hides content
            if (_isDragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.85,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_copy_rounded,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                AppStrings.of(context).dropFilesHere,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'refresh_fab',
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed: () => _restartServer(context),
        tooltip: s.restartServer,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  /// Wraps child with DropTarget on desktop platforms.
  Widget _wrapWithDropTarget({
    required List devices,
    required ThemeData theme,
    required Widget child,
  }) {
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (!isDesktop) return child;

    return DropTarget(
      // Every tab stays mounted in HomeShell's IndexedStack once visited, and
      // desktop_drop matches a drop against each mounted DropTarget's render
      // bounds rather than Flutter's normal hit-testing — so without this
      // guard, a single drop fires every tab's DropTarget at once (e.g. this
      // one and QuickSendPage's) and pops up duplicate sheets.
      onDragEntered: (_) {
        if (ref.read(homeTabProvider) != 0) return;
        setState(() => _isDragging = true);
      },
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        if (ref.read(homeTabProvider) != 0) return;
        setState(() => _isDragging = false);
        final files = details.files
            .map((xfile) => File(xfile.path))
            .where((f) => f.existsSync())
            .toList();
        if (files.isNotEmpty) {
          _showQuickSend(null, initialFiles: files);
        }
      },
      child: child,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final s = AppStrings.of(context);
    return ListView(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.wifi,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.wifiWarning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _RadialPulse(),
                const SizedBox(height: 32),
                Text(
                  s.noDevicesFound,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    s.makeOthersOpen,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList(List devices, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                AppStrings.of(
                  context,
                ).devicesOnNetwork(devices.length).toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Material(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: DeviceTile(
                    device: devices[index],
                    onTap: () => _startQuickChat(devices[index]),
                    onLongPress: () => _showQuickSend(devices[index]),
                    onQuickRoom: (device) => _startQuickChat(device),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActiveRoomCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);
    if (room == null) return const SizedBox.shrink();
    final hasAccepted = room.members.any(
      (m) => m.status == MemberStatus.accepted,
    );
    if (!hasAccepted) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final accepted = room.members
        .where((m) => m.status == MemberStatus.accepted)
        .toList();
    final names = accepted.map((m) => m.alias).join(', ');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.chat, color: Colors.white, size: 20),
        ),
        title: Text(
          s.activeRoom,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          names.isEmpty ? s.tapToReturn : names,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${accepted.length + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: theme.colorScheme.primary),
          ],
        ),
        onTap: () => ref.read(homeTabProvider.notifier).state = 1,
      ),
    );
  }
}

/// Animated radial "scanning" indicator: a solid primary disc with a sensors
/// glyph, behind expanding/fading concentric rings. Matches the Terra mock-up's
/// nearby-devices discovery state.
class _RadialPulse extends StatefulWidget {
  const _RadialPulse();

  @override
  State<_RadialPulse> createState() => _RadialPulseState();
}

class _RadialPulseState extends State<_RadialPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  static const double _core = 92;
  static const double _max = 200;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _max,
      height: _max,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _ring(scheme, (_controller.value + i / 3) % 1.0),
              Container(
                width: _core,
                height: _core,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.sensors, color: scheme.onPrimary, size: 40),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(ColorScheme scheme, double t) {
    final size = _core + (_max - _core) * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: (1 - t) * 0.15),
      ),
    );
  }
}
