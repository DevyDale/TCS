// lib/core/app_settings.dart
// Singleton ChangeNotifier — drives BOTH theme and locale for the entire app.
// Listen to this in main.dart and rebuild MaterialApp when it changes.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  // Singleton
  static final AppSettings _i = AppSettings._();
  factory AppSettings() => _i;
  AppSettings._();

  // ── State ─────────────────────────────────────────────────
  bool   _dark          = false;
  String _lang          = 'en';
  bool   _pushEnabled   = true;
  bool   _announcements = true;
  bool   _groupActivity = true;
  bool   _showOnline    = true;
  bool   _discoverable  = true;

  // ── Public getters ────────────────────────────────────────
  bool   get isDark        => _dark;
  String get lang          => _lang;
  bool   get pushEnabled   => _pushEnabled;
  bool   get announcements => _announcements;
  bool   get groupActivity => _groupActivity;
  bool   get showOnline    => _showOnline;
  bool   get discoverable  => _discoverable;

  // Derived getters for MaterialApp
  ThemeMode get themeMode =>
      _dark ? ThemeMode.dark : ThemeMode.light;

  Locale get locale => Locale(_lang);

  // ── Load on app start (call in main before runApp) ────────
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _dark          = p.getBool('dark_mode')      ?? false;
    _lang          = p.getString('language')      ?? 'en';
    _pushEnabled   = p.getBool('push_notifs')     ?? true;
    _announcements = p.getBool('announcements')   ?? true;
    _groupActivity = p.getBool('group_activity')  ?? true;
    _showOnline    = p.getBool('show_online')     ?? true;
    _discoverable  = p.getBool('discoverable')    ?? true;
    notifyListeners();
  }

  // ── Setters (persist + notify) ────────────────────────────

  Future<void> setDark(bool v) async {
    if (_dark == v) return;
    _dark = v;
    (await SharedPreferences.getInstance()).setBool('dark_mode', v);
    notifyListeners();
  }

  Future<void> setLang(String v) async {
    if (_lang == v) return;
    _lang = v;
    (await SharedPreferences.getInstance()).setString('language', v);
    notifyListeners();
  }

  Future<void> setPush(bool v) async {
    _pushEnabled = v;
    final p = await SharedPreferences.getInstance();
    p.setBool('push_notifs', v);
    if (!v) { _announcements = false; _groupActivity = false;
      p.setBool('announcements', false); p.setBool('group_activity', false); }
    notifyListeners();
  }

  Future<void> setAnnouncements(bool v) async {
    _announcements = v;
    (await SharedPreferences.getInstance()).setBool('announcements', v);
    notifyListeners();
  }

  Future<void> setGroupActivity(bool v) async {
    _groupActivity = v;
    (await SharedPreferences.getInstance()).setBool('group_activity', v);
    notifyListeners();
  }

  Future<void> setShowOnline(bool v) async {
    _showOnline = v;
    (await SharedPreferences.getInstance()).setBool('show_online', v);
    notifyListeners();
  }

  Future<void> setDiscoverable(bool v) async {
    _discoverable = v;
    (await SharedPreferences.getInstance()).setBool('discoverable', v);
    notifyListeners();
  }

  // ── Theme data ────────────────────────────────────────────

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F4F8),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E54E9),
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
    ),
    cardColor: Colors.white,
    fontFamily: 'Momo',
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D0D1A),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E54E9),
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF161628),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF161628),
    fontFamily: 'Momo',
  );
}