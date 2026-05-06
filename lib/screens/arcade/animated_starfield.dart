// lib/widgets/arcade/animated_starfield.dart
//
// Animated twinkling starfield — drop behind anything dark to give it
// that "deep space arcade" feel. Stars are rendered on Canvas (no widgets
// per star) so 200+ stars cost almost nothing.
//
// USAGE:
//   Stack(children: [
//     const Positioned.fill(child: AnimatedStarfield()),
//     YourContent(),
//   ])

import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedStarfield extends StatefulWidget {
  /// Number of stars rendered. 200 is the sweet spot on mid-range Android.
  final int starCount;

  /// Speed multiplier for the slow drift. 1.0 = default.
  final double driftSpeed;

  /// Optional tint applied to the stars. Defaults to white.
  final Color color;

  const AnimatedStarfield({
    super.key,
    this.starCount = 200,
    this.driftSpeed = 1.0,
    this.color = Colors.white,
  });

  @override
  State<AnimatedStarfield> createState() => _AnimatedStarfieldState();
}

class _AnimatedStarfieldState extends State<AnimatedStarfield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Star> _stars;
  final _rand = Random(42);  // deterministic so re-renders look identical

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _stars = List.generate(widget.starCount, (_) => _Star.random(_rand));
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
      builder: (_, __) => CustomPaint(
        painter: _StarfieldPainter(
          stars: _stars,
          progress: _ctrl.value,
          driftSpeed: widget.driftSpeed,
          color: widget.color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Star {
  final double x;        // 0..1 normalised
  final double y;        // 0..1 normalised
  final double radius;   // px
  final double phase;    // 0..1, twinkle offset
  final double twinkleSpeed;

  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.twinkleSpeed,
  });

  factory _Star.random(Random rand) {
    return _Star(
      x: rand.nextDouble(),
      y: rand.nextDouble(),
      radius: rand.nextDouble() * 1.4 + 0.4, // 0.4-1.8 px
      phase:  rand.nextDouble(),
      twinkleSpeed: rand.nextDouble() * 1.5 + 0.5,
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double      progress;
  final double      driftSpeed;
  final Color       color;

  _StarfieldPainter({
    required this.stars,
    required this.progress,
    required this.driftSpeed,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (final s in stars) {
      // Slow horizontal drift for parallax feel
      final driftX = (progress * driftSpeed * 30) % 1.0;
      var x = s.x + driftX;
      if (x > 1.0) x -= 1.0;

      // Twinkle: opacity oscillates with phase + time
      final twinkle = 0.3 +
          0.7 * (0.5 + 0.5 *
              sin((progress * 2 * pi * s.twinkleSpeed) + (s.phase * 2 * pi)));

      paint.color = color.withOpacity(twinkle);

      canvas.drawCircle(
        Offset(x * size.width, s.y * size.height),
        s.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.progress != progress;
}
