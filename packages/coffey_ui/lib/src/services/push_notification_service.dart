import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../repositories/notification_repository.dart';
import '../router/app_routes.dart';

/// Runs in a separate isolate when a push arrives while the app is fully
/// terminated/backgrounded, so it must be a top-level function. It doesn't
/// need to do anything beyond exist — the OS already shows the
/// notification tray entry from the payload; tap handling is covered by
/// [PushNotificationService._handleNotificationTap] via
/// `onMessageOpenedApp`/`getInitialMessage` once the app is foregrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Registers this device for push, and routes to the relevant screen when
/// the user taps a notification. Every Firebase/FCM call is wrapped so a
/// device or build without Firebase configured (no google-services.json /
/// GoogleService-Info.plist yet) just skips push silently — same fail-soft
/// approach as the backend's fcm-client.ts.
class PushNotificationService {
  PushNotificationService({required NotificationRepository notificationRepository})
      : _notificationRepository = notificationRepository;

  final NotificationRepository _notificationRepository;

  Future<void> initialize(GoRouter router) async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleNotificationTap(m, router));
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage, router);
    } catch (err) {
      debugPrint('Push notification setup skipped: $err');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _notificationRepository.registerFcmToken(token);
    } catch (err) {
      debugPrint('FCM token registration failed: $err');
    }
  }

  void _handleNotificationTap(RemoteMessage message, GoRouter router) {
    final type = message.data['type'];
    final weekId = message.data['weekId'];
    if (weekId == null) return;

    switch (type) {
      case 'pick_reminder':
        router.pushNamed('pickSheet', pathParameters: {'weekId': weekId as String});
      case 'results':
        router.pushNamed('weeklyStandings', pathParameters: {'weekId': weekId as String});
      default:
        router.go(AppRoutes.home);
    }
  }
}
