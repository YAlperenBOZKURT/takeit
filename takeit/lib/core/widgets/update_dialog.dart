import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Stage { idle, downloading, installing }

class _UpdateDialogState extends State<UpdateDialog> {
  _Stage _stage = _Stage.idle;
  double _progress = 0;
  String? _error;
  final _cancelToken = CancelToken();

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    super.dispose();
  }

  bool get _busy => _stage != _Stage.idle;

  /// Single tap does download → install back to back — the user shouldn't
  /// have to come back and press a second button once the file lands.
  Future<void> _updateNow() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
      _error = null;
    });

    try {
      final path = await UpdateService.download(
        widget.info,
        (p) => setState(() => _progress = p),
        _cancelToken,
      );
      if (!mounted) return;

      setState(() => _stage = _Stage.installing);
      await UpdateService.install(path);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    if (e is DioException && CancelToken.isCancel(e)) return '';
    final text = e.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.system_update_alt_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Güncelleme'),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni bir sürüm hazır.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'v${widget.info.currentVersion}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'v${widget.info.version}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null && _error!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _stage == _Stage.downloading && _progress > 0
                      ? _progress
                      : null,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _stage == _Stage.downloading
                    ? '%${(_progress * 100).toStringAsFixed(0)} indiriliyor'
                    : 'Kuruluyor…',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  if (!_cancelToken.isCancelled) _cancelToken.cancel();
                  Navigator.of(context).pop();
                },
          child: const Text('Sonra'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _updateNow,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(switch (_stage) {
            _Stage.idle => 'Güncelleyelim',
            _Stage.downloading => 'İndiriliyor',
            _Stage.installing => 'Kuruluyor',
          }),
        ),
      ],
    );
  }
}
