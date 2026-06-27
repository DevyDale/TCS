// lib/utils/responsive.dart
//
// Window size classes for TCS — drives phone vs tablet/iPad layouts.
// Based on Material 3 window size class breakpoints. No dependencies.
import 'package:flutter/widgets.dart';

enum WindowSize { compact, medium, expanded }

class Responsive {
  Responsive._();

  static const double mediumBreakpoint   = 600; // small tablet / phone landscape
  static const double expandedBreakpoint = 840; // tablet landscape / iPad

  static WindowSize sizeOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= expandedBreakpoint) return WindowSize.expanded;
    if (w >= mediumBreakpoint)   return WindowSize.medium;
    return WindowSize.compact;
  }

  // Phone-style: single full-screen pane + bottom nav.
  static bool isCompact(BuildContext context) =>
      sizeOf(context) == WindowSize.compact;

  // Tablet/iPad: wide enough for a side NavigationRail.
  static bool isWide(BuildContext context) =>
      sizeOf(context) != WindowSize.compact;

  // Wide enough for a two-pane master-detail (list + content).
  static bool isExpanded(BuildContext context) =>
      sizeOf(context) == WindowSize.expanded;

  // Max readable width so a feed never stretches edge to edge. Centre content in this.
  static double contentMaxWidth(BuildContext context) {
    switch (sizeOf(context)) {
      case WindowSize.expanded: return 720;
      case WindowSize.medium:   return 640;
      case WindowSize.compact:  return double.infinity;
    }
  }
}
