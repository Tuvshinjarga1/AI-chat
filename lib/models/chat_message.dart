import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String text;
  final String sender; // 'user' or 'bot'
  final DateTime timestamp;
  final String? sessionId;
  final bool isTyping;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.sessionId,
    this.isTyping = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      sender: data['sender'] ?? 'bot',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      sessionId: data['sessionId'],
      isTyping: data['isTyping'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'sender': sender,
      'timestamp': Timestamp.fromDate(timestamp),
      'sessionId': sessionId,
      'isTyping': isTyping,
    };
  }
}
