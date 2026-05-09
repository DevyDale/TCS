// lib/screens/settings/about_developer_screen.dart
// Sky-themed Lumora screen — twinkling stars + slow shooting stars

import 'dart:math' as math;
import 'package:flutter/material.dart';

class AboutDeveloperScreen extends StatefulWidget {
  const AboutDeveloperScreen({super.key});
  @override
  State<AboutDeveloperScreen> createState() => _AboutDeveloperScreenState();
}

class _AboutDeveloperScreenState extends State<AboutDeveloperScreen>
    with TickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final AnimationController _shoot;
  late final List<_Star> _stars;
  late final List<_ShootingStar> _shootingStars;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42); // fixed seed → consistent star field
    _stars = List.generate(140, (_) => _Star(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      r: rng.nextDouble() * 1.4 + 0.4,
      phase: rng.nextDouble() * math.pi * 2,
      speed: rng.nextDouble() * 0.5 + 0.5,
    ));
    _shootingStars = [
      _ShootingStar(startX: 0.00, startY: 0.18, delay: 0.00, angleDeg: 24),
      _ShootingStar(startX: 0.10, startY: 0.50, delay: 0.38, angleDeg: 18),
      _ShootingStar(startX: 0.05, startY: 0.74, delay: 0.68, angleDeg: 22),
    ];
    _twinkle = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat();
    _shoot = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _shoot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(children: [
        // ── Sky gradient ────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Color(0xFF050816),
                Color(0xFF0B1030),
                Color(0xFF1A0F3D),
                Color(0xFF050816),
              ],
              stops: [0.0, 0.4, 0.75, 1.0],
            ),
          ),
        ),
        // ── Star canvas ─────────────────────────────────────
        Positioned.fill(child: AnimatedBuilder(
          animation: Listenable.merge([_twinkle, _shoot]),
          builder: (_, __) => CustomPaint(
            painter: _SkyPainter(
              stars: _stars,
              shootingStars: _shootingStars,
              twinkle: _twinkle.value,
              shoot: _shoot.value,
            ),
          ),
        )),
        // ── Lumora wordmark ─────────────────────────────────
        Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _twinkle,
              builder: (_, __) {
                final glow = 0.5 + 0.5 *
                    math.sin(_twinkle.value * 2 * math.pi);
                return Text('Lumora', style: TextStyle(
                  fontFamily: 'Alfa',
                  fontSize: 64,
                  color: Colors.white,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(color: const Color(0xFF6DD5FA)
                        .withOpacity(0.45 + 0.30 * glow),
                        blurRadius: 28 + 12 * glow),
                    Shadow(color: const Color(0xFF8E54E9)
                        .withOpacity(0.35 + 0.25 * glow),
                        blurRadius: 50 + 20 * glow),
                  ],
                ));
              },
            ),
            const SizedBox(height: 18),
            Text('A studio under the stars',
              style: TextStyle(fontFamily: 'Momo',
                fontSize: 12,
                color: Colors.white.withOpacity(0.55),
                letterSpacing: 2.4)),
          ],
        )),
        // ── Back button (translucent over sky) ──────────────
        Positioned(
          left: 8, top: top + 12,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Models ──────────────────────────────────────────────────
class _Star {
  final double x, y, r, phase, speed;
  _Star({required this.x, required this.y, required this.r,
         required this.phase, required this.speed});
}

class _ShootingStar {
  final double startX, startY, delay, angleDeg;
  _ShootingStar({required this.startX, required this.startY,
                 required this.delay, required this.angleDeg});
}

// ── Painter ─────────────────────────────────────────────────
class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final List<_ShootingStar> shootingStars;
  final double twinkle;   // 0..1
  final double shoot;     // 0..1
  _SkyPainter({required this.stars, required this.shootingStars,
               required this.twinkle, required this.shoot});

  @override
  void paint(Canvas canvas, Size size) {
    // Twinkling stars
    for (final s in stars) {
      final t = (twinkle * 2 * math.pi * s.speed) + s.phase;
      final alpha = 0.35 + 0.55 * (0.5 + 0.5 * math.sin(t));
      final p = Paint()..color = Colors.white.withOpacity(alpha.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height), s.r, p);
    }

    // Shooting stars — each "active" for 25% of the master cycle
    const activeWindow = 0.25;
    const trailLen = 90.0;
    for (final ss in shootingStars) {
      final raw = (shoot - ss.delay) % 1.0;
      if (raw < 0 || raw > activeWindow) continue;
      final p = raw / activeWindow; // 0..1 within active window

      final rad = ss.angleDeg * math.pi / 180;
      const travel = 1.25;
      final cx = (ss.startX + p * travel) * size.width;
      final cy = (ss.startY + p * travel * math.tan(rad)) * size.height;

      // Trail fades in then out across the active window
      final fade = (1 - (p - 0.5).abs() * 2).clamp(0.0, 1.0);
      final dx = -math.cos(rad) * trailLen;
      final dy = -math.sin(rad) * trailLen;
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.85 * fade),
          ],
        ).createShader(Rect.fromPoints(
            Offset(cx + dx, cy + dy), Offset(cx, cy)))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8;
      canvas.drawLine(Offset(cx + dx, cy + dy), Offset(cx, cy), paint);

      // Bright head
      canvas.drawCircle(Offset(cx, cy), 1.8,
          Paint()..color = Colors.white.withOpacity(fade));
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.twinkle != twinkle || old.shoot != shoot;
}