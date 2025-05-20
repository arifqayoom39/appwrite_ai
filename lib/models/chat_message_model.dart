class ChatMessageModel {
  final String id;
  final String chatId;
  final String role; // 'user', 'assistant', or 'system'
  final String content;
  final String timestamp;

  ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['\$id'] ?? map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'role': role,
      'content': content,
      'timestamp': timestamp,
    };
  }
}
