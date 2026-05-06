// lib/services/api_service.dart
// ALL auth URLs corrected: /api/auth/ → /api/accounts/
// to match TCS/urls.py: path("accounts/", include("apps.accounts.urls"))
//
// SECTION 1 FIX: SharedPreferences keys are now centralised in
// session_keys.dart. _Tokens.saveUser also persists identity fields
// (fullName, preferredName, role, userId) so the splash and dashboard
// can read them without parsing JSON.
//
// Bug fixes: replaced '\$page' / '\$id' literal escapes (which sent
// the literal text "$page" / "$id" to the server) with proper
// interpolation in getMyPosts / getMyFweets / getFavorites / deletePost.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/screens/auth/session_keys.dart';
import 'package:web_socket_channel/web_socket_channel.dart';


// ─────────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────────

class ApiConfig {
  // Android emulator → host machine
  static const String baseUrl = 'http://10.0.2.2:8000';

  // iOS simulator / same Mac
  // static const String baseUrl = 'http://127.0.0.1:8000';

  // Physical device on same WiFi — replace with your Mac IP
  // Run: ipconfig getifaddr en0
  // static const String baseUrl = 'http://192.168.x.x:8000';

  static String get api => '$baseUrl/api';
  static String get ws  => baseUrl.replaceFirst('http', 'ws');
}

// ─────────────────────────────────────────────────────────────
// EXCEPTION
// ─────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int?   statusCode;
  const ApiException(this.message, {this.statusCode});
  @override String toString() => message;
}

// ─────────────────────────────────────────────────────────────
// TOKEN STORE
// ─────────────────────────────────────────────────────────────

class _Tokens {
  // Now point at the shared single-source-of-truth (session_keys.dart)
  // instead of duplicating string literals.
  static const _a = SessionKeys.accessToken;
  static const _r = SessionKeys.refreshToken;
  static const _u = SessionKeys.userJson;

  static Future<void> save(String a, String r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_a, a);
    await p.setString(_r, r);
  }

  static Future<String?> access() async =>
      (await SharedPreferences.getInstance()).getString(_a);

  static Future<String?> refresh() async =>
      (await SharedPreferences.getInstance()).getString(_r);

  /// Persist the full user JSON AND the individual identity fields.
  /// Other screens (splash, login_id, dashboard) read these direct
  /// keys without having to parse JSON, so we keep them in sync here.
  static Future<void> saveUser(Map<String, dynamic> u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_u, jsonEncode(u));
    await p.setString(SessionKeys.userId,        (u['user_id']        ?? '').toString());
    await p.setString(SessionKeys.fullName,      (u['name']           ?? '').toString());
    await p.setString(SessionKeys.preferredName, (u['preferred_name'] ?? '').toString());
    await p.setString(SessionKeys.role,          (u['role']           ?? '').toString());
  }

  static Future<Map<String, dynamic>?> user() async {
    final raw = (await SharedPreferences.getInstance()).getString(_u);
    return raw != null ? jsonDecode(raw) as Map<String, dynamic> : null;
  }

  static Future<bool> has() async {
    final t = await access();
    return t != null && t.isNotEmpty;
  }

  /// Wipe every session-related key. Driven by SessionKeys.all so we
  /// can never forget to clear one when a new key is introduced.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in SessionKeys.all) {
      await p.remove(k);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// API SERVICE
// ─────────────────────────────────────────────────────────────

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();
  factory ApiService() => instance;

  final _client = http.Client();

  /// Call this on app launch (from the splash) BEFORE deciding whether
  /// to route the user to the dashboard. If we have an access token,
  /// try to refresh it proactively so the first dashboard API call
  /// hits a fresh token instead of a stale one. If refresh fails, the
  /// session is wiped so the splash falls through to RoleSelection.
  Future<void> initialize() async {
    if (await _Tokens.has()) await _tryRefresh();
  }

  Future<bool> get isLoggedIn              => _Tokens.has();
  Future<void> clearTokens()               => _Tokens.clear();
  Future<String?> get accessToken          => _Tokens.access();
  Future<Map<String, dynamic>?> get cachedUser => _Tokens.user();

  // ── Headers ───────────────────────────────────────────────

  Future<Map<String, String>> _h({bool auth = true}) async {
    final h = {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (auth) {
      final t = await _Tokens.access();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  // ── Core HTTP ─────────────────────────────────────────────

  Future<http.Response> _raw(String method, Uri uri,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final h = await _h(auth: auth);
    final b = body != null ? jsonEncode(body) : null;
    switch (method) {
      case 'GET':    return _client.get(uri,    headers: h);
      case 'POST':   return _client.post(uri,   headers: h, body: b);
      case 'PUT':    return _client.put(uri,    headers: h, body: b);
      case 'PATCH':  return _client.patch(uri,  headers: h, body: b);
      case 'DELETE': return _client.delete(uri, headers: h);
      default:       throw ApiException('Unknown method: $method');
    }
  }

  dynamic _decode(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    String msg = 'Request failed (${res.statusCode})';
    if (body is Map) {
      msg = (body['detail'] ?? body['error'] ??
             body['non_field_errors']?.toString() ??
             body.values.firstOrNull?.toString() ?? msg).toString();
    }
    throw ApiException(msg, statusCode: res.statusCode);
  }

  // ── Token refresh ─────────────────────────────────────────
  // URL: /api/accounts/token/refresh/  ← FIXED (was /api/auth/)

  Future<bool> _tryRefresh() async {
    final r = await _Tokens.refresh();
    if (r == null) return false;
    try {
      final res = await _client.post(
        Uri.parse('${ApiConfig.api}/accounts/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': r}),
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        await _Tokens.save(d['access'] as String, r);
        return true;
      }
    } catch (_) {}
    await _Tokens.clear();
    return false;
  }

  Future<dynamic> _req(String method, String path,
      {Map<String, dynamic>? body,
       Map<String, String>?  query,
       bool auth = true}) async {
    final uri = Uri.parse('${ApiConfig.api}$path')
        .replace(queryParameters: query);
    var res = await _raw(method, uri, body: body, auth: auth);
    if (res.statusCode == 401 && auth) {
      if (await _tryRefresh()) {
        res = await _raw(method, uri, body: body, auth: auth);
      }
    }
    return _decode(res);
  }

  // ── Public HTTP helpers ───────────────────────────────────

  Future<dynamic> get(String path,
      {Map<String, String>? query, bool auth = true}) =>
      _req('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) =>
      _req('POST', path, body: body, auth: auth);

  Future<dynamic> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) =>
      _req('PUT', path, body: body, auth: auth);

  Future<dynamic> patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) =>
      _req('PATCH', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = true}) =>
      _req('DELETE', path, auth: auth);

  // ── Multipart upload ──────────────────────────────────────

  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    String field    = 'file',
    String mimeType = 'image/jpeg',
    Map<String, String> extraFields = const {},
  }) async {
    final token = await _Tokens.access();
    final parts = mimeType.split('/');
    final req   = http.MultipartRequest('POST',
        Uri.parse('${ApiConfig.api}$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..fields.addAll(extraFields)
      ..files.add(await http.MultipartFile.fromPath(
        field, filePath,
        contentType: MediaType(parts[0], parts.length > 1 ? parts[1] : '*'),
      ));
    final streamed = await req.send();
    final res      = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Future<dynamic> _upload(String path, Map<String, String> fields,
      String fileField, File file, String mimeType) =>
      uploadFile(path,
          filePath:    file.path,
          field:       fileField,
          mimeType:    mimeType,
          extraFields: fields);

  // ══════════════════════════════════════════════════════════
  // AUTH  — all URLs now /accounts/ not /auth/
  // ══════════════════════════════════════════════════════════

  /// POST /api/accounts/student/verify/
  Future<Map<String, dynamic>> verifyStudent({
    required String studentId,
    required String dateOfBirth,
  }) async {
    final d = await post('/accounts/student/verify/', body: {
      'student_id':    studentId,
      'date_of_birth': dateOfBirth,
    }, auth: false) as Map<String, dynamic>;
    if (d['success'] != true) {
      throw const ApiException('Invalid student ID or date of birth.');
    }
    return d;
  }

  /// POST /api/accounts/staff/verify/
  Future<Map<String, dynamic>> verifyStaff({
    required String staffId,
    required String dateOfBirth,
  }) async {
    final d = await post('/accounts/staff/verify/', body: {
      'staff_id':      staffId,
      'date_of_birth': dateOfBirth,
    }, auth: false) as Map<String, dynamic>;
    if (d['success'] != true) {
      throw const ApiException('Invalid staff ID or date of birth.');
    }
    return d;
  }

  /// POST /api/accounts/login/
  Future<Map<String, dynamic>> loginWithId({
    required String userId,
    required String dateOfBirth,
    required String role, // 'student' | 'teaching_staff'
  }) async {
    final d = await post('/accounts/login/', body: {
      'user_id':       userId,
      'date_of_birth': dateOfBirth,
      'role':          role,
    }, auth: false) as Map<String, dynamic>;
    await _Tokens.save(d['access'] as String, d['refresh'] as String);
    await _Tokens.saveUser(d['user'] as Map<String, dynamic>);
    return d;
  }

  /// POST /api/accounts/logout/
  Future<void> logout() async {
    final refresh = await _Tokens.refresh();
    if (refresh != null) {
      try {
        await post('/accounts/logout/', body: {'refresh': refresh});
      } catch (_) {}
    }
    await _Tokens.clear();
  }

  // ══════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getMyProfile()                        => get('/users/me/');
  Future<dynamic> updateProfile(Map<String, dynamic> d) => patch('/users/me/', body: d);
  Future<dynamic> getUserProfile(String userId)         => get('/users/$userId/');
  Future<dynamic> followToggle(String userId)           => post('/users/$userId/follow/');
  Future<dynamic> searchUsers(String q)                 => get('/users/search/', query: {'q': q});
  Future<dynamic> getSuggestedUsers({int limit = 20})   =>
      get('/users/suggested/', query: {'limit': '$limit'});
  Future<dynamic> getFollowers(String userId)           => get('/users/$userId/followers/');
  Future<dynamic> getFollowing(String userId)           => get('/users/$userId/following/');
  Future<dynamic> updateFcmToken(String token)          =>
      post('/users/me/fcm-token/', body: {'fcm_token': token});

  Future<dynamic> uploadAvatar(File f) =>
      _upload('/users/me/avatar/', {}, 'avatar', f, 'image/jpeg');

  Future<dynamic> uploadCover(File f) =>
      _upload('/users/me/cover/', {}, 'cover', f, 'image/jpeg');

  // ── Phase 3 — privacy toggles ────────────────────────────

  /// Set or clear interests visibility on my profile.
  /// Convenience wrapper around updateProfile.
  Future<dynamic> setInterestsVisibility(String visibility) =>
      updateProfile({'interests_visibility': visibility});

  /// Set bio public/private on my profile.
  /// Reads & merges the existing privacy_settings dict so we don't
  /// clobber other privacy keys that may live there.
  Future<dynamic> setBioPublic(bool isPublic) async {
    final me = await getMyProfile() as Map<String, dynamic>;
    final prefs = Map<String, dynamic>.from(
        (me['privacy_settings'] as Map?) ?? {});
    prefs['bio_public'] = isPublic;
    return updateProfile({'privacy_settings': prefs});
  }

  // ══════════════════════════════════════════════════════════
  // FEED & POSTS
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getFeed({String type = 'home', int page = 1}) =>
      get('/posts/feed/', query: {'type': type, 'page': '$page'});

  Future<dynamic> getPosts({String? userId, int page = 1}) =>
      get('/posts/', query: {
        if (userId != null) 'user_id': userId,
        'page': '$page',
      });

  Future<dynamic> createPost({
    required String content,
    String postType        = 'post',
    String visibility      = 'public',
    String location        = '',
    String backgroundColor = '',
  }) => post('/posts/', body: {
    'content':          content,
    'post_type':        postType,
    'visibility':       visibility,
    'location':         location,
    'background_color': backgroundColor,
  });

  Future<dynamic> getPost(String id)    => get('/posts/$id/');

  /// Profile: my regular posts
  /// FIX: was sending the literal string "$page" because of '\$page' escape.
  Future<dynamic> getMyPosts({int page = 1}) =>
      get('/posts/mine/', query: {'post_type': 'post', 'page': '$page'});

  /// Profile: my fweets
  /// FIX: was sending the literal string "$page" because of '\$page' escape.
  Future<dynamic> getMyFweets({int page = 1}) =>
      get('/posts/mine/', query: {'post_type': 'fweet', 'page': '$page'});

  /// Profile: bookmarked/favorited posts
  /// FIX: was sending the literal string "$page" because of '\$page' escape.
  Future<dynamic> getFavorites({int page = 1}) =>
      get('/posts/bookmarks/', query: {'page': '$page'});

  /// FIX: was hitting "/posts/$id/" literally because of '\$id' escape.
  Future<dynamic> deletePost(String id) => delete('/posts/$id/');
  Future<dynamic> updatePost(String id, Map<String, dynamic> data) =>
      patch('/posts/$id/', body: data);
  Future<dynamic> likeToggle(String id)        => post('/posts/$id/like/');
  Future<dynamic> sharePost(String postId, List<String> userIds) =>
      post('/posts/$postId/share/', body: {'user_ids': userIds});
  Future<dynamic> bookmarkToggle(String id)    => post('/posts/$id/bookmark/');
  Future<dynamic> getBookmarks({int page = 1}) =>
      get('/posts/bookmarks/', query: {'page': '$page'});
  Future<dynamic> flagPost(String id, {String reason = 'other'}) =>
      post('/posts/$id/flag/', body: {'reason': reason});
  Future<dynamic> getComments(String postId, {int page = 1}) =>
      get('/posts/$postId/comments/', query: {'page': '$page'});
  Future<dynamic> addComment(String postId, String text, {String? parentId}) =>
      post('/posts/$postId/comments/', body: {
        'text': text,
        if (parentId != null) 'parent_id': parentId,
      });
  /// Upload an image or video to a post. Routes through the existing
  /// uploadFile() helper so auth, error decoding, and MIME formatting
  /// stay consistent with every other multipart upload.
  ///
  /// `mediaType` must be 'image' or 'video' — the backend uses it to
  /// route the asset through the right Cloudinary resource bucket.
  Future<dynamic> uploadPostMedia(
    String postId,
    File   file, {
    String mediaType = 'image',
  }) {
    final ext = file.path.split('.').last.toLowerCase();
    final mime = mediaType == 'video'
        ? switch (ext) {
            'mov'  => 'video/quicktime',
            'webm' => 'video/webm',
            _      => 'video/mp4',
          }
        : switch (ext) {
            'png'  => 'image/png',
            'webp' => 'image/webp',
            'gif'  => 'image/gif',
            _      => 'image/jpeg',
          };
    return uploadFile(
      '/posts/upload/',
      filePath:    file.path,
      field:       'file',
      mimeType:    mime,
      extraFields: {
        'post_id':    postId,
        'media_type': mediaType,
      },
    );
  }  // ══════════════════════════════════════════════════════════
  // CHAT
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getChatRooms() => get('/chat/rooms/');
  Future<dynamic> startDM(String targetUserId) =>
      post('/chat/rooms/', body: {'room_type': 'direct', 'member_ids': [targetUserId]});
  Future<dynamic> createGroupChat({
    required String       name,
    required List<String> memberIds,
    String description = '',
  }) => post('/chat/rooms/', body: {
    'room_type':  'group', 'name': name,
    'description': description, 'member_ids': memberIds,
  });
  Future<dynamic> getRoomMessages(String roomId, {String? beforeId}) =>
      get('/chat/rooms/$roomId/messages/',
          query: {if (beforeId != null) 'before': beforeId});
  Future<dynamic> markRoomRead(String roomId)  => post('/chat/rooms/$roomId/read/');
  Future<dynamic> uploadChatMedia({
    required String roomId,
    required File   file,
    required String mimeType,
  }) => _upload('/chat/upload/', {'room_id': roomId}, 'file', file, mimeType);
  Future<dynamic> searchGifs(String query, {int limit = 20}) =>
      get('/chat/gifs/search/', query: {'q': query, 'limit': '$limit'});
  Future<dynamic> getTrendingGifs({int limit = 16}) =>
      get('/chat/gifs/trending/', query: {'limit': '$limit'});
  Future<dynamic> getStickerPacks()         => get('/chat/stickers/');
  Future<dynamic> getSavedMaterials()       => get('/chat/saved/');
  Future<dynamic> deleteSavedMaterial(String id) => delete('/chat/saved/$id/');
  Future<dynamic> getStudyBuddies()         => get('/chat/study-buddy/');

  // ══════════════════════════════════════════════════════════
  // GROUPS  (study groups — separate from CLUBS)
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getGroups({String filter = 'all', String q = ''}) =>
      get('/groups/', query: {'filter': filter, if (q.isNotEmpty) 'q': q});
  Future<dynamic> getGroup(String id)          => get('/groups/$id/');
  Future<dynamic> joinGroup(String id)         => post('/groups/$id/join/');
  Future<dynamic> leaveGroup(String id)        => delete('/groups/$id/leave/');
  Future<dynamic> getGroupMaterials(String id) => get('/groups/$id/materials/');
  Future<dynamic> updateStudyBuddy(Map<String, dynamic> data) =>
      put('/groups/buddies/me/', body: data);

  // ══════════════════════════════════════════════════════════
  // EVENTS  (Phase 2)
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getEvents({String? category, String? search, int page = 1}) =>
      get('/events/', query: {
        if (category != null) 'category': category,
        if (search   != null) 'search':   search,
        'page': '$page',
      });

  Future<dynamic> getEvent(String id) => get('/events/$id/');

  /// Phase 2 spec 9.4 — three-state RSVP.
  /// Pass null to clear an existing RSVP (sends {"status": "clear"}).
  /// Otherwise pass one of: kRsvpGoing, kRsvpInterested, kRsvpNotGoing.
  Future<dynamic> setRsvp(String eventId, String? status) =>
      post('/events/$eventId/rsvp/', body: {
        'status': status ?? 'clear',
      });

  /// Legacy binary toggle — kept for any old call sites that haven't
  /// been migrated yet. Prefer setRsvp(...).
  @Deprecated('Use setRsvp(eventId, status). Will be removed.')
  Future<dynamic> rsvpToggle(String id) =>
      post('/events/$id/rsvp/toggle/');

  Future<dynamic> getMyEvents() => get('/events/mine/');

  Future<dynamic> createEvent(Map<String, dynamic> data) =>
      post('/events/', body: data);

  /// Phase 2 spec 10.2 — upload an event poster (Cloudinary).
  Future<dynamic> uploadEventPoster(
    String eventId, {
    required String filePath,
    String mimeType = 'image/jpeg',
  }) =>
      uploadFile('/events/$eventId/poster/',
          filePath: filePath, field: 'poster', mimeType: mimeType);

  /// Phase 2 spec 10.3 — unified events + announcements carousel.
  /// Returns a Map with `results` (list) and `count`.
  Future<dynamic> getCampusHighlights({int limit = 10}) =>
      get('/events/highlights/', query: {'limit': '$limit'});

  // ══════════════════════════════════════════════════════════
  // PHASE 3 — chat helpers for share-profile + other-user actions
  // ══════════════════════════════════════════════════════════

  /// Recent chats for the share-profile bottom sheet.
  /// Returns up to `limit` recent rooms. The widget falls back to
  /// getChatRooms() automatically if this endpoint isn't deployed yet.
  Future<dynamic> getRecentChats({int limit = 5}) =>
      get('/chat/recent/', query: {'limit': '$limit'});

  /// Send a chat request from the other-user-profile screen's
  /// "Message" button. Backend creates a ChatRequest the receiver
  /// can accept or decline.
  Future<dynamic> sendChatRequest(String targetUserId, {String message = ''}) =>
      post('/chat/requests/send/', body: {
        'user_id': targetUserId,
        if (message.isNotEmpty) 'message': message,
      });

  /// Share a profile to a chat room as a regular text message.
  /// Embeds the user_id as `[profile:USER_ID]` so a future chat
  /// polish pass can render it as a rich profile card. For now it
  /// just shows up as text with a recognisable token.
  Future<dynamic> shareProfileToRoom({
    required String roomId,
    required String targetUserId,
    required String targetName,
  }) {
    final text = 'Check out this profile: $targetName [profile:$targetUserId]';
    return post('/chat/rooms/$roomId/messages/', body: {'text': text});
  }

  // ══════════════════════════════════════════════════════════
  // CLUBS  (Phase 5 — separate from study GROUPS above)
  // ══════════════════════════════════════════════════════════
  //
  // Backend lives at apps.clubs / /api/clubs/. The clubs app is a
  // distinct module from apps.groups (study groups). Clubs are
  // campus-wide communities with verification, roles, approval-gated
  // joining, and admin controls.
  // ──────────────────────────────────────────────────────────

  /// GET /api/clubs/?filter=all|mine|pending|admin&q=&category=&page=
  Future<dynamic> getClubs({
    String  filter   = 'all',
    String? q,
    String? category,
    int     page     = 1,
  }) =>
      get('/clubs/', query: {
        'filter': filter,
        if (q != null && q.isNotEmpty)               'q': q,
        if (category != null && category.isNotEmpty) 'category': category,
        'page': '$page',
      });

  /// GET /api/clubs/<id>/
  Future<dynamic> getClub(String id) => get('/clubs/$id/');

  /// POST /api/clubs/  (creator becomes PRESIDENT)
  Future<dynamic> createClub(Map<String, dynamic> data) =>
      post('/clubs/', body: data);

  /// PATCH /api/clubs/<id>/  (admin only — Executive or President)
  Future<dynamic> updateClub(String id, Map<String, dynamic> data) =>
      patch('/clubs/$id/', body: data);

  /// DELETE /api/clubs/<id>/  (president only — soft dissolve)
  Future<dynamic> dissolveClub(String id) => delete('/clubs/$id/');

  /// POST /api/clubs/<id>/join/
  /// Returns { status, role, is_member, is_pending, is_admin }.
  /// If the club has requires_approval=true, status comes back
  /// 'pending' and the user enters the admin's review queue.
  Future<dynamic> joinClub(String id) => post('/clubs/$id/join/');

  /// DELETE /api/clubs/<id>/leave/
  /// Backend rejects this for the current president — they have to
  /// transfer presidency first to prevent orphan clubs.
  Future<dynamic> leaveClub(String id) => delete('/clubs/$id/leave/');

  /// GET /api/clubs/<id>/members/?status=active|pending
  /// Default 'active'. Use 'pending' to show approval queue (admin).
  Future<dynamic> getClubMembers(String id, {String status = 'active'}) =>
      get('/clubs/$id/members/', query: {'status': status});

  /// POST /api/clubs/<id>/members/<user_id>/approve/   (admin only)
  Future<dynamic> approveClubMember(String clubId, String userId) =>
      post('/clubs/$clubId/members/$userId/approve/');

  /// POST /api/clubs/<id>/members/<user_id>/reject/    (admin only)
  Future<dynamic> rejectClubMember(String clubId, String userId) =>
      post('/clubs/$clubId/members/$userId/reject/');

  /// DELETE /api/clubs/<id>/members/<user_id>/         (admin only)
  /// Cannot remove the president — backend enforces this.
  Future<dynamic> removeClubMember(String clubId, String userId) =>
      delete('/clubs/$clubId/members/$userId/');

  /// PATCH /api/clubs/<id>/members/<user_id>/role/     (admin only)
  /// body: {"role": "member" | "executive" | "president"}
  /// Promoting to 'president' is allowed only if the caller is the
  /// current president; the existing president gets demoted to
  /// executive in the same atomic transaction.
  Future<dynamic> changeClubMemberRole(
          String clubId, String userId, String role) =>
      patch('/clubs/$clubId/members/$userId/role/', body: {'role': role});

  /// POST /api/clubs/<id>/cover/   (admin only)
  Future<dynamic> uploadClubCover(
    String id, {
    required String filePath,
    String mimeType = 'image/jpeg',
  }) =>
      uploadFile('/clubs/$id/cover/',
          filePath: filePath, field: 'cover', mimeType: mimeType);

  /// POST /api/clubs/<id>/logo/    (admin only)
  Future<dynamic> uploadClubLogo(
    String id, {
    required String filePath,
    String mimeType = 'image/jpeg',
  }) =>
      uploadFile('/clubs/$id/logo/',
          filePath: filePath, field: 'logo', mimeType: mimeType);

  // ══════════════════════════════════════════════════════════
  // ARCADE
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getGames()          => get('/arcade/games/');
  Future<dynamic> getPlayerStats()    => get('/arcade/stats/');
  Future<dynamic> getTokenWallet()    => get('/arcade/tokens/');

  Future<dynamic> getLeaderboard({String? gameSlug, int limit = 20}) =>
      get('/arcade/leaderboard/', query: {
        if (gameSlug != null) 'game': gameSlug,
        'limit': '$limit',
      });

  Future<dynamic> submitScore({
    required String game,
    required int    score,
    int bonusTokens = 0,
  }) => post('/arcade/submit-score/', body: {
    'game':         game,
    'score':        score,
    'bonus_tokens': bonusTokens,
  });

  Future<dynamic> getGamerTag()           => get('/arcade/gamer-tag/');
  Future<dynamic> uploadGamerAvatar(File file) =>
      uploadFile('/arcade/gamer-tag/avatar/',
          filePath: file.path, field: 'avatar', mimeType: 'image/jpeg');

  Future<dynamic> getGameRequests()        => get('/arcade/game-requests/');
  Future<dynamic> sendChallenge({
    required String receiverId,
    required String gameSlug,
    required int    wager,
  }) => post('/arcade/game-requests/', body: {
    'receiver_id': receiverId,
    'game_slug':   gameSlug,
    'wager':       wager,
  });
  Future<dynamic> acceptChallenge(String id)  =>
      post('/arcade/game-requests/$id/accept/', body: {});
  Future<dynamic> declineChallenge(String id) =>
      post('/arcade/game-requests/$id/decline/', body: {});
  Future<dynamic> getSession(String id)       => get('/arcade/game-sessions/$id/');
  Future<dynamic> updateSession(String id,
      {required String action, int? score}) =>
      patch('/arcade/game-sessions/$id/', body: {
        'action': action,
        if (score != null) 'score': score,
      });
  Future<dynamic> checkAutoQuit(String id) =>
      post('/arcade/game-sessions/$id/auto-quit/', body: {});

  // ══════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getNotifications({bool unreadOnly = false, int page = 1}) =>
      get('/notifications/', query: {
        if (unreadOnly) 'unread': 'true',
        'page': '$page',
      });
  Future<int> getUnreadCount() async {
    final d = await get('/notifications/unread-count/') as Map<String, dynamic>;
    return d['unread_count'] as int? ?? 0;
  }
  Future<dynamic> markNotificationRead(String id) => post('/notifications/$id/read/');
  Future<dynamic> markAllNotificationsRead()       => post('/notifications/mark-all-read/');
  Future<dynamic> deleteNotification(String id)    => delete('/notifications/$id/');
  Future<dynamic> clearAllNotifications()          => delete('/notifications/clear/');

  // ══════════════════════════════════════════════════════════
  // FEEDBACK / SUGGESTION BOX
  // ══════════════════════════════════════════════════════════

  Future<dynamic> submitSuggestion({
    required String title,
    required String message,
    required String category,
  }) => post('/feedback/suggest/', body: {
    'title':    title,
    'message':  message,
    'category': category,
  });

  Future<dynamic> getMySuggestions() => get('/feedback/mine/');

  // ══════════════════════════════════════════════════════════
  // DATA ENTRY
  // ══════════════════════════════════════════════════════════

  Future<dynamic> registerStudent({
    required String fullName,
    required String preferredName,
    required String studentId,
    required String dateOfBirth,
    required String courseType,
    required String dateOfCommencement,
  }) => post('/dataentry/student/', body: {
    'full_name':            fullName,
    'preferred_name':       preferredName,
    'student_id':           studentId,
    'date_of_birth':        dateOfBirth,
    'course_type':          courseType,
    'date_of_commencement': dateOfCommencement,
  }, auth: false);

  Future<dynamic> registerStaff({
    required String staffType,
    required String staffId,
    required String fullName,
    required String preferredName,
    required String dateOfBirth,
  }) => post('/dataentry/staff/', body: {
    'staff_type':     staffType,
    'staff_id':       staffId,
    'full_name':      fullName,
    'preferred_name': preferredName,
    'date_of_birth':  dateOfBirth,
  }, auth: false);
}

// ─────────────────────────────────────────────────────────────
// CHAT WEBSOCKET SERVICE
// ─────────────────────────────────────────────────────────────

class ChatWebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(String roomId) async {
    await disconnect();
    final token = await _Tokens.access();
    if (token == null) return;
    final uri = Uri.parse('${ApiConfig.ws}/ws/chat/$roomId/?token=$token');
    _channel  = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try { _controller.add(jsonDecode(raw as String) as Map<String, dynamic>); }
        catch (_) {}
      },
      onDone:  () => _channel = null,
      onError: (_) => _channel = null,
    );
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void _send(Map<String, dynamic> p) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(p));
  }

  void sendText(String text, {String? replyToId, List<String> mentions = const []}) =>
      _send({'action':'message','message_type':'text','text':text,
        if (replyToId != null) 'reply_to': replyToId,
        if (mentions.isNotEmpty) 'mentions': mentions});

  void sendMedia({required String messageType, required String mediaUrl,
      String? fileName, double? duration, String? replyToId}) =>
      _send({'action':'message','message_type':messageType,'media_url':mediaUrl,
        if (fileName  != null) 'file_name':      fileName,
        if (duration  != null) 'media_duration': duration,
        if (replyToId != null) 'reply_to':       replyToId});

  void sendSticker(int stickerId, {String? replyToId}) => _send(
      {'action':'message','message_type':'sticker','sticker_id':stickerId,
        if (replyToId != null) 'reply_to': replyToId});

  void sendGif(String gifUrl) =>
      sendMedia(messageType: 'gif', mediaUrl: gifUrl);

  void sendTyping(bool isTyping) =>
      _send({'action':'typing','is_typing':isTyping});

  void sendRead(String messageId) =>
      _send({'action':'read','message_id':messageId});

  void sendReaction(String messageId, String emoji) =>
      _send({'action':'reaction','message_id':messageId,'emoji':emoji});

  void deleteMessage(String messageId) =>
      _send({'action':'delete_message','message_id':messageId});

  void editMessage(String messageId, String newText) =>
      _send({'action':'edit_message','message_id':messageId,'text':newText});

  void fetchHistory({String? beforeMessageId, int limit = 30}) => _send({
    'action':'fetch_history',
    if (beforeMessageId != null) 'before_message_id': beforeMessageId,
    'limit': limit,
  });

  void dispose() { disconnect(); _controller.close(); }
}

// ─────────────────────────────────────────────────────────────
// NOTIFICATION WEBSOCKET SERVICE
// ─────────────────────────────────────────────────────────────

class NotificationWebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  Future<void> connect() async {
    await disconnect();
    final token = await _Tokens.access();
    if (token == null) return;
    final uri = Uri.parse('${ApiConfig.ws}/ws/notifications/?token=$token');
    _channel  = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try { _controller.add(jsonDecode(raw as String) as Map<String, dynamic>); }
        catch (_) {}
      },
      onDone:  () => _channel = null,
      onError: (_) => _channel = null,
    );
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void markRead(String id) =>
      _channel?.sink.add(jsonEncode({'action':'mark_read','id':id}));
  void markAllRead() =>
      _channel?.sink.add(jsonEncode({'action':'mark_all_read'}));

  void dispose() { disconnect(); _controller.close(); }
}
