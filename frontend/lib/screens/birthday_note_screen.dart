// lib/screens/birthday_note_screen.dart
//
// Opened when a "Happy Birthday" notification is tapped. Shows a festive,
// confetti-filled note with a unique AI-generated message and the age the
// user is turning. Data: GET /ai/birthday-note/ → {name, age, message}.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/widgets/t_text.dart';

// Festive gradient + confetti palette.
const _kTop    = Color(0xFF7B2FF7);
const _kMid    = Color(0xFFD6336C);
const _kBottom = Color(0xFFFF8A3D);

const _kConfetti = [
  Color(0xFFFFD93D), Color(0xFFFF6B6B), Color(0xFF6BCB77),
  Color(0xFF4D96FF), Color(0xFFFF9F1C), Color(0xFFE6A0FF),
  Color(0xFFFFFFFF),
];

class BirthdayNoteScreen extends StatefulWidget {
  const BirthdayNoteScreen({super.key});

  @override
  State<BirthdayNoteScreen> createState() => _BirthdayNoteScreenState();
}

class _BirthdayNoteScreenState extends State<BirthdayNoteScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();

  late final AnimationController _entry;
  late final AnimationController _cake;

  String _name = '';
  int? _age;
  String _message = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _cake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _entry.dispose();
    _cake.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/ai/birthday-note/') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name = (data['name'] as String? ?? '').trim();
        _age = (data['age'] as num?)?.toInt();
        _message = (data['message'] as String? ?? '').trim();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = "Happy birthday! 🎉 Wishing you the most wonderful day — "
            "from Dale and the whole TCS family.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ageLine = _age != null
        ? "You're turning $_age today 🎈"
        : "It's your special day 🎈";

    return Scaffold(
      body: Stack(children: [
        // Festive gradient
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kTop, _kMid, _kBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          ),
          child: SizedBox.expand(),
        ),
        // Soft glow blobs
        Positioned(top: -80, left: -60, child: _glow(220, Colors.white.withOpacity(0.12))),
        Positioned(bottom: -100, right: -70, child: _glow(260, Colors.white.withOpacity(0.10))),

        // Confetti
        const Positioned.fill(child: IgnorePointer(child: _Confetti())),

        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8, right: 12,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),

        // Content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              child: FadeTransition(
                opacity: _entry,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.08), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: _entry, curve: Curves.easeOutCubic)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bobbing cake
                      AnimatedBuilder(
                        animation: _cake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, math.sin(_cake.value * math.pi * 2) * 8),
                          child: Transform.rotate(
                            angle: math.sin(_cake.value * math.pi * 2) * 0.06,
                            child: child,
                          ),
                        ),
                        child: const T('🎂', style: TextStyle(fontSize: 88)),
                      ),
                      const SizedBox(height: 18),
                      const T('HAPPY BIRTHDAY',
                          style: TextStyle(fontFamily: 'Momo',
                              fontSize: 13, letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(_name.isEmpty ? '🎉' : '$_name!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Alfa',
                              fontSize: 40, height: 1.05, color: Colors.white,
                              shadows: [Shadow(
                                  color: Colors.black26, blurRadius: 12,
                                  offset: Offset(0, 4))])),
                      const SizedBox(height: 14),
                      // Age pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35))),
                        child: T(ageLine,
                            style: const TextStyle(fontFamily: 'Arch',
                                fontSize: 13.5, fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 26),
                      // Frosted message card
                      _MessageCard(loading: _loading, message: _message),
                      const SizedBox(height: 26),
                      // Close CTA
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 16, offset: const Offset(0, 6))]),
                          child: const T('Thank you, Dale  💜',
                              style: TextStyle(fontFamily: 'Arch',
                                  fontWeight: FontWeight.bold, fontSize: 14.5,
                                  color: _kMid)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  final bool loading;
  final String message;
  const _MessageCard({required this.loading, required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(children: [
                    SizedBox(width: 26, height: 26,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.4)),
                    SizedBox(height: 14),
                    T('Dale is writing your note…',
                        style: TextStyle(fontFamily: 'Momo',
                            fontSize: 12.5, color: Colors.white70)),
                  ]),
                )
              : Column(children: [
                  const T('💌', style: TextStyle(fontSize: 26)),
                  const SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Momo',
                          fontSize: 15, height: 1.6, color: Colors.white,
                          letterSpacing: 0.2)),
                  const SizedBox(height: 14),
                  const T('— Dale & the TCS family',
                      style: TextStyle(fontFamily: 'Arch',
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                ]),
        ),
      ),
    );
  }
}

// ── Confetti ─────────────────────────────────────────────────
class _Confetti extends StatefulWidget {
  const _Confetti();
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _particles = List.generate(90, (i) {
      return _Particle(
        x: rnd.nextDouble(),
        size: 6 + rnd.nextDouble() * 8,
        color: _kConfetti[rnd.nextInt(_kConfetti.length)],
        speed: 0.5 + rnd.nextDouble() * 0.9,
        drift: (rnd.nextDouble() - 0.5) * 0.18,
        phase: rnd.nextDouble(),
        rotSpeed: (rnd.nextDouble() - 0.5) * 8,
        circle: rnd.nextBool(),
      );
    });
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 7))
      ..repeat();
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
        painter: _ConfettiPainter(_particles, _ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _Particle {
  final double x, size, speed, drift, phase, rotSpeed;
  final Color color;
  final bool circle;
  const _Particle({
    required this.x, required this.size, required this.color,
    required this.speed, required this.drift, required this.phase,
    required this.rotSpeed, required this.circle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final prog = (t * p.speed + p.phase) % 1.0;
      final y = prog * (size.height + 40) - 20;
      final x = p.x * size.width +
          math.sin((prog + p.phase) * math.pi * 2) * p.drift * size.width;
      final angle = (t + p.phase) * p.rotSpeed;
      paint.color = p.color.withOpacity(0.92);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
