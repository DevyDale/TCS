// lib/widgets/pulse_glow.dart
//
// Wrap any widget to make it gently pulse (scale + glow) while [active].
// Used to signal "available for study" on the availability toggle, replacing
// the old full-width green banner. When [active] is false it renders the child
// untouched with zero animation cost.

import 'package:flutter/material.dart';

class PulseGlow extends StatefulWidget {
  final Widget child;
  final bool   active;
  final Color  color;
  final double maxScale;
  final double borderRadius;

  const PulseGlow({
    super.key,
    required this.child,
    this.active = true,
    this.color = const Color(0xFF43E97B), // study-green
    this.maxScale = 1.06,
    this.borderRadius = 18,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t     = Curves.easeInOut.transform(_c.value);
        final scale = 1.0 + (widget.maxScale - 1.0) * t;
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.20 + 0.35 * t),
                  blurRadius: 10 + 18 * t,
                  spreadRadius: 1 + 3 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
