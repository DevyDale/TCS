import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../../utils/responsive_helper.dart';
import 'login_id_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _dark  = Color(0xFF0D0D1A);
const _card  = Color(0xFF141428);

// ─────────────────────────────────────────────────────────────
// Role data — Student and Staff only, loginType removed
// ─────────────────────────────────────────────────────────────

class _Role {
  final String       title;
  final String       subtitle;
  final String       description;
  final IconData     icon;
  final List<Color>  gradient;
  final List<String> perks;

  const _Role({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.perks,
  });
}

const _roles = [
  _Role(
    title:       'Student',
    subtitle:    'Login with ID & Date of Birth',
    description: 'Access your feed, study groups, arcade games, and campus events.',
    icon:        Icons.school_rounded,
    gradient:    [Color(0xFF6DD5FA), Color(0xFF2575FC)],
    perks:       ['Feed & Announcements', 'Study Hub & Buddies', 'Arcade & Leaderboard'],
  ),
  _Role(
    title:       'Staff',
    subtitle:    'Login with ID & Date of Birth',
    description: 'Manage announcements, monitor students, and engage with campus life.',
    icon:        Icons.badge_rounded,
    gradient:    [Color(0xFF81C784), Color(0xFF388E3C)],
    perks:       ['Post Announcements', 'Student Groups', 'Campus Events'],
  ),
];

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _gradientCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..forward();
    _particleCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 5))..repeat();
    _gradientCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 8))..repeat();
    _pulseCtrl    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000))..repeat(reverse: true);

    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _particleCtrl.dispose();
    _gradientCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // All roles use ID login — no branching needed
  void _navigate(_Role role) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => LoginIdScreen(role: role.title.toLowerCase()),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 380),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final res  = R(context);
    final logoSize = res.logoSize + (context.isTablet ? 20 : context.isWide ? 40 : 0);

    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        children: [
          // ── Animated gradient bg ──────────────────────────
          AnimatedBuilder(
            animation: _gradientCtrl,
            builder: (_, __) {
              final t = _gradientCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFF0D0D1A),
                      Color(0xFF12103A),
                      Color(0xFF1A0D2E),
                    ],
                    begin: Alignment(math.cos(t * math.pi * 2) * 0.5, -1),
                    end:   Alignment(-math.cos(t * math.pi * 2) * 0.5, 1),
                  ),
                ),
              );
            },
          ),

          // ── Ambient glow ──────────────────────────────────
          Positioned(top: -80, left: -80,
              child: _blob(_kG2.withOpacity(0.12), 300)),
          Positioned(bottom: -60, right: -60,
              child: _blob(_kG3.withOpacity(0.08), 280)),
          Positioned(top: size.height * 0.4, left: size.width * 0.6,
              child: _blob(_kG1.withOpacity(0.06), 200)),

          // ── Main content ──────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: res.formMaxW + 80),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.isPhone ? 20 : 32,
                          24,
                          context.isPhone ? 20 : 32,
                          32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(res, logoSize),
                            SizedBox(height: res.lg),

                            // Phone: vertical list | Tablet+: 2-col grid
                            if (context.isPhone)
                              ..._roles.asMap().entries.map((e) =>
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _RoleCard(
                                    role:      e.value,
                                    index:     e.key,
                                    onTap:     () => _navigate(e.value),
                                    pulseAnim: _pulseAnim,
                                  ),
                                ),
                              )
                            else
                              _buildGrid(res),

                            SizedBox(height: res.md),
                            _buildFooter(res),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(R res, double size) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_kG1, _kG2, _kG3, _kG4],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color:       _kG2.withOpacity(0.25 + 0.15 * _pulseAnim.value),
                  blurRadius:  20 + 12 * _pulseAnim.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.school, size: size * 0.47, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Welcome to TCS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily:    'Alfa',
            fontSize:      res.headingXL + 4,
            color:         Colors.white,
            letterSpacing: 0.5,
          )),
        const SizedBox(height: 8),
        Text('Taylors College Social & Arcade',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily:    'Arch',
            fontSize:      res.body,
            color:         Colors.white.withOpacity(0.4),
            letterSpacing: 1,
          )),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color:        _kG2.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: _kG2.withOpacity(0.25)),
          ),
          child: Text('Select your role to get started',
            style: TextStyle(
              fontFamily:    'Arch',
              fontSize:      res.caption + 1,
              color:         _kG1,
              fontWeight:    FontWeight.w600,
              letterSpacing: 0.3,
            )),
        ),
      ],
    );
  }

  Widget _buildGrid(R res) {
    return GridView.count(
      crossAxisCount:   2,
      crossAxisSpacing: 14,
      mainAxisSpacing:  14,
      childAspectRatio: 1.05,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      children: _roles.asMap().entries.map((e) => _RoleCard(
        role:      e.value,
        index:     e.key,
        onTap:     () => _navigate(e.value),
        pulseAnim: _pulseAnim,
        compact:   false,
      )).toList(),
    );
  }

  Widget _buildFooter(R res) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: Color(0xFF1D9E75), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Secure login  ·  All data encrypted',
                style: TextStyle(
                  fontFamily: 'Arch', fontSize: res.caption,
                  color: Colors.white.withOpacity(0.3),
                )),
          ],
        ),
        const SizedBox(height: 10),
        Text('POWERED BY LUMORA',
            style: TextStyle(
              fontFamily:    'Arch', fontSize: 9,
              color:         Colors.white.withOpacity(0.2),
              letterSpacing: 3,
            )),
      ],
    );
  }

  Widget _blob(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// ─────────────────────────────────────────────────────────────
// Role card
// ─────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final _Role             role;
  final int               index;
  final VoidCallback      onTap;
  final Animation<double> pulseAnim;
  final bool              compact;

  const _RoleCard({
    required this.role,
    required this.index,
    required this.onTap,
    required this.pulseAnim,
    this.compact = true,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120),
        lowerBound: 0.96, upperBound: 1.0, value: 1.0);
    _scaleAnim = CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final g   = widget.role.gradient;
    final res = R(context);

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown:   (_) { _pressCtrl.reverse(); HapticFeedback.selectionClick(); },
        onTapUp:     (_) { _pressCtrl.forward(); widget.onTap(); },
        onTapCancel: ()  { _pressCtrl.forward(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:        _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:      g.last.withOpacity(0.12),
                blurRadius: 20,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          child: widget.compact
              ? _buildHorizontal(g, res)
              : _buildVertical(g, res),
        ),
      ),
    );
  }

  Widget _buildHorizontal(List<Color> g, R res) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              shape:    BoxShape.circle,
              gradient: LinearGradient(colors: g,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(
                  color:      g.last.withOpacity(0.35),
                  blurRadius: 14,
                  offset:     const Offset(0, 4))],
            ),
            child: Icon(widget.role.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.role.title,
                    style: TextStyle(
                      fontFamily:    'Alfa',
                      fontSize:      res.subheading,
                      color:         Colors.white,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(height: 3),
                Text(widget.role.subtitle,
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontSize:   res.caption,
                      color:      Colors.white.withOpacity(0.45),
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 5,
                  children: widget.role.perks.take(2).map((p) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        g.first.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border:       Border.all(color: g.first.withOpacity(0.2)),
                      ),
                      child: Text(p,
                        style: TextStyle(
                          fontFamily:  'Arch', fontSize: 10,
                          color:       g.first, fontWeight: FontWeight.w600,
                        )),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient:     LinearGradient(colors: g,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVertical(List<Color> g, R res) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape:    BoxShape.circle,
                  gradient: LinearGradient(colors: g,
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(
                      color: g.last.withOpacity(0.35), blurRadius: 14)],
                ),
                child: Icon(widget.role.icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        g.first.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: g.first.withOpacity(0.2)),
                ),
                child: Icon(Icons.arrow_forward_rounded, color: g.first, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(widget.role.title,
              style: TextStyle(
                fontFamily:    'Alfa',
                fontSize:      res.subheading + 2,
                color:         Colors.white,
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 4),
          Text(widget.role.subtitle,
              style: TextStyle(
                fontFamily: 'Arch',
                fontSize:   res.caption,
                color:      Colors.white.withOpacity(0.4),
              )),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.role.perks.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Container(width: 5, height: 5,
                    decoration: BoxDecoration(
                        color: g.first, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(p, style: TextStyle(
                  fontFamily: 'Arch', fontSize: res.caption,
                  color: Colors.white.withOpacity(0.65),
                )),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }
}