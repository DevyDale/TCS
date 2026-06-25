// lib/theme/app_colors.dart
//
// Theme-aware semantic palette. Read these instead of hardcoding Colors.white /
// dark hex values so screens flip with the light/dark switch. Values mirror the
// ThemeData in main.dart. Backed by AppSettings (no BuildContext needed), so it
// works inside helper methods too; the whole app rebuilds on setDark().
//
// Usage: color: AppC.card,  /  style: TextStyle(color: AppC.text)
// NOTE: AppC getters are not const — wrap-and-deconst the enclosing widget if a
// `const` complains.

import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class AppC {
  static bool get isDark => AppSettings().isDark;

  // ── Surfaces ──────────────────────────────────────────────
  static Color get bg    => isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F8FA);
  static Color get card  => isDark ? const Color(0xFF1A1A24) : Colors.white;
  static Color get card2 => isDark ? const Color(0xFF22222E) : const Color(0xFFF1F3F7);

  // ── Text ──────────────────────────────────────────────────
  static Color get text  => isDark ? const Color(0xFFEDEDF5) : const Color(0xFF1A1A2E);
  static Color get sub   => isDark ? Colors.white70          : Colors.grey.shade600;
  static Color get faint => isDark ? Colors.white38          : Colors.grey.shade400;

  // ── Lines ─────────────────────────────────────────────────
  static Color get border  => isDark ? const Color(0xFF2A2A38) : const Color(0xFFE6E8EE);
  static Color get divider => isDark ? Colors.white12          : const Color(0xFFECECEC);

  // ── Misc ──────────────────────────────────────────────────
  /// Black/white that flips (e.g. for the tile outlines added for distinctivity).
  static Color get ink => isDark ? Colors.white : Colors.black;
  static Color get shadow => Colors.black.withValues(alpha: isDark ? 0.30 : 0.05);
}
