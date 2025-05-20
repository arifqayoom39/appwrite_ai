class ChatSessionModel {
  final String id;
  final String userId;
  final String title;
  final String createdAt;
  final String updatedAt;
  final String modelId;

  ChatSessionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.modelId,
  });

  factory ChatSessionModel.fromMap(Map<String, dynamic> map) {
    return ChatSessionModel(
      id: map['\$id'] ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'New Conversation',
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
      modelId: map['modelId'] ?? 'meta-llama/llama-3.1-8b-instruct:free',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'modelId': modelId,
    };
  }

  // Generate a title from the first message content
  static String generateTitleFromContent(String content) {
    // Limit title to first 30 characters or first sentence
    if (content.length <= 30) {
      return content;
    }
    
    // Try to find the end of the first sentence
    final firstSentenceEnd = content.indexOf('.');
    if (firstSentenceEnd > 0 && firstSentenceEnd < 50) {
      return content.substring(0, firstSentenceEnd + 1);
    }
    
    // Otherwise just take first 30 chars and add ellipsis
    return '${content.substring(0, 30)}...';
  }
}
