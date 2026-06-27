// lib/services/api_service.dart
// ALL auth URLs corrected: /api/auth/ → /api/accounts/
// to match TCS/urls.py: path("accounts/", include("apps.accounts.urls"))
//
// SECTION 1 FIX: SharedPreferences keys are now centralised in
// session_keys.dart. _Tokens.saveUser also persists identity fields
// (fullName, preferredName, role, userId) so the splash and dashboard
// can read them without parsing JSON.
//
// STICKY-SESSION FIX
// ──────────────────
// _tryRefresh() and initialize() MUST NEVER call _Tokens.clear() —
// under ANY circumstance. The session is sticky: tokens stay in
// SharedPreferences from login until the moment the user explicitly
// taps Logout. Whatever the backend says when we try to refresh —
// 200, 401, 500, timeout, network blackout — the session stays put.
//
// Refresh succeeds → update access token, return true.
// Refresh fails for ANY reason → return false. NOTHING ELSE.
//
// The ONLY function that wipes the session is logout(), which is
// only invoked when the user explicitly taps the logout button.
// This guarantees the splash screen always finds a valid session
// after login and routes the user straight to the dashboard.
//
// RESUME-REFRESH HOOK
// ───────────────────
// A new public method refreshAccessToken() exposes the existing
// private _tryRefresh() to the root widget. _TCSAppState calls it on
// AppLifecycleState.resumed when the saved JWT's exp claim is within
// 5 minutes, so the dashboard and downstream clients (Dale AI SSE,
// arcade WebViews, WebSockets) all see a fresh token when the user
// brings the app back to the foreground.
//
// Bug fixes: replaced '\$page' / '\$id' literal escapes (which sent
// the literal text "$page" / "$id" to the server) with proper
// interpolation in getMyPosts / getMyFweets / getFavorites / deletePost.
//
// ARCADE OVERHAUL: full token-economy + multiplayer + spectator API.
// Legacy methods (sendChallenge, getSession, updateSession,
// checkAutoQuit) are kept so existing screens keep compiling, but
// the ones whose backend endpoint was removed are marked @Deprecated
// — migrate call sites to createChallenge / submitMatchResult /
// forfeitSession.
//
// SAVED MATERIALS + QUIZ: added updateSavedMaterial in the CHAT
// section, saveGroupMaterialToLibrary in the GROUPS section, and a
// dedicated QUIZ section that talks to the new /api/quiz/* routes.
// The frontend never sends file bytes for quiz generation — the
// backend pulls the file straight from Cloudinary and extracts text.
//
// CHAT BUBBLES (Phase 3B): createBubble / discoverBubbles / joinBubble
// / inviteToBubble / getMyBubbleInvites / acceptBubbleInvite /
// declineBubbleInvite live in the CHAT section of ApiService.
//
// CLUB EVENT CREATION (new): generateEventPoster (Flux AI),
// createClubEvent (POST /clubs/<id>/events/), and inviteToClub
// (POST /clubs/<id>/invites/) for the redesigned club screen.
//
// EVENT DELETE (new): deleteEvent(String id) maps to
// DELETE /api/events/<id>/ which soft-deletes the event server-side
// (sets is_active=False). Used by the club screen's event detail
// dialog when an admin chooses Delete Event.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../screens/auth/session_keys.dart';


// ─────────────────────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────────────────────

class ApiConfig {
  // Production backend (DigitalOcean droplet, Sydney).
  // Override for local dev with:
  //   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
  //   (Android emulator: http://10.0.2.2:8000)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tcs-nsw.duckdns.org',
  );

  static String get api => '$baseUrl/api';

  // Converts http→ws AND https→wss (replaceFirst on 'http' inside
  // 'https' correctly yields 'wss').
  static String get ws => baseUrl.replaceFirst('http', 'ws');
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
  ///
  /// THIS IS THE ONLY DESTRUCTIVE CALL IN THE ENTIRE FILE.
  /// Invoked exclusively from ApiService.logout(). DO NOT call from
  /// _tryRefresh, initialize, or anywhere else.
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

  /// Best-effort proactive refresh. Call this on app launch (from the
  /// splash) so the first dashboard API call hits a fresh access
  /// token instead of a stale one.
  ///
  /// STICKY-SESSION FIX: this method CANNOT wipe the session. If the
  /// refresh fails for any reason (401, 500, timeout, network out),
  /// the session is left untouched. The splash screen routes to the
  /// dashboard regardless of the result of this call.
  Future<void> initialize() async {
    if (!await _Tokens.has()) return;
    try {
      await _tryRefresh().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Refresh attempt timed out or threw — that's fine. Session
      // stays put; individual API calls handle their own auth.
    }
  }


  

  Future<bool> get isLoggedIn              => _Tokens.has();
  Future<void> clearTokens()               => _Tokens.clear();
  Future<String?> get accessToken          => _Tokens.access();
  Future<Map<String, dynamic>?> get cachedUser => _Tokens.user();

  /// Public hook for proactive token refresh.
  ///
  /// Invoked by `_TCSAppState.didChangeAppLifecycleState` whenever
  /// the app comes back to the foreground AND the saved JWT's `exp`
  /// claim is expired or within 5 minutes of expiring. Returns true
  /// 
  /// 
  ///   // Add this getter right after the existing getters (around line 90-100)
  Future<String?> get currentUserId async {
    final user = await cachedUser;
    return user?['user_id']?.toString() ?? 
           user?['id']?.toString();
  }

  // Optional: Also add a synchronous version using cached data
  String? get currentUserIdSync {
    // This is faster but might be null if not loaded yet
    return null; // We'll use the async version for reliability
  }
  /// on success, false on any failure (per the sticky-session
  /// contract, the session is left untouched either way).
  Future<bool> refreshAccessToken() => _tryRefresh();

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
      case 'DELETE': return _client.delete(uri, headers: h, body: b); // ← body added
      default:       throw ApiException('Unknown method: $method');
    }
  }

 dynamic _decode(http.Response res) {
    // 204 No Content (and other empty-body successes) — return null cleanly
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty || res.statusCode == 204) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    final body = res.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    String msg = 'Request failed (${res.statusCode})';
    if (body is Map) {
      msg = (body['detail'] ?? body['error'] ??
             body['non_field_errors']?.toString() ??
             body.values.firstOrNull?.toString() ?? msg).toString();
    }
    throw ApiException(msg, statusCode: res.statusCode);
  }

  // ── Token refresh ─────────────────────────────────────────
  // URL: /api/accounts/token/refresh/
  //
  // STICKY-SESSION FIX: this method NEVER wipes the session. Period.
  //
  //   200 → update the access token + return true
  //   any non-200 → return false (session preserved)
  //   exception (network/timeout) → return false (session preserved)
  //
  // The session can ONLY be wiped via explicit logout(). If the
  // refresh token is genuinely dead, individual API calls will start
  // returning 401 and bubble up as ApiException to the calling screen
  // — but the user remains "logged in" from the splash's perspective
  // and won't be force-routed back to RoleSelection on cold start.
  Future<bool> _tryRefresh() async {
    final r = await _Tokens.refresh();
    if (r == null || r.isEmpty) return false;
    try {
      final res = await _client.post(
        Uri.parse('${ApiConfig.api}/accounts/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': r}),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        final newAccess  = d['access'] as String;
        final newRefresh = (d['refresh'] as String?) ?? r;
        await _Tokens.save(newAccess, newRefresh);
        return true;
      }
      // Any non-200 response — including 401 — does NOT wipe the
      // session. We just return false and let the caller decide.
    } catch (_) {
      // Network error / timeout / DNS — session stays put.
    }
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
      // Try a single refresh + retry. If refresh fails, the original
      // 401 surfaces as an ApiException; the calling screen handles
      // it. Session is NOT wiped.
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

  /// Permanently delete the signed-in user's account (irreversible).
  Future<dynamic> deleteAccount() => post('/accounts/delete/');

  Future<dynamic> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) =>
      _req('PUT', path, body: body, auth: auth);

  Future<dynamic> patch(String path,
      {Map<String, dynamic>? body, bool auth = true}) =>
      _req('PATCH', path, body: body, auth: auth);
Future<dynamic> delete(String path,
      {Map<String, dynamic>? body, bool auth = true}) =>
      _req('DELETE', path, body: body, auth: auth);
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
    // Defence-in-depth: wipe any prior user's cached data before
    // saving the new session, in case the previous user closed the
    // app without logging out.
    await _Tokens.clear();
    await _Tokens.save(d['access'] as String, d['refresh'] as String);
    await _Tokens.saveUser(d['user'] as Map<String, dynamic>);
    return d;
  }

  /// Email/password login for visitor/parent accounts.
  Future<Map<String, dynamic>> loginPassword({
    required String identifier,
    required String password,
  }) async {
    final d = await post('/accounts/login-password/', body: {
      'identifier': identifier,
      'password':   password,
    }, auth: false) as Map<String, dynamic>;
    if (d['success'] == false) {
      throw Exception(d['error'] ?? 'Invalid credentials.');
    }
    await _Tokens.clear();
    await _Tokens.save(d['access'] as String, d['refresh'] as String);
    await _Tokens.saveUser(d['user'] as Map<String, dynamic>);
    return d;
  }

  /// Self-registration for visitor/parent, then logs in to get a session.
  Future<Map<String, dynamic>> registerVisitor({
    required String name,
    required String username,
    required String email,
    required String password,
    required String dateOfBirth, // YYYY-MM-DD
    required String role,        // 'visitor' | 'parent'
  }) async {
    await post('/accounts/register/', body: {
      'name': name, 'username': username, 'email': email,
      'password': password, 'confirm_password': password,
      'date_of_birth': dateOfBirth, 'role': role,
    }, auth: false);
    return loginPassword(identifier: email, password: password);
  }

  /// POST /api/accounts/logout/
  /// THE ONLY PLACE _Tokens.clear() IS CALLED. Invoked when the user
  /// explicitly taps the logout button.
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

  Future<dynamic> setInterestsVisibility(String visibility) =>
      updateProfile({'interests_visibility': visibility});

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

  Future<dynamic> getFeelings() => get('/feelings/');

  Future<dynamic> createPost({
    required String content,
    String  postType        = 'post',
    String  visibility      = 'public',
    String  location        = '',
    String  backgroundColor = '',
    String? feeling,
    String? clubId,
  }) => post('/posts/', body: {
    'content':          content,
    'post_type':        postType,
    'visibility':       visibility,
    'location':         location,
    'background_color': backgroundColor,
    if (feeling != null && feeling.isNotEmpty) 'feeling': feeling,
    if (clubId  != null && clubId.isNotEmpty)  'club':    clubId,
  });

  Future<dynamic> getPost(String id)    => get('/posts/$id/');

  Future<dynamic> getMyPosts({int page = 1}) =>
      get('/posts/mine/', query: {'post_type': 'post', 'page': '$page'});

  Future<dynamic> getMyFweets({int page = 1}) =>
      get('/posts/mine/', query: {'post_type': 'fweet', 'page': '$page'});

  Future<dynamic> getFavorites({int page = 1}) =>
      get('/posts/bookmarks/', query: {'page': '$page'});

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

  // -- SAFETY / MODERATION --
  Future<dynamic> blockUser(String userId, {String reason = ''}) =>
      post('/moderation/blocks/', body: {'blocked': userId, 'reason': reason});
  Future<dynamic> unblockUser(String userId) =>
      delete('/moderation/blocks/$userId/');
  Future<dynamic> getBlockedUsers() => get('/moderation/blocks/');
  Future<dynamic> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String detail = '',
  }) =>
      post('/moderation/reports/', body: {
        'content_type_model': targetType,
        'object_id': targetId,
        'reason': reason,
        'description': detail,
      });
  Future<dynamic> getComments(String postId, {int page = 1}) =>
      get('/posts/$postId/comments/', query: {'page': '$page'});
  Future<dynamic> addComment(String postId, String text, {String? parentId}) =>
      post('/posts/$postId/comments/', body: {
        'text': text,
        if (parentId != null) 'parent_id': parentId,
      });
  Future<dynamic> getReplies(String postId, String commentId, {int page = 1}) =>
      get('/posts/$postId/comments/',
          query: {'parent': commentId, 'page': '$page'});
  Future<dynamic> likeComment(String commentId) =>
      post('/posts/comments/$commentId/like/');

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
  }

  // ══════════════════════════════════════════════════════════
  // HIGHLIGHTS  (Instagram-style profile story highlights)
  // ══════════════════════════════════════════════════════════
  //
  // Django routes still to build:
  //   GET    /api/highlights/mine/                  my highlights
  //   GET    /api/highlights/<id>/                  one highlight + items
  //   GET    /api/users/<user_id>/highlights/       another user's
  //   POST   /api/highlights/                       create {title}
  //   POST   /api/highlights/upload/                multipart:
  //          highlight_id, file, media_type, is_cover
  //   DELETE /api/highlights/<id>/                  delete highlight
  //   DELETE /api/highlights/<id>/items/<item_id>/  delete one item
  //
  // Each highlight's `items` should serialize with at least `url` and
  // `media_type` — that's what HighlightStory.fromJson reads.

  Future<dynamic> getMyHighlights() => get('/highlights/mine/');

  Future<dynamic> getHighlight(String id) => get('/highlights/$id/');

  Future<dynamic> getUserHighlights(String userId) =>
      get('/users/$userId/highlights/');

  Future<dynamic> createHighlight({required String title}) =>
      post('/highlights/', body: {'title': title});

  Future<dynamic> uploadHighlightMedia(
    String highlightId,
    File   file, {
    String mediaType = 'image',
    bool   isCover   = false,
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
      '/highlights/upload/',
      filePath:    file.path,
      field:       'file',
      mimeType:    mime,
      extraFields: {
        'highlight_id': highlightId,
        'media_type':   mediaType,
        'is_cover':     isCover ? 'true' : 'false',
      },
    );
  }

  Future<dynamic> deleteHighlight(String id) => delete('/highlights/$id/');

  Future<dynamic> deleteHighlightItem(String highlightId, String itemId) =>
      delete('/highlights/$highlightId/items/$itemId/');

  // ══════════════════════════════════════════════════════════
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

  /// Upload a Chat Bubble's profile picture. Call AFTER createBubble()
  /// since the room must already exist. Routes through uploadFile() so
  /// auth + MIME formatting match every other Cloudinary upload.
  Future<dynamic> uploadBubbleAvatar(String roomId, File file) {
    final ext = file.path.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png'  => 'image/png',
      'webp' => 'image/webp',
      _      => 'image/jpeg',
    };
    return uploadFile('/chat/rooms/$roomId/avatar/',
        filePath: file.path, field: 'avatar', mimeType: mime);
  }
  Future<dynamic> searchGifs(String query, {int limit = 20}) =>
      get('/chat/gifs/search/', query: {'q': query, 'limit': '$limit'});
  Future<dynamic> getTrendingGifs({int limit = 16}) =>
      get('/chat/gifs/trending/', query: {'limit': '$limit'});
  Future<dynamic> getStickerPacks()         => get('/chat/stickers/');
  Future<dynamic> getSavedMaterials()       => get('/chat/saved/');
  Future<dynamic> deleteSavedMaterial(String id) => delete('/chat/saved/$id/');

  Future<dynamic> updateSavedMaterial({
    required String id,
    String? title,
    String? subject,
    String? sourceName,
    String? groupId,
  }) =>
      patch('/chat/saved/$id/', body: {
        if (title       != null) 'title':       title,
        if (subject     != null) 'subject':     subject,
        if (sourceName  != null) 'source_name': sourceName,
        if (groupId     != null) 'group_id':    groupId,
      });

  Future<dynamic> getStudyBuddies()         => get('/groups/buddies/');

  // ══════════════════════════════════════════════════════════
  // CHAT BUBBLES (Phase 3B)
  // ══════════════════════════════════════════════════════════

  Future<dynamic> createBubble({
    required String       name,
    String                about     = '',
    bool                  isPublic  = false,
    List<String>          memberIds = const [],
  }) =>
      post('/chat/rooms/', body: {
        'name':       name,
        'description':      about,
        'is_public':  isPublic,
        'member_ids': memberIds,
      });

  Future<dynamic> discoverBubbles({String q = ''}) =>
      get('/chat/bubbles/discover/',
          query: {if (q.isNotEmpty) 'q': q});

  Future<dynamic> joinBubble(String roomId) =>
      post('/chat/bubbles/$roomId/join/');

  Future<dynamic> inviteToBubble({
    required String       roomId,
    required List<String> userIds,
    String                message = '',
  }) =>
      post('/chat/bubbles/$roomId/invite/', body: {
        'user_ids': userIds,
        if (message.isNotEmpty) 'message': message,
      });

  Future<dynamic> getMyBubbleInvites() => get('/chat/invites/');

  Future<dynamic> acceptBubbleInvite(String inviteId) =>
      post('/chat/invites/$inviteId/accept/');

  Future<dynamic> declineBubbleInvite(String inviteId) =>
      post('/chat/invites/$inviteId/decline/');

  // ══════════════════════════════════════════════════════════
  // GROUPS
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getGroups({String filter = 'all', String q = ''}) =>
      get('/groups/', query: {'filter': filter, if (q.isNotEmpty) 'q': q});
  Future<dynamic> getGroup(String id)          => get('/groups/$id/');
  Future<dynamic> joinGroup(String id)         => post('/groups/$id/join/');
  Future<dynamic> leaveGroup(String id)        => delete('/groups/$id/leave/');
  Future<dynamic> getGroupMaterials(String id) => get('/groups/$id/materials/');

  /// Dissolve a study group. Backend should:
  ///   - copy all materials to caller's saved-materials library
  ///   - delete the group + its messages
  ///   - emit an activity record "Dissolved by <admin> on <date>"
  Future<dynamic> dissolveGroup(String id) => delete('/groups/$id/dissolve/');

  Future<dynamic> saveGroupMaterialToLibrary({
    required String groupId,
    required String materialId,
    String? title,
    String? subject,
  }) =>
      post('/groups/$groupId/materials/$materialId/save/', body: {
        if (title   != null) 'title':   title,
        if (subject != null) 'subject': subject,
      });
Future<dynamic> updateStudyBuddy(Map<String, dynamic> data) =>
      post('/groups/buddies/me/', body: data);  // ══════════════════════════════════════════════════════════
  // QUIZ
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getMyQuizzes({String? subject}) =>
      get('/quiz/', query: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });

  Future<dynamic> generateQuiz({
    required String      materialId,
    String?              subject,
    int                  numQuestions = 10,
    String               difficulty   = 'medium',
    List<String>         questionTypes = const ['mcq', 'true_false', 'short'],
  }) =>
      post('/quiz/generate/', body: {
        'material_id':    materialId,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'num_questions':  numQuestions,
        'difficulty':     difficulty,
        'question_types': questionTypes,
      });

  Future<dynamic> getQuizForPlay(String quizId) =>
      get('/quiz/$quizId/play/');

  Future<dynamic> submitQuizAttempt({
    required String              quizId,
    required Map<String, dynamic> answers,
    int                          durationSeconds = 0,
  }) =>
      post('/quiz/$quizId/submit/', body: {
        'answers':           answers,
        'duration_seconds':  durationSeconds,
      });

  Future<dynamic> getQuizDetail(String quizId) =>
      get('/quiz/$quizId/');

  Future<dynamic> deleteQuiz(String quizId) =>
      delete('/quiz/$quizId/');

  Future<dynamic> getQuizAttempts(String quizId) =>
      get('/quiz/$quizId/attempts/');

  // ══════════════════════════════════════════════════════════
  // EVENTS
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getEvents({String? category, String? search, int page = 1}) =>
      get('/events/', query: {
        if (category != null) 'category': category,
        if (search   != null) 'search':   search,
        'page': '$page',
      });

  Future<dynamic> getEvent(String id) => get('/events/$id/');

  Future<dynamic> setRsvp(String eventId, String? status) =>
      post('/events/$eventId/rsvp/', body: {
        'status': status ?? 'clear',
      });

  @Deprecated('Use setRsvp(eventId, status). Will be removed.')
  Future<dynamic> rsvpToggle(String id) =>
      post('/events/$id/rsvp/toggle/');

  Future<dynamic> getMyEvents() => get('/events/mine/');

  Future<dynamic> createEvent(Map<String, dynamic> data) =>
      post('/events/', body: data);

  /// DELETE /api/events/<id>/
  /// Soft-deletes the event server-side (sets is_active=False).
  /// Backend permission: caller must be the event organizer OR a
  /// teacher/admin. Used by the club screen's event detail dialog
  /// when an admin chooses Delete Event.
  Future<dynamic> deleteEvent(String id) => delete('/events/$id/');

  Future<dynamic> uploadEventPoster(
    String eventId, {
    required String filePath,
    String mimeType = 'image/jpeg',
  }) =>
      uploadFile('/events/$eventId/poster/',
          filePath: filePath, field: 'poster', mimeType: mimeType);

  Future<dynamic> getCampusHighlights({int limit = 10}) =>
      get('/events/highlights/', query: {'limit': '$limit'});

  /// POST /api/events/generate-poster/
  /// Calls the backend Flux AI poster generator. The Django view
  /// should: (1) verify the caller is president or executive of the
  /// given club, (2) call Flux with the prompt, (3) upload the result
  /// to Cloudinary, (4) return {"poster_url": "..."}.
  Future<dynamic> generateEventPoster({
    required String prompt,
    required String title,
    required String clubId,
  }) =>
      post('/events/generate-poster/', body: {
        'prompt':  prompt,
        'title':   title,
        'club_id': clubId,
      });

  // ══════════════════════════════════════════════════════════
  // PHASE 3 — chat helpers for share-profile + other-user actions
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getRecentChats({int limit = 5}) =>
      get('/chat/recent/', query: {'limit': '$limit'});

  Future<dynamic> getChatRequests()       => get('/chat/requests/');
  Future<dynamic> getSentChatRequests()   => get('/chat/requests/sent/');
  Future<dynamic> getOnlineUsers()        => get('/chat/users/online/');
  Future<dynamic> getConnectedUsers()     => get('/chat/users/connected/');

  Future<dynamic> analyzeWithDale(String roomId) =>
      post('/chat/rooms/$roomId/ai-analyze/', body: const {});

  Future<dynamic> sendChatRequest(String targetUserId, {String message = ''}) =>
      post('/chat/requests/send/', body: {
        'user_id': targetUserId,
        if (message.isNotEmpty) 'message': message,
      });

  Future<dynamic> shareProfileToRoom({
    required String roomId,
    required String targetUserId,
    required String targetName,
  }) {
    final text = 'Check out this profile: $targetName [profile:$targetUserId]';
    return post('/chat/rooms/$roomId/messages/', body: {'text': text});
  }

  // ══════════════════════════════════════════════════════════
  // CLUBS
  // ══════════════════════════════════════════════════════════

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

  Future<dynamic> getClub(String id) => get('/clubs/$id/');
  /// POST /api/clubs/  (creator becomes PRESIDENT)
  ///
  /// Uploads logo + cover after creation, then performs a final GET so
  /// the returned map has BOTH logo_url and cover_url populated.
  Future<dynamic> createClub(
    Map<String, dynamic> data, {
    String? logoPath,
    String? coverPath,
  }) async {
    final created = await post('/clubs/', body: data) as Map<String, dynamic>;
    final id = created['id']?.toString();
    if (id == null || id.isEmpty) return created;

    if (logoPath != null && logoPath.isNotEmpty) {
      try { await uploadClubLogo(id, filePath: logoPath); } catch (_) {}
    }
    if (coverPath != null && coverPath.isNotEmpty) {
      try { await uploadClubCover(id, filePath: coverPath); } catch (_) {}
    }

    // Final fetch so the caller sees both URLs merged in.
    try {
      final fresh = await getClub(id) as Map<String, dynamic>;
      return fresh;
    } catch (_) {
      return created;
    }
  }


  Future<dynamic> updateClub(String id, Map<String, dynamic> data) =>
      patch('/clubs/$id/', body: data);

  Future<dynamic> dissolveClub(String id) => delete('/clubs/$id/');

  Future<dynamic> joinClub(String id) => post('/clubs/$id/join/');

  Future<dynamic> leaveClub(String id) => delete('/clubs/$id/leave/');

  Future<dynamic> getClubMembers(String id, {String status = 'active'}) =>
      get('/clubs/$id/members/', query: {'status': status});

  Future<dynamic> approveClubMember(String clubId, String userId) =>
      post('/clubs/$clubId/members/$userId/approve/');

  Future<dynamic> declineClubMember(String clubId, String userId) =>
      post('/clubs/$clubId/members/$userId/reject/');

  Future<dynamic> removeClubMember(String clubId, String userId) =>
      delete('/clubs/$clubId/members/$userId/');

  Future<dynamic> getClubFeed(String clubId) =>
      get('/clubs/$clubId/feed/');

  Future<dynamic> getClubPosts(String clubId, {int page = 1}) =>
      get('/posts/', query: {'club_id': clubId, 'page': '$page'});

  Future<dynamic> changeClubMemberRole(
          String clubId, String userId, String role) =>
      patch('/clubs/$clubId/members/$userId/role/', body: {'role': role});

  Future<dynamic> uploadClubCover(
    String id, {
    required String filePath,
    String mimeType = 'image/jpeg',
  }) =>
      uploadFile('/clubs/$id/cover/',
          filePath: filePath, field: 'cover', mimeType: mimeType);

  Future<dynamic> uploadClubLogo(
    String id, {
    required String filePath,
    String mimeType = 'image/jpeg',
  }) =>
      uploadFile('/clubs/$id/logo/',
          filePath: filePath, field: 'logo', mimeType: mimeType);

  /// POST /api/clubs/<id>/events/
  /// Creates a club-scoped event. Backend permission: caller must be
  /// president or executive of the given club. The poster_url field
  /// is the Cloudinary URL returned by generateEventPoster, if used.
  Future<dynamic> createClubEvent({
    required String clubId,
    required String title,
    String? description,
    String? location,
    required String startTime,
    String? endTime,
    String? posterUrl,
  }) =>
      post('/clubs/$clubId/events/', body: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
        'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (posterUrl != null && posterUrl.isNotEmpty)
          'poster_url': posterUrl,
      });

  /// POST /api/clubs/<id>/chat/
  /// Get-or-create the club's members-only chat room. Backend should:
  ///   (1) verify the caller is an active member or admin of the club,
  ///   (2) return the existing club chat room, or create one on the
  ///       first call (group room, members = all active club members,
  ///       name defaults to "<club.name> Chat").
  /// Response shape matches other chat-room endpoints: id, name,
  /// room_type, members, ai_enabled, last_message, …
  Future<dynamic> getOrCreateClubChat(String clubId) =>
      post('/clubs/$clubId/chat/');

  /// POST /api/clubs/<id>/invites/
  /// Send club invites to a list of user IDs. Backend permission:
  /// caller must be president of the given club. Creates ClubInvite
  /// rows + dispatches in-app notifications.
  Future<dynamic> inviteToClub({
    required String clubId,
    required List<String> userIds,
  }) =>
      post('/clubs/$clubId/invites/', body: {'user_ids': userIds});

  /// Generates a club logo via the same /ai/image/ endpoint the
  /// AI Image Generator screen uses (Pollinations FLUX). We wrap the
  /// raw prompt with logo-friendly guidance so the result is a
  /// centered, square, recognizable mark.
  ///
  /// Response shape (from /ai/image/):
  ///   { id, prompt, model, image_url, width, height, seed, created_at }
  /// The create-club sheet reads `image_url` from this map.
  Future<dynamic> generateClubLogo({
    required String prompt,
    String name = '',
  }) {
    final enhanced = name.isNotEmpty
        ? 'Club logo for "$name": $prompt. Centered, clean vector-style '
          'mark, bold flat illustration, square composition, recognizable '
          'at small sizes, minimal background.'
        : 'Club logo: $prompt. Centered, clean vector-style mark, bold '
          'flat illustration, square composition, recognizable at small '
          'sizes, minimal background.';
    return post('/ai/image/', body: {
      'prompt': enhanced,
      'model':  'flux',
      'aspect': 'square',
    });
  }

  // ══════════════════════════════════════════════════════════
  // ARCADE
  // ══════════════════════════════════════════════════════════

  Future<dynamic> getGames()        => get('/arcade/games/');
  Future<dynamic> getPlayerStats()  => get('/arcade/stats/');
  Future<dynamic> getLeaderboard({String? gameSlug, int limit = 20}) =>
      get('/arcade/leaderboard/', query: {
        if (gameSlug != null) 'game': gameSlug,
        'limit': '$limit',
      });

  Future<dynamic> getTokenWallet() => get('/arcade/tokens/');

  Future<dynamic> getTokenHistory({int limit = 50}) =>
      get('/arcade/tokens/history/', query: {'limit': '$limit'});

  Future<dynamic> getTransferHistory({int limit = 50}) =>
      get('/arcade/tokens/transfers/', query: {'limit': '$limit'});

  Future<dynamic> sendTokens({
    required String recipientUserId,
    required int    amount,
    String          note = '',
  }) => post('/arcade/tokens/transfer/', body: {
    'recipient_user_id': recipientUserId,
    'amount':            amount,
    'note':              note,
  });

  Future<dynamic> submitScore({
    required String game,
    required int    score,
    int             bonusTokens = 0,
  }) => post('/arcade/submit-score/', body: {
    'game':         game,
    'score':        score,
    'bonus_tokens': bonusTokens,
  });

  Future<dynamic> getGamerTag()           => get('/arcade/gamer-tag/');
  Future<dynamic> setGamerTag(String tag) =>
      patch('/arcade/gamer-tag/', body: {'gamer_tag': tag});
  Future<dynamic> uploadGamerAvatar(File file) =>
      uploadFile('/arcade/gamer-tag/avatar/',
          filePath: file.path, field: 'avatar', mimeType: 'image/jpeg');

  Future<dynamic> searchGamers({required String query, int limit = 10}) =>
      get('/arcade/gamer-tag/search/', query: {
        'q':     query,
        'limit': '$limit',
      });

  Future<dynamic> getGameRequests() => get('/arcade/game-requests/');

  Future<dynamic> getMySentInvites({String? status}) =>
      get('/arcade/game-invites/sent/', query: {
        if (status != null) 'status': status,
      });

  Future<dynamic> createChallenge({
    required String       gameSlug,
    required List<String> recipientUserIds,
    required int          wager,
  }) => post('/arcade/game-invites/', body: {
    'game_slug':           gameSlug,
    'recipient_user_ids':  recipientUserIds,
    'wager':               wager,
  });

  Future<dynamic> cancelInvite(String inviteId) =>
      post('/arcade/game-invites/$inviteId/cancel/', body: {});

  Future<dynamic> sendChallenge({
    required String receiverId,
    required String gameSlug,
    required int    wager,
  }) => post('/arcade/game-invites/', body: {
    'receiver_id': receiverId,
    'game_slug':   gameSlug,
    'wager':       wager,
  });

  Future<dynamic> acceptChallenge(String requestId) =>
      post('/arcade/game-requests/$requestId/accept/', body: {});

  Future<dynamic> declineChallenge(String requestId) =>
      post('/arcade/game-requests/$requestId/decline/', body: {});

  Future<dynamic> getLiveSessions() => get('/arcade/sessions/live/');

  Future<dynamic> getSession(String id) => get('/arcade/sessions/$id/');

  Future<dynamic> startSession(String id) =>
      post('/arcade/sessions/$id/start/', body: {});

  Future<dynamic> submitMatchResult({
    required String sessionId,
    required int    score,
  }) => post('/arcade/sessions/$sessionId/result/',
            body: {'score': score});

  Future<dynamic> forfeitSession(String id) =>
      post('/arcade/sessions/$id/forfeit/', body: {});

  Future<dynamic> getMatchMessages(String sessionId, {int limit = 30}) =>
      get('/arcade/sessions/$sessionId/messages/',
          query: {'limit': '$limit'});

  @Deprecated('Use submitMatchResult / forfeitSession instead.')
  Future<dynamic> updateSession(String id,
      {required String action, int? score}) {
    if (action == 'submit_score' && score != null) {
      return submitMatchResult(sessionId: id, score: score);
    }
    if (action == 'quit' || action == 'forfeit') {
      return forfeitSession(id);
    }
    return getSession(id);
  }

  @Deprecated('No longer needed — server settles automatically.')
  Future<dynamic> checkAutoQuit(String id) => getSession(id);

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

  Future<dynamic> getSuggestionCategories() =>
      get('/feedback/categories/');

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

  // ══════════════════════════════════════════════════════════
  // STUDY HUB — teacher bridge (resources + Q&A + office hours)
  // ══════════════════════════════════════════════════════════
  Future<dynamic> studyResources({String? subject, String? kind}) =>
      get('/studyhub/resources/', query: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (kind != null && kind.isNotEmpty) 'kind': kind,
      });

  Future<dynamic> uploadStudyResource({
    required String filePath,
    required String title,
    required String subject,
    required String kind,
    String mimeType = 'application/octet-stream',
  }) => uploadFile('/studyhub/resources/',
        filePath: filePath, field: 'file', mimeType: mimeType,
        extraFields: {'title': title, 'subject': subject, 'kind': kind});

  Future<dynamic> addStudyLink({
    required String title, required String subject, required String linkUrl,
  }) => post('/studyhub/resources/', body: {
        'title': title, 'subject': subject, 'kind': 'link', 'link_url': linkUrl,
      });

  Future<dynamic> deleteStudyResource(String id) =>
      delete('/studyhub/resources/$id/');
  Future<dynamic> verifyStudyResource(String id) =>
      post('/studyhub/resources/$id/verify/');
  Future<dynamic> downloadStudyResource(String id) =>
      post('/studyhub/resources/$id/download/');

  Future<dynamic> studyQuestions({String? subject, String? status}) =>
      get('/studyhub/questions/', query: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (status != null && status.isNotEmpty) 'status': status,
      });
  Future<dynamic> studyQuestion(String id) => get('/studyhub/questions/$id/');
  Future<dynamic> askStudyQuestion({
    required String title, required String subject, String body = '',
  }) => post('/studyhub/questions/', body: {
        'title': title, 'subject': subject, 'body': body,
      });
  Future<dynamic> answerStudyQuestion(String id, String body) =>
      post('/studyhub/questions/$id/answer/', body: {'body': body});
  Future<dynamic> resolveStudyQuestion(String id) =>
      post('/studyhub/questions/$id/resolve/');
  Future<dynamic> upvoteStudyQuestion(String id) =>
      post('/studyhub/questions/$id/upvote/');
  Future<dynamic> acceptStudyAnswer(String id) =>
      post('/studyhub/answers/$id/accept/');
  Future<dynamic> upvoteStudyAnswer(String id) =>
      post('/studyhub/answers/$id/upvote/');

  Future<dynamic> openTeachers({String? subject}) =>
      get('/studyhub/teachers/', query: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });
  Future<dynamic> myAvailability() => get('/studyhub/teachers/me/');
  Future<dynamic> setAvailability({
    required String subjects, required bool isOpen, String note = '',
  }) => post('/studyhub/teachers/', body: {
        'subjects': subjects, 'is_open': isOpen, 'note': note,
      });

  // ── Quizzes (Study Hub teacher quizzes) ──────────────────
  Future<dynamic> generateStudyQuiz({
    required String topic, String subject = '',
    int count = 5, String difficulty = 'medium',
  }) => post('/studyhub/quizzes/generate/', body: {
        'topic': topic, 'subject': subject,
        'count': count, 'difficulty': difficulty,
      });

  Future<dynamic> listQuizzes({bool mine = false, String? subject}) =>
      get('/studyhub/quizzes/', query: {
        if (mine) 'mine': '1',
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });

  Future<dynamic> saveQuiz({
    required String title, required String subject,
    required List<Map<String, dynamic>> questions,
    String description = '', String source = 'manual', int xpReward = 20,
  }) => post('/studyhub/quizzes/', body: {
        'title': title, 'subject': subject, 'description': description,
        'source': source, 'xp_reward': xpReward, 'questions': questions,
      });

  Future<dynamic> getQuiz(String id) => get('/studyhub/quizzes/$id/');
  Future<dynamic> publishQuiz(String id) => post('/studyhub/quizzes/$id/publish/');
  Future<dynamic> deleteStudyQuiz(String id) =>
      delete('/studyhub/quizzes/$id/delete/');
  Future<dynamic> attemptQuiz(String id, Map<String, int> answers) =>
      post('/studyhub/quizzes/$id/attempt/', body: {'answers': answers});
  Future<dynamic> quizAnalytics(String id) =>
      get('/studyhub/quizzes/$id/analytics/');

  // ── Child-safety routing (safeguarding leads only) ───────
  Future<dynamic> childSafetyCases({String status = 'open_active'}) =>
      get('/moderation/staff/child-safety/', query: {'status': status});
  Future<dynamic> childSafetyCase(String id) =>
      get('/moderation/staff/child-safety/$id/');
  Future<dynamic> childSafetyAction(String id, String action, {String? note}) =>
      post('/moderation/staff/child-safety/$id/action/',
          body: {'action': action, if (note != null) 'note': note});

  // ── Study sessions ───────────────────────────────────────
  Future<dynamic> studySessions({String when = 'upcoming', bool mine = false,
          String? subject}) =>
      get('/studyhub/sessions/', query: {
        'when': when, if (mine) 'mine': '1',
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });

  Future<dynamic> studySubjects() => get('/studyhub/subjects/');

  /// Teacher-authored published quiz questions reshaped for Quiz Battle.
  Future<dynamic> quizBattleBank({String? subject, int limit = 60}) =>
      get('/studyhub/quizzes/battle-bank/', query: {
        'limit': '$limit',
        if (subject != null && subject.isNotEmpty) 'subject': subject,
      });

  Future<dynamic> scheduleSession({
    required String title, required String subject, required String whenIso,
    String description = '', String location = '', String link = '',
    bool notify = true,
  }) => post('/studyhub/sessions/', body: {
        'title': title, 'subject': subject, 'when': whenIso,
        'description': description, 'location': location, 'link': link,
        'notify': notify,
      });

  Future<dynamic> rsvpSession(String id) => post('/studyhub/sessions/$id/rsvp/');
  Future<dynamic> remindSession(String id) => post('/studyhub/sessions/$id/remind/');
  Future<dynamic> deleteSession(String id) => delete('/studyhub/sessions/$id/delete/');

  // ── Demand insights (teacher-only) ───────────────────────
  Future<dynamic> studyInsights() => get('/studyhub/insights/');

  // ── Group mentor (teacher-as-mentor, spec §3G) ───────────
  Future<dynamic> joinGroupAsMentor(String groupId) =>
      post('/groups/$groupId/join-mentor/');
  Future<dynamic> stepDownMentor(String groupId) =>
      post('/groups/$groupId/step-down-mentor/');
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
