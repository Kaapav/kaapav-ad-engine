// lib/services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'worker_api.dart';
import 'local_storage.dart';
import 'notification_service.dart';

/// FCM Service — handles device registration, foreground messages
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Initialize FCM listeners
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // When user taps notification (app in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      debugPrint('✅ FCM Service initialized');
    } catch (e) {
      debugPrint('⚠️ FCM Service init failed: $e');
    }
  }

  /// Register device with Worker backend
  Future<void> registerDevice(String? fcmToken) async {
    fcmToken ??= await _messaging.getToken();
    if (fcmToken == null) {
      debugPrint('⚠️ No FCM token available');
      return;
    }

    try {
      final deviceName = await _getDeviceName();
      final api = WorkerApiService();
      
      await api.registerDevice(fcmToken, deviceName: deviceName);
      
      debugPrint('✅ Device registered with Worker');
      await LocalStorageService.saveSetting('fcm_registered', true);
    } catch (e) {
      debugPrint('⚠️ Device registration failed: $e');
      await LocalStorageService.saveSetting('fcm_registered', false);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground FCM: ${message.notification?.title}');

    // Show local notification
    final notification = message.notification;
    if (notification != null) {
NotificationService().showAlert(
  title: notification.title ?? 'Notification',
  body: notification.body ?? '',
  payload: message.data.toString(),
);
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');

    // TODO: Navigate to specific screen based on payload
    // Example:
    // if (message.data['type'] == 'lead') {
    //   navigatorKey.currentState?.pushNamed('/lead-detail', arguments: message.data['lead_id']);
    // }
  }

  /// Get device name
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return '${info.name} (${info.model})';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Mobile Device';
    }
  }

  /// Check if device is registered
  Future<bool> isRegistered() async {
return LocalStorageService.getSetting<bool>('fcm_registered') ?? false;
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('⚠️ Failed to get FCM token: $e');
      return null;
    }
  }
}