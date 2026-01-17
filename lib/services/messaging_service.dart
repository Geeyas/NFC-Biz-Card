import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Message type enum
enum MessageType {
  text,
  image,
  card,
  system,
}

/// Chat message model
class ChatMessage {
  final String id;
  final String connectionId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final bool read;
  final String? imageUrl;
  final Map<String, dynamic>? cardData;

  ChatMessage({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.text,
    required this.type,
    required this.timestamp,
    this.read = false,
    this.imageUrl,
    this.cardData,
  });

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: id,
      connectionId: map['connectionId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhoto: map['senderPhoto'],
      text: map['text'] ?? '',
      type: _parseType(map['type']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      read: map['read'] ?? false,
      imageUrl: map['imageUrl'],
      cardData: map['cardData'] != null
          ? Map<String, dynamic>.from(map['cardData'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'connectionId': connectionId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'read': read,
      'imageUrl': imageUrl,
      'cardData': cardData,
    };
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'card':
        return MessageType.card;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  /// Create a copy with updated fields
  ChatMessage copyWith({
    bool? read,
    String? text,
    String? imageUrl,
  }) {
    return ChatMessage(
      id: id,
      connectionId: connectionId,
      senderId: senderId,
      senderName: senderName,
      senderPhoto: senderPhoto,
      text: text ?? this.text,
      type: type,
      timestamp: timestamp,
      read: read ?? this.read,
      imageUrl: imageUrl ?? this.imageUrl,
      cardData: cardData,
    );
  }
}

/// Service to manage chat messages between connected users
class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Typing indicators cache
  final Map<String, bool> _typingIndicators = {};

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get current user name
  String get currentUserName =>
      _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Unknown';

  /// Get current user photo
  String? get currentUserPhoto => _auth.currentUser?.photoURL;

  /// Send a text message
  Future<bool> sendMessage({
    required String connectionId,
    required String recipientId,
    required String text,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? cardData,
  }) async {
    try {
      if (currentUserId == null) {
        debugPrint('❌ No user logged in');
        return false;
      }

      if (text.trim().isEmpty && type == MessageType.text) {
        debugPrint('❌ Cannot send empty message');
        return false;
      }

      // Generate message ID
      final messageRef = _database.child('messages/$connectionId').push();
      final messageId = messageRef.key!;

      final message = ChatMessage(
        id: messageId,
        connectionId: connectionId,
        senderId: currentUserId!,
        senderName: currentUserName,
        senderPhoto: currentUserPhoto,
        text: text,
        type: type,
        timestamp: DateTime.now(),
        read: false,
        imageUrl: imageUrl,
        cardData: cardData,
      );

      // Save message
      await messageRef.set(message.toMap());

      // Update connection's last interaction
      await _database.child('connections/$connectionId').update({
        'lastInteraction': DateTime.now().millisecondsSinceEpoch,
      });

      // Update unread count for recipient
      await _incrementUnreadCount(connectionId, recipientId);

      debugPrint('✅ Message sent');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  /// Send a system message (connection established, etc.)
  Future<bool> sendSystemMessage({
    required String connectionId,
    required String text,
  }) async {
    try {
      final messageRef = _database.child('messages/$connectionId').push();
      final messageId = messageRef.key!;

      final message = ChatMessage(
        id: messageId,
        connectionId: connectionId,
        senderId: 'system',
        senderName: 'System',
        text: text,
        type: MessageType.system,
        timestamp: DateTime.now(),
        read: true, // System messages are always "read"
      );

      await messageRef.set(message.toMap());
      debugPrint('✅ System message sent');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending system message: $e');
      return false;
    }
  }

  /// Get messages stream for a connection
  Stream<List<ChatMessage>> getMessages(String connectionId) {
    return _database
        .child('messages/$connectionId')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <ChatMessage>[];

      final messagesMap = event.snapshot.value as Map<dynamic, dynamic>;
      final messages = <ChatMessage>[];

      messagesMap.forEach((key, value) {
        if (value is Map) {
          messages.add(ChatMessage.fromMap(key, value));
        }
      });

      // Sort by timestamp (oldest first for chat display)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return messages;
    });
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String connectionId) async {
    try {
      if (currentUserId == null) return;

      final snapshot = await _database.child('messages/$connectionId').get();

      if (!snapshot.exists) return;

      final messagesMap = snapshot.value as Map<dynamic, dynamic>;
      final updates = <String, dynamic>{};

      messagesMap.forEach((key, value) {
        if (value is Map) {
          final message = ChatMessage.fromMap(key, value);

          // Mark as read if sent by other user and not already read
          if (message.senderId != currentUserId && !message.read) {
            updates['$key/read'] = true;
          }
        }
      });

      if (updates.isNotEmpty) {
        await _database.child('messages/$connectionId').update(updates);

        // Reset unread count
        await _database
            .child('users/${currentUserId!}/unreadCounts/$connectionId')
            .remove();
      }

      debugPrint('✅ Messages marked as read');
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  /// Get unread message count for a connection
  Stream<int> getUnreadCount(String connectionId) {
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _database
        .child('users/${currentUserId!}/unreadCounts/$connectionId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;
      return event.snapshot.value as int? ?? 0;
    });
  }

  /// Get total unread message count
  Stream<int> getTotalUnreadCount() {
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _database
        .child('users/${currentUserId!}/unreadCounts')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;

      final countsMap = event.snapshot.value as Map<dynamic, dynamic>;
      int total = 0;

      countsMap.forEach((key, value) {
        total += (value as int? ?? 0);
      });

      return total;
    });
  }

  /// Increment unread count for recipient
  Future<void> _incrementUnreadCount(
      String connectionId, String recipientId) async {
    try {
      final countRef =
          _database.child('users/$recipientId/unreadCounts/$connectionId');

      final snapshot = await countRef.get();
      final currentCount = snapshot.exists ? (snapshot.value as int? ?? 0) : 0;

      await countRef.set(currentCount + 1);
    } catch (e) {
      debugPrint('❌ Error incrementing unread count: $e');
    }
  }

  /// Set typing indicator
  Future<void> setTyping(String connectionId, bool isTyping) async {
    try {
      if (currentUserId == null) return;

      await _database
          .child('typing/$connectionId/${currentUserId!}')
          .set(isTyping ? ServerValue.timestamp : null);

      _typingIndicators[connectionId] = isTyping;
    } catch (e) {
      debugPrint('❌ Error setting typing indicator: $e');
    }
  }

  /// Get typing indicator stream
  Stream<bool> getTypingIndicator(String connectionId, String otherUserId) {
    return _database
        .child('typing/$connectionId/$otherUserId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return false;

      // Check if timestamp is recent (within 5 seconds)
      final timestamp = event.snapshot.value;
      if (timestamp is int) {
        final typingTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        return now.difference(typingTime).inSeconds < 5;
      }

      return false;
    });
  }

  /// Delete a message
  Future<bool> deleteMessage(String connectionId, String messageId) async {
    try {
      await _database.child('messages/$connectionId/$messageId').remove();
      debugPrint('✅ Message deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      return false;
    }
  }

  /// Delete all messages in a conversation
  Future<bool> deleteConversation(String connectionId) async {
    try {
      await _database.child('messages/$connectionId').remove();

      // Also clear typing indicators
      await _database.child('typing/$connectionId').remove();

      // Clear unread count
      if (currentUserId != null) {
        await _database
            .child('users/${currentUserId!}/unreadCounts/$connectionId')
            .remove();
      }

      debugPrint('✅ Conversation deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting conversation: $e');
      return false;
    }
  }

  /// Get last message for a connection
  Future<ChatMessage?> getLastMessage(String connectionId) async {
    try {
      final snapshot = await _database
          .child('messages/$connectionId')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      if (!snapshot.exists) return null;

      final messagesMap = snapshot.value as Map<dynamic, dynamic>;
      final lastEntry = messagesMap.entries.first;

      return ChatMessage.fromMap(lastEntry.key, lastEntry.value);
    } catch (e) {
      debugPrint('❌ Error getting last message: $e');
      return null;
    }
  }

  /// Search messages in a conversation
  Future<List<ChatMessage>> searchMessages(
      String connectionId, String query) async {
    try {
      final snapshot = await _database.child('messages/$connectionId').get();

      if (!snapshot.exists) return [];

      final messagesMap = snapshot.value as Map<dynamic, dynamic>;
      final results = <ChatMessage>[];

      messagesMap.forEach((key, value) {
        if (value is Map) {
          final message = ChatMessage.fromMap(key, value);

          if (message.text.toLowerCase().contains(query.toLowerCase())) {
            results.add(message);
          }
        }
      });

      // Sort by timestamp (newest first)
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return results;
    } catch (e) {
      debugPrint('❌ Error searching messages: $e');
      return [];
    }
  }
}
