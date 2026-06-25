// lib/screens/staff/staff_ui.dart
//
// Shared design kit for the staff experience — one consistent visual language
// across Home, Protect, Oversight, Governance, and the tab hosts.
//
// Redesigned: deeper 3-stop header with a bottom highlight + accent glow,
// faintly tinted "glass" cards with a hairline top sheen, and a cleaner
// gradient section label. API and dimensions are unchanged so every screen
// that already uses these keeps laying out identically.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

// Staff accent gradient (indigo → violet → soft magenta).
const kStaffG1 = Color(0xFF5B53E8);
const kStaffG2 = Color(0xFF7C4DEF);
const kStaffG3 = Color(0xFFB14AE0);
const kStaffGrad = LinearGradient(
  colors: [kStaffG1, kStaffG2, kStaffG3],
  stops: [0.0, 0.55, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// A rounded-bottom gradient header with layered glow blobs, a soft accent
/// halo, and a thin highlight line along the bottom edge. The header floats
/// over the page background at its rounded corners; [child] sits below the
/// status bar. Shape, padding, and corner radius are unchanged.
class StaffHeader extends StatelessWidget {
  final Widget child;
  final double bottomPad;
  final EdgeInsets? horizontal;
  const StaffHeader({
    super.key,
    required this.child,
    this.bottomPad = 18,
    this.horizontal,
  });

  static Widget _glow(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)])),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final pad = horizontal ?? const EdgeInsets.symmetric(horizontal: 8);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: Stack(children: [
        const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: kStaffGrad))),

        // Diagonal sheen across the top-left.
        Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.0),
            ],
          )),
        )),

        // Glow blobs (kept) + a warm accent halo for depth.
        Positioned(top: -55, right: -45,
            child: _glow(190, Colors.white.withValues(alpha: 0.18))),
        Positioned(top: 10, right: 60,
            child: _glow(150, const Color(0xFFF7971E).withValues(alpha: 0.14))),
        Positioned(bottom: -70, left: -55,
            child: _glow(200, Colors.black.withValues(alpha: 0.12))),

        // Thin highlight line along the bottom edge.
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          height: 1.2,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ])),
        )),

        Padding(
          padding: EdgeInsets.fromLTRB(
              pad.left, top + 12, pad.right, bottomPad),
          child: child,
        ),
      ]),
    );
  }
}

/// Elevated "glass" card decoration used for every staff content card.
/// Faint gradient tint + hairline border + soft shadow. Same radius (18) and
/// call signature as before, so existing layouts are untouched.
BoxDecoration staffCard({Color? color, Color? border}) => BoxDecoration(
      gradient: color == null
          ? LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                AppC.card,
                Color.alphaBlend(
                    kStaffG2.withValues(alpha: 0.05), AppC.card),
              ],
            )
          : null,
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
          color: border ?? AppC.border.withValues(alpha: 0.9), width: 1),
      boxShadow: [
        BoxShadow(
          color: kStaffG1.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

/// Section heading with a rounded gradient accent bar and optional [subtitle].
class StaffSectionLabel extends StatelessWidget {
  final String text;
  final String? subtitle;
  final Widget? trailing;
  const StaffSectionLabel(this.text, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 4, height: subtitle == null ? 18 : 30,
          decoration: BoxDecoration(
            gradient: kStaffGrad,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(
                color: kStaffG2.withValues(alpha: 0.4),
                blurRadius: 8, offset: const Offset(0, 2))]),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: TextStyle(fontFamily: 'Alfa', fontSize: 16,
                color: AppC.text)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11, color: AppC.sub)),
            ],
          ],
        )),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
