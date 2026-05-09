// lib/services/chat_list_ws_service.dart
//
// Single WebSocket connection that powers the chat list's realtime
// updates. The backend's ChatListConsumer joins all of the user's
// chatlist_<room_id> groups behind the scenes and forwards the
// relevant events here:
//
//   { "event": "new_message", "room_id": "...", "message": {...} }
//   { "event": "typing",      "room_id": "...", "user_id": "...",
//     "user_name": "...", "is_typing": bool }
//   { "event": "recording",   "room_id": "...", "user_id": "...",
//     "is_recording": bool }
//   { "event": "presence",    "user_id": "...",
//     "is_online": bool, "last_active_at": iso8601 }
//   { "event": "ai_enabled",  "room_id": "...", "ai_enabled": bool }
//
// Auto-reconnects with exponential backoff. Token is read via the
// public ApiService().accessToken getter — same SharedPreferences-
// backed token store the rest of the app uses.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tcs_app/services/api_service.dart';


class ChatListWebSocketService {
  WebSocket?           _ws;
  StreamSubscription?  _sub;
  Timer?               _reconnect;
  bool                 _disposed = false;
  int                  _attempt  = 0;

  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _ctrl.stream;

  bool get isConnected => _ws != null && _ws!.readyState == WebSocket.open;

  // ── Public ────────────────────────────────────────────────

  Future<void> connect() async {
    _disposed = false;
    await _open();
  }

  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _sub?.cancel();
    _ws?.close();
    _ctrl.close();
  }

  // ── Internals ─────────────────────────────────────────────

  Future<void> _open() async {
    try {
      // Same SharedPreferences-backed token store the rest of the
      // app uses. The previous version read flutter_secure_storage
      // directly which always returned null because tokens are
      // saved via _Tokens / SessionKeys in api_service.dart.
      final token = await ApiService().accessToken;
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      // ApiConfig.ws is the project-wide ws:// (or wss://) base URL —
      // it already does the http→ws scheme swap, so we don't need
      // any manual replaceFirst here.
      final url = '${ApiConfig.ws}/ws/chat-list/?token=$token';

      _ws = await WebSocket.connect(url);
      _attempt = 0;

      _sub = _ws!.listen(
        (raw) {
          if (raw is! String) return;
          try {
            final data = jsonDecode(raw);
            if (data is Map<String, dynamic>) _ctrl.add(data);
          } catch (_) {}
        },
        onDone:  _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _ws = null;
    _sub?.cancel();
    _attempt = (_attempt + 1).clamp(1, 6);
    final delay = Duration(seconds: 1 << (_attempt - 1));   // 1,2,4,8,16,32
    _reconnect?.cancel();
    _reconnect = Timer(delay, _open);
  }
}