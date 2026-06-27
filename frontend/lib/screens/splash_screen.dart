import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'legal/eula_screen.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:get/get.dart'
    hide ContextExtensionss; // hide only GetX's context extension so its
                             // isPhone/isTablet don't clash with R(context)
import 'package:shared_preferences/shared_preferences.dart';

import 'noticeboard_screen.dart';

import '../services/api_service.dart';
import '../utils/responsive_helper.dart';
import 'auth/role_selection_screen.dart';
import 'auth/session_keys.dart';
import 'dashboard/dashboard_screen.dart';
import 'visitor/visitor_dashboard_screen.dart';
import '../walkthroughscreen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _kLogoHeroTag = 'tcs_app_logo';

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
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
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
    // Session check is local (SharedPreferences) — no network — so the splash
    // only needs to flash the brand briefly, not stall. Trimmed from ~2.9s.
    await Future.delayed(const Duration(milliseconds: 120));
    _logoCtrl.forward();
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 240));
    _progressCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 560));
    _checkAuthAndNavigate();
  }

  // ────────────────────────────────────────────────────────────
  //  STICKY SESSION RULE
  // ────────────────────────────────────────────────────────────
  // The user STAYS logged in until they explicitly tap Logout.
  // No network call, no refresh check, no backend response —
  // NOTHING — can send the user back to RoleSelection from this
  // splash. The ONLY thing that matters is whether session data
  // exists in SharedPreferences.
  //
  // If a refresh token is present locally → DASHBOARD.
  // If not                                → RoleSelection.
  //
  // The token-refresh attempt happens AFTER the navigation
  // decision is locked in, fire-and-forget, in the background.
  // Whatever the backend returns (200, 401, 500, timeout, blocked
  // network, the apocalypse) cannot affect this navigation.
  // ────────────────────────────────────────────────────────────
  Future<void> _checkAuthAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();

    // Either token's presence is enough — they're saved together
    // at login. We accept either to be maximally lenient.
    final refreshToken = prefs.getString(SessionKeys.refreshToken) ?? '';
    final accessToken  = prefs.getString(SessionKeys.accessToken)  ?? '';
    final hasSession   = refreshToken.isNotEmpty || accessToken.isNotEmpty;

    if (!mounted) return;

    Widget dest;
    if (!hasSession) {
      // App Store G1.2: EULA must be accepted before login/registration.
      bool _eulaOk = await EulaGate.isAccepted();
      while (!_eulaOk) {
        if (!mounted) return;
        final _r = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const EulaScreen()),
        );
        _eulaOk = _r == true;
      }
      if (!mounted) return;

      final walkthroughCompleted =
          prefs.getBool('walkthrough_completed') ?? false;
      dest = walkthroughCompleted
          ? const RoleSelectionScreen()
          : const WalkthroughScreen();
    } else {
      // Pull cached identity. If the direct keys are blank for any
      // reason, recover from the full user JSON.
      var fullName      = prefs.getString(SessionKeys.fullName)      ?? '';
      var preferredName = prefs.getString(SessionKeys.preferredName) ?? '';
      var role          = prefs.getString(SessionKeys.role)          ?? '';

      if (fullName.isEmpty) {
        final raw = prefs.getString(SessionKeys.userJson);
        if (raw != null && raw.isNotEmpty) {
          try {
            final u = jsonDecode(raw) as Map<String, dynamic>;
            fullName      = (u['name']           ?? '').toString();
            preferredName = (u['preferred_name'] ?? '').toString();
            role          = (u['role']           ?? '').toString();
          } catch (_) {/* corrupt JSON — ignore */}
        }
      }

      dest = (role == 'visitor' || role == 'parent')
          ? const VisitorDashboardScreen()
          : DashboardScreen(
              fullName:      fullName,
              preferredName: preferredName,
              role:          role,
            );

      // Fire-and-forget background refresh. Result is discarded —
      // it can only succeed (updating the access_token) or fail
      // silently. It CANNOT wipe the session, and it CANNOT change
      // where this navigation goes.
      ApiService.instance.initialize().catchError((_) {});
    }

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, anim, __) => dest,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));

    // Cold-launched from an announcement push? Open the board on top of the
    // dashboard now that we've routed there. Logged-in users only.
    if (hasSession && pendingAnnouncementId != null) {
      final id = pendingAnnouncementId;
      pendingAnnouncementId = null;
      Get.to(() => NoticeboardScreen(highlightId: id));
    }
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
    final titleSize = context.isPhone ? 34.0 : context.isTablet ? 42.0 : 50.0;

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

                    // Logo — soft halo behind, Hero flies to role selection
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: logoSize * 1.6,
                              height: logoSize * 1.6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _kG2.withOpacity(0.30),
                                    _kG1.withOpacity(0.10),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                            Hero(tag: _kLogoHeroTag, child: _buildLogo(logoSize)),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: res.lg),

                    // Wordmark — "Taylors College" with "Sydney" stacked below
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                colors: [_kG1, _kG2, _kG3, _kG4],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(b),
                              blendMode: BlendMode.srcIn,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  T(
                                    'Taylors College',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Alfa',
                                      fontSize: titleSize,
                                      color: AppC.text,
                                      height: 1.05,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  T(
                                    'Sydney',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Alfa',
                                      fontSize: titleSize,
                                      color: AppC.text,
                                      height: 1.05,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: res.xs),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: T(
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

                    // Progress bar — gradient fill
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.isPhone ? 64 : 100),
                      child: AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (_, __) => LayoutBuilder(
                          builder: (context, c) => Stack(
                            children: [
                              Container(
                                height: 4,
                                width: c.maxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              Container(
                                height: 4,
                                width: c.maxWidth * _progressCtrl.value.clamp(0.0, 1.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  gradient: const LinearGradient(
                                    colors: [_kG1, _kG2, _kG3],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: res.md),

                    FadeTransition(
                      opacity: _lumoraFade,
                      child: Column(
                        children: [
                          // Splash bg is always dark — use fixed white tones so the
                          // credit is visible regardless of the app's light/dark theme.
                          T('Powered by LUMORA',
                              style: const TextStyle(
                                fontFamily: 'Arch', fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: 2.5,
                              )),
                          const SizedBox(height: 4),
                          T('Taylors College Social & Arcade',
                              style: TextStyle(
                                fontFamily: 'Momo', fontSize: context.isPhone ? 11 : 12,
                                color: Colors.white.withOpacity(0.55), letterSpacing: 1,
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