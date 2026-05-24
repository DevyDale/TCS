// lib/services/push_service.dart
//
// FCM client wiring. The backend (apps/notifications/tasks.py) already
// creates notifications and sends FCM pushes to user.fcm_token; this is the
// missing phone-side half:
//   • asks notification permission
//   • obtains the APNs (iOS) + FCM token and POSTs it to /users/me/fcm-token/
//   • re-sends on token refresh
//   • shows a banner for FOREGROUND messages (iOS via presentation options,
//     Android via flutter_local_notifications)
//   • routes taps (foreground, background, terminated) by payload `type`
//
// Call PushService.instance.init() right after a successful login (next to
// NotificationService.instance.bootstrap()). Attach `pushNavigatorKey` to
// your MaterialApp's navigatorKey, and register the background handler in
// main() — see the wiring notes Claude provided.

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import 'notification_service.dart';

/// Attach to MaterialApp(navigatorKey: pushNavigatorKey) so we can route
/// from outside any widget's BuildContext (e.g. a notification tap).
final GlobalKey<NavigatorState> pushNavigatorKey = GlobalKey<NavigatorState>();

/// MUST be a top-level / static function. Register in main() with
/// FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler).
/// Messages that carry a `notification` block are shown by the OS itself
/// while backgrounded/terminated, so there's nothing to do here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tcs_default',
    'General',
    description: 'Messages, requests and campus activity',
    importance: Importance.high,
  );

  /// Idempotent. Safe to call again after a re-login (re-syncs the token).
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    if (_ready) {
      await _syncToken();
      return;
    }
    _ready = true;

    // iOS: show the banner + badge + sound even while the app is foreground.
    await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Local notifications — used to surface FOREGROUND pushes on Android
    // (iOS handles foreground display via the presentation options above).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _fln.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final p = resp.payload;
        if (p != null && p.isNotEmpty) _routeByType(_decode(p));
      },
    );
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _syncToken();
    messaging.onTokenRefresh.listen(_sendToken);

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _routeByType(m.data));

    // App launched from a terminated state by tapping a push.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Defer until the navigator exists.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _routeByType(initial.data));
    }
  }

  Future<void> _syncToken() async {
    final messaging = FirebaseMessaging.instance;
    try {
      // iOS: the FCM token only resolves once the APNs token is available.
      if (Platform.isIOS) {
        await messaging.getAPNSToken();
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _sendToken(token);
    } catch (_) {/* permission denied / no APNs yet — try again next launch */}
  }

  Future<void> _sendToken(String token) async {
    try {
      await ApiService().updateFcmToken(token);
    } catch (_) {/* offline / not logged in yet — refresh will retry */}
  }

  void _onForeground(RemoteMessage m) {
    // Keep the in-app list + bell badge fresh.
    NotificationService.instance.refresh();

    final n = m.notification;
    if (n == null) return; // data-only message; nothing to display

    _fln.show(
      m.hashCode,
      n.title ?? 'StudentHub',
      n.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: _encode(m.data),
    );
  }

  // ── Tap routing (mirrors notifications_screen route names) ──────────
  void _routeByType(Map<String, dynamic> data) {
    final nav = pushNavigatorKey.currentState;
    if (nav == null) return;
    final type = (data['type'] ?? '').toString();
    switch (type) {
      case 'chat':
        nav.pushNamed('/chat/room',
            arguments: {'room_id': data['room_id']});
        break;
      case 'chat_request':
        nav.pushNamed('/chat/requests');
        break;
      case 'follow':
        nav.pushNamed('/profile/other',
            arguments: {'user_id': data['user_id']});
        break;
      case 'like':
      case 'comment':
        nav.pushNamed('/posts/detail',
            arguments: {'post_id': data['post_id']});
        break;
      case 'game_request':
        nav.pushNamed('/arcade/requests');
        break;
      case 'event_reminder':
        nav.pushNamed('/events/details',
            arguments: {'event_id': data['event_id']});
        break;
    }
  }

  // ── tiny payload codec (local-notification payload is a single string) ─
  String _encode(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('&');

  Map<String, dynamic> _decode(String s) {
    final out = <String, dynamic>{};
    for (final pair in s.split('&')) {
      final i = pair.indexOf('=');
      if (i > 0) out[pair.substring(0, i)] = pair.substring(i + 1);
    }
    return out;
  }
}