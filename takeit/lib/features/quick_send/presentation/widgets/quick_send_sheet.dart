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
import '../../../room/presentation/providers/room_provider.dart';
import '../providers/quick_send_provider.dart';

/// An item queued for sending: either a file or a text snippet.
class _SendItem {
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? text;

  bool get isFile => filePath != null;
  bool get isText => text != null;

  String get displayName => isFile ? fileName! : 'Text';
  String get displaySize {
    if (isText) return '${text!.length} chars';
    final bytes = fileSize ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  _SendItem.file({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  }) : text = null;

  _SendItem.textContent(this.text)
    : filePath = null,
      fileName = null,
      fileSize = null;
}

class QuickSendSheet extends ConsumerStatefulWidget {
  final Device? preselectedDevice;

  /// Pre-filled files (e.g. from drag & drop on device list).
  final List<File>? initialFiles;

  const QuickSendSheet({super.key, this.preselectedDevice, this.initialFiles});

  @override
  ConsumerState<QuickSendSheet> createState() => _QuickSendSheetState();
}

const int _kMaxItems = 10;

class _QuickSendSheetState extends ConsumerState<QuickSendSheet> {
  final List<_SendItem> _items = [];
  final _textController = TextEditingController();
  bool _isDragging = false;
  bool _showRecipients = false;
  final Set<String> _selectedFingerprints = {};

  @override
  void initState() {
    super.initState();
    if (widget.preselectedDevice != null) {
      _selectedFingerprints.add(widget.preselectedDevice!.fingerprint);
    }
    if (widget.initialFiles != null) {
      for (final file in widget.initialFiles!) {
        if (file.existsSync()) {
          _items.add(
            _SendItem.file(
              filePath: file.path,
              fileName: file.uri.pathSegments.last,
              fileSize: file.lengthSync(),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: _showRecipients
              ? _buildRecipientStep(theme, s)
              : _buildContentStep(theme, s),
        ),
      ),
    );
  }

  // ─── Step 1: Content selection ───

  Widget _buildContentStep(ThemeData theme, AppStrings s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.send_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              s.quickSend,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_items.length} ${s.itemsReady}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Items list (TOP) — shows what's queued for sending
        Flexible(
          child: _items.isEmpty
              ? _buildEmptyItemsHint(theme, s)
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) =>
                      _buildItemRow(_items[index], index, theme),
                ),
        ),
        const SizedBox(height: 12),

        // Drop area + add row
        DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) {
            setState(() => _isDragging = false);
            for (final xfile in details.files) {
              if (_items.length >= _kMaxItems) {
                _showLimitToast();
                break;
              }
              final file = File(xfile.path);
              if (file.existsSync()) {
                setState(() {
                  _items.add(
                    _SendItem.file(
                      filePath: xfile.path,
                      fileName: xfile.name,
                      fileSize: file.lengthSync(),
                    ),
                  );
                });
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _isDragging
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isDragging
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: _isDragging ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDragging
                      ? Icons.file_download
                      : Icons.cloud_upload_outlined,
                  size: 26,
                  color: _isDragging
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isDragging ? s.dropFilesHere : s.dropOrAddFiles,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _isDragging
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    tooltip: s.addFile,
                    color: theme.colorScheme.primary,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    onPressed: _pasteClipboard,
                    icon: const Icon(Icons.content_paste),
                    tooltip: s.paste,
                    color: theme.colorScheme.primary,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Text input with "Ekle" button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: s.quickTextHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _addTypedText(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: FilledButton.tonalIcon(
                onPressed: _addTypedText,
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.addButton),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Next button
        FilledButton.icon(
          onPressed: _items.isEmpty
              ? null
              : () => setState(() => _showRecipients = true),
          icon: const Icon(Icons.arrow_forward),
          label: Text(s.selectRecipientsBtn),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyItemsHint(ThemeData theme, AppStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 36,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            s.nothingAddedYet,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(_SendItem item, int index, ThemeData theme) {
    final isText = item.isText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isText
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isText ? Icons.notes : Icons.insert_drive_file_outlined,
              size: 18,
              color: isText
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isText
                      ? (item.text!.length > 60
                            ? '${item.text!.substring(0, 60)}…'
                            : item.text!)
                      : item.fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  item.displaySize,
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
            onPressed: () => setState(() => _items.removeAt(index)),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _addTypedText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(_SendItem.textContent(text));
      _textController.clear();
    });
  }

  // ─── Step 2: Recipient selection ───

  Widget _buildRecipientStep(ThemeData theme, AppStrings s) {
    final devices = ref.watch(discoveryControllerProvider);
    final room = ref.watch(roomProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with back
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showRecipients = false),
              icon: const Icon(Icons.arrow_back),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Text(
              s.selectRecipients,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_items.length} ${s.itemsReady}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Device list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isSelected = _selectedFingerprints.contains(
                device.fingerprint,
              );
              final isInRoom =
                  room != null &&
                  room.members.any((m) => m.fingerprint == device.fingerprint);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedFingerprints.add(device.fingerprint);
                    } else {
                      _selectedFingerprints.remove(device.fingerprint);
                    }
                  });
                },
                title: Text(device.alias),
                subtitle: isInRoom
                    ? Text(
                        s.inRoom,
                        style: TextStyle(
                          color: theme.colorScheme.tertiary,
                          fontSize: 12,
                        ),
                      )
                    : null,
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

        // Send button
        FilledButton.icon(
          onPressed: _selectedFingerprints.isEmpty
              ? null
              : () => _sendAll(devices),
          icon: const Icon(Icons.send),
          label: Text(s.send),
        ),
      ],
    );
  }

  // ─── Actions ───

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    bool hitLimit = false;
    setState(() {
      for (final file in result.files) {
        if (_items.length >= _kMaxItems) {
          hitLimit = true;
          break;
        }
        if (file.path != null) {
          _items.add(
            _SendItem.file(
              filePath: file.path!,
              fileName: file.name,
              fileSize: file.size,
            ),
          );
        }
      }
    });
    if (hitLimit) _showLimitToast();
  }

  Future<void> _pasteClipboard() async {
    if (_items.length >= _kMaxItems) {
      _showLimitToast();
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _items.add(_SendItem.textContent(data.text!.trim()));
      });
    }
  }

  void _showLimitToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Max $_kMaxItems')));
  }

  Future<void> _sendAll(List<Device> devices) async {
    final selectedDevices = devices
        .where((d) => _selectedFingerprints.contains(d.fingerprint))
        .toList();
    if (selectedDevices.isEmpty) return;

    final notifier = ref.read(quickTransfersProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final s = AppStrings.of(context);

    // Rule: a single text snippet → send as popup; otherwise everything as files.
    final isSingleTextOnly = _items.length == 1 && _items.first.isText;
    final singleText = isSingleTextOnly ? _items.first.text : null;
    final items = List<_SendItem>.from(_items);

    // Close the sheet immediately. The transfer keeps running in the
    // background (driven by the provider, tracked in the transfers UI), so the
    // popup never lingers waiting for the recipient to accept + upload.
    Navigator.pop(context);

    final failedAliases = <String>{};
    if (singleText != null) {
      for (final device in selectedDevices) {
        final ok = await notifier.sendText(target: device, content: singleText);
        if (!ok) failedAliases.add(device.alias);
      }
    } else {
      // Materialize all items into file paths (text → temp .txt).
      final toSend = <_FileToSend>[];
      for (final item in items) {
        if (item.isFile) {
          toSend.add(
            _FileToSend(
              filePath: item.filePath!,
              fileName: item.fileName!,
              fileSize: item.fileSize!,
              mimeType: _guessMime(item.fileName!),
            ),
          );
        } else if (item.isText) {
          toSend.add(await _writeTextToTempFile(item.text!));
        }
      }

      final batchFiles = [
        for (final f in toSend)
          QuickOutgoingFile(
            filePath: f.filePath,
            fileName: f.fileName,
            fileSize: f.fileSize,
            fileMimeType: f.mimeType,
          ),
      ];
      for (final device in selectedDevices) {
        final ok = await notifier.sendFiles(target: device, files: batchFiles);
        if (!ok) failedAliases.add(device.alias);
      }
    }

    if (failedAliases.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.unreachableDevices(failedAliases.join(', ')))),
      );
    }
  }

  Future<_FileToSend> _writeTextToTempFile(String content) async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    final fileName = 'clipboard_$stamp.txt';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content);
    final size = await file.length();
    return _FileToSend(
      filePath: file.path,
      fileName: fileName,
      fileSize: size,
      mimeType: 'text/plain',
    );
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
}

class _FileToSend {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String? mimeType;
  _FileToSend({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.mimeType,
  });
}
