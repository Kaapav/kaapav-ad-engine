import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'services/local_storage.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 Background FCM: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF020B14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await LocalStorageService.init();

  // Init local notifications (doesn't require Firebase)
  final notificationService = NotificationService();
  await notificationService.init();

  bool firebaseReady = false;

  try {
    await Firebase.initializeApp();
    firebaseReady = true;
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  }

  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final fcmService = FCMService();
    await fcmService.init();

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('📱 FCM Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null && token.trim().isNotEmpty) {
          await LocalStorageService.saveSetting('fcm_token', token);
          await fcmService.registerDevice(token); // register initial token
        }

        messaging.onTokenRefresh.listen((newToken) async {
          await LocalStorageService.saveSetting('fcm_token', newToken);
          await fcmService.registerDevice(newToken);
        });
      }
    } catch (e) {
      debugPrint('⚠️ FCM setup failed: $e');
    }
  } else {
    debugPrint('⚠️ Firebase not ready -> FCM disabled for this run');
  }

  runApp(
    const ProviderScope(
      child: KaapavAdEngine(),
    ),
  );
}