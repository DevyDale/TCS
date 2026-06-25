// lib/screens/arcade/spectator_screen.dart
//
// Watch a live match. Connects via MatchWsService and renders:
//   • Participant pills (with live scores when broadcast)
//   • Spectator count / "you are watching"
//   • Floating chat + cheer overlay (auto-fades)
//   • Cheer button (defaults to 🔥) + text input with cooldown
//   • "Match settled" overlay with winner + payout when match ends
//
// The actual game canvas is game-specific. This screen renders a
// neutral viewer placeholder using the latest `state` payload.
// You can override `gameRenderer` from a per-game widget to draw it.

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../services/match_ws_service.dart';



const _kDarkBg     = Color(0xFF0D0D1A);
const _kDarkCard   = Color(0xFF161628);
const _kDarkCard2  = Color(0xFF1E1E38);
const _kNeonBlue   = Color(0xFF6DD5FA);
const _kNeonPurple = Color(0xFF8E54E9);
const _kNeonOrange = Color(0xFFF7971E);
const _kNeonRed    = Color(0xFFFF5858);
const _kTokenColor = Color(0xFFFFD700);

const _kCheerCooldownMs = 1100;
const _kChatCooldownMs  = 2100;
const _kCheerEmojis     = ['🔥', '👏', '⚡', '💪', '😱', '🎯'];


class SpectatorScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  /// Optional game-specific renderer. Receives the latest `state`
  /// payload from a player and returns a widget to draw it.
  final Widget Function(Map<String, dynamic>? payload)? gameRenderer;
  const SpectatorScreen({
    super.key, required this.session, this.gameRenderer,
  });
  @override
  State<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends State<SpectatorScreen> {
  final _api    = ApiService();
  final _ws     = MatchWsService();
  final _chatCtl= TextEditingController();
  StreamSubscription<MatchEvent>? _sub;

  Map<String, dynamic> _session = {};
  Map<String, dynamic>? _latestStatePayload;
  Map<String, int>     _scores  = {};   // user_id → score
  int                  _watchers= 0;

  final List<_OverlayMsg> _overlay = [];
  Map<String, dynamic>?   _settled;       // payout snapshot
  DateTime? _lastChatAt, _lastCheerAt;

  @override
  void initState() {
    super.initState();
    _session = Map<String, dynamic>.from(widget.session);
    _watchers = (_session['spectator_count'] as int?) ?? 0;
    _connect();
    _hydrateMessages();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ws.dispose();
    _chatCtl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final id = _session['id'] as String? ?? '';
    if (id.isEmpty) return;
    await _ws.connect(id);
    _sub = _ws.stream.listen(_handleEvent);
  }

  Future<void> _hydrateMessages() async {
    final id = _session['id'] as String? ?? '';
    if (id.isEmpty) return;
    try {
      final res = await _api.getMatchMessages(id, limit: 12);
      if (!mounted) return;
      for (final m in (res as List? ?? const [])) {
        final mm = m as Map<String, dynamic>;
        _pushOverlay(_OverlayMsg(
          tag:    mm['user_tag']  as String? ?? '',
          name:   mm['user_name'] as String? ?? '',
          text:   mm['text']      as String? ?? '',
          emoji:  mm['emoji']     as String? ?? '',
          isCheer: mm['kind']     == 'cheer',
        ));
      }
      setState(() {});
    } catch (_) {/* non-fatal */}
  }

  void _handleEvent(MatchEvent e) {
    switch (e.type) {
      case 'snapshot':
        if (e.session != null) {
          setState(() {
            _session  = e.session!;
            _watchers = (_session['spectator_count'] as int?) ?? _watchers;
          });
        }
        break;
      case 'state':
        setState(() => _latestStatePayload = e.payload);
        break;
      case 'result':
        final from = e.from; final s = e.score;
        if (from != null && s != null) {
          setState(() => _scores[from] = s);
        }
        break;
      case 'chat':
        _pushOverlay(_OverlayMsg(
          tag:   e.userTag  ?? '',
          name:  e.userName ?? '',
          text:  e.text     ?? '',
          emoji: '',
        ));
        break;
      case 'cheer':
        _pushOverlay(_OverlayMsg(
          tag:    e.userTag ?? '',
          name:   '',
          text:   '',
          emoji:  e.emoji ?? '🔥',
          isCheer: true,
        ));
        break;
      case 'presence':
        if (e.count != null) setState(() => _watchers = e.count!);
        break;
      case 'settled':
        setState(() {
          _settled = e.raw;
          if (e.session != null) _session = e.session!;
        });
        HapticFeedback.heavyImpact();
        break;
      case 'error':
      default: break;
    }
  }

  void _pushOverlay(_OverlayMsg m) {
    setState(() {
      _overlay.add(m);
      if (_overlay.length > 8) _overlay.removeAt(0);
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _overlay.remove(m));
    });
  }

  // ── User actions ───────────────────────────────────────
  bool get _chatReady {
    if (_lastChatAt == null) return true;
    return DateTime.now().difference(_lastChatAt!).inMilliseconds
           >= _kChatCooldownMs;
  }
  bool get _cheerReady {
    if (_lastCheerAt == null) return true;
    return DateTime.now().difference(_lastCheerAt!).inMilliseconds
           >= _kCheerCooldownMs;
  }

  void _sendCheer([String emoji = '🔥']) {
    if (!_cheerReady) return;
    HapticFeedback.lightImpact();
    _ws.sendCheer(emoji);
    setState(() => _lastCheerAt = DateTime.now());
  }

  void _sendChat() {
    final text = _chatCtl.text.trim();
    if (text.isEmpty || !_chatReady) return;
    HapticFeedback.selectionClick();
    _ws.sendChat(text);
    _chatCtl.clear();
    setState(() => _lastChatAt = DateTime.now());
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final parts = (_session['participants'] as List? ?? const [])
                    .cast<Map<String, dynamic>>();
    final game  = _session['game_name'] as String? ?? 'Match';
    final pot   = _session['pot']       as int?    ?? 0;

    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg, elevation: 0,
        title: Row(children: [
          Expanded(child: Text(game,
            style: const TextStyle(fontFamily: 'Alfa', color: Colors.white),
            overflow: TextOverflow.ellipsis)),
          Icon(Icons.visibility_rounded,
              color: Colors.white.withOpacity(0.6), size: 18),
          const SizedBox(width: 4),
          Text('$_watchers',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                color: Colors.white.withOpacity(0.6))),
        ]),
      ),
      body: Stack(children: [
        Column(children: [
          // Pot strip
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kNeonOrange, _kNeonRed]),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const T('🏆',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const T('PRIZE POT',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11, letterSpacing: 1.4,
                    color: Colors.white)),
              const Spacer(),
              Text('🪙 $pot',
                style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: Colors.white)),
            ]),
          ),

          // Participants
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8,
              children: parts.map(_participantTile).toList())),

          // Game canvas (placeholder + overrideable renderer)
          Expanded(child: Padding(padding: const EdgeInsets.all(16),
            child: Stack(children: [
              Container(decoration: BoxDecoration(color: _kDarkCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06))),
                child: widget.gameRenderer != null
                  ? widget.gameRenderer!(_latestStatePayload)
                  : _DefaultGameViewer(payload: _latestStatePayload)),

              // Floating message overlay
              if (_overlay.isNotEmpty)
                Positioned(left: 8, right: 8, bottom: 8,
                  child: IgnorePointer(child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _overlay.map((m) =>
                      _OverlayBubble(msg: m)).toList()))),
            ]))),

          // Cheer + chat input row
          if (_settled == null)
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                // Cheer button
                Opacity(opacity: _cheerReady ? 1.0 : 0.4,
                  child: GestureDetector(
                    onLongPress: _cheerReady ? _showCheerSheet : null,
                    onTap: () => _sendCheer(),
                    child: Container(width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kNeonOrange, _kNeonRed]),
                        borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: T('🔥',
                          style: TextStyle(fontSize: 22)))))),
                const SizedBox(width: 8),
                // Chat field
                Expanded(child: Container(
                  decoration: BoxDecoration(
                    color: _kDarkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.05))),
                  child: TextField(
                    controller: _chatCtl,
                    maxLength: 120,
                    style: const TextStyle(color: Colors.white,
                        fontFamily: 'Momo', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _chatReady
                          ? 'Cheer them on...'
                          : 'Slow down — wait a sec',
                      hintStyle: TextStyle(fontFamily: 'Momo',
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendChat(),
                  ))),
                const SizedBox(width: 8),
                Opacity(opacity: _chatReady ? 1.0 : 0.4,
                  child: GestureDetector(onTap: _sendChat,
                    child: Container(width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kNeonBlue, _kNeonPurple]),
                        borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Icon(
                          Icons.send_rounded, color: Colors.white))))),
              ])),
        ]),

        // Settled overlay
        if (_settled != null) _SettledOverlay(
          session: _session,
          payout:  _settled!,
          onClose: () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }

  // ── Pieces ─────────────────────────────────────────────
  Widget _participantTile(Map<String, dynamic> p) {
    final user = p['user'] as Map<String, dynamic>?;
    final id   = user?['user_id']     as String? ?? '';
    final tag  = user?['gamer_tag']   as String? ?? '';
    final name = user?['display_name']as String? ?? '?';
    final av   = user?['avatar_url']  as String? ?? '';
    final s    = _scores[id] ?? (p['score'] as int? ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _kDarkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kNeonPurple.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 12,
          backgroundColor: _kNeonPurple.withOpacity(0.25),
          backgroundImage: av.isNotEmpty ? NetworkImage(av) : null,
          child: av.isEmpty ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white,
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 11)) : null),
        const SizedBox(width: 6),
        Text('@${tag.isNotEmpty ? tag : name}',
          style: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 12,
              color: Colors.white)),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: _kNeonBlue.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8)),
          child: Text('$s',
            style: const TextStyle(fontFamily: 'Momo',
                fontWeight: FontWeight.bold, fontSize: 11,
                color: _kNeonBlue))),
      ]),
    );
  }

  void _showCheerSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _kDarkCard,
      shape: const RoundedRectangleBorder(borderRadius:
          BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const T('Pick a cheer',
            style: TextStyle(fontFamily: 'Alfa',
                fontSize: 16, color: Colors.white)),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12,
            children: _kCheerEmojis.map((e) => GestureDetector(
              onTap: () { Navigator.pop(context); _sendCheer(e); },
              child: Container(width: 56, height: 56,
                decoration: BoxDecoration(color: _kDarkCard2,
                    borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(e,
                    style: const TextStyle(fontSize: 26)))))).toList()),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
class _OverlayMsg {
  final String tag, name, text, emoji;
  final bool   isCheer;
  _OverlayMsg({
    required this.tag, required this.name,
    required this.text, required this.emoji,
    this.isCheer = false,
  });
}

class _OverlayBubble extends StatelessWidget {
  final _OverlayMsg msg;
  const _OverlayBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (msg.tag.isNotEmpty)
          Text('@${msg.tag} ',
            style: const TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 11,
                color: _kNeonBlue)),
        if (msg.isCheer)
          Text(msg.emoji.isNotEmpty ? msg.emoji : '🔥',
            style: const TextStyle(fontSize: 16))
        else
          Flexible(child: Text(msg.text,
            style: const TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: Colors.white))),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────
class _DefaultGameViewer extends StatelessWidget {
  final Map<String, dynamic>? payload;
  const _DefaultGameViewer({required this.payload});
  @override
  Widget build(BuildContext context) {
    if (payload == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          T('🎮', style: TextStyle(fontSize: 56)),
          SizedBox(height: 14),
          T('Waiting for the players to start...',
            style: TextStyle(fontFamily: 'Momo',
                color: Colors.white60, fontSize: 13)),
        ])));
    }
    return Center(child: Padding(padding: const EdgeInsets.all(20),
      child: Text(payload.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Momo',
            color: Colors.white60, fontSize: 11))));
  }
}


// ─────────────────────────────────────────────────────────────
class _SettledOverlay extends StatelessWidget {
  final Map<String, dynamic> session, payout;
  final VoidCallback         onClose;
  const _SettledOverlay({
    required this.session, required this.payout,
    required this.onClose,
  });
  @override
  Widget build(BuildContext context) {
    final winner = payout['winner'] as Map<String, dynamic>?
                ?? (session['winner'] as Map<String, dynamic>?);
    final pot    = (payout['pot']    as int?) ?? (session['pot'] as int? ?? 0);
    final draw   = (payout['draw']   as bool?) ?? false;
    final tag    = winner?['gamer_tag']    as String? ?? '';
    final name   = winner?['display_name'] as String? ?? '';

    return Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.85),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _kDarkCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _kNeonOrange.withOpacity(0.3))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(draw ? '🤝' : '🏆',
            style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 8),
          Text(draw ? 'Match drawn' : 'Winner!',
            style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 24, color: Colors.white)),
          const SizedBox(height: 6),
          if (!draw)
            Text('@${tag.isNotEmpty ? tag : name}',
              style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  color: _kNeonOrange, fontSize: 16)),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: _kNeonOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _kNeonOrange.withOpacity(0.4))),
            child: Text(draw
                ? 'All wagers refunded (🪙 $pot total)'
                : 'Pot: 🪙 $pot',
              style: const TextStyle(fontFamily: 'Alfa',
                  color: _kNeonOrange, fontSize: 14))),
          const SizedBox(height: 22),
          GestureDetector(onTap: onClose,
            child: Container(padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kNeonBlue, _kNeonPurple]),
                borderRadius: BorderRadius.circular(12)),
              child: const T('Close',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 14)))),
        ]),
      ),
    ));
  }
}