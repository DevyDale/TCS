// lib/widgets/uploading_overlay.dart
//
// A reusable "uploading…" indicator that matches the AI-screen theme
// (white card + animated SweepGradient border). Uploads are
// indeterminate (no % from the server) so this shows a spinner + label.
//
// Two ways to use it:
//
// 1) As a blocking dialog (works on ANY screen, easiest to bolt on):
//
//      showUploadingDialog(context, message: 'Uploading material…');
//      try {
//        await _api.uploadGroupMaterial(...);   // your existing call
//      } finally {
//        if (mounted) dismissUploadingDialog(context);
//      }
//
// 2) As an inline overlay inside a Stack (no extra route):
//
//      Stack(children: [
//        ...yourBody,
//        if (_uploading) const UploadingOverlay(message: 'Uploading material…'),
//      ])

import 'dart:math' as math;
import 'package:flutter/material.dart';

const _kCard = Color(0xFFFFFFFF);
const _kInk = Color(0xFF0D0D1A);
const _kInkSoft = Color(0xFF374151);
const _kSlate = Color(0xFF6B7280);

const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

/// Full-area dimmed overlay for use inside a Stack.
class UploadingOverlay extends StatelessWidget {
  final String message;
  final String? subtitle;
  const UploadingOverlay({
    super.key,
    this.message = 'Uploading…',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x47000000), // ~28% black
        child: Center(
          child: _UploadingCard(message: message, subtitle: subtitle),
        ),
      ),
    );
  }
}

/// Show a blocking, non-dismissible uploading dialog from any screen.
/// Pair every call with [dismissUploadingDialog] in a `finally` block.
Future<void> showUploadingDialog(
  BuildContext context, {
  String message = 'Uploading…',
  String? subtitle,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x47000000),
    builder: (_) => PopScope(
      canPop: false,
      child: Center(child: _UploadingCard(message: message, subtitle: subtitle)),
    ),
  );
}

/// Dismiss the dialog opened by [showUploadingDialog].
void dismissUploadingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

class _UploadingCard extends StatelessWidget {
  final String message;
  final String? subtitle;
  const _UploadingCard({required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: _AnimatedGradientBorder(
        radius: 22,
        borderWidth: 1.8,
        child: Container(
          width: 230,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: _kInkSoft),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _kSlate, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedGradientBorder extends StatefulWidget {
  final Widget child;
  final double radius;
  final double borderWidth;
  const _AnimatedGradientBorder({
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.6,
  });

  @override
  State<_AnimatedGradientBorder> createState() =>
      _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<_AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: SweepGradient(
                colors: _gradColors, startAngle: t, endAngle: t + 2 * math.pi),
          ),
          padding: EdgeInsets.all(widget.borderWidth),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}