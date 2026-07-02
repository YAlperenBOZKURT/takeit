import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../discovery/domain/entities/device.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../domain/entities/room_member.dart';
import '../providers/room_provider.dart';

class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(discoveryControllerProvider);
    final room = ref.watch(roomProvider);
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    if (room != null) {
      return _buildInviteStatus(room.members, theme, s);
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(s.createRoom, style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  s.selectUpTo4,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.noDevicesFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return _buildDeviceCheckbox(devices[index], theme);
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : _createRoom,
                  child: Text(s.createRoom),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCheckbox(Device device, ThemeData theme) {
    final isSelected = _selected.contains(device.fingerprint);
    final canSelect = _selected.length < 4 || isSelected;

    return CheckboxListTile(
      value: isSelected,
      onChanged: canSelect
          ? (value) {
              setState(() {
                if (value == true) {
                  _selected.add(device.fingerprint);
                } else {
                  _selected.remove(device.fingerprint);
                }
              });
            }
          : null,
      title: Text(device.alias),
      subtitle: Text(device.deviceType == 'mobile' ? 'Phone' : 'Desktop'),
      secondary: Icon(
        device.deviceType == 'mobile' ? Icons.phone_android : Icons.computer,
      ),
    );
  }

  void _createRoom() {
    final devices = ref.read(discoveryControllerProvider);
    final selected = devices
        .where((d) => _selected.contains(d.fingerprint))
        .toList();
    ref.read(roomProvider.notifier).createRoom(selected);
  }

  Widget _buildInviteStatus(
    List<RoomMember> members,
    ThemeData theme,
    AppStrings s,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.roomCreated, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    final (color, label) = switch (m.status) {
                      MemberStatus.pending => (
                        const Color(0xFFE67E22),
                        s.statusPending,
                      ),
                      MemberStatus.accepted => (
                        const Color(0xFF27AE60),
                        s.statusAccepted,
                      ),
                      MemberStatus.declined => (
                        const Color(0xFFE74C3C),
                        s.statusDeclined,
                      ),
                      MemberStatus.offline => (
                        const Color(0xFF3B424C),
                        s.statusOffline,
                      ),
                    };
                    return Chip(
                      avatar: CircleAvatar(backgroundColor: color, radius: 8),
                      label: Text('${m.alias} — $label'),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.waitingForResponses,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
