import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Model representing a user's device
class UserDevice {
  final String deviceId; // Unique device identifier
  final String userId; // Owner of the device
  final String? fcmToken; // Current FCM token for this device
  final String deviceName; // e.g., "Samsung Galaxy S24"
  final String deviceModel; // e.g., "SM-S928B"
  final String platform; // "android" or "ios"
  final String osVersion; // e.g., "Android 14" or "iOS 17.5"
  final DateTime lastActive; // Last time this device was used
  final DateTime createdAt; // When device was first registered
  final bool isActive; // Whether this device is currently active

  UserDevice({
    required this.deviceId,
    required this.userId,
    this.fcmToken,
    required this.deviceName,
    required this.deviceModel,
    required this.platform,
    required this.osVersion,
    required this.lastActive,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'userId': userId,
      'fcmToken': fcmToken,
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'platform': platform,
      'osVersion': osVersion,
      'lastActive': lastActive.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive,
    };
  }

  factory UserDevice.fromJson(Map<dynamic, dynamic> json, String deviceId) {
    return UserDevice(
      deviceId: deviceId,
      userId: json['userId'] ?? '',
      fcmToken: json['fcmToken'],
      deviceName: json['deviceName'] ?? 'Unknown Device',
      deviceModel: json['deviceModel'] ?? 'Unknown Model',
      platform: json['platform'] ?? 'unknown',
      osVersion: json['osVersion'] ?? 'Unknown',
      lastActive: DateTime.fromMillisecondsSinceEpoch(
        json['lastActive'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isActive: json['isActive'] ?? true,
    );
  }

  UserDevice copyWith({
    String? deviceId,
    String? userId,
    String? fcmToken,
    String? deviceName,
    String? deviceModel,
    String? platform,
    String? osVersion,
    DateTime? lastActive,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserDevice(
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      fcmToken: fcmToken ?? this.fcmToken,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      lastActive: lastActive ?? this.lastActive,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Service for managing user devices and FCM tokens
class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  String? _currentDeviceId;
  String? get currentDeviceId => _currentDeviceId;

  /// Register or update current device
  Future<String?> registerDevice(String userId, String? fcmToken) async {
    try {
      // Get device information
      final deviceInfo = await _getDeviceInfo();

      // Generate or retrieve device ID
      final deviceId = await _getOrCreateDeviceId();
      _currentDeviceId = deviceId;

      final device = UserDevice(
        deviceId: deviceId,
        userId: userId,
        fcmToken: fcmToken,
        deviceName: deviceInfo['name'] ?? 'Unknown Device',
        deviceModel: deviceInfo['model'] ?? 'Unknown Model',
        platform: deviceInfo['platform'] ?? 'unknown',
        osVersion: deviceInfo['osVersion'] ?? 'Unknown',
        lastActive: DateTime.now(),
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save to database under devices/{deviceId}
      await _database.child('devices').child(deviceId).set(device.toJson());

      // Also save a reference under users/{userId}/devices/{deviceId}
      await _database
          .child('users')
          .child(userId)
          .child('devices')
          .child(deviceId)
          .set({
        'deviceId': deviceId,
        'deviceName': device.deviceName,
        'platform': device.platform,
        'lastActive': device.lastActive.millisecondsSinceEpoch,
      });

      debugPrint('✅ [Device] Device registered: ${device.deviceName}');
      debugPrint('   Device ID: $deviceId');
      debugPrint('   Model: ${device.deviceModel}');
      debugPrint('   Platform: ${device.platform} ${device.osVersion}');

      return deviceId;
    } catch (e) {
      debugPrint('❌ [Device] Error registering device: $e');
      return null;
    }
  }

  /// Update FCM token for current device
  Future<void> updateFCMToken(String deviceId, String fcmToken) async {
    try {
      await _database.child('devices').child(deviceId).update({
        'fcmToken': fcmToken,
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('✅ [Device] FCM token updated for device: $deviceId');
    } catch (e) {
      debugPrint('❌ [Device] Error updating FCM token: $e');
    }
  }

  /// Update device last active time
  Future<void> updateLastActive(String deviceId) async {
    try {
      await _database.child('devices').child(deviceId).update({
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('❌ [Device] Error updating last active: $e');
    }
  }

  /// Get all devices for a user
  Stream<List<UserDevice>> getUserDevices(String userId) {
    return _database
        .child('users')
        .child(userId)
        .child('devices')
        .onValue
        .map((event) {
      final List<UserDevice> devices = [];
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> devicesMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        for (var entry in devicesMap.entries) {
          // Get full device info from devices collection
          _database.child('devices').child(entry.key).once().then((snapshot) {
            if (snapshot.snapshot.value != null) {
              final deviceData =
                  snapshot.snapshot.value as Map<dynamic, dynamic>;
              devices.add(UserDevice.fromJson(deviceData, entry.key));
            }
          });
        }
      }
      return devices;
    });
  }

  /// Get all FCM tokens for a user (from all their devices)
  Future<List<String>> getUserFCMTokens(String userId) async {
    try {
      final snapshot =
          await _database.child('users').child(userId).child('devices').once();

      if (snapshot.snapshot.value == null) {
        return [];
      }

      final Map<dynamic, dynamic> devicesMap =
          snapshot.snapshot.value as Map<dynamic, dynamic>;

      List<String> tokens = [];

      // Get tokens from each device
      for (var entry in devicesMap.entries) {
        final deviceSnapshot =
            await _database.child('devices').child(entry.key).once();

        if (deviceSnapshot.snapshot.value != null) {
          final deviceData =
              deviceSnapshot.snapshot.value as Map<dynamic, dynamic>;
          final token = deviceData['fcmToken'];
          final isActive = deviceData['isActive'] ?? true;

          if (token != null && isActive) {
            tokens.add(token as String);
          }
        }
      }

      debugPrint(
          '✅ [Device] Found ${tokens.length} active tokens for user: $userId');
      return tokens;
    } catch (e) {
      debugPrint('❌ [Device] Error getting user FCM tokens: $e');
      return [];
    }
  }

  /// Deactivate device (e.g., when user logs out)
  Future<void> deactivateDevice(String deviceId) async {
    try {
      await _database.child('devices').child(deviceId).update({
        'isActive': false,
        'fcmToken': null,
      });
      debugPrint('✅ [Device] Device deactivated: $deviceId');
    } catch (e) {
      debugPrint('❌ [Device] Error deactivating device: $e');
    }
  }

  /// Remove device completely
  Future<void> removeDevice(String userId, String deviceId) async {
    try {
      await _database.child('devices').child(deviceId).remove();
      await _database
          .child('users')
          .child(userId)
          .child('devices')
          .child(deviceId)
          .remove();
      debugPrint('✅ [Device] Device removed: $deviceId');
    } catch (e) {
      debugPrint('❌ [Device] Error removing device: $e');
    }
  }

  /// Get device information based on platform
  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Sanitize osVersion to remove invalid Firebase path characters
        final osVersion = 'Android ${androidInfo.version.release}'
            .replaceAll('.', '_')
            .replaceAll('#', '')
            .replaceAll('\$', '')
            .replaceAll('[', '')
            .replaceAll(']', '');
        return {
          'name': _getAndroidDeviceName(androidInfo),
          'model': androidInfo.model,
          'platform': 'android',
          'osVersion': osVersion,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Sanitize osVersion to remove invalid Firebase path characters
        final osVersion = 'iOS ${iosInfo.systemVersion}'
            .replaceAll('.', '_')
            .replaceAll('#', '')
            .replaceAll('\$', '')
            .replaceAll('[', '')
            .replaceAll(']', '');
        return {
          'name': iosInfo.name,
          'model': iosInfo.model,
          'platform': 'ios',
          'osVersion': osVersion,
        };
      } else if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        final osVersion = (webInfo.platform ?? 'Unknown')
            .replaceAll('.', '_')
            .replaceAll('#', '')
            .replaceAll('\$', '')
            .replaceAll('[', '')
            .replaceAll(']', '');
        return {
          'name': webInfo.browserName.name,
          'model': 'Web Browser',
          'platform': 'web',
          'osVersion': osVersion,
        };
      }
    } catch (e) {
      debugPrint('❌ [Device] Error getting device info: $e');
    }

    return {
      'name': 'Unknown Device',
      'model': 'Unknown Model',
      'platform': 'unknown',
      'osVersion': 'Unknown',
    };
  }

  /// Get friendly Android device name
  String _getAndroidDeviceName(AndroidDeviceInfo info) {
    // Try to construct a friendly name
    String manufacturer = info.manufacturer.toUpperCase();
    String model = info.model;

    // Handle Samsung devices
    if (manufacturer.contains('SAMSUNG')) {
      if (model.startsWith('SM-')) {
        // Try to map common Samsung models to friendly names
        if (model.contains('S928')) return 'Samsung Galaxy S24 Ultra';
        if (model.contains('S926')) return 'Samsung Galaxy S24+';
        if (model.contains('S921')) return 'Samsung Galaxy S24';
        if (model.contains('S918')) return 'Samsung Galaxy S23 Ultra';
        return 'Samsung Galaxy $model';
      }
    }

    // For other manufacturers, combine manufacturer and model
    return '$manufacturer $model';
  }

  /// Get or create a unique device ID
  Future<String> _getOrCreateDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Sanitize Android ID to remove invalid Firebase path characters
        return _sanitizeDeviceId(androidInfo.id);
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor != null
            ? _sanitizeDeviceId(iosInfo.identifierForVendor!)
            : _generateDeviceId();
      }
    } catch (e) {
      debugPrint('❌ [Device] Error getting device ID: $e');
    }

    return _generateDeviceId();
  }

  /// Sanitize device ID to remove invalid Firebase path characters
  String _sanitizeDeviceId(String deviceId) {
    return deviceId
        .replaceAll('.', '_')
        .replaceAll('#', '_')
        .replaceAll('\$', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('/', '_');
  }

  /// Generate a random device ID as fallback
  String _generateDeviceId() {
    final now = DateTime.now();
    return 'device_${now.millisecondsSinceEpoch}_${now.microsecond}';
  }
}
