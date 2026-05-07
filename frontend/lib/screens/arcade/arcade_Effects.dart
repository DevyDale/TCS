// lib/widgets/arcade/arcade_effects.dart
//
// Four reusable arcade visual effects:
//   • NeonPulse        — wraps any widget with a pulsing colored glow
//   • AnimatedCounter  — number that animates from old → new value
//   • SparkleBurst     — particle effect emitter for celebrations
//   • ShimmerLoader    — skeleton placeholder while content loads
//
// All four are pure widgets — no new packages needed.

import 'dart:math';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
// NeonPulse — pulsing glow border around a child
// ════════════════════════════════════════════════════════════
//
// Wrap anything that should "feel alive" — LIVE badges, playable
// game tiles, the active carousel card, primary CTAs.
//
//   NeonPulse(
//     color: Color(0xFF8E54E9),
//     child: YourBadge(),
//   )

class NeonPulse extends StatefulWidget {
  final Widget child;
  final Color  color;
  final double intensity;       // 0..1, how strong the pulse is
  final Duration duration;
  final BorderRadius? borderRadius;

  const NeonPulse({
    super.key,
    required this.child,
    this.color = const Color(0xFF8E54E9),
    this.intensity = 1.0,
    this.duration = const Duration(milliseconds: 1400),
    this.borderRadius,
  });

  @override
  State<NeonPulse> createState() => _NeonPulseState();
}

class _NeonPulseState extends State<NeonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        final glow = (8 + (t * 18)) * widget.intensity;
        final opacity = (0.35 + (t * 0.45)) * widget.intensity;
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            shape: widget.borderRadius == null
                ? BoxShape.circle
                : BoxShape.rectangle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(opacity),
                blurRadius: glow,
                spreadRadius: glow * 0.20,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ════════════════════════════════════════════════════════════
// AnimatedCounter — number that tweens between values
// ════════════════════════════════════════════════════════════
//
// Drop-in replacement for `Text('$tokens')`. When tokens changes,
// the displayed value smoothly counts up/down to it.
//
//   AnimatedCounter(
//     value: tokens,                  // current value
//     style: TextStyle(...),          // your existing style
//     prefix: '🪙 ',                  // optional
//   )

class AnimatedCounter extends StatefulWidget {
  final int      value;
  final TextStyle? style;
  final Duration duration;
  final String   prefix;
  final String   suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
    _to   = widget.value;
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (widget.value != _to) {
      _from = _to;
      _to   = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final shown = (_from + ((_to - _from) * t)).round();
        return Text(
          '${widget.prefix}$shown${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// SparkleBurst — particle effect that fires once
// ════════════════════════════════════════════════════════════
//
// Imperatively trigger via a GlobalKey, or use as a one-shot when
// rebuilt. Good for: token gain, level up, achievement unlock,
// game victory.
//
// Imperative usage:
//   final sparkleKey = GlobalKey<SparkleBurstState>();
//   ...
//   Stack(children: [
//     YourContent(),
//     Positioned.fill(child: SparkleBurst(key: sparkleKey)),
//   ])
//   ...
//   sparkleKey.currentState?.fire();   // triggers a burst

class SparkleBurst extends StatefulWidget {
  final List<Color> colors;
  final int particleCount;
  final Duration duration;

  const SparkleBurst({
    super.key,
    this.colors = const [
      Color(0xFFFFD700),
      Color(0xFF6DD5FA),
      Color(0xFF8E54E9),
      Color(0xFFFF5858),
    ],
    this.particleCount = 24,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<SparkleBurst> createState() => SparkleBurstState();
}

class SparkleBurstState extends State<SparkleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rand = Random();
  List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Fire a burst from the centre of the widget.
  void fire() {
    _particles = List.generate(widget.particleCount, (_) {
      final angle = _rand.nextDouble() * 2 * pi;
      final speed = _rand.nextDouble() * 120 + 60;
      return _Particle(
        angle: angle,
        speed: speed,
        size:  _rand.nextDouble() * 4 + 2,
        color: widget.colors[_rand.nextInt(widget.colors.length)],
        spin:  (_rand.nextDouble() - 0.5) * 6,
      );
    });
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _SparklePainter(
            particles: _particles,
            progress:  _ctrl.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  final double angle, speed, size, spin;
  final Color  color;
  _Particle({
    required this.angle, required this.speed,
    required this.size,  required this.color,
    required this.spin,
  });
}

class _SparklePainter extends CustomPainter {
  final List<_Particle> particles;
  final double          progress;
  _SparklePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty || progress == 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final fade   = 1.0 - progress;
    final paint  = Paint();

    for (final p in particles) {
      final dx = cos(p.angle) * p.speed * progress;
      final dy = sin(p.angle) * p.speed * progress
                 + (progress * progress * 80);    // gravity
      final pos = centre + Offset(dx, dy);

      paint.color = p.color.withOpacity(fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * progress);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress;
}

// ════════════════════════════════════════════════════════════
// ShimmerLoader — skeleton placeholder
// ════════════════════════════════════════════════════════════
//
// Replace boring CircularProgressIndicators with skeleton screens.
// Shows the shape of what's loading, not just "wait".
//
//   ShimmerLoader(
//     width: 280, height: 80,
//     borderRadius: BorderRadius.circular(14),
//   )

class ShimmerLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor      = const Color(0xFF1E1E38),
    this.highlightColor = const Color(0xFF2C2C50),
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value.clamp(0.0, 1.0),
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
          ),
        );
      },
    );
  }
}
