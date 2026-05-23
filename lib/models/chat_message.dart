enum ChatRole { user, assistant }

/// Single turn in a chat exchange. Two recognized authors only — system
/// prompts are owned by whoever drives the chat (e.g. ExerciseChatScreen)
/// and never appear in the in-memory message list.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final ChatRole role;
  final String content;

  Map<String, String> toOpenAiJson() => {
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'content': content,
  };

  @override
  bool operator ==(Object other) =>
      other is ChatMessage && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);
}
