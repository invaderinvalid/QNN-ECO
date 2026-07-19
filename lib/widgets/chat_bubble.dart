import 'package:flutter/material.dart';

import '../core/models/chat_entry.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = entry.role == 'user';
    final isError = entry.role == 'error';
    final background = isError
        ? colors.errorContainer
        : isUser
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = isError
        ? colors.onErrorContainer
        : isUser
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          entry.content.isEmpty && entry.role == 'assistant'
              ? 'Thinking…'
              : entry.content,
          style: TextStyle(color: foreground),
        ),
      ),
    );
  }
}
