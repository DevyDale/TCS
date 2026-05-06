// lib/screens/role_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/login_id_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _floatCtrl;
  late final List<AnimationController> _cardCtrls; // now 2

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _logoScale;
  late final Animation<double> _floatAnim;
  late final List<Animation<Offset>> _cardSlides;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

    // Only 2 cards now
    _cardCtrls = List.generate(2, (_) => AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600)));

    _headerFade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _logoScale   = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _floatAnim   = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _cardSlides  = _cardCtrls.map((ctrl) =>
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic))
    ).toList();

    _runEntrance();
  }

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _entryCtrl.forward();
    for (int i = 0; i < _cardCtrls.length; i++) {
      await Future.delayed(Duration(milliseconds: 200 + i * 120));
      _cardCtrls[i].forward();
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _navigate(Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => screen,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 380),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(color: Colors.grey.shade50),
        Positioned(top: -60, right: -60,
            child: _GlassBlob(color: _kG1.withOpacity(0.18), size: 220)),
        Positioned(bottom: 120, left: -80,
            child: _GlassBlob(color: _kG4.withOpacity(0.12), size: 260)),

        SafeArea(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 32),

            // ── Header ────────────────────────────────────────
            FadeTransition(opacity: _headerFade,
              child: SlideTransition(position: _headerSlide,
                child: Column(children: [
                  AnimatedBuilder(animation: _floatAnim,
                    builder: (_, child) => Transform.translate(
                        offset: Offset(0, _floatAnim.value), child: child),
                    child: ScaleTransition(scale: _logoScale,
                      child: Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [_kG1, _kG2, _kG3, _kG4],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(
                              color: _kG2.withOpacity(0.35),
                              blurRadius: 24, spreadRadius: 4,
                              offset: const Offset(0, 8))]),
                        child: const Icon(Icons.school, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                        colors: [_kG1, _kG2, _kG3, _kG4],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight).createShader(b),
                    blendMode: BlendMode.srcIn,
                    child: const Text('TCS', style: TextStyle(
                        fontFamily: 'Alfa', fontSize: 38,
                        fontWeight: FontWeight.bold, letterSpacing: 1.2,
                        color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Text('One platform for every student.\nLearn, play, connect.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                        color: Colors.grey.shade500, height: 1.5)),
                ]),
              ),
            ),

            const SizedBox(height: 44),

            // ── "Who are you?" label ──────────────────────────
            FadeTransition(opacity: _headerFade,
              child: Row(children: [
                Container(width: 4, height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kG2, _kG3],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text('Who are you?', style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 18,
                    color: Colors.grey.shade800, letterSpacing: 0.5)),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Student card ──────────────────────────────────
            _buildCard(
              index: 0,
              icon: Icons.school_rounded,
              title: 'Student',
              subtitle: 'Login with Student ID & Date of Birth',
              gradientColors: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
              badgeLabel: 'ID Login',
              badgeColor: const Color(0xFF0288D1),
              onTap: () => _navigate(const LoginIdScreen(role: 'student')),
            ),

            const SizedBox(height: 14),

            // ── Staff card ────────────────────────────────────
            _buildCard(
              index: 1,
              icon: Icons.badge_rounded,
              title: 'Staff',
              subtitle: 'Teaching & non-teaching staff ID login',
              gradientColors: const [Color(0xFF81C784), Color(0xFF388E3C)],
              badgeLabel: 'Staff',
              badgeColor: const Color(0xFF388E3C),
              onTap: () => _navigate(const LoginIdScreen(role: 'teaching_staff')),
            ),

            const SizedBox(height: 40),

            // ── Footer ────────────────────────────────────────
            FadeTransition(opacity: _headerFade,
              child: Column(children: [
                Text('Powered by LUMORA', style: TextStyle(
                    fontFamily: 'Momo', fontSize: 12,
                    color: Colors.grey.shade400, letterSpacing: 2)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.shield_rounded, size: 13,
                      color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text('Secured · Role-verified · GDPR compliant',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                        color: Colors.grey.shade400)),
                ]),
              ]),
            ),

            const SizedBox(height: 24),
          ]),
        )),
      ]),
    );
  }

  Widget _buildCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required String badgeLabel,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return SlideTransition(
      position: _cardSlides[index],
      child: FadeTransition(
        opacity: _cardCtrls[index],
        child: _RoleCard(
          icon: icon, title: title, subtitle: subtitle,
          gradientColors: gradientColors,
          badgeLabel: badgeLabel, badgeColor: badgeColor, onTap: onTap,
        ),
      ),
    );
  }
}

// ── Role Card widget ──────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title, subtitle, badgeLabel;
  final List<Color> gradientColors;
  final Color badgeColor;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.title,
      required this.subtitle, required this.gradientColors,
      required this.badgeLabel, required this.badgeColor, required this.onTap});
  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100),
        lowerBound: 0.97, upperBound: 1.0, value: 1.0);
  }
  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) { _pressCtrl.forward(); widget.onTap(); },
      onTapCancel: () => _pressCtrl.forward(),
      child: ScaleTransition(
        scale: _pressCtrl,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: widget.gradientColors.last.withOpacity(0.15),
                  blurRadius: 20, offset: const Offset(0, 6)),
              BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Row(children: [
              Container(width: 6, height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradientColors,
                      begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: widget.gradientColors
                            .map((c) => c.withOpacity(0.15)).toList(),
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16)),
                  child: Icon(widget.icon, color: widget.badgeColor, size: 28))),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(widget.title, style: const TextStyle(
                          fontFamily: 'Arch', fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(widget.badgeLabel, style: TextStyle(
                            fontFamily: 'Momo', fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.badgeColor))),
                    ]),
                    const SizedBox(height: 5),
                    Text(widget.subtitle, style: TextStyle(
                        fontFamily: 'Momo', fontSize: 13,
                        color: Colors.grey.shade500)),
                  ]),
              )),
              Padding(padding: const EdgeInsets.only(right: 16),
                child: Container(width: 34, height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.gradientColors),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 14))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GlassBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlassBlob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}