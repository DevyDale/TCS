import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationToggle extends StatefulWidget {
  const NotificationToggle({super.key});

  @override
  State<NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<NotificationToggle> {
  bool _enabled = false; // default OFF (Apple guideline 4.5.4)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _syncFromSystem();
  }

  Future<void> _syncFromSystem() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final prefs = await SharedPreferences.getInstance();
    final userPref = prefs.getBool('notifications_enabled') ?? false;

    if (!mounted) return;
    setState(() {
      _enabled = userPref &&
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _loading = false;
    });
  }

  Future<void> _onToggle(bool value) async {
    if (value) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        final token = await FirebaseMessaging.instance.getToken();
        // TODO: POST token to Django backend (FCM registration endpoint)
        debugPrint('FCM token: $token');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_enabled', true);
        if (mounted) setState(() => _enabled = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable notifications in iOS Settings'),
            ),
          );
        }
      }
    } else {
      await FirebaseMessaging.instance.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
      if (mounted) setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        title: Text('Push Notifications'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SwitchListTile(
      title: const Text('Push Notifications'),
      subtitle: const Text('Get notified about new posts and messages'),
      value: _enabled,
      onChanged: _onToggle,
    );
  }
}
