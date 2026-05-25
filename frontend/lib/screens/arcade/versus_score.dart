// lib/screens/arcade/versus_score.dart
//
// Shared "live-score duel" engine used by score-based games in versus mode
// (snake, sushi-rush, quiz-battle, texas-poker, …). Both players play the same
// game at once; each pumps its score over the match WebSocket so the other
// sees it live, and the higher final score takes the pot. Quitting forfeits.
//
// A game in versus mode:
//   final vs = VersusScore(mp: mp, myId: myId, onChange: () => setState(() {}));
//   await vs.connect();
//   ... on score change ...     vs.pushScore(_score);
//   ... when the run ends ...    vs.submit(_score);
//   ... on quit ...              vs.forfeit();
//   ... in dispose ...           vs.dispose();
// and reads vs.oppScore / vs.oppConnected / vs.settled for its UI.
import 'dart:async';
import 'package:flutter/material.dart';

import 'game_engine.dart';                  // colours + MultiplayerSession
import '../../services/match_ws_service.dart';

class VersusScore {
  final MultiplayerSession mp;
  final String myId;
  final VoidCallback onChange;

  MatchWsService? _ws;
  StreamSubscription<MatchEvent>? _sub;

  int    oppScore     = 0;
  bool   oppConnected = false;
  bool   settled      = false;
  bool   settledWin   = false;
  String settledText  = '';
  int    pot          = 0;
  bool   _resultSent  = false;

  VersusScore({required this.mp, required this.myId, required this.onChange});

  Future<void> connect() async {
    _ws = MatchWsService();
    _sub = _ws!.stream.listen(_onEvent);
    await _ws!.connect(mp.sessionId);
  }

  // Broadcast my current score so the opponent sees it climb live.
  void pushScore(int score) => _ws?.broadcastState({'score': score});

  // Submit my final score exactly once; the server settles the winner.
  void submit(int score) {
    if (_resultSent) return;
    _resultSent = true;
    _ws?.submitResult(score);
  }

  void forfeit() => _ws?.forfeit();

  void dispose() {
    _sub?.cancel();
    _ws?.dispose();
  }

  void _onEvent(MatchEvent e) {
    switch (e.type) {
      case 'presence':
        final uid = e.raw['user_id']?.toString() ?? '';
        if (e.raw['is_player'] == true && uid.isNotEmpty &&
            uid != myId && e.raw['joined'] == true) {
          oppConnected = true;
          onChange();
        }
        break;
      case 'state':
        final s = e.payload?['score'];
        if (s is num) { oppScore = s.toInt(); oppConnected = true; onChange(); }
        break;
      case 'settled':
        final winnerId = e.raw['winner']?.toString();
        final draw     = e.raw['draw'] == true;
        pot = (e.raw['pot'] as num?)?.toInt() ?? (mp.wager * 2);
        settled = true;
        if (draw || winnerId == null) {
          settledText = 'Draw — your wager is refunded.';
          settledWin  = false;
        } else if (winnerId == myId) {
          settledText = 'You win the pot! 🪙 $pot';
          settledWin  = true;
        } else {
          settledText = 'You lost the duel.';
          settledWin  = false;
        }
        onChange();
        break;
      case 'forfeit':
        // Opponent quit — the server's 'settled' event follows.
        break;
    }
  }
}

// ── Compact two-player scoreboard for the in-game HUD ──────────
class VersusScoreBar extends StatelessWidget {
  final int meScore;
  final String oppLabel;
  final int oppScore;
  const VersusScoreBar({super.key,
    required this.meScore, required this.oppLabel, required this.oppScore});

  @override
  Widget build(BuildContext context) {
    final meLead = meScore >= oppScore;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: kDarkCard2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _side('YOU', meScore, meLead),
        const Text('VS', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 12, color: Colors.white38)),
        _side(oppLabel.isEmpty ? 'RIVAL' : oppLabel, oppScore, !meLead),
      ]),
    );
  }

  Widget _side(String label, int score, bool lead) => Column(children: [
    SizedBox(width: 110, child: Text(label, maxLines: 1, textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: 'Momo', fontSize: 10,
            color: lead ? const Color(0xFFFFD700) : Colors.white54))),
    Text('$score', style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
        color: lead ? const Color(0xFFFFD700) : Colors.white)),
  ]);
}

// ── "Waiting for opponent" overlay ────────────────────────────
class VersusWaitingOverlay extends StatelessWidget {
  final String opponent;
  const VersusWaitingOverlay({super.key, required this.opponent});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withOpacity(0.6),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: kNeonOrange),
      const SizedBox(height: 16),
      Text('Waiting for ${opponent.isEmpty ? "opponent" : opponent}…',
        style: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
            fontSize: 16, color: Colors.white)),
      const SizedBox(height: 6),
      const Text('The duel starts when you both connect.',
        style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: Colors.white54)),
    ])));
}

// ── Result overlay (win / lose / draw) ────────────────────────
class VersusResultOverlay extends StatelessWidget {
  final bool win;
  final String text;
  final VoidCallback onClose;
  const VersusResultOverlay({super.key,
    required this.win, required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withOpacity(0.82),
    child: Center(child: Container(margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: kDarkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (win ? Colors.green.shade400 : kNeonRed)
              .withOpacity(0.4))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(win ? '🏆' : '🤝', style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white)),
        const SizedBox(height: 20),
        GestureDetector(onTap: onClose, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
              borderRadius: BorderRadius.circular(14)),
          child: const Text('Back to Arcade', style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)))),
      ]))));
}
