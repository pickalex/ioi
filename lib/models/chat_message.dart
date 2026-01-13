enum ChatMessageType { user, system }

class ChatMessage {
  final String sender;
  final String content;
  final ChatMessageType type;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.content,
    this.type = ChatMessageType.user,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
