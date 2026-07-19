class ChatEntry {
  const ChatEntry({required this.role, required this.content});

  final String role;
  final String content;

  ChatEntry copyWith({String? content}) {
    return ChatEntry(role: role, content: content ?? this.content);
  }
}
