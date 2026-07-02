import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/services/transfer_queue_service.dart';
import '../../../../core/utils/format_utils.dart';

class TransferApprovalSheet extends ConsumerStatefulWidget {
  final TransferBatch batch;

  const TransferApprovalSheet({super.key, required this.batch});

  @override
  ConsumerState<TransferApprovalSheet> createState() =>
      _TransferApprovalSheetState();
}

class _TransferApprovalSheetState extends ConsumerState<TransferApprovalSheet> {
  bool _acting = false;
  late final List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.batch.files.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final batch = widget.batch;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final queueCount = ref.watch(queueDepthProvider);

    // Auto-dismiss if this batch was cleared (e.g., sender went offline).
    final currentApproval = ref.watch(currentApprovalProvider);
    if ((currentApproval == null || currentApproval.batchId != batch.batchId) &&
        !_acting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }

    final sourceLabel = batch.source == TransferSource.room
        ? s.roomSource
        : s.quickSendSource;

    final checkedCount = _selected.where((b) => b).length;
    final totalSize = batch.files.fold<int>(0, (sum, f) => sum + f.fileSize);

    final screenH = MediaQuery.of(context).size.height;
    final maxSheetH = screenH * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetH),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 16 + bottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (batch.files.length > 1)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      tooltip: s.selectAll,
                      iconSize: 28,
                      color: Colors.white,
                      splashRadius: 22,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _acting
                          ? null
                          : () => setState(
                              () => _selected.fillRange(
                                0,
                                _selected.length,
                                true,
                              ),
                            ),
                      icon: const Icon(Icons.select_all),
                    ),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    s.fileTransfer,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (batch.files.length > 1)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      tooltip: s.selectNone,
                      iconSize: 28,
                      color: Colors.white,
                      splashRadius: 22,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _acting
                          ? null
                          : () => setState(
                              () => _selected.fillRange(
                                0,
                                _selected.length,
                                false,
                              ),
                            ),
                      icon: const Icon(Icons.deselect),
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: batch.source == TransferSource.quick
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$sourceLabel — ${batch.senderAlias} • ${batch.files.length} • ${formatFileSize(totalSize)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: batch.source == TransferSource.quick
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (batch.files.length == 1)
                      _FileRow(
                        name: batch.files[0].fileName,
                        size: batch.files[0].fileSize,
                        mimeType: batch.files[0].fileMimeType,
                        checked: _selected[0],
                        onChanged: _acting
                            ? null
                            : (v) => setState(() => _selected[0] = v ?? false),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final available = constraints.maxWidth;
                          const cardW = 110.0;
                          const cardH = 104.0;
                          const spacing = 8.0;
                          final total = batch.files.length;

                          // How many cards fit horizontally on one row.
                          final capPerRow =
                              ((available + spacing) / (cardW + spacing))
                                  .floor()
                                  .clamp(1, total);

                          Widget cardAt(int i) => SizedBox(
                            width: cardW,
                            height: cardH,
                            child: _FileCard(
                              name: batch.files[i].fileName,
                              size: batch.files[i].fileSize,
                              mimeType: batch.files[i].fileMimeType,
                              checked: _selected[i],
                              onTap: _acting
                                  ? null
                                  : () => setState(
                                      () => _selected[i] = !_selected[i],
                                    ),
                            ),
                          );

                          Widget rowOf(List<int> indices) {
                            final children = <Widget>[];
                            for (var k = 0; k < indices.length; k++) {
                              if (k > 0) {
                                children.add(const SizedBox(width: spacing));
                              }
                              children.add(cardAt(indices[k]));
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: children,
                            );
                          }

                          // Case 1: everything fits in a single row → center it.
                          if (total <= capPerRow) {
                            return SizedBox(
                              height: cardH,
                              child: Center(
                                child: rowOf(List.generate(total, (i) => i)),
                              ),
                            );
                          }

                          // Case 2: fill top row first up to capacity, rest on bottom.
                          final topCount = (total <= 2 * capPerRow)
                              ? capPerRow
                              : (total + 1) ~/ 2; // balanced when overflow
                          final top = List.generate(topCount, (i) => i);
                          final bottom = List.generate(
                            total - topCount,
                            (i) => topCount + i,
                          );

                          final needsScroll =
                              topCount > capPerRow || bottom.length > capPerRow;
                          final rowsWidget = Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              rowOf(top),
                              const SizedBox(height: spacing),
                              rowOf(bottom),
                            ],
                          );

                          if (!needsScroll) {
                            return SizedBox(
                              height: cardH * 2 + spacing,
                              child: Center(child: rowsWidget),
                            );
                          }

                          return SizedBox(
                            height: cardH * 2 + spacing,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.trackpad,
                                      PointerDeviceKind.stylus,
                                    },
                                    scrollbars: true,
                                  ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                child: rowsWidget,
                              ),
                            ),
                          );
                        },
                      ),

                    if (queueCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.queue,
                              size: 14,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.filesQueued(queueCount),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _acting = true);
                        ref.read(transferQueueProvider).declineAllCurrent();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(s.decline),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: FilledButton.icon(
                      onPressed: checkedCount == 0
                          ? null
                          : () {
                              setState(() => _acting = true);
                              ref
                                  .read(transferQueueProvider)
                                  .resolveCurrent(_selected);
                              Navigator.of(context).pop();
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        checkedCount == batch.files.length
                            ? s.accept
                            : s.acceptSelected(checkedCount),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String name;
  final int size;
  final String? mimeType;
  final bool checked;
  final ValueChanged<bool?>? onChanged;

  const _FileRow({
    required this.name,
    required this.size,
    required this.mimeType,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: onChanged),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getFileColor(mimeType),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(mimeType),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    formatFileSize(size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
}

/// Compact card used in the horizontally-scrolling 2-row grid for multi-file
/// approvals. Tap to toggle; a check badge shows the selection state.
class _FileCard extends StatelessWidget {
  final String name;
  final int size;
  final String? mimeType;
  final bool checked;
  final VoidCallback? onTap;

  const _FileCard({
    required this.name,
    required this.size,
    required this.mimeType,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: checked
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: checked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _colorFor(mimeType),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _iconFor(mimeType),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    formatFileSize(size),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: checked
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: checked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: 1.5,
                    ),
                  ),
                  child: checked
                      ? Icon(
                          Icons.check,
                          size: 12,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String? m) {
    if (m == null) return Icons.insert_drive_file;
    if (m.startsWith('image/')) return Icons.image;
    if (m.startsWith('video/')) return Icons.videocam;
    if (m.startsWith('audio/')) return Icons.audiotrack;
    if (m == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Color _colorFor(String? m) {
    if (m == null) return const Color(0xFF3B424C);
    if (m.startsWith('image/')) return const Color(0xFF27AE60);
    if (m.startsWith('video/')) return const Color(0xFF8E44AD);
    if (m.startsWith('audio/')) return const Color(0xFFE67E22);
    if (m == 'application/pdf') return const Color(0xFFE74C3C);
    return const Color(0xFF3B424C);
  }
}
