import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';


import '../services/api_service.dart';
import '../utils/responsive_helper.dart';
import 'auth/role_selection_screen.dart';
import 'auth/session_keys.dart';
import 'dashboard/dashboard_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _progressCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _gradientCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _lumoraFade;

  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _logoCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _gradientCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

    _logoScale   = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _titleSlide  = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _titleFade    = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _subtitleFade = CurvedAnimation(parent: _textCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));
    _lumoraFade   = CurvedAnimation(parent: _textCtrl, curve: const Interval(0.6, 1.0, curve: Curves.easeOut));

    final rng = math.Random();
    for (int i = 0; i < 22; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(), y: rng.nextDouble(),
        radius: rng.nextDouble() * 4 + 2,
        speed:  rng.nextDouble() * 0.3 + 0.1,
        color:  [_kG1, _kG2, _kG3, _kG4][rng.nextInt(4)].withOpacity(rng.nextDouble() * 0.5 + 0.2),
        offset: rng.nextDouble() * math.pi * 2,
      ));
    }
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _progressCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    _checkAuthAndNavigate();
  }

  // ── SECTION 1 FIX ────────────────────────────────────────
  // Refresh the token BEFORE deciding where to route. Access tokens
  // expire after 60 minutes; if the user comes back the next day the
  // old token is dead and the dashboard would render with broken
  // API calls. ApiService.initialize() refreshes it (or wipes the
  // session if the refresh token is also dead). Then we just check
  // whether we still have a valid token and navigate accordingly.
  Future<void> _checkAuthAndNavigate() async {
    await ApiService.instance.initialize();

    final prefs       = await SharedPreferences.getInstance();
    final token       = prefs.getString(SessionKeys.accessToken);
    final fullName    = prefs.getString(SessionKeys.fullName)      ?? '';
    final preferredName = prefs.getString(SessionKeys.preferredName) ?? '';
    final role        = prefs.getString(SessionKeys.role)          ?? '';

    if (!mounted) return;

    final dest = (token != null && token.isNotEmpty && fullName.isNotEmpty)
        ? DashboardScreen(
            fullName:      fullName,
            preferredName: preferredName,
            role:          role,
          )
        : const RoleSelectionScreen();

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, anim, __) => dest,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  void dispose() {
    _logoCtrl.dispose(); _textCtrl.dispose(); _progressCtrl.dispose();
    _particleCtrl.dispose(); _gradientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final res  = R(context);
    // Logo scales with screen — bigger on tablets/desktop
    final logoSize = res.logoSize + (context.isTablet ? 20 : context.isWide ? 40 : 0);

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _gradientCtrl,
            builder: (_, __) {
              final t = _gradientCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [Color(0xFF0D0D1A), Color(0xFF12103A), Color(0xFF1A0D2E)],
                    begin: Alignment(math.cos(t * math.pi * 2) * 0.5, -1),
                    end: Alignment(-math.cos(t * math.pi * 2) * 0.5, 1),
                  ),
                ),
              );
            },
          ),

          // Particles
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ParticlePainter(particles: _particles, progress: _particleCtrl.value),
            ),
          ),

          // Glow blobs
          Positioned(top: size.height * 0.1, left: -60,
            child: _GlowBlob(color: _kG2.withOpacity(0.15), size: context.isWide ? 300 : 220)),
          Positioned(bottom: size.height * 0.15, right: -80,
            child: _GlowBlob(color: _kG3.withOpacity(0.10), size: context.isWide ? 340 : 260)),

          // Content — centred and constrained on wide screens
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.isPhone ? double.infinity : 480),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Logo
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: _buildLogo(logoSize),
                      ),
                    ),

                    SizedBox(height: res.lg),

                    // App name
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [_kG1, _kG2, _kG3, _kG4],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'TCS',
                            style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: context.isPhone ? 44 : context.isTablet ? 54 : 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: res.xs),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Learn · Play · Connect',
                        style: TextStyle(
                          fontFamily: 'Arch',
                          fontSize: context.isPhone ? 14 : 16,
                          color: Colors.white54,
                          letterSpacing: 3,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Progress bar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.isPhone ? 48 : 80),
                      child: AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (_, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progressCtrl.value,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(_kG1),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: res.md),

                    FadeTransition(
                      opacity: _lumoraFade,
                      child: Column(
                        children: [
                          Text('POWERED BY LUMORA',
                              style: TextStyle(
                                fontFamily: 'Momo', fontSize: 10,
                                color: Colors.white.withOpacity(0.3), letterSpacing: 3.5,
                              )),
                          const SizedBox(height: 4),
                          Text('Taylors College Social & Arcade',
                              style: TextStyle(
                                fontFamily: 'Momo', fontSize: context.isPhone ? 12 : 13,
                                color: Colors.white.withOpacity(0.45), letterSpacing: 1,
                              )),
                        ],
                      ),
                    ),

                    SizedBox(height: res.md),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_kG1, _kG2, _kG3, _kG4],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _kG2.withOpacity(0.5), blurRadius: 32, spreadRadius: 6)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.9, height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
          ),
          Icon(Icons.school, size: size * 0.47, color: Colors.white),
        ],
      ),
    );
  }
}

class _Particle {
  final double x, y, radius, speed, offset;
  final Color color;
  const _Particle({required this.x, required this.y, required this.radius,
      required this.speed, required this.color, required this.offset});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  const _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t  = (progress + p.offset / (math.pi * 2)) % 1.0;
      final dy = (p.y - t * p.speed) % 1.0;
      final dx = p.x + math.sin(t * math.pi * 2 + p.offset) * 0.04;
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height), p.radius,
        Paint()..color = p.color..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
