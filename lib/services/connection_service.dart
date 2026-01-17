import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:cardflow/services/fcm_service.dart';

/// Connection status types
enum ConnectionStatus {
  pending,
  connected,
  declined,
  blocked,
}

/// Connection model
class Connection {
  final String id;
  final String initiatorId;
  final String recipientId;
  final String initiatorName;
  final String recipientName;
  final String? initiatorPhoto;
  final String? recipientPhoto;
  final String cardId;
  final ConnectionStatus status;
  final DateTime requestedAt;
  final DateTime? connectedAt;
  final DateTime lastInteraction;
  final String shareMethod;
  final String? requestNote;

  Connection({
    required this.id,
    required this.initiatorId,
    required this.recipientId,
    required this.initiatorName,
    required this.recipientName,
    this.initiatorPhoto,
    this.recipientPhoto,
    required this.cardId,
    required this.status,
    required this.requestedAt,
    this.connectedAt,
    required this.lastInteraction,
    required this.shareMethod,
    this.requestNote,
  });

  factory Connection.fromMap(String id, Map<dynamic, dynamic> map) {
    return Connection(
      id: id,
      initiatorId: map['initiatorId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      initiatorName: map['initiatorName'] ?? '',
      recipientName: map['recipientName'] ?? '',
      initiatorPhoto: map['initiatorPhoto'],
      recipientPhoto: map['recipientPhoto'],
      cardId: map['cardId'] ?? '',
      status: _parseStatus(map['status']),
      requestedAt: DateTime.fromMillisecondsSinceEpoch(map['requestedAt'] ?? 0),
      connectedAt: map['connectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['connectedAt'])
          : null,
      lastInteraction:
          DateTime.fromMillisecondsSinceEpoch(map['lastInteraction'] ?? 0),
      shareMethod: map['shareMethod'] ?? 'unknown',
      requestNote: map['requestNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'initiatorId': initiatorId,
      'recipientId': recipientId,
      'initiatorName': initiatorName,
      'recipientName': recipientName,
      'initiatorPhoto': initiatorPhoto,
      'recipientPhoto': recipientPhoto,
      'cardId': cardId,
      'status': status.toString().split('.').last,
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'connectedAt': connectedAt?.millisecondsSinceEpoch,
      'lastInteraction': lastInteraction.millisecondsSinceEpoch,
      'shareMethod': shareMethod,
      'requestNote': requestNote,
    };
  }

  static ConnectionStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return ConnectionStatus.pending;
      case 'connected':
        return ConnectionStatus.connected;
      case 'declined':
        return ConnectionStatus.declined;
      case 'blocked':
        return ConnectionStatus.blocked;
      default:
        return ConnectionStatus.pending;
    }
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == initiatorId ? recipientId : initiatorId;
  }

  String getOtherUserName(String currentUserId) {
    return currentUserId == initiatorId ? recipientName : initiatorName;
  }

  String? getOtherUserPhoto(String currentUserId) {
    return currentUserId == initiatorId ? recipientPhoto : initiatorPhoto;
  }
}

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _createConnectionId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String? get currentUserId => _auth.currentUser?.uid;

  String get currentUserName =>
      _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Unknown';

  String? get currentUserPhoto => _auth.currentUser?.photoURL;

  Future<bool> sendConnectionRequest({
    required String recipientId,
    required String recipientName,
    String? recipientPhoto,
    required String cardId,
    required String shareMethod,
    String? note,
  }) async {
    try {
      if (currentUserId == null) {
        debugPrint('No user logged in');
        return false;
      }

      final connectionId = _createConnectionId(currentUserId!, recipientId);
      final existingConnection =
          await _database.child('connections/$connectionId').get();

      if (existingConnection.exists) {
        final data = existingConnection.value as Map;
        final status = data['status'] as String?;

        // Allow resending if declined, otherwise reject
        if (status != 'declined') {
          debugPrint('Connection already exists with status: $status');
          return false;
        }

        // If declined, remove old connection before creating new one
        await _database.child('connections/$connectionId').remove();
        debugPrint('Removed declined connection, creating new request');
      }

      final connection = Connection(
        id: connectionId,
        initiatorId: currentUserId!,
        recipientId: recipientId,
        initiatorName: currentUserName,
        recipientName: recipientName,
        initiatorPhoto: currentUserPhoto,
        recipientPhoto: recipientPhoto,
        cardId: cardId,
        status: ConnectionStatus.pending,
        requestedAt: DateTime.now(),
        lastInteraction: DateTime.now(),
        shareMethod: shareMethod,
        requestNote: note,
      );

      await _database
          .child('connections/$connectionId')
          .set(connection.toMap());

      await _database
          .child(
              'users/${currentUserId!}/connections/pending_sent/$recipientId')
          .set(true);

      await _database
          .child(
              'users/$recipientId/connections/pending_received/${currentUserId!}')
          .set(true);

      await FCMService().sendNotificationToUser(
        recipientUserId: recipientId,
        title: 'New Connection Request',
        body:
            '$currentUserName wants to connect with you${note != null ? ": $note" : ""}',
        type: 'connection_request',
        additionalData: {
          'connectionId': connectionId,
          'senderId': currentUserId!,
          'senderName': currentUserName,
        },
      );

      debugPrint('Connection request sent to $recipientName');
      return true;
    } catch (e) {
      debugPrint('Error sending connection request: $e');
      return false;
    }
  }

  Future<bool> acceptConnectionRequest(String connectionId) async {
    try {
      if (currentUserId == null) return false;

      final connectionRef = _database.child('connections/$connectionId');
      final snapshot = await connectionRef.get();

      if (!snapshot.exists) {
        debugPrint('Connection not found');
        return false;
      }

      final connection =
          Connection.fromMap(connectionId, snapshot.value as Map);

      await connectionRef.update({
        'status': 'connected',
        'connectedAt': DateTime.now().millisecondsSinceEpoch,
        'lastInteraction': DateTime.now().millisecondsSinceEpoch,
      });

      final otherUserId = connection.getOtherUserId(currentUserId!);

      await _database
          .child('users/${currentUserId!}/connections/connected/$otherUserId')
          .set(true);
      await _database
          .child(
              'users/${currentUserId!}/connections/pending_received/$otherUserId')
          .remove();

      await _database
          .child('users/$otherUserId/connections/connected/${currentUserId!}')
          .set(true);
      await _database
          .child(
              'users/$otherUserId/connections/pending_sent/${currentUserId!}')
          .remove();

      await FCMService().sendNotificationToUser(
        recipientUserId: otherUserId,
        title: 'Connection Accepted',
        body: '$currentUserName accepted your connection request!',
        type: 'connection_accepted',
        additionalData: {
          'connectionId': connectionId,
          'senderId': currentUserId!,
          'senderName': currentUserName,
        },
      );

      debugPrint('Connection request accepted');
      return true;
    } catch (e) {
      debugPrint('Error accepting connection: $e');
      return false;
    }
  }

  Future<bool> declineConnectionRequest(String connectionId) async {
    try {
      if (currentUserId == null) return false;

      final connectionRef = _database.child('connections/$connectionId');
      final snapshot = await connectionRef.get();

      if (!snapshot.exists) return false;

      final connection =
          Connection.fromMap(connectionId, snapshot.value as Map);
      final otherUserId = connection.getOtherUserId(currentUserId!);

      await connectionRef.update({
        'status': 'declined',
        'lastInteraction': DateTime.now().millisecondsSinceEpoch,
      });

      await _database
          .child(
              'users/${currentUserId!}/connections/pending_received/$otherUserId')
          .remove();
      await _database
          .child(
              'users/$otherUserId/connections/pending_sent/${currentUserId!}')
          .remove();

      debugPrint('Connection declined');
      return true;
    } catch (e) {
      debugPrint('Error declining connection: $e');
      return false;
    }
  }

  Future<bool> removeConnection(String connectionId,
      {bool block = false}) async {
    try {
      if (currentUserId == null) return false;

      final connectionRef = _database.child('connections/$connectionId');
      final snapshot = await connectionRef.get();

      if (!snapshot.exists) return false;

      final connection =
          Connection.fromMap(connectionId, snapshot.value as Map);
      final otherUserId = connection.getOtherUserId(currentUserId!);

      if (block) {
        await connectionRef.update({
          'status': 'blocked',
          'lastInteraction': DateTime.now().millisecondsSinceEpoch,
        });

        await _database
            .child('users/${currentUserId!}/connections/blocked/$otherUserId')
            .set(true);
      } else {
        await connectionRef.remove();
      }

      await _database
          .child('users/${currentUserId!}/connections/connected/$otherUserId')
          .remove();
      await _database
          .child('users/$otherUserId/connections/connected/${currentUserId!}')
          .remove();

      debugPrint(block ? 'Connection blocked' : 'Connection removed');
      return true;
    } catch (e) {
      debugPrint('Error removing connection: $e');
      return false;
    }
  }

  Stream<List<Connection>> getMyConnections() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _database.child('connections').onValue.map((event) {
      if (!event.snapshot.exists) return <Connection>[];

      final connectionsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final connections = <Connection>[];

      connectionsMap.forEach((key, value) {
        if (value is Map) {
          final connection = Connection.fromMap(key, value);

          if ((connection.initiatorId == currentUserId ||
                  connection.recipientId == currentUserId) &&
              connection.status == ConnectionStatus.connected) {
            connections.add(connection);
          }
        }
      });

      connections
          .sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));

      return connections;
    });
  }

  Stream<List<Connection>> getPendingRequests() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _database.child('connections').onValue.map((event) {
      if (!event.snapshot.exists) return <Connection>[];

      final connectionsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final requests = <Connection>[];

      connectionsMap.forEach((key, value) {
        if (value is Map) {
          final connection = Connection.fromMap(key, value);

          if (connection.recipientId == currentUserId &&
              connection.status == ConnectionStatus.pending) {
            requests.add(connection);
          }
        }
      });

      requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

      return requests;
    });
  }

  Stream<List<Connection>> getSentRequests() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _database.child('connections').onValue.map((event) {
      if (!event.snapshot.exists) return <Connection>[];

      final connectionsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final requests = <Connection>[];

      connectionsMap.forEach((key, value) {
        if (value is Map) {
          final connection = Connection.fromMap(key, value);

          if (connection.initiatorId == currentUserId &&
              connection.status == ConnectionStatus.pending) {
            requests.add(connection);
          }
        }
      });

      requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

      return requests;
    });
  }

  Future<bool> isConnectedWith(String userId) async {
    if (currentUserId == null) return false;

    final connectionId = _createConnectionId(currentUserId!, userId);
    final snapshot = await _database.child('connections/$connectionId').get();

    if (!snapshot.exists) return false;

    final connection = Connection.fromMap(connectionId, snapshot.value as Map);
    return connection.status == ConnectionStatus.connected;
  }

  Future<ConnectionStatus?> getConnectionStatus(String userId) async {
    if (currentUserId == null) return null;

    final connectionId = _createConnectionId(currentUserId!, userId);
    final snapshot = await _database.child('connections/$connectionId').get();

    if (!snapshot.exists) return null;

    final connection = Connection.fromMap(connectionId, snapshot.value as Map);
    return connection.status;
  }

  Future<Map<String, int>> getConnectionStats() async {
    if (currentUserId == null) {
      return {
        'total': 0,
        'pending': 0,
        'thisMonth': 0,
      };
    }

    final snapshot = await _database.child('connections').get();

    if (!snapshot.exists) {
      return {
        'total': 0,
        'pending': 0,
        'thisMonth': 0,
      };
    }

    final connectionsMap = snapshot.value as Map<dynamic, dynamic>;
    int total = 0;
    int pending = 0;
    int thisMonth = 0;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    connectionsMap.forEach((key, value) {
      if (value is Map) {
        final connection = Connection.fromMap(key, value);

        if (connection.initiatorId == currentUserId ||
            connection.recipientId == currentUserId) {
          if (connection.status == ConnectionStatus.connected) {
            total++;
            if (connection.connectedAt != null &&
                connection.connectedAt!.isAfter(monthStart)) {
              thisMonth++;
            }
          } else if (connection.status == ConnectionStatus.pending &&
              connection.recipientId == currentUserId) {
            pending++;
          }
        }
      }
    });

    return {
      'total': total,
      'pending': pending,
      'thisMonth': thisMonth,
    };
  }

  /// Disconnect from a connection - removes connection and deletes all chat messages
  Future<bool> disconnect(String connectionId) async {
    try {
      if (currentUserId == null) return false;

      final connectionRef = _database.child('connections/$connectionId');
      final snapshot = await connectionRef.get();

      if (!snapshot.exists) return false;

      final connection =
          Connection.fromMap(connectionId, snapshot.value as Map);
      final otherUserId = connection.getOtherUserId(currentUserId!);

      // Step 1: Delete all messages in this connection
      await _database.child('messages/$connectionId').remove();

      // Step 2: Update connection status to disconnected
      await connectionRef.update({
        'status': 'disconnected',
        'disconnectedAt': DateTime.now().millisecondsSinceEpoch,
        'disconnectedBy': currentUserId!,
        'lastInteraction': DateTime.now().millisecondsSinceEpoch,
      });

      // Step 3: Remove from user's connected list
      await _database
          .child('users/${currentUserId!}/connections/connected/$otherUserId')
          .remove();
      await _database
          .child('users/$otherUserId/connections/connected/${currentUserId!}')
          .remove();

      debugPrint('✅ Connection disconnected successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error disconnecting: $e');
      return false;
    }
  }
}
