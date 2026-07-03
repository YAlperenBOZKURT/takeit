import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../discovery/domain/entities/device.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../providers/quick_send_provider.dart';

const int _kMaxFiles = 10;

enum _SendStatus { idle, sending }

/// A file picked for the Send tab's own flow. Deliberately separate from
/// [QuickSendSheet]'s `_SendItem` — this tab's flow (files shown inline on
/// the page, then a recipient sheet, then inline progress) is independent of
/// the shared sheet used by Nearby's drag-drop and long-press-a-device.
class _PickedFile {
  final String path;
  final String name;
  final int size;

  _PickedFile({required this.path, required this.name, required this.size});

  String get displaySize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// The "Send" tab — its own advanced send flow: add files (shown inline,
/// removable), pick one or more recipients from a sheet, then watch inline
/// per-file progress until the page resets. Independent of [QuickSendSheet].
class QuickSendPage extends ConsumerStatefulWidget {
  const QuickSendPage({super.key});

  @override
  ConsumerState<QuickSendPage> createState() => _QuickSendPageState();
}

class _QuickSendPageState extends ConsumerState<QuickSendPage> {
  final List<_PickedFile> _files = [];
  bool _isDragging = false;
  _SendStatus _status = _SendStatus.idle;
  Set<String> _activeSessionIds = {};
  int _recipientCount = 0;

  void _addFiles(Iterable<File> newFiles) {
    var hitLimit = false;
    setState(() {
      for (final f in newFiles) {
        if (_files.length >= _kMaxFiles) {
          hitLimit = true;
          break;
        }
        if (!f.existsSync()) continue;
        _files.add(
          _PickedFile(
            path: f.path,
            name: f.uri.pathSegments.last,
            size: f.lengthSync(),
          ),
        );
      }
    });
    if (hitLimit) _showLimitToast();
  }

  void _showLimitToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Max $_kMaxFiles')));
  }

  Future<void> _pickFiles() async {
    // Shared with Quick Send's sheet and Chat: the native picker can only run
    // one invocation at a time across the OS, so a pick already in flight on
    // another surface must block this one instead of racing it.
    if (ref.read(filePickerBusyProvider)) return;
    ref.read(filePickerBusyProvider.notifier).state = true;

    // On mobile the picker copies each selected file into the app cache
    // before returning — for large files this is the slow part the loading
    // state covers. That copy cannot be aborted mid-flight.
    List<String>? paths;
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      paths = result?.paths.whereType<String>().toList();
    } finally {
      ref.read(filePickerBusyProvider.notifier).state = false;
    }
    if (paths == null || paths.isEmpty) return;

    // Page was closed while the OS was still copying: discard the result and
    // remove the cached copies the picker made. Desktop paths point at the
    // user's original files — never delete those.
    if (!mounted) {
      if (Platform.isAndroid || Platform.isIOS) {
        for (final p in paths) {
          try {
            await File(p).delete();
          } catch (_) {}
        }
      }
      return;
    }

    _addFiles(paths.map(File.new));
  }

  /// Pastes clipboard text as a `.txt` file so it flows through the same
  /// file list, remove, and send path as anything else on this page.
  Future<void> _pasteClipboard() async {
    if (_files.length >= _kMaxFiles) {
      _showLimitToast();
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    final fileName = 'clipboard_$stamp.txt';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(text);
    final size = await file.length();
    if (!mounted) return;

    setState(() {
      _files.add(_PickedFile(path: file.path, name: fileName, size: size));
    });
  }

  Future<void> _selectRecipients() async {
    final selected = await showModalBottomSheet<List<Device>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecipientPickerSheet(),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    _startSending(selected);
  }

  Future<void> _startSending(List<Device> recipients) async {
    final notifier = ref.read(quickTransfersProvider.notifier);
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final batchFiles = [
      for (final f in _files)
        QuickOutgoingFile(
          filePath: f.path,
          fileName: f.name,
          fileSize: f.size,
          fileMimeType: _guessMime(f.name),
        ),
    ];

    setState(() {
      _status = _SendStatus.sending;
      _recipientCount = recipients.length;
      _activeSessionIds = {};
    });

    final failedAliases = <String>{};
    final futures = <Future<void>>[];
    for (final device in recipients) {
      futures.add(
        notifier
            .sendFiles(
              target: device,
              files: batchFiles,
              onSessionsCreated: (ids) {
                if (!mounted) return;
                setState(
                  () => _activeSessionIds = {..._activeSessionIds, ...ids},
                );
              },
            )
            .then((ok) {
              if (!ok) failedAliases.add(device.alias);
            }),
      );
    }
    await Future.wait(futures);
    if (!mounted) return;

    if (failedAliases.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.unreachableDevices(failedAliases.join(', ')))),
      );
    } else {
      messenger.showSnackBar(SnackBar(content: Text(s.filesSent)));
    }

    setState(() {
      _status = _SendStatus.idle;
      _files.clear();
      _activeSessionIds = {};
      _recipientCount = 0;
    });
  }

  String? _guessMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.zip')) return 'application/zip';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canInteract = _status == _SendStatus.idle;
    final isPicking = ref.watch(filePickerBusyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.quickSend)),
      body: DropTarget(
        // Guarded to this tab only — see the matching comment in
        // DeviceListPage._wrapWithDropTarget for why (IndexedStack keeps
        // every tab's DropTarget mounted, so an unguarded drop fires all of
        // them at once).
        onDragEntered: (_) {
          if (ref.read(homeTabProvider) != 2 || !canInteract) return;
          setState(() => _isDragging = true);
        },
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          if (ref.read(homeTabProvider) != 2 || !canInteract) return;
          setState(() => _isDragging = false);
          _addFiles(details.files.map((x) => File(x.path)));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.dropOrAddFiles,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (canInteract && _files.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setState(_files.clear),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: Text(s.clearAll),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _status == _SendStatus.sending
                    ? _buildSendingList(theme, s)
                    : (_files.isEmpty
                          ? _buildEmptyZone(theme, s)
                          : _buildFileList(theme)),
              ),
              const SizedBox(height: 24),
              if (canInteract) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isPicking ? null : _pickFiles,
                        icon: isPicking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_circle_outline),
                        label: Text(isPicking ? s.preparingFiles : s.addFile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: isPicking ? null : _pasteClipboard,
                      icon: const Icon(Icons.content_paste),
                      tooltip: s.paste,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _files.isEmpty || isPicking
                      ? null
                      : _selectRecipients,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(s.selectRecipientsBtn),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyZone(ThemeData theme, AppStrings s) {
    final scheme = theme.colorScheme;
    return DottedZone(
      active: _isDragging,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_file_outlined,
              size: 40,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.dropFilesHere,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(ThemeData theme) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final f = _files[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      f.displaySize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _files.removeAt(index)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSendingList(ThemeData theme, AppStrings s) {
    final sessions = ref
        .watch(quickTransfersProvider)
        .where((session) => _activeSessionIds.contains(session.sessionId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              _recipientCount > 1
                  ? '${s.sendingFiles} ($_recipientCount)'
                  : s.sendingFiles,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: _files.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final file = _files[index];
              // Average progress across every recipient still receiving this
              // file — one file can have several in-flight sessions at once
              // when broadcasting to multiple recipients.
              final matching = sessions.where((s2) => s2.fileName == file.name);
              final progress = matching.isEmpty
                  ? 0.0
                  : matching.map((s2) => s2.progress).reduce((a, b) => a + b) /
                        matching.length;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for picking one or more recipients for the Send tab's own
/// flow. Separate from QuickSendSheet's recipient step so changes here can't
/// affect Nearby's drag-drop or long-press-a-device send paths.
class _RecipientPickerSheet extends ConsumerStatefulWidget {
  const _RecipientPickerSheet();

  @override
  ConsumerState<_RecipientPickerSheet> createState() =>
      _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends ConsumerState<_RecipientPickerSheet> {
  final Set<String> _selectedFingerprints = {};

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(discoveryControllerProvider);
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add_alt, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    s.selectRecipients,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: devices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          s.noDevicesFound,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final isSelected = _selectedFingerprints.contains(
                            device.fingerprint,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedFingerprints.add(device.fingerprint);
                              } else {
                                _selectedFingerprints.remove(
                                  device.fingerprint,
                                );
                              }
                            }),
                            title: Text(device.alias),
                            secondary: CircleAvatar(
                              child: Icon(
                                device.deviceType == 'mobile'
                                    ? Icons.phone_android
                                    : Icons.computer,
                              ),
                            ),
                            dense: true,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _selectedFingerprints.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        devices
                            .where(
                              (d) =>
                                  _selectedFingerprints.contains(d.fingerprint),
                            )
                            .toList(),
                      ),
                icon: const Icon(Icons.send),
                label: Text(s.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed-border drop zone used by the Send tab's empty state.
class DottedZone extends StatelessWidget {
  const DottedZone({super.key, required this.child, this.active = false});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.06)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Center(child: child),
    );
  }
}
