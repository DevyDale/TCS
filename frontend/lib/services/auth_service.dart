// lib/services/auth_service.dart
// KEY FIX: verify URLs changed from /api/auth/ to /api/accounts/
// because TCS/urls.py maps: path("accounts/", include("apps.accounts.urls"))
// so verify_student and verify_staff live at /api/accounts/student/verify/

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/services/notification_Service.dart';

// ─── Config ───────────────────────────────────────────────────
class ApiConfig {
  // Android Emulator → use 10.0.2.2 (routes to Mac's localhost)
  static const String baseUrl = 'http://10.0.2.2:8000';

  // iOS Simulator or Mac browser → use 127.0.0.1
  // static const String baseUrl = 'http://127.0.0.1:8000';

  // Physical device on same WiFi → run `ipconfig getifaddr en0`
  // static const String baseUrl = 'http://192.168.x.x:8000';

  static String get api => '$baseUrl/api';
  static String get ws  => baseUrl.replaceFirst('http', 'ws');
}

// ─── SharedPreferences keys ───────────────────────────────────
class _Keys {
  static const access_token  = 'access_token';
  static const refresh_token = 'refresh_token';
  static const fullName      = 'fullName';
  static const preferredName = 'preferredName';
  static const role          = 'role';
  static const userId        = 'userId';
  static const userJson      = 'sh_current_user';
}

// ─── Exception ────────────────────────────────────────────────
class AuthException implements Exception {
  final String message;
  final int?   statusCode;
  const AuthException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

// ─── AuthResult ───────────────────────────────────────────────
class AuthResult {
  final String               accessToken;
  final String               refreshToken;
  final Map<String, dynamic> user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  String get userId        => user['user_id']       as String? ?? '';
  String get role          => user['role']           as String? ?? '';
  String get displayName   => user['display_name']   as String? ?? '';
  String get name          => user['name']           as String? ?? '';
  String get preferredName => user['preferred_name'] as String? ?? '';
  String get avatarUrl     => user['avatar_url']     as String? ?? '';
  bool   get isVerified    => user['is_verified']    as bool?   ?? false;
  int    get xp            => user['xp']             as int?    ?? 0;
  int    get level         => user['level']          as int?    ?? 1;
  int    get tokens        => user['tokens']         as int?    ?? 0;

  bool get isStudent          => role == 'student';
  bool get isTeachingStaff    => role == 'teaching_staff';
  bool get isNonTeachingStaff => role == 'non_teaching_staff';
  bool get isStaff            => isTeachingStaff || isNonTeachingStaff;
}

// ─── AuthService ──────────────────────────────────────────────
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  factory AuthService() => instance;

  final _client = http.Client();
  static const _json = {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  // ── Parse response — throws AuthException on error ──────────
  Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    String msg = 'Something went wrong. Please try again.';
    if (body is Map) {
      msg = (body['detail'] ??
             body['error'] ??
             body['non_field_errors']?.toString() ??
             (body.values.isNotEmpty ? body.values.first?.toString() : null) ??
             msg).toString();
    }
    throw AuthException(msg, statusCode: res.statusCode);
  }

  // ── Save session to SharedPreferences ───────────────────────
  Future<void> _saveSession(AuthResult r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_Keys.access_token,  r.accessToken);
    await p.setString(_Keys.refresh_token, r.refreshToken);
    await p.setString(_Keys.fullName,      r.name);
    await p.setString(_Keys.preferredName, r.preferredName);
    await p.setString(_Keys.role,          r.role);
    await p.setString(_Keys.userId,        r.userId);
    await p.setString(_Keys.userJson,      jsonEncode(r.user));
  }

  // ── Initialize (call in main before runApp) ─────────────────
  Future<void> initialize() async {
    final p     = await SharedPreferences.getInstance();
    final token = p.getString(_Keys.access_token);
    if (token != null && token.isNotEmpty) {
      await refreshAccessToken();
    }
  }

  // ── Verify student ──────────────────────────────────────────
  // URL: POST /api/accounts/student/verify/   ← FIXED (was /api/auth/)
  Future<Map<String, dynamic>> verifyStudent({
    required String studentId,
    required String dateOfBirth,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.api}/accounts/student/verify/'),
      headers: _json,
      body: jsonEncode({
        'student_id':    studentId,
        'date_of_birth': dateOfBirth,
      }),
    );
    final d = _parse(res);
    if (d['success'] != true) {
      throw const AuthException('Student ID or date of birth is incorrect.');
    }
    return d;
  }

  // ── Verify staff ────────────────────────────────────────────
  // URL: POST /api/accounts/staff/verify/     ← FIXED (was /api/auth/)
  Future<Map<String, dynamic>> verifyStaff({
    required String staffId,
    required String dateOfBirth,
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.api}/accounts/staff/verify/'),
      headers: _json,
      body: jsonEncode({
        'staff_id':      staffId,
        'date_of_birth': dateOfBirth,
      }),
    );
    final d = _parse(res);
    if (d['success'] != true) {
      throw const AuthException('Staff ID or date of birth is incorrect.');
    }
    return d;
  }

  // ── Login with ID + DOB ─────────────────────────────────────
  // URL: POST /api/accounts/login/
  Future<AuthResult> loginWithId({
    required String userId,
    required String dateOfBirth,
    required String role, // 'student' | 'teaching_staff' | 'non_teaching_staff'
  }) async {
    final res = await _client.post(
      Uri.parse('${ApiConfig.api}/accounts/login/'),
      headers: _json,
      body: jsonEncode({
        'user_id':       userId,
        'date_of_birth': dateOfBirth,
        'role':          role,
      }),
    );
    final d      = _parse(res);
    final result = AuthResult(
      accessToken:  d['access']  as String,
      refreshToken: d['refresh'] as String,
      user:         d['user']    as Map<String, dynamic>,
    );
    await _saveSession(result);
    return result;
  }

  // ── Refresh token ───────────────────────────────────────────
  Future<bool> refreshAccessToken() async {
    final p       = await SharedPreferences.getInstance();
    final refresh = p.getString(_Keys.refresh_token);
    if (refresh == null) return false;
    try {
      final res = await _client.post(
        Uri.parse('${ApiConfig.api}/accounts/token/refresh/'),
        headers: _json,
        body: jsonEncode({'refresh': refresh}),
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        await p.setString(_Keys.access_token, d['access'] as String);
        return true;
      }
    } catch (_) {}
    await clearTokens();
    return false;
  }

 Future<void> logout() async {
    final p       = await SharedPreferences.getInstance();
    final refresh = p.getString(_Keys.refresh_token);
    final access  = p.getString(_Keys.access_token);
    if (refresh != null) {
      try {
        await _client.post(
          Uri.parse('${ApiConfig.api}/accounts/logout/'),
          headers: {
            ..._json,
            if (access != null) 'Authorization': 'Bearer $access',
          },
          body: jsonEncode({'refresh': refresh}),
        );
      } catch (_) {}
    }
    // Tear down WS + clear in-memory notifications BEFORE wiping tokens
    // so the service stops cleanly without trying to reconnect with stale auth.
    await NotificationService.instance.disposeAll();
    await clearTokens();
  }  // ── Helpers ─────────────────────────────────────────────────
  Future<bool> get isLoggedIn async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_Keys.access_token);
    return t != null && t.isNotEmpty;
  }

  Future<String?> get accessToken async =>
      (await SharedPreferences.getInstance()).getString(_Keys.access_token);

  Future<Map<String, dynamic>?> get currentUser async {
    final raw = (await SharedPreferences.getInstance()).getString(_Keys.userJson);
    return raw != null ? jsonDecode(raw) as Map<String, dynamic> : null;
  }

  Future<void> clearTokens() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_Keys.access_token);
    await p.remove(_Keys.refresh_token);
    await p.remove(_Keys.fullName);
    await p.remove(_Keys.preferredName);
    await p.remove(_Keys.role);
    await p.remove(_Keys.userId);
    await p.remove(_Keys.userJson);
  }
}