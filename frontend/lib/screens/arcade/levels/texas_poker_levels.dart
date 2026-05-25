// lib/screens/arcade/levels/texas_poker_levels.dart
//
// 10-level progression for Texas Hold'em.
// Difficulty scales the number of CPU opponents (more rivals = lower odds your
// hand is best at showdown), the big blind relative to your stack (more
// pressure), and the opponents' calling tendency ('aiAgg').
//
// Win a sit-down by doubling your stack or taking the majority of 5 hands;
// bust and you retry. targetScore is about a doubled stack, so a dominant win
// rates 3 stars; squeaking out a hand-count win rates fewer. A loss scores 0
// (no stars), so only a real win unlocks the next level.
import 'package:flutter/material.dart';
import '../game_engine.dart';
import '../level_system.dart';

const kTexasPokerLevels = <LevelConfig>[
  LevelConfig(level: 1, title: 'Campus Cafe', subtitle: '1 rival · low blinds',
    targetScore: 1200, icon: Icons.local_cafe_rounded, gradient: [Color(0xFF66BB6A), Color(0xFFFFD700)],
    params: {'cpus': 1, 'startChips': 600, 'bigBlind': 20, 'aiAgg': 0.3}),
  LevelConfig(level: 2, title: 'Dorm Room', subtitle: '1 rival · blinds creep up',
    targetScore: 1200, icon: Icons.king_bed_rounded, gradient: [Color(0xFF66BB6A), Color(0xFFFFD700)],
    params: {'cpus': 1, 'startChips': 600, 'bigBlind': 30, 'aiAgg': 0.35}),
  LevelConfig(level: 3, title: 'Student Lounge', subtitle: '2 rivals at the table',
    targetScore: 1400, icon: Icons.weekend_rounded, gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    params: {'cpus': 2, 'startChips': 700, 'bigBlind': 40, 'aiAgg': 0.4}),
  LevelConfig(level: 4, title: 'Common Room', subtitle: '2 rivals · bigger bets',
    targetScore: 1400, icon: Icons.weekend_rounded, gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    params: {'cpus': 2, 'startChips': 700, 'bigBlind': 60, 'aiAgg': 0.4}),
  LevelConfig(level: 5, title: 'Card Society', subtitle: '2 rivals · halfway',
    targetScore: 1600, icon: Icons.style_rounded, gradient: [kNeonPurple, Color(0xFF6B2FD9)],
    params: {'cpus': 2, 'startChips': 800, 'bigBlind': 80, 'aiAgg': 0.45}),
  LevelConfig(level: 6, title: 'Back Room', subtitle: '3 rivals · the table fills',
    targetScore: 1600, icon: Icons.style_rounded, gradient: [kNeonPurple, Color(0xFF6B2FD9)],
    params: {'cpus': 3, 'startChips': 800, 'bigBlind': 100, 'aiAgg': 0.45}),
  LevelConfig(level: 7, title: 'High Roller', subtitle: '3 rivals · steep blinds',
    targetScore: 1800, icon: Icons.diamond_rounded, gradient: [Color(0xFF232526), Color(0xFF414345)],
    params: {'cpus': 3, 'startChips': 900, 'bigBlind': 130, 'aiAgg': 0.5}),
  LevelConfig(level: 8, title: 'Finals Night', subtitle: '3 rivals · real pressure',
    targetScore: 1800, icon: Icons.nightlife_rounded, gradient: [kNeonOrange, kNeonRed],
    params: {'cpus': 3, 'startChips': 900, 'bigBlind': 160, 'aiAgg': 0.55}),
  LevelConfig(level: 9, title: 'The Vault', subtitle: '3 rivals · huge blinds',
    targetScore: 2000, icon: Icons.account_balance_rounded, gradient: [kNeonOrange, kNeonRed],
    params: {'cpus': 3, 'startChips': 1000, 'bigBlind': 200, 'aiAgg': 0.6}),
  LevelConfig(level: 10, title: 'Championship', subtitle: '3 rivals · winner takes all',
    targetScore: 2000, icon: Icons.emoji_events_rounded, gradient: [Color(0xFFFFD700), Color(0xFFFFA000)],
    params: {'cpus': 3, 'startChips': 1000, 'bigBlind': 250, 'aiAgg': 0.6}),
];
