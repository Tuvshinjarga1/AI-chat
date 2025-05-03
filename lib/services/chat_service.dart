import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aichat/models/chat_message.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final _uuid = Uuid();

  // Save message to Firestore
  static Future<ChatMessage> saveMessage({
    required String userId,
    required String text,
    required String sender,
    String? sessionId,
  }) async {
    final messageRef = _firestore.collection('messages').doc();
    final timestamp = DateTime.now();

    final message = ChatMessage(
      id: messageRef.id,
      userId: userId,
      text: text,
      sender: sender,
      timestamp: timestamp,
      sessionId: sessionId ?? _uuid.v4(),
    );

    await messageRef.set(message.toMap());
    return message;
  }

  // Get chat history for a user
  static Stream<List<ChatMessage>> getChatHistory(String userId) {
    return _firestore
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  // Get chat sessions for a user
  static Future<List<Map<String, dynamic>>> getChatSessions(
      String userId) async {
    // Get all messages for this user
    final messagesQuery = await _firestore
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    // Extract unique session IDs and get first message of each session
    final Map<String, Map<String, dynamic>> sessions = {};

    for (var doc in messagesQuery.docs) {
      final message = ChatMessage.fromFirestore(doc);
      final sessionId = message.sessionId;

      if (sessionId != null && !sessions.containsKey(sessionId)) {
        // Find first message of this session
        sessions[sessionId] = {
          'sessionId': sessionId,
          'lastMessageTime': message.timestamp,
          'title': _generateSessionTitle(message.text),
        };
      }
    }

    // Convert to list and sort by time
    final sessionsList = sessions.values.toList();
    sessionsList.sort((a, b) => (b['lastMessageTime'] as DateTime)
        .compareTo(a['lastMessageTime'] as DateTime));

    return sessionsList;
  }

  // Get messages for a specific session
  static Stream<List<ChatMessage>> getSessionMessages(String sessionId) {
    return _firestore
        .collection('messages')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  // Delete a chat session and all its messages
  static Future<void> deleteSession(String sessionId) async {
    final batch = _firestore.batch();

    final messagesQuery = await _firestore
        .collection('messages')
        .where('sessionId', isEqualTo: sessionId)
        .get();

    for (var doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Search in Firestore for matching questions
  static Future<String?> searchInFirestore(String query) async {
    final snapshot = await _firestore.collection('questions').get();

    List<Map<String, dynamic>> matches = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final question = data['question'].toString().toLowerCase();
      final queryLower = query.toLowerCase();

      if (question == queryLower) {
        return data['answer'];
      }

      if (question.contains(queryLower)) {
        final score = queryLower.length / question.length;
        matches.add({
          'score': score,
          'answer': data['answer'],
        });
      }
    }

    matches
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    if (matches.isNotEmpty) {
      return matches.first['answer'];
    }

    return null;
  }

  // Ask Gemini AI for an answer
  static Future<String> askGemini(String query) async {
    const apiKey = 'AIzaSyBBsD6c_V4-oQGPCOdZZS-BHYK3O176QJY';
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final headers = {
      'Content-Type': 'application/json',
    };

    final body = jsonEncode({
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
                  "Дараах асуултад зөвхөн Монгол хэл дээр хариулаарай: $query"
            }
          ]
        }
      ]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['candidates'][0]['content']['parts'][0]['text'];
        return result;
      } else {
        print('Gemini error: ${response.body}');
        return "Gemini-с хариу авч чадсангүй.";
      }
    } catch (e) {
      return "Алдаа гарлаа: $e";
    }
  }

  // Generate a title for a chat session based on the first message
  static String _generateSessionTitle(String text) {
    // Use first 30 characters of text as title or truncate with ellipsis
    if (text.length <= 30) {
      return text;
    } else {
      return '${text.substring(0, 27)}...';
    }
  }

  // Save AI response to the question database
  static Future<void> saveQuestionAnswer({
    required String question,
    required String answer,
    List<String> tags = const ['gemini-generated'],
  }) async {
    await _firestore.collection('questions').add({
      'question': question,
      'answer': answer,
      'tags': tags,
      'createdAt': Timestamp.now(),
      'createdBy': 'system',
    });
  }

  // Get statistics for admin dashboard
  static Future<Map<String, dynamic>> getStats() async {
    final Map<String, dynamic> stats = {};

    // Total questions count
    final questionsSnapshot = await _firestore.collection('questions').get();
    stats['totalQuestions'] = questionsSnapshot.docs.length;

    // AI generated vs manual questions
    int aiGenerated = 0;
    for (var doc in questionsSnapshot.docs) {
      final data = doc.data();
      final tags = data['tags'] as List?;
      if (tags != null && tags.contains('gemini-generated')) {
        aiGenerated++;
      }
    }
    stats['aiGeneratedQuestions'] = aiGenerated;
    stats['manualQuestions'] = stats['totalQuestions'] - aiGenerated;

    // Total users
    final usersSnapshot = await _firestore.collection('users').get();
    stats['totalUsers'] = usersSnapshot.docs.length;

    // Total chat messages
    final messagesSnapshot = await _firestore.collection('messages').get();
    stats['totalMessages'] = messagesSnapshot.docs.length;

    // Recent activity (last 7 days)
    final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
    final recentMessagesSnapshot = await _firestore
        .collection('messages')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(oneWeekAgo))
        .get();
    stats['recentMessages'] = recentMessagesSnapshot.docs.length;

    return stats;
  }

  // Get messages for a specific session as a list (not stream)
  static Future<List<ChatMessage>> getSessionMessagesAsList(
      String sessionId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  // Delete all chat sessions for a user
  static Future<void> deleteAllUserSessions(String userId) async {
    try {
      // Get all messages for this user
      final messagesQuery = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: userId)
          .get();

      if (messagesQuery.docs.isEmpty) {
        return; // No messages to delete
      }

      // Firebase allows maximum 500 operations per batch
      // So we need to split into chunks if there are many messages
      final int batchSize = 450; // Leave some room for safety
      List<List<DocumentSnapshot>> chunks = [];

      for (var i = 0; i < messagesQuery.docs.length; i += batchSize) {
        final end = (i + batchSize < messagesQuery.docs.length)
            ? i + batchSize
            : messagesQuery.docs.length;
        chunks.add(messagesQuery.docs.sublist(i, end));
      }

      // Delete messages in batches
      for (var chunk in chunks) {
        final batch = _firestore.batch();
        for (var doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error deleting all chat sessions: $e');
      throw e;
    }
  }
}
