import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/transfer_record.dart';
import '../providers/history_provider.dart';

enum HistoryFilter { all, video, audio, pdf, clipboard, text }

enum DirectionFilter { all, sent, received }

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  HistoryFilter _filter = HistoryFilter.all;
  DirectionFilter _direction = DirectionFilter.all;

  static const _pageSize = 20;
  int _visibleCount = _pageSize;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final allRecords = ref.read(historyProvider);
    final filtered = _applyFilter(allRecords);
    if (_visibleCount < filtered.length) {
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(0, filtered.length);
      });
    }
  }

  void _resetPagination() {
    _visibleCount = _pageSize;
  }

  List<TransferRecord> _applyFilter(List<TransferRecord> records) {
    // Direction filter first
    var filtered = switch (_direction) {
      DirectionFilter.all => records,
      DirectionFilter.sent =>
        records
            .where(
              (r) => r.direction == 'sent' || r.direction == 'clipboard_sent',
            )
            .toList(),
      DirectionFilter.received =>
        records
            .where(
              (r) =>
                  r.direction == 'received' ||
                  r.direction == 'clipboard_received',
            )
            .toList(),
    };

    // Type filter
    return switch (_filter) {
      HistoryFilter.all => filtered,
      HistoryFilter.clipboard =>
        filtered.where((r) => r.fileMimeType == 'text/clipboard').toList(),
      HistoryFilter.text =>
        filtered
            .where(
              (r) =>
                  r.fileMimeType != null &&
                  r.fileMimeType!.startsWith('text/') &&
                  r.fileMimeType != 'text/clipboard',
            )
            .toList(),
      HistoryFilter.video =>
        filtered
            .where(
              (r) =>
                  r.fileMimeType != null &&
                  r.fileMimeType!.startsWith('video/'),
            )
            .toList(),
      HistoryFilter.audio =>
        filtered
            .where(
              (r) =>
                  r.fileMimeType != null &&
                  r.fileMimeType!.startsWith('audio/'),
            )
            .toList(),
      HistoryFilter.pdf =>
        filtered.where((r) => r.fileMimeType == 'application/pdf').toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final allRecords = ref.watch(historyProvider);
    final records = _applyFilter(allRecords);
    final visibleRecords = records.take(_visibleCount).toList();
    final hasMore = _visibleCount < records.length;
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.transferHistory),
        actions: [
          if (allRecords.isNotEmpty)
            IconButton(
              onPressed: () => _confirmClear(context, ref),
              icon: const Icon(Icons.delete_outline),
              tooltip: s.clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          // Direction dropdown + Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DirectionFilter>(
                      value: _direction,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        DropdownMenuItem(
                          value: DirectionFilter.all,
                          child: Text(
                            s.filterAll,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        DropdownMenuItem(
                          value: DirectionFilter.sent,
                          child: Text(
                            s.filterSent,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        DropdownMenuItem(
                          value: DirectionFilter.received,
                          child: Text(
                            s.filterReceived,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _direction = v;
                            _resetPagination();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: s.all,
                  icon: Icons.list,
                  selected: _filter == HistoryFilter.all,
                  onTap: () => setState(() {
                    _filter = HistoryFilter.all;
                    _resetPagination();
                  }),
                ),
                _FilterChip(
                  label: 'Video',
                  icon: Icons.videocam,
                  selected: _filter == HistoryFilter.video,
                  onTap: () => setState(() {
                    _filter = HistoryFilter.video;
                    _resetPagination();
                  }),
                ),
                _FilterChip(
                  label: 'Audio',
                  icon: Icons.audiotrack,
                  selected: _filter == HistoryFilter.audio,
                  onTap: () => setState(() {
                    _filter = HistoryFilter.audio;
                    _resetPagination();
                  }),
                ),
                _FilterChip(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf,
                  selected: _filter == HistoryFilter.pdf,
                  onTap: () => setState(() {
                    _filter = HistoryFilter.pdf;
                    _resetPagination();
                  }),
                ),
                _FilterChip(
                  label: s.textFilter,
                  icon: Icons.text_snippet,
                  selected: _filter == HistoryFilter.text,
                  onTap: () => setState(() {
                    _filter = HistoryFilter.text;
                    _resetPagination();
                  }),
                ),
                _FilterChip(
                  label: 'Clipboard',
                  icon: Icons.content_paste,
                  selected: _filter == HistoryFilter.clipboard,
                  onTap: () => setState(() {
                    _filter = HistoryFilter.clipboard;
                    _resetPagination();
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Records list
          Expanded(
            child: ClipRect(
              child: Material(
                color: Colors.transparent,
                child: records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              s.noTransfersYet,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: visibleRecords.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= visibleRecords.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final record = visibleRecords[index];
                          if (record.fileMimeType == 'text/clipboard') {
                            return _ClipboardRecordTile(
                              record: record,
                              onDelete: () => _deleteRecord(record.id),
                            );
                          }
                          return _RecordTile(
                            record: record,
                            onDelete: () => _deleteRecord(record.id),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.clearHistoryConfirm),
        content: Text(s.clearHistoryMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearHistory();
              Navigator.pop(ctx);
            },
            child: Text(s.clear),
          ),
        ],
      ),
    );
  }

  void _deleteRecord(String id) {
    final s = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteFromHistory),
        content: Text(s.deleteRecordConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(historyProvider.notifier).deleteRecord(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.recordDeleted),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unselectedColor = theme.brightness == Brightness.light
        ? theme.colorScheme.onSurfaceVariant
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : unselectedColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : unselectedColor,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: theme.brightness == Brightness.light
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.white.withValues(alpha: 0.15),
        selectedColor: theme.colorScheme.primaryContainer,
        showCheckmark: false,
      ),
    );
  }
}

class _ClipboardRecordTile extends StatelessWidget {
  final TransferRecord record;
  final VoidCallback onDelete;

  const _ClipboardRecordTile({required this.record, required this.onDelete});

  String get _fullText => record.savePath ?? record.fileName;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).copiedToClipboard),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final isSent = record.direction == 'clipboard_sent';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + peer + direction + delete button
              Row(
                children: [
                  Icon(
                    isSent ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: isSent
                        ? const Color(0xFFE67E22)
                        : const Color(0xFF27AE60),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${isSent ? 'to' : 'from'} ${record.peerAlias}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDate(record.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.content_copy,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(s.deleteFromHistory),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Clipboard content preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fullText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _RecordTile extends StatelessWidget {
  final TransferRecord record;
  final VoidCallback onDelete;

  const _RecordTile({required this.record, required this.onDelete});

  void _openFile(BuildContext context) {
    final s = AppStrings.of(context);
    final path = record.savePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.filePathNotAvailable)));
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.fileNotFound)));
      return;
    }
    OpenFilex.open(path);
  }

  Future<void> _openFolder(BuildContext context) async {
    final s = AppStrings.of(context);
    final path = record.savePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.filePathNotAvailable)));
      return;
    }
    final file = File(path);
    final dir = file.parent;
    if (!dir.existsSync()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.folderNotFound)));
      return;
    }
    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', path.replaceAll('/', '\\')]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [dir.path]);
    } else {
      // Android / iOS: trailing slash forces OpenFilex to dispatch the path
      // as a directory (trick borrowed from LocalSend). Without it, Android
      // treats the last segment as a file and silently fails.
      var folderPath = dir.path;
      if (!folderPath.endsWith('/')) folderPath = '$folderPath/';
      final result = await OpenFilex.open(folderPath);
      if (!context.mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dir.path),
            action: SnackBarAction(
              label: s.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: dir.path));
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final isSent =
        record.direction == 'sent' || record.direction == 'clipboard_sent';

    return ListTile(
      onTap: () => _openFile(context),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getFileColor(record.fileMimeType),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getFileIcon(record.fileMimeType),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        record.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatFileSize(record.fileSize)} ${isSent ? 'to' : 'from'} ${record.peerAlias}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                isSent ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: isSent
                    ? const Color(0xFFE67E22)
                    : const Color(0xFF27AE60),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(record.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onSelected: (value) {
              switch (value) {
                case 'open':
                  _openFile(context);
                case 'location':
                  _openFolder(context);
                case 'info':
                  _showInfo(context);
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 18),
                    const SizedBox(width: 8),
                    Text(s.openFile),
                  ],
                ),
              ),
              if (record.savePath != null && record.savePath!.isNotEmpty)
                PopupMenuItem(
                  value: 'location',
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, size: 18),
                      const SizedBox(width: 8),
                      Text(s.openFileLocation),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(s.info),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.deleteFromHistory,
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

  void _showInfo(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final isSent =
        record.direction == 'sent' || record.direction == 'clipboard_sent';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                record.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(theme, s.transferDate, _formatDateTime(record.timestamp)),
            _infoRow(theme, s.transferSize, formatFileSize(record.fileSize)),
            _infoRow(theme, s.transferPeer, record.peerAlias),
            _infoRow(
              theme,
              s.transferDirection,
              isSent ? s.directionSent : s.directionReceived,
            ),
            if (record.savePath != null && record.savePath!.isNotEmpty)
              _infoRow(theme, s.transferSavePath, record.savePath!),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.close)),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String? mimeType) {
    if (mimeType == null) return const Color(0xFF3B424C);
    if (mimeType.startsWith('image/')) return const Color(0xFF27AE60);
    if (mimeType.startsWith('video/')) return const Color(0xFF8E44AD);
    if (mimeType.startsWith('audio/')) return const Color(0xFFE67E22);
    if (mimeType == 'application/pdf') return const Color(0xFFE74C3C);
    return const Color(0xFF3B424C);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
