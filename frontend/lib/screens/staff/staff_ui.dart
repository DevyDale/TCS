// lib/screens/staff/staff_ui.dart
//
// Shared design kit for the staff experience — one consistent visual language
// across Home, Protect, Oversight, Governance, and the tab hosts:
//   • StaffHeader   — rounded-bottom gradient header with soft glow blobs.
//   • staffCard     — elevated card decoration.
//   • StaffSectionLabel — section heading with an accent bar.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

// Staff accent gradient (indigo → violet).
const kStaffG1 = Color(0xFF5B53E8);
const kStaffG2 = Color(0xFF8E54E9);
const kStaffGrad = LinearGradient(
  colors: [kStaffG1, kStaffG2],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// A rounded-bottom gradient header with soft glow blobs. The header floats
/// over the page background at its rounded corners. [child] is laid out below
/// the status bar.
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
        Positioned(top: -55, right: -45,
            child: _glow(190, Colors.white.withValues(alpha: 0.16))),
        Positioned(bottom: -70, left: -55,
            child: _glow(190, Colors.black.withValues(alpha: 0.10))),
        Padding(
          padding: EdgeInsets.fromLTRB(
              pad.left, top + 12, pad.right, bottomPad),
          child: child,
        ),
      ]),
    );
  }
}

/// Elevated card decoration used for every staff content card.
BoxDecoration staffCard({Color? color, Color? border}) => BoxDecoration(
      color: color ?? AppC.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border ?? AppC.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

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
          width: 4, height: subtitle == null ? 16 : 30,
          decoration: BoxDecoration(
            gradient: kStaffGrad,
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
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
