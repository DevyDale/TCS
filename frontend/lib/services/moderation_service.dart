// lib/services/moderation_service.dart
//
// Apple App Store Guideline 1.2 (UGC) compliance: lets users report
// objectionable content and block abusive users. Backend lives at
// apps/moderation/ in tcs_backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth/session_keys.dart';
import 'api_service.dart';

class ModerationService {
  ModerationService._();
  static final instance = ModerationService._();

  Future<Map<String, String>> _authHeaders() async {
    final p = await SharedPreferences.getInstance();
    final tok = p.getString(SessionKeys.accessToken) ?? '';
    return {
      'Content-Type': 'application/json',
      if (tok.isNotEmpty) 'Authorization': 'Bearer $tok',
    };
  }

  /// Reasons must match REASON_CHOICES in apps/moderation/models.py
  static const reasons = <String, String>{
    'spam':         'Spam or scam',
    'harassment':   'Harassment or bullying',
    'hate_speech':  'Hate speech or discrimination',
    'violence':     'Violence or threats',
    'sexual':       'Sexual or explicit content',
    'self_harm':    'Self-harm or suicide',
    'illegal':      'Illegal activity',
    'false_info':   'False or misleading information',
    'other':        'Something else',
  };

  /// [contentType] is one of: 'post', 'comment', 'user'
  /// [objectId]    is the target's primary key (UUID for users, int for post/comment)
  Future<bool> reportContent({
    required String contentType,
    required String objectId,
    required String reason,
    String description = '',
  }) async {
    final url = Uri.parse('${ApiService.api}/moderation/reports/');
    final body = jsonEncode({
      'content_type_model': contentType,
      'object_id':          objectId,
      'reason':             reason,
      'description':        description,
    });
    final res = await http.post(url, headers: await _authHeaders(), body: body);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  /// [blockedUuid] is the target user's UUID (the `id` field, NOT user_id).
  Future<bool> blockUser(String blockedUuid) async {
    final url = Uri.parse('${ApiService.api}/moderation/blocks/');
    final body = jsonEncode({'blocked': blockedUuid});
    final res = await http.post(url, headers: await _authHeaders(), body: body);
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<bool> unblockUser(String blockedUuid) async {
    final url = Uri.parse('${ApiService.api}/moderation/blocks/$blockedUuid/');
    final res = await http.delete(url, headers: await _authHeaders());
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<List<Map<String, dynamic>>> listBlockedUsers() async {
    final url = Uri.parse('${ApiService.api}/moderation/blocks/');
    final res = await http.get(url, headers: await _authHeaders());
    if (res.statusCode != 200) return const [];
    final decoded = jsonDecode(res.body);
    final list = decoded is Map && decoded.containsKey('results')
        ? decoded['results']
        : decoded;
    if (list is! List) return const [];
    return list.cast<Map<String, dynamic>>();
  }
}
