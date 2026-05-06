// lib/utils/responsive_helper.dart
//
// Drop this one file in and use it across every screen to make
// the app feel correct on phones, tablets, iPads and desktops.

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// BREAKPOINTS
// ─────────────────────────────────────────────────────────────

class TCSBreakpoints {
  static const double phone  = 600;  // < 600  → phone
  static const double tablet = 900;  // 600–900 → tablet / iPad portrait
  static const double laptop = 1200; // 900–1200 → iPad landscape / laptop
                                     // > 1200  → desktop
}

// ─────────────────────────────────────────────────────────────
// DEVICE TYPE
// ─────────────────────────────────────────────────────────────

enum TCSDevice { phone, tablet, laptop, desktop }

extension DeviceExt on BuildContext {
  double   get screenW => MediaQuery.of(this).size.width;
  double   get screenH => MediaQuery.of(this).size.height;
  bool     get isPhone  => screenW < TCSBreakpoints.phone;
  bool     get isTablet => screenW >= TCSBreakpoints.phone  && screenW < TCSBreakpoints.tablet;
  bool     get isLaptop => screenW >= TCSBreakpoints.tablet && screenW < TCSBreakpoints.laptop;
  bool     get isDesktop => screenW >= TCSBreakpoints.laptop;
  bool     get isSmall  => isPhone;
  bool     get isWide   => isLaptop || isDesktop;

  TCSDevice get device {
    if (screenW < TCSBreakpoints.phone)  return TCSDevice.phone;
    if (screenW < TCSBreakpoints.tablet) return TCSDevice.tablet;
    if (screenW < TCSBreakpoints.laptop) return TCSDevice.laptop;
    return TCSDevice.desktop;
  }
}

// ─────────────────────────────────────────────────────────────
// RESPONSIVE VALUES
// ─────────────────────────────────────────────────────────────

class R {
  final BuildContext _ctx;
  R(this._ctx);

  double get w => _ctx.screenW;
  double get h => _ctx.screenH;

  // ── Font sizes ────────────────────────────────────────────
  double get headingXL => _ctx.isPhone ? 28 : _ctx.isTablet ? 34 : 40;
  double get heading   => _ctx.isPhone ? 22 : _ctx.isTablet ? 26 : 30;
  double get subheading => _ctx.isPhone ? 16 : _ctx.isTablet ? 18 : 20;
  double get body      => _ctx.isPhone ? 13 : _ctx.isTablet ? 14 : 15;
  double get caption   => _ctx.isPhone ? 11 : _ctx.isTablet ? 12 : 13;

  // ── Spacing ───────────────────────────────────────────────
  double get xs  => _ctx.isPhone ?  8 : _ctx.isTablet ? 10 : 12;
  double get sm  => _ctx.isPhone ? 12 : _ctx.isTablet ? 16 : 20;
  double get md  => _ctx.isPhone ? 20 : _ctx.isTablet ? 24 : 28;
  double get lg  => _ctx.isPhone ? 28 : _ctx.isTablet ? 36 : 44;
  double get xl  => _ctx.isPhone ? 40 : _ctx.isTablet ? 52 : 64;

  // ── Icon sizes ────────────────────────────────────────────
  double get iconSm  => _ctx.isPhone ? 18 : 20;
  double get iconMd  => _ctx.isPhone ? 22 : _ctx.isTablet ? 26 : 28;
  double get iconLg  => _ctx.isPhone ? 32 : _ctx.isTablet ? 40 : 48;
  double get iconXL  => _ctx.isPhone ? 44 : _ctx.isTablet ? 56 : 64;

  // ── Card / container widths ───────────────────────────────
  double get cardMaxW  => _ctx.isPhone ? double.infinity : _ctx.isTablet ? 520 : 600;
  double get formMaxW  => _ctx.isPhone ? double.infinity : _ctx.isTablet ? 480 : 560;

  // ── Padding ───────────────────────────────────────────────
  EdgeInsets get pagePad   => EdgeInsets.symmetric(horizontal: _ctx.isPhone ? 20 : _ctx.isTablet ? 36 : 48);
  EdgeInsets get cardPad   => EdgeInsets.all(_ctx.isPhone ? 20 : _ctx.isTablet ? 28 : 36);
  EdgeInsets get inputPad  => EdgeInsets.symmetric(horizontal: 16, vertical: _ctx.isPhone ? 14 : 16);

  // ── Border radius ─────────────────────────────────────────
  double get radiusSm => _ctx.isPhone ? 12 : 14;
  double get radiusMd => _ctx.isPhone ? 16 : 18;
  double get radiusLg => _ctx.isPhone ? 20 : _ctx.isTablet ? 24 : 28;

  // ── Avatar / logo sizes ───────────────────────────────────
  double get logoSize   => _ctx.isPhone ? 80 : _ctx.isTablet ? 100 : 120;
  double get avatarSize => _ctx.isPhone ? 44 : _ctx.isTablet ? 52 : 60;

  // ── Button height ─────────────────────────────────────────
  double get btnH => _ctx.isPhone ? 52 : _ctx.isTablet ? 56 : 60;
}

// Shorthand: R(context).heading etc.
R r(BuildContext ctx) => R(ctx);

// ─────────────────────────────────────────────────────────────
// RESPONSIVE WRAPPER — constrains width on large screens
// ─────────────────────────────────────────────────────────────

/// Wrap any screen's body with this to automatically centre
/// and constrain it on tablets/desktop while staying full-width on phones.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESPONSIVE GRID — 1 col on phone, N cols on wider
// ─────────────────────────────────────────────────────────────

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int phoneCols;
  final int tabletCols;
  final int desktopCols;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.phoneCols   = 1,
    this.tabletCols  = 2,
    this.desktopCols = 3,
    this.spacing     = 12,
    this.runSpacing  = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.isPhone ? phoneCols
        : context.isTablet       ? tabletCols
        :                          desktopCols;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final itemW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing:    spacing,
          runSpacing: runSpacing,
          children: children.map((c) => SizedBox(width: itemW, child: c)).toList(),
        );
      },
    );
  }
}
