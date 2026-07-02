import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/l10n/app_strings.dart';

class ClipboardPopup extends StatelessWidget {
  final String senderAlias;
  final String content;

  const ClipboardPopup({
    super.key,
    required this.senderAlias,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.content_paste, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(s.clipboardFrom(senderAlias))),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.close),
        ),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.copiedToClipboard),
                duration: const Duration(seconds: 1),
              ),
            );
            Navigator.pop(context);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text(s.copy),
        ),
      ],
    );
  }
}
