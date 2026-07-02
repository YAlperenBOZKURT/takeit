import 'package:flutter/material.dart';
import '../../../../core/l10n/app_strings.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final VoidCallback onAttachmentTap;
  final VoidCallback? onPasteTap;
  final bool isSending;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onAttachmentTap,
    this.onPasteTap,
    this.isSending = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: widget.isSending ? null : widget.onAttachmentTap,
            icon: widget.isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          if (widget.onPasteTap != null)
            IconButton(
              onPressed: widget.onPasteTap,
              icon: const Icon(Icons.content_paste),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: AppStrings.of(context).clipboardShared,
            ),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: AppStrings.of(context).typeMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: _hasText ? _send : null,
            icon: const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}
