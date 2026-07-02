import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../domain/entities/device.dart';
import '../providers/device_actions_provider.dart';

class DeviceTile extends ConsumerWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(Device device)? onQuickRoom;

  const DeviceTile({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
    this.onQuickRoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final trusted = ref.watch(trustedDevicesProvider);
    final blocked = ref.watch(blockedDevicesProvider);
    final isTrusted = trusted.contains(device.fingerprint);
    final isBlocked = blocked.contains(device.fingerprint);
    final initials = device.alias.isNotEmpty
        ? device.alias.substring(0, 1).toUpperCase()
        : '?';
    final color = _colorFromFingerprint(device.fingerprint);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isBlocked
                    ? Colors.red
                    : isTrusted
                    ? const Color(0xFF27AE60)
                    : const Color(0xFFE67E22),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(device.alias),
      subtitle: Text(_deviceSubtitle(), style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            device.deviceType == 'mobile'
                ? Icons.phone_android
                : Icons.computer,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onSelected: (value) {
              switch (value) {
                case 'quick_room':
                  onQuickRoom?.call(device);
                case 'trust':
                  ref
                      .read(trustedDevicesProvider.notifier)
                      .add(device.fingerprint);
                  ref
                      .read(blockedDevicesProvider.notifier)
                      .remove(device.fingerprint);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.deviceTrusted(device.alias))),
                  );
                case 'untrust':
                  ref
                      .read(trustedDevicesProvider.notifier)
                      .remove(device.fingerprint);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.deviceUntrusted(device.alias))),
                  );
                case 'block':
                  ref
                      .read(blockedDevicesProvider.notifier)
                      .add(device.fingerprint);
                  ref
                      .read(trustedDevicesProvider.notifier)
                      .remove(device.fingerprint);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.deviceBlocked(device.alias))),
                  );
                case 'unblock':
                  ref
                      .read(blockedDevicesProvider.notifier)
                      .remove(device.fingerprint);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.deviceUnblocked(device.alias))),
                  );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'quick_room',
                child: Row(
                  children: [
                    const Icon(Icons.group_add, size: 18),
                    const SizedBox(width: 8),
                    Text(s.quickRoom),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (isTrusted)
                PopupMenuItem(
                  value: 'untrust',
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(s.untrustDevice),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'trust',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 18,
                        color: Color(0xFF27AE60),
                      ),
                      const SizedBox(width: 8),
                      Text(s.trustDevice),
                    ],
                  ),
                ),
              if (isBlocked)
                PopupMenuItem(
                  value: 'unblock',
                  child: Row(
                    children: [
                      const Icon(Icons.block, size: 18),
                      const SizedBox(width: 8),
                      Text(s.unblockDevice),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        Icons.block,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.blockDevice,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _deviceSubtitle() {
    final osLabel = _osDisplayName(device.os);
    if (osLabel.isNotEmpty) return osLabel;
    return device.deviceType == 'mobile' ? 'Phone' : 'Desktop';
  }

  static String _osDisplayName(String os) {
    switch (os) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return '';
    }
  }

  Color _colorFromFingerprint(String fingerprint) {
    final hash = fingerprint.hashCode;
    final colors = [
      const Color(0xFFE67E22),
      const Color(0xFF2980B9),
      const Color(0xFF27AE60),
      const Color(0xFF8E44AD),
      const Color(0xFFE74C3C),
      const Color(0xFF16A085),
      const Color(0xFFF39C12),
      const Color(0xFF2C3E50),
    ];
    return colors[hash.abs() % colors.length];
  }
}
