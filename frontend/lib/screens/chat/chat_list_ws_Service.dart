// lib/services/chat_list_ws_service.dart
//
// Single WebSocket connection that powers the chat list's realtime
// updates. The backend's ChatListConsumer joins all of the user's
// room groups behind the scenes and forwards relevant events here:
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
// Auto-reconnects with backoff. Token is read from secure storage
// the same way the per-room ChatWebSocketService does it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class ChatListWebSocketService {
  WebSocket? _ws;
  StreamSubscription? _sub;
  Timer? _reconnect;
  bool _disposed = false;
  int _attempt = 0;

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
      final token = await const FlutterSecureStorage().read(key: 'access_token');
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      // Same host as ApiService, but websocket scheme.
      final apiBase = ApiService.baseUrl;          // e.g. https://api.tcs.dev/api
      final root    = apiBase.replaceFirst(RegExp(r'/api/?$'), '');
      final wsRoot  = root
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://',  'ws://');
      final url     = '$wsRoot/ws/chat-list/?token=$token';

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