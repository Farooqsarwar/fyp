class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String? itemId;
  final String? itemType;
  final String content;
  final bool isRead;
  final bool isSystemMessage;
  final DateTime createdAt;
  final String? photoUrl; // Add this line

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.itemId,
    this.itemType,
    required this.content,
    this.isRead = false,
    this.isSystemMessage = false,
    required this.createdAt,
    this.photoUrl, // Add this line
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      itemId: json['item_id'],
      itemType: json['item_type'],
      content: json['content'],
      isRead: json['is_read'] ?? false,
      isSystemMessage: json['is_system_message'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      photoUrl: json['photo_url'], // Add this line
    );
  }
}