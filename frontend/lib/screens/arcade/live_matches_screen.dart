// lib/screens/arcade/live_matches_screen.dart
//
// Browse currently-active matches you can spectate. Tap a card to
// open the spectator screen.

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'spectator_screen.dart';



const _kDarkBg     = Color(0xFF0D0D1A);
const _kDarkCard   = Color(0xFF161628);
const _kDarkCard2  = Color(0xFF1E1E38);
const _kNeonBlue   = Color(0xFF6DD5FA);
const _kNeonPurple = Color(0xFF8E54E9);
const _kNeonOrange = Color(0xFFF7971E);
const _kNeonRed    = Color(0xFFFF5858);
const _kTokenColor = Color(0xFFFFD700);


class LiveMatchesScreen extends StatefulWidget {
  const LiveMatchesScreen({super.key});
  @override
  State<LiveMatchesScreen> createState() => _LiveMatchesScreenState();
}

class _LiveMatchesScreenState extends State<LiveMatchesScreen> {
  final _api = ApiService();
  Timer? _poller;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Light polling — refresh every 8s while screen is open
    _poller = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await _api.getLiveSessions();
      if (!mounted) return;
      setState(() {
        _sessions = (res as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Map<String, dynamic> s) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SpectatorScreen(session: s),
    )).then((_) => _load(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg, elevation: 0,
        title: Row(children: [
          _LiveDot(),
          const SizedBox(width: 8),
          const T('Live Matches',
            style: TextStyle(fontFamily: 'Alfa', color: Colors.white)),
          const SizedBox(width: 10),
          Text('${_sessions.length}',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                color: Colors.white.withOpacity(0.5))),
        ]),
      ),
      body: RefreshIndicator(
        color: _kNeonBlue,
        onRefresh: () async => _load(),
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kNeonBlue))
          : _sessions.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Center(child: T('🎮', style: TextStyle(fontSize: 64))),
                SizedBox(height: 14),
                Center(child: T('No live matches right now',
                  style: TextStyle(fontFamily: 'Alfa',
                      color: Colors.white60, fontSize: 16))),
                SizedBox(height: 6),
                Center(child: T('Pull down to refresh',
                  style: TextStyle(fontFamily: 'Momo',
                      color: Colors.white24, fontSize: 12))),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (_, i) => _MatchCard(
                  session: _sessions[i],
                  onTap:   () => _open(_sessions[i]),
                ),
              ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;
  const _MatchCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final game     = session['game_name'] as String? ?? 'Game';
    final pot      = session['pot']       as int?    ?? 0;
    final watchers = session['spectator_count'] as int? ?? 0;
    final parts    = (session['participants'] as List? ?? const [])
                       .cast<Map<String, dynamic>>();
    return Container(
      margin:  const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kDarkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kNeonBlue.withOpacity(0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _LiveDot(),
                  const SizedBox(width: 6),
                  T('LIVE',
                    style: TextStyle(fontFamily: 'Momo',
                        letterSpacing: 1.5, fontSize: 10,
                        color: Colors.green.shade400,
                        fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('· $watchers watching',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                        color: Colors.white.withOpacity(0.4))),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _kNeonOrange.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kNeonOrange.withOpacity(0.3))),
                    child: Text('🏆 🪙 $pot',
                      style: const TextStyle(fontFamily: 'Alfa',
                          color: _kNeonOrange, fontSize: 12))),
                ]),
                const SizedBox(height: 10),
                Text(game,
                  style: const TextStyle(fontFamily: 'Alfa',
                      fontSize: 18, color: Colors.white)),
                const SizedBox(height: 12),
                // Participant pills
                Wrap(spacing: 8, runSpacing: 8,
                  children: parts.map(_pill).toList()),
                const SizedBox(height: 12),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kNeonBlue, _kNeonPurple]),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisSize: MainAxisSize.min,
                        children: [
                      Icon(Icons.visibility_rounded,
                          color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      T('Watch',
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, fontSize: 12,
                            color: Colors.white)),
                    ])),
                ]),
              ]),
          )),
      ),
    );
  }

  Widget _pill(Map<String, dynamic> p) {
    final user = p['user'] as Map<String, dynamic>?;
    final tag  = user?['gamer_tag']     as String? ?? '';
    final name = user?['display_name']  as String? ?? '?';
    final av   = user?['avatar_url']    as String? ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: _kDarkCard2,
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 11,
          backgroundColor: _kNeonPurple.withOpacity(0.25),
          backgroundImage: av.isNotEmpty ? NetworkImage(av) : null,
          child: av.isEmpty ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white,
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 10)) : null),
        const SizedBox(width: 6),
        Text('@${tag.isNotEmpty ? tag : name}',
          style: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 11,
              color: Colors.white70)),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}
class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _ctl,
    builder: (_, __) => Container(width: 10, height: 10,
      decoration: BoxDecoration(
        color: Colors.green.shade400.withOpacity(0.4 + 0.6 * _ctl.value),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: Colors.green.shade400.withOpacity(0.6 * _ctl.value),
            blurRadius: 8 * _ctl.value)])));
}