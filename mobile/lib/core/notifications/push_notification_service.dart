import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

/// Handles FCM push notifications: permission, token registration,
/// foreground display, and background message handling.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  static const _channel = AndroidNotificationChannel(
    'society_notifications',
    'Society Notifications',
    description: 'Notifications from Sainath Society',
    importance: Importance.high,
  );

  /// Initialize Firebase + notification channels. Call after Firebase.initializeApp().
  Future<void> init() async {
    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Init local notifications
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Request permission (Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notifications: permission denied');
      return;
    }

    // Get FCM token and register with server
    _fcmToken = await _messaging.getToken();
    if (_fcmToken != null) {
      await _registerToken(_fcmToken!);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _registerToken(token);
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Background message tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a terminated state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final deviceInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      await api.post('/push/register-device', data: {
        'token': token,
        'platform': 'fcm',
        'deviceInfo': deviceInfo,
      });
      debugPrint('FCM token registered with server');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Unregister token on logout.
  Future<void> unregister() async {
    if (_fcmToken != null) {
      try {
        await api.post('/push/unregister-device', data: {'token': _fcmToken});
      } catch (_) {}
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    // Navigation on tap can be handled here if needed
    debugPrint('Notification tapped: ${message.data}');
  }
}

/// Top-level function for background messages (must be top-level).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.notification?.title}');
}
