import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double? _progress;
  bool _installing = false;
  String? _filePath;
  String? _error;
  final _cancelToken = CancelToken();

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _error = null;
    });

    try {
      final path = await UpdateService.download(
        widget.info,
        (p) => setState(() => _progress = p),
        _cancelToken,
      );
      setState(() {
        _filePath = path;
        _progress = 1.0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _install() async {
    final path = _filePath;
    if (path == null) return;
    setState(() => _installing = true);
    try {
      await UpdateService.install(path);
      // On Android/Linux the app stays open, close dialog
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final isLinux = Platform.isLinux;

    String installLabel;
    if (isLinux) {
      installLabel = 'Klasörü Aç';
    } else if (isMobile) {
      installLabel = 'Yükle';
    } else {
      installLabel = 'Kur ve Yeniden Başlat';
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.system_update_alt_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Güncelleme Mevcut'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'v${widget.info.currentVersion}  →  v${widget.info.version}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.info.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.info.changelog.length > 300
                    ? '${widget.info.changelog.substring(0, 300)}…'
                    : widget.info.changelog,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                _filePath != null
                    ? 'İndirme tamamlandı'
                    : '${((_progress ?? 0) * 100).toStringAsFixed(0)}% indiriliyor…',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _installing
              ? null
              : () {
                  if (!_cancelToken.isCancelled) _cancelToken.cancel();
                  Navigator.of(context).pop();
                },
          child: const Text('Sonra'),
        ),
        if (_filePath == null)
          FilledButton.icon(
            onPressed: _progress != null ? null : _download,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('İndir'),
          )
        else
          FilledButton.icon(
            onPressed: _installing ? null : _install,
            icon: _installing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(installLabel),
          ),
      ],
    );
  }
}
