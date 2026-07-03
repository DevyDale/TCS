// lib/screens/arcade/arcade_registry.dart
//
// Single source of truth for which arcade games are actually built, shared by
// the arcade grid, the challenge picker and the versus launcher — so nothing
// offers a game that dead-ends on a "coming soon" message.

import 'package:flutter/material.dart';

import 'campus_Craft_game.dart';
import 'memory_rush_game.dart';
import 'quiz_battle_game.dart';
import 'spirit_racers_game.dart';
import 'ninja_tag_game.dart';
import 'sushi_rush_game.dart';
import 'battle_bots_game.dart';
import 'pool_royale_game.dart';
import 'snake_game.dart';
import 'number_guesser_game.dart';
import 'texas_poker_game.dart';
import 'tic_Tac_toe.dart';

/// Slug → solo-game builder. If a slug isn't here, the game isn't built.
final Map<String, Widget Function(BuildContext)> playableGames = {
  'quiz-battle':     (ctx) => const QuizBattleGame(),
  'spirit-racers':   (ctx) => const SpiritRacersGame(),
  'ninja-tag':       (ctx) => const NinjaTagGame(),
  'sushi-rush':      (ctx) => const SushiRushGame(),
  'battle-bots':     (ctx) => const BattleBotsGame(),
  'pool-royale':     (ctx) => const PoolRoyaleGame(),
  'snake':           (ctx) => const SnakeGame(),
  'memory-match':    (ctx) => const MemoryMatchGame(),
  'number-guesser':  (ctx) => const NumberGuesserGame(),
  'tic-tac-toe':     (ctx) => const TicTacToeGame(),
  'campus-craft':    (ctx) => const CampusCraftGame(),
  'texas-poker':     (ctx) => const TexasPokerGame(),
};

bool isGameBuilt(String slug) => playableGames.containsKey(slug);

/// Games with a real-time head-to-head build. Others fall back to the solo
/// game rather than a dead "coming soon".
bool isVersusCapable(String slug) => slug == 'tic-tac-toe';
