// lib/screens/arcade/levels/quiz_battle_levels.dart
//
// 10-level progression for Quiz Battle.
// Each level adds questions, shrinks the timer, mixes in harder
// categories, and raises the target score.

import 'package:flutter/material.dart';
import '../game_engine.dart';
import '../level_system.dart';

const kQuizBattleLevels = <LevelConfig>[
  LevelConfig(level: 1,
    title: 'Freshman Quiz', subtitle: 'Easy questions, plenty of time',
    targetScore: 600, icon: Icons.school_rounded,
    gradient: [kNeonBlue, kNeonPurple],
    params: {'questionCount':  6, 'timePerQ': 25, 'difficulty': 'easy'}),
  LevelConfig(level: 2,
    title: 'Pop Quiz', subtitle: 'A little faster now',
    targetScore: 800, icon: Icons.quiz_rounded,
    gradient: [kNeonBlue, kNeonPurple],
    params: {'questionCount':  8, 'timePerQ': 22, 'difficulty': 'easy'}),
  LevelConfig(level: 3,
    title: 'Pop Culture', subtitle: 'Trivia mixed in',
    targetScore: 1100, icon: Icons.movie_rounded,
    gradient: [Color(0xFFB24592), Color(0xFFF15F79)],
    params: {'questionCount': 10, 'timePerQ': 20, 'difficulty': 'easy'}),
  LevelConfig(level: 4,
    title: 'Brain Strain', subtitle: 'Mid-tier questions',
    targetScore: 1500, icon: Icons.psychology_rounded,
    gradient: [Color(0xFFB24592), Color(0xFFF15F79)],
    params: {'questionCount': 12, 'timePerQ': 18, 'difficulty': 'medium'}),
  LevelConfig(level: 5,
    title: 'Half-Time Hero', subtitle: 'Halfway to legend',
    targetScore: 1900, icon: Icons.bolt_rounded,
    gradient: [kNeonOrange, kNeonRed],
    params: {'questionCount': 14, 'timePerQ': 16, 'difficulty': 'medium'}),
  LevelConfig(level: 6,
    title: 'Lab Lockdown', subtitle: 'Science round dominates',
    targetScore: 2300, icon: Icons.science_rounded,
    gradient: [kNeonOrange, kNeonRed],
    params: {'questionCount': 14, 'timePerQ': 14, 'difficulty': 'medium'}),
  LevelConfig(level: 7,
    title: 'Pressure Cooker', subtitle: 'Tight clock — keep up',
    targetScore: 2700, icon: Icons.timer_rounded,
    gradient: [Color(0xFFFC466B), Color(0xFF3F5EFB)],
    params: {'questionCount': 15, 'timePerQ': 12, 'difficulty': 'medium'}),
  LevelConfig(level: 8,
    title: 'Genius Gauntlet', subtitle: 'Hard questions only',
    targetScore: 3200, icon: Icons.lightbulb_rounded,
    gradient: [Color(0xFFFC466B), Color(0xFF3F5EFB)],
    params: {'questionCount': 16, 'timePerQ': 11, 'difficulty': 'hard'}),
  LevelConfig(level: 9,
    title: 'Lightning Round', subtitle: 'Blink and you lose',
    targetScore: 3800, icon: Icons.flash_on_rounded,
    gradient: [Color(0xFFFFD700), Color(0xFFFFA000)],
    params: {'questionCount': 18, 'timePerQ': 10, 'difficulty': 'hard'}),
  LevelConfig(level: 10,
    title: 'Champion Final', subtitle: 'Quiz Master title on the line',
    targetScore: 4500, icon: Icons.emoji_events_rounded,
    gradient: [Color(0xFFFFD700), Color(0xFFFFA000)],
    params: {'questionCount': 20, 'timePerQ':  9, 'difficulty': 'hard'}),
];
