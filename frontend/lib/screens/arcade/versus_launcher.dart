// lib/screens/arcade/versus_launcher.dart
//
// Turns an accepted GameSession (from acceptChallenge / a live-match join)
// into the right game opened in versus mode. Works out which side this phone
// is: participants[0] is the challenger (X / first move), [1] is the receiver.
//
// Only games that support head-to-head are routed to versus mode; others fall
// back to a "coming soon" note. As each game is wired for multiplayer, add it
// to the switch below.
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'game_engine.dart';        // MultiplayerSession
import 'tic_Tac_toe.dart';        // TicTacToeGame (dual-mode)
// import 'snake_game.dart';      // TODO: re-enable once versus snake is rebuilt

Future<void> openVersusGame(BuildContext ctx, Map<String, dynamic> session) async {
  final slug  = session['game_slug']?.toString() ?? '';
  final parts = (session['participants'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const <Map<String, dynamic>>[];

  // Who am I?
  final me   = await ApiService().cachedUser;
  final myId = me?['user_id']?.toString() ?? me?['id']?.toString() ?? '';

  String userIdOf(Map<String, dynamic> p) =>
      (p['user'] as Map?)?['user_id']?.toString() ?? '';
  String tagOf(Map<String, dynamic> p) {
    final u = (p['user'] as Map?) ?? const {};
    final tag = (u['gamer_tag'] ?? '').toString();
    return tag.isNotEmpty ? tag : (u['display_name'] ?? 'Opponent').toString();
  }

  final iAmX = parts.isNotEmpty && userIdOf(parts.first) == myId;

  // Opponent = the participant that isn't me (fall back to the other index).
  Map<String, dynamic>? oppPart;
  for (final p in parts) {
    if (userIdOf(p) != myId) { oppPart = p; break; }
  }
  final oppTag = oppPart != null ? tagOf(oppPart) : 'Opponent';

  final mp = MultiplayerSession(
    sessionId:   session['id']?.toString() ?? '',
    opponentTag: oppTag,
    wager:       (session['wager'] as num?)?.toInt() ?? 0,
    gameSlug:    slug,
  );

  if (!ctx.mounted) return;

  Widget? game;
  switch (slug) {
    case 'tic-tac-toe':
      game = TicTacToeGame(mp: mp, iAmX: iAmX, myId: myId);
      break;
    // case 'snake':
    //   game = SnakeGame(mp: mp, myId: myId);   // TODO: rebuild versus snake
    //   break;
    // TODO: add more head-to-head games here as they're wired.
  }

  if (game == null) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      backgroundColor: Colors.orange.shade800,
      content: Text('Head-to-head for "${session['game_name'] ?? slug}" is coming soon.'),
    ));
    return;
  }

  Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => game!));
}
