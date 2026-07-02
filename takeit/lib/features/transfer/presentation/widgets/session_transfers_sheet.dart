import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../domain/entities/transfer_session.dart';
import '../providers/session_transfers_provider.dart';
import '../providers/transfer_provider.dart';
import '../../../quick_send/presentation/providers/quick_send_provider.dart';

class SessionTransfersSheet extends ConsumerWidget {
  const SessionTransfersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(sessionTransfersProvider);
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    final active = all.where((t) => t.isActive).toList();
    final done = all.where((t) => t.isCompleted).toList();
    final failed = all.where((t) => t.isFailed).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.swap_vert, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    s.sessionTransfersTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${all.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: all.isEmpty
                  ? Center(
                      child: Text(
                        s.noTransfersYet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (active.isNotEmpty)
                          _SectionHeader(
                            label: '${s.activeSection} (${active.length})',
                          ),
                        ...active.map((t) => _TransferRow(view: t)),
                        if (done.isNotEmpty)
                          _SectionHeader(label: s.completedSection),
                        ...done.map((t) => _TransferRow(view: t)),
                        if (failed.isNotEmpty)
                          _SectionHeader(label: s.failedSection),
                        ...failed.map((t) => _TransferRow(view: t)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  final SessionTransferView view;
  const _TransferRow({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final session = view.session;
    final isOutgoing = session.direction == TransferDirection.sending;

    Color statusColor;
    IconData statusIcon;
    if (view.isActive) {
      statusColor = theme.colorScheme.primary;
      statusIcon = isOutgoing ? Icons.upload_rounded : Icons.download_rounded;
    } else if (view.isCompleted) {
      statusColor = const Color(0xFF27AE60);
      statusIcon = Icons.check_circle;
    } else {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.error_outline;
    }

    final canOpen =
        view.isCompleted &&
        session.savePath != null &&
        session.savePath!.isNotEmpty;

    return InkWell(
      onTap: canOpen ? () => _openFile(context, session.savePath!, s) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(s),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (view.isActive) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: session.progress > 0 ? session.progress : null,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (view.isActive)
              IconButton(
                onPressed: () => _cancel(ref),
                icon: const Icon(Icons.close),
                tooltip: s.cancel,
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.error,
              )
            else if (view.isFailed && _canRetry(ref))
              IconButton(
                onPressed: () => _retry(ref),
                icon: const Icon(Icons.refresh),
                tooltip: s.retry,
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.primary,
              )
            else if (canOpen)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(AppStrings s) {
    final session = view.session;
    final sizeMb = (session.fileSize / (1024 * 1024)).toStringAsFixed(1);
    final dir = session.direction == TransferDirection.sending
        ? s.sending
        : s.receiving;
    if (session.status == TransferStatus.pending &&
        session.direction == TransferDirection.sending) {
      return '${s.statusPending} · $sizeMb MB · ${session.senderAlias}';
    }
    if (view.isActive && session.fileSize > 0 && session.progress > 0) {
      final pct = (session.progress * 100).toStringAsFixed(0);
      return '$dir · $pct% · $sizeMb MB';
    }
    return '$dir · $sizeMb MB · ${session.senderAlias}';
  }

  void _cancel(WidgetRef ref) {
    if (view.origin == TransferOrigin.room) {
      ref.read(transferProvider.notifier).cancelSession(view.sessionId);
    } else {
      ref.read(quickTransfersProvider.notifier).cancelSession(view.sessionId);
    }
  }

  bool _canRetry(WidgetRef ref) {
    if (view.session.direction != TransferDirection.sending) return false;
    if (view.session.status != TransferStatus.failed) return false;
    if (view.origin == TransferOrigin.room) {
      return ref.read(transferProvider.notifier).canRetry(view.sessionId);
    } else {
      return ref.read(quickTransfersProvider.notifier).canRetry(view.sessionId);
    }
  }

  void _retry(WidgetRef ref) {
    if (view.origin == TransferOrigin.room) {
      ref.read(transferProvider.notifier).retrySession(view.sessionId);
    } else {
      ref.read(quickTransfersProvider.notifier).retrySession(view.sessionId);
    }
  }

  Future<void> _openFile(
    BuildContext context,
    String path,
    AppStrings s,
  ) async {
    final file = File(path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fileNotFound)));
      }
      return;
    }
    await OpenFilex.open(path);
  }
}
