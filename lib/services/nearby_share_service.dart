import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// Premium Nearby Share Service for CardFlow
/// Enables seamless phone-to-phone business card sharing
/// Works on both Android and iOS
class NearbyShareService {
  static final NearbyShareService _instance = NearbyShareService._internal();
  factory NearbyShareService() => _instance;
  NearbyShareService._internal();

  final Nearby _nearby = Nearby();

  // Connection state
  String? _connectedEndpointId;
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  // Callbacks
  Function(String data)? onDataReceived;
  Function(String imagePath)? onImageReceived;
  Function()? onConnectionSuccess;
  Function(String error)? onError;
  Function()? onDisconnected;

  /// Request all necessary permissions for Nearby Connections
  Future<bool> requestPermissions() async {
    try {
      debugPrint('📱 Requesting Nearby Share permissions...');

      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();

      bool allGranted = statuses.values.every(
        (status) => status.isGranted || status.isLimited,
      );

      if (allGranted) {
        debugPrint('✅ All permissions granted');
        return true;
      } else {
        debugPrint('❌ Some permissions denied');
        final denied = statuses.entries
            .where((e) => !e.value.isGranted && !e.value.isLimited)
            .map((e) => e.key.toString())
            .toList();
        debugPrint('Denied permissions: $denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Start advertising as sender (allows others to discover you)
  Future<bool> startSharing({
    required String cardData,
    required String userName,
    String? imagePath,
  }) async {
    try {
      debugPrint('📡 Starting to advertise as sender...');
      debugPrint('👤 User name: $userName');

      if (_isAdvertising) {
        debugPrint('⚠️ Already advertising');
        return true;
      }

      await _nearby.startAdvertising(
        userName,
        Strategy.P2P_POINT_TO_POINT,
        onConnectionInitiated: (String endpointId, ConnectionInfo info) {
          debugPrint('🔗 Connection initiated with: ${info.endpointName}');
          debugPrint('   Endpoint ID: $endpointId');

          // Auto-accept connection
          _nearby.acceptConnection(
            endpointId,
            onPayLoadRecieved: (String endpointId, Payload payload) {
              // Sender doesn't receive data, only sends
              debugPrint('📥 Payload received (unexpected in sender mode)');
            },
            onPayloadTransferUpdate:
                (String endpointId, PayloadTransferUpdate update) {
              debugPrint('📊 Transfer update: ${update.status}');
              if (update.status == PayloadStatus.SUCCESS) {
                debugPrint('✅ Data sent successfully!');
              }
            },
          );
        },
        onConnectionResult: (String endpointId, Status status) async {
          debugPrint('🔌 Connection result: ${status.toString()}');

          if (status == Status.CONNECTED) {
            _connectedEndpointId = endpointId;
            debugPrint('✅ Connected! Sending card data...');

            // Send card data as bytes
            Uint8List bytes = Uint8List.fromList(cardData.codeUnits);
            await _nearby.sendBytesPayload(endpointId, bytes);
            debugPrint('📤 Card data sent (${bytes.length} bytes)');

            // Send image if available
            if (imagePath != null && imagePath.isNotEmpty) {
              try {
                debugPrint('📸 Sending image file: $imagePath');
                await _nearby.sendFilePayload(endpointId, imagePath);
                debugPrint('✅ Image file sent');
              } catch (e) {
                debugPrint('❌ Error sending image: $e');
              }
            }

            onConnectionSuccess?.call();

            // Disconnect after sending
            Future.delayed(const Duration(seconds: 3), () {
              stopSharing();
            });
          } else if (status == Status.REJECTED) {
            debugPrint('❌ Connection rejected');
            onError?.call('Connection rejected by receiver');
          } else if (status == Status.ERROR) {
            debugPrint('❌ Connection error');
            onError?.call('Connection failed');
          }
        },
        onDisconnected: (String endpointId) {
          debugPrint('🔌 Disconnected from: $endpointId');
          _connectedEndpointId = null;
          onDisconnected?.call();
        },
      );

      _isAdvertising = true;
      debugPrint('✅ Advertising started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting advertising: $e');
      onError?.call('Failed to start sharing: $e');
      return false;
    }
  }

  /// Start discovering as receiver (finds nearby senders)
  Future<bool> startReceiving({
    required String userName,
  }) async {
    try {
      debugPrint('🔍 Starting discovery as receiver...');
      debugPrint('👤 User name: $userName');

      if (_isDiscovering) {
        debugPrint('⚠️ Already discovering');
        return true;
      }

      await _nearby.startDiscovery(
        userName,
        Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (String endpointId, String name, String serviceId) {
          debugPrint('🎯 Found endpoint: $name');
          debugPrint('   Endpoint ID: $endpointId');
          debugPrint('   Service ID: $serviceId');

          // Auto-request connection when sender found
          debugPrint('📞 Requesting connection...');
          _nearby.requestConnection(
            userName,
            endpointId,
            onConnectionInitiated: (String endpointId, ConnectionInfo info) {
              debugPrint('🔗 Connection initiated with: ${info.endpointName}');

              // Accept connection and prepare to receive data
              _nearby.acceptConnection(
                endpointId,
                onPayLoadRecieved: (String endpointId, Payload payload) {
                  debugPrint('📥 Payload received!');

                  if (payload.type == PayloadType.BYTES &&
                      payload.bytes != null) {
                    String cardData = String.fromCharCodes(payload.bytes!);
                    debugPrint(
                        '✅ Card data received (${cardData.length} chars)');
                    onDataReceived?.call(cardData);
                  } else if (payload.type == PayloadType.FILE) {
                    debugPrint('📸 Image file received: ${payload.id}');
                    if (payload.uri != null) {
                      debugPrint('✅ Image path: ${payload.uri}');
                      onImageReceived?.call(payload.uri!);
                    }
                  } else {
                    debugPrint('⚠️ Unexpected payload type: ${payload.type}');
                  }
                },
                onPayloadTransferUpdate:
                    (String endpointId, PayloadTransferUpdate update) {
                  debugPrint('📊 Transfer update: ${update.status}');
                },
              );
            },
            onConnectionResult: (String endpointId, Status status) {
              debugPrint('🔌 Connection result: ${status.toString()}');

              if (status == Status.CONNECTED) {
                _connectedEndpointId = endpointId;
                debugPrint('✅ Connected! Waiting for data...');
                onConnectionSuccess?.call();
              } else if (status == Status.REJECTED) {
                debugPrint('❌ Connection rejected');
                onError?.call('Connection rejected');
              } else if (status == Status.ERROR) {
                debugPrint('❌ Connection error');
                onError?.call('Connection failed');
              }
            },
            onDisconnected: (String endpointId) {
              debugPrint('🔌 Disconnected from: $endpointId');
              _connectedEndpointId = null;
              onDisconnected?.call();
            },
          );
        },
        onEndpointLost: (String? endpointId) {
          debugPrint('📡 Lost endpoint: $endpointId');
        },
      );

      _isDiscovering = true;
      debugPrint('✅ Discovery started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting discovery: $e');
      onError?.call('Failed to start receiving: $e');
      return false;
    }
  }

  /// Stop sharing (sender)
  Future<void> stopSharing() async {
    try {
      if (_isAdvertising) {
        await _nearby.stopAdvertising();
        _isAdvertising = false;
        debugPrint('🛑 Stopped advertising');
      }
      if (_connectedEndpointId != null) {
        await _nearby.disconnectFromEndpoint(_connectedEndpointId!);
        _connectedEndpointId = null;
      }
    } catch (e) {
      debugPrint('❌ Error stopping sharing: $e');
    }
  }

  /// Stop receiving (receiver)
  Future<void> stopReceiving() async {
    try {
      if (_isDiscovering) {
        await _nearby.stopDiscovery();
        _isDiscovering = false;
        debugPrint('🛑 Stopped discovery');
      }
      if (_connectedEndpointId != null) {
        await _nearby.disconnectFromEndpoint(_connectedEndpointId!);
        _connectedEndpointId = null;
      }
    } catch (e) {
      debugPrint('❌ Error stopping receiving: $e');
    }
  }

  /// Stop all operations
  Future<void> stopAll() async {
    await stopSharing();
    await stopReceiving();
    _connectedEndpointId = null;
  }

  /// Check if currently connected
  bool get isConnected => _connectedEndpointId != null;

  /// Check if currently sharing
  bool get isSharing => _isAdvertising;

  /// Check if currently receiving
  bool get isReceiving => _isDiscovering;
}
