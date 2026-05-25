// lib/screens/arcade/levels/campus_craft_levels.dart
//
// 10-level progression for Campus Craft (a slide puzzle).
// Difficulty scales the grid size and how thoroughly it's scrambled.
// 'size' is the grid (3 = 3x3 / 8 tiles ... 5 = 5x5 / 24 tiles) and 'shuffles'
// is how many random slides scramble the solved board.
//
// Solving always earns at least 1 star (which unlocks the next level); faster
// solves using fewer moves earn more. Targets ease down on the big grids
// because the time/move bonuses are fixed, so a 5x5 solve still rates well.
import 'package:flutter/material.dart';
import '../game_engine.dart';
import '../level_system.dart';

const kCampusCraftLevels = <LevelConfig>[
  LevelConfig(level: 1, title: 'Freshman Plot', subtitle: '3x3 — find your footing',
    targetScore: 1000, icon: Icons.home_work_rounded, gradient: [kNeonBlue, kNeonOrange],
    params: {'size': 3, 'shuffles': 15}),
  LevelConfig(level: 2, title: 'Quad Shuffle', subtitle: '3x3 — a bit more scrambled',
    targetScore: 1000, icon: Icons.home_work_rounded, gradient: [kNeonBlue, kNeonOrange],
    params: {'size': 3, 'shuffles': 30}),
  LevelConfig(level: 3, title: 'Courtyard Chaos', subtitle: '3x3 — fully jumbled',
    targetScore: 950, icon: Icons.grid_view_rounded, gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    params: {'size': 3, 'shuffles': 60}),
  LevelConfig(level: 4, title: 'Campus Builder', subtitle: '4x4 — the real puzzle begins',
    targetScore: 950, icon: Icons.grid_view_rounded, gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    params: {'size': 4, 'shuffles': 60}),
  LevelConfig(level: 5, title: 'Faculty Row', subtitle: '4x4 — halfway there',
    targetScore: 900, icon: Icons.apartment_rounded, gradient: [kNeonPurple, Color(0xFF6B2FD9)],
    params: {'size': 4, 'shuffles': 120}),
  LevelConfig(level: 6, title: 'District Plan', subtitle: '4x4 — heavily scrambled',
    targetScore: 850, icon: Icons.apartment_rounded, gradient: [kNeonPurple, Color(0xFF6B2FD9)],
    params: {'size': 4, 'shuffles': 220}),
  LevelConfig(level: 7, title: 'City Block', subtitle: '4x4 — for the patient',
    targetScore: 800, icon: Icons.location_city_rounded, gradient: [Color(0xFF232526), Color(0xFF414345)],
    params: {'size': 4, 'shuffles': 340}),
  LevelConfig(level: 8, title: 'Master Architect', subtitle: '5x5 — 24 tiles',
    targetScore: 700, icon: Icons.architecture_rounded, gradient: [kNeonOrange, kNeonRed],
    params: {'size': 5, 'shuffles': 160}),
  LevelConfig(level: 9, title: 'Metropolis', subtitle: '5x5 — seriously scrambled',
    targetScore: 650, icon: Icons.architecture_rounded, gradient: [kNeonOrange, kNeonRed],
    params: {'size': 5, 'shuffles': 320}),
  LevelConfig(level: 10, title: 'Grand Campus', subtitle: '5x5 — total chaos',
    targetScore: 600, icon: Icons.emoji_events_rounded, gradient: [Color(0xFFFFD700), Color(0xFFFFA000)],
    params: {'size': 5, 'shuffles': 520}),
];
