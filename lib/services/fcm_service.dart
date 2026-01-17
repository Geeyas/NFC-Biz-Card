import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cardflow/services/device_service.dart';

/// Firebase Cloud Messaging Service
/// Handles push notifications for connection requests and messages
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  final DeviceService _deviceService = DeviceService();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM service
  Future<void> initialize() async {
    try {
      // Request permission (iOS requires explicit permission, Android auto-grants)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint(
          '✅ [FCM] Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications for foreground display
        await _initializeLocalNotifications();

        // Get FCM token
        await _getFCMToken();

        // Listen to token refresh
        _fcm.onTokenRefresh.listen(_handleTokenRefresh);

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle background message tap
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Handle notification tap when app was terminated
        RemoteMessage? initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        debugPrint('✅ [FCM] Service initialized successfully');
      } else {
        debugPrint('⚠️ [FCM] Notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error initializing: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    debugPrint('✅ [FCM] Local notifications initialized');
  }

  /// Get FCM token and save to database
  Future<void> _getFCMToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        _fcmToken = token;
        debugPrint('✅ [FCM] Token: $token');

        // Save token to device (not user directly)
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _deviceService.registerDevice(user.uid, token);
        }
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error getting token: $e');
    }
  }

  /// Save FCM token to device (DEPRECATED - kept for backwards compatibility)
  /// Now handled by DeviceService
  @Deprecated('Use DeviceService.registerDevice() instead')
  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      // Register device with token
      await _deviceService.registerDevice(userId, token);
      debugPrint('✅ [FCM] Token saved via DeviceService');
    } catch (e) {
      debugPrint('❌ [FCM] Error saving token: $e');
    }
  }

  /// Handle token refresh
  void _handleTokenRefresh(String token) async {
    _fcmToken = token;
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update token in device service
      final deviceId = _deviceService.currentDeviceId;
      if (deviceId != null) {
        await _deviceService.updateFCMToken(deviceId, token);
      } else {
        // If no device ID, register new device
        await _deviceService.registerDevice(user.uid, token);
      }
    }
    debugPrint('🔄 [FCM] Token refreshed: $token');
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 [FCM] Foreground message received');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'cardflow_channel', // Channel ID
      'CardFlow Notifications', // Channel name
      channelDescription: 'Notifications for connection requests and messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'CardFlow',
      message.notification?.body ?? 'You have a new notification',
      details,
      payload: message.data['type'] ?? '',
    );

    debugPrint('✅ [FCM] Local notification shown');
  }

  /// Handle notification tap (when app is in background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 [FCM] Notification tapped');
    debugPrint('Data: ${message.data}');

    // Navigate based on notification type
    String type = message.data['type'] ?? '';
    _navigateBasedOnType(type, message.data);
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('👆 [FCM] Local notification tapped');
    String type = response.payload ?? '';
    _navigateBasedOnType(type, {});
  }

  /// Navigate to appropriate screen based on notification type
  void _navigateBasedOnType(String type, Map<String, dynamic> data) {
    // This will be called when user taps notification
    // You'll need to implement navigation in your app's context
    debugPrint('🔄 [FCM] Navigate to: $type');

    switch (type) {
      case 'connection_request':
        debugPrint('➡️ Navigate to My Connections (Requests tab)');
        // Navigator.push(context, MaterialPageRoute(...));
        break;
      case 'connection_accepted':
        debugPrint('➡️ Navigate to My Connections (Connected tab)');
        break;
      case 'new_message':
        String? connectionId = data['connectionId'];
        debugPrint('➡️ Navigate to Chat: $connectionId');
        break;
      default:
        debugPrint('➡️ Navigate to Home');
    }
  }

  /// Send push notification to a specific user via Cloud Function
  /// Sends to ALL active devices for the user
  Future<void> sendNotificationToUser({
    required String recipientUserId,
    required String title,
    required String body,
    required String type,
    Map<String, String>? additionalData,
  }) async {
    try {
      debugPrint('📤 [FCM] Sending notification via Cloud Function');
      debugPrint('   Recipient: $recipientUserId');
      debugPrint('   Title: $title');

      // Get ALL FCM tokens for this user (from all their devices)
      List<String> recipientTokens =
          await _deviceService.getUserFCMTokens(recipientUserId);

      if (recipientTokens.isEmpty) {
        debugPrint(
            '⚠️ [FCM] Recipient $recipientUserId has no active devices with FCM tokens');
        return;
      }

      debugPrint('   📱 Sending to ${recipientTokens.length} device(s)');

      // Call the Cloud Function for each device
      final HttpsCallable callable =
          _functions.httpsCallable('sendNotification');

      int successCount = 0;
      for (String token in recipientTokens) {
        try {
          String tokenPreview = token.substring(0, min(20, token.length));
          debugPrint('   Sending to device with token: $tokenPreview...');

          final result = await callable.call<Map<String, dynamic>>({
            'title': title,
            'body': body,
            'recipientToken': token,
            'data': {
              'type': type,
              ...?additionalData,
            },
          });

          if (result.data['success'] == true) {
            successCount++;
            debugPrint('   ✅ Notification sent to device!');
          }
        } catch (e) {
          debugPrint('   ❌ Failed to send to one device: $e');
          // Continue to next device even if one fails
        }
      }

      debugPrint(
          '✅ [FCM] Sent notifications to $successCount/${recipientTokens.length} device(s)');
    } catch (e, stackTrace) {
      debugPrint('❌ [FCM] Error sending notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Delete FCM token on logout (deactivate current device)
  Future<void> deleteFCMToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;

      // Deactivate current device
      final deviceId = _deviceService.currentDeviceId;
      if (deviceId != null) {
        await _deviceService.deactivateDevice(deviceId);
        debugPrint('✅ [FCM] Device deactivated: $deviceId');
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error deleting token: $e');
    }
  }

  /// Get FCM token for a specific user (returns first active device token)
  /// For multiple devices, use DeviceService.getUserFCMTokens() instead
  Future<String?> getUserFCMToken(String userId) async {
    try {
      // Get all tokens from user's devices
      List<String> tokens = await _deviceService.getUserFCMTokens(userId);
      if (tokens.isNotEmpty) {
        return tokens.first; // Return first active device token
      }
      return null;
    } catch (e) {
      debugPrint('❌ [FCM] Error getting user token: $e');
      return null;
    }
  }

  /// Subscribe to a topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ [FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ [FCM] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ [FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ [FCM] Error unsubscribing from topic: $e');
    }
  }

  /// Start listening for notifications in database (workaround for Cloud Functions)
  /// This displays notifications when app is running/background without needing deployed Cloud Functions
  void startNotificationListener() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint(
          '⚠️ [FCM] Cannot start notification listener - no user logged in');
      return;
    }

    debugPrint(
        '🔊 [FCM] Starting in-app notification listener for user: $userId');

    // Listen to notifications node for this user
    _database
        .child('notifications')
        .orderByChild('recipientUserId')
        .equalTo(userId)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.exists) {
        try {
          final notification =
              Map<String, dynamic>.from(event.snapshot.value as Map);

          // Skip if already sent
          if (notification['sent'] == true) {
            return;
          }

          debugPrint('📩 [FCM] New notification received from database');
          debugPrint('   Title: ${notification['title']}');
          debugPrint('   Body: ${notification['body']}');
          debugPrint('   Type: ${notification['type']}');

          // Show local notification
          _localNotifications.show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
            notification['title'] ?? 'New Notification',
            notification['body'] ?? '',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'cardflow_notifications',
                'CardFlow Notifications',
                channelDescription: 'Connection requests and messages',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
                color: Color(0xFF667eea),
              ),
            ),
            payload: notification['type'] ?? 'unknown',
          );

          // Mark as sent in database
          event.snapshot.ref.update({
            'sent': true,
            'sentAt': DateTime.now().millisecondsSinceEpoch,
            'sentVia': 'in-app-listener',
          });

          debugPrint('✅ [FCM] Notification displayed via in-app listener');
        } catch (e) {
          debugPrint('❌ [FCM] Error processing notification: $e');
        }
      }
    });
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  debugPrint('🔔 [FCM] Background message received');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}
