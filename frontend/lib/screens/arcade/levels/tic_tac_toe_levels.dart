// lib/screens/arcade/levels/tic_tac_toe_levels.dart
//
// 10-level progression for Tic Tac Toe.
// Difficulty scales the minimax AI: 'aiDepth' is how many plies the AI
// searches (higher = smarter; level 10 plays perfectly), and 'aiRandomness'
// is the chance per turn it blunders to a random square (higher = easier).
//
// Clearing a level needs >=1 star: a win scores full marks (3 stars), a draw
// still counts (2 stars) — important since a perfect AI can only be drawn,
// never beaten.
import 'package:flutter/material.dart';
import '../game_engine.dart';
import '../level_system.dart';

const kTicTacToeLevels = <LevelConfig>[
  LevelConfig(level: 1,
    title: 'Wobbly Bot', subtitle: 'Barely paying attention',
    targetScore: 100, icon: Icons.sentiment_very_satisfied_rounded,
    gradient: [kNeonBlue, kNeonOrange],
    params: {'aiDepth': 0, 'aiRandomness': 0.85}),
  LevelConfig(level: 2,
    title: 'Rookie', subtitle: 'Learning the ropes',
    targetScore: 115, icon: Icons.sentiment_satisfied_rounded,
    gradient: [kNeonBlue, kNeonOrange],
    params: {'aiDepth': 1, 'aiRandomness': 0.6}),
  LevelConfig(level: 3,
    title: 'Casual Player', subtitle: 'Will block the obvious',
    targetScore: 130, icon: Icons.grid_3x3_rounded,
    gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    params: {'aiDepth': 1, 'aiRandomness': 0.4}),
  LevelConfig(level: 4,
    title: 'Schoolyard Champ', subtitle: 'Thinks a move ahead',
    targetScore: 145, icon: Icons.grid_3x3_rounded,
    gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    params: {'aiDepth': 2, 'aiRandomness': 0.3}),
  LevelConfig(level: 5,
    title: 'Sharp', subtitle: 'Halfway — mistakes get punished',
    targetScore: 160, icon: Icons.psychology_rounded,
    gradient: [kNeonPurple, Color(0xFF6B2FD9)],
    params: {'aiDepth': 3, 'aiRandomness': 0.2}),
  LevelConfig(level: 6,
    title: 'Tactician', subtitle: 'Sets little traps',
    targetScore: 175, icon: Icons.psychology_rounded,
    gradient: [kNeonPurple, Color(0xFF6B2FD9)],
    params: {'aiDepth': 4, 'aiRandomness': 0.12}),
  LevelConfig(level: 7,
    title: 'Strategist', subtitle: 'Rarely slips up',
    targetScore: 190, icon: Icons.bolt_rounded,
    gradient: [Color(0xFF232526), Color(0xFF414345)],
    params: {'aiDepth': 5, 'aiRandomness': 0.06}),
  LevelConfig(level: 8,
    title: 'Calculating', subtitle: 'No free squares',
    targetScore: 205, icon: Icons.smart_toy_rounded,
    gradient: [kNeonOrange, kNeonRed],
    params: {'aiDepth': 6, 'aiRandomness': 0.0}),
  LevelConfig(level: 9,
    title: 'Grandmaster', subtitle: 'Almost unbeatable',
    targetScore: 220, icon: Icons.military_tech_rounded,
    gradient: [kNeonOrange, kNeonRed],
    params: {'aiDepth': 8, 'aiRandomness': 0.0}),
  LevelConfig(level: 10,
    title: 'Flawless', subtitle: 'Perfect play — a draw is a triumph',
    targetScore: 235, icon: Icons.emoji_events_rounded,
    gradient: [Color(0xFFFFD700), Color(0xFFFFA000)],
    params: {'aiDepth': 9, 'aiRandomness': 0.0}),
];
