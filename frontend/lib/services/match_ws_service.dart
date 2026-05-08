// lib/services/match_ws_service.dart
//
// WebSocket client for live arcade matches.
// Connects to: ws(s)://<host>/ws/arcade/match/<sessionId>/?token=<jwt>
//
// Both players AND spectators connect here. The server enforces who
// can do what — players can broadcast state/result/forfeit, anyone
// can chat/cheer.
//
// USAGE (spectator):
//   final ws = MatchWsService();
//   await ws.connect(sessionId);
//   ws.stream.listen((event) { ... });
//   ws.sendChat("nice shot");
//   ws.sendCheer("🔥");
//   ws.dispose();
//
// USAGE (player):
//   ws.broadcastState({'x': 1, 'y': 2});   // game-specific payload
//   ws.submitResult(1234);
//   ws.forfeit();

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_service.dart';   // for ApiConfig

class MatchEvent {
  final String              type;
  final Map<String, dynamic> raw;
  MatchEvent(this.type, this.raw);

  // Convenience getters
  String?  get from         => raw['from']      as String?;
  String?  get userTag      => raw['user_tag']  as String?;
  String?  get userName     => raw['user_name'] as String?;
  String?  get text         => raw['text']      as String?;
  String?  get emoji        => raw['emoji']     as String?;
  int?     get score        => raw['score']     as int?;
  int?     get count        => raw['count']     as int?;
  bool?    get joined       => raw['joined']    as bool?;
  bool?    get isPlayer     => raw['is_player'] as bool?;
  Map<String, dynamic>? get session => raw['session'] as Map<String, dynamic>?;
  Map<String, dynamic>? get payload => raw['payload'] as Map<String, dynamic>?;
}

class MatchWsService {
  WebSocketChannel? _channel;
  final _controller = StreamController<MatchEvent>.broadcast();
  bool _disposed = false;

  Stream<MatchEvent> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  Future<void> connect(String sessionId) async {
    await disconnect();
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      _controller.add(MatchEvent('error',
          {'message': 'Not authenticated'}));
      return;
    }
    final uri = Uri.parse(
      '${ApiConfig.ws}/ws/arcade/match/$sessionId/?token=$token',
    );
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try {
          final m = jsonDecode(raw as String) as Map<String, dynamic>;
          final t = m['type'] as String? ?? 'unknown';
          _controller.add(MatchEvent(t, m));
        } catch (_) {/* swallow malformed */}
      },
      onDone:  () => _channel = null,
      onError: (_) => _channel = null,
      cancelOnError: false,
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

  // ── Player actions ──────────────────────────────────────
  void broadcastState(Map<String, dynamic> payload) =>
      _send({'action': 'state', 'payload': payload});

  void submitResult(int score) =>
      _send({'action': 'result', 'score': score});

  void forfeit() => _send({'action': 'forfeit'});

  // ── Anyone (player or spectator) ────────────────────────
  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _send({'action': 'chat', 'text': t});
  }

  void sendCheer(String emoji) =>
      _send({'action': 'cheer', 'emoji': emoji});

  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
  }

  // ── Helpers ─────────────────────────────────────────────
  Future<String?> _accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}