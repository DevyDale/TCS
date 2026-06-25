// lib/screens/auth/role_selection_screen.dart
//
// Role picker — matches the light AI Hub aesthetic.
// White card surfaces with animated SweepGradient borders, soft
// grey backgrounds, dark ink text. Role-specific colors stay on
// each card's icon chip and perk pills, so Student vs Staff
// remain visually distinct without breaking the page palette.

import 'dart:math' as math;
import 'package:tcs_app/widgets/t_text.dart';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/auth/login_id_screen.dart';

import '../../utils/responsive_helper.dart';

// ── Light palette (matches AI Hub) ───────────────────────────
const _kBg1 = Color(0xFFFAFAFC);
const _kBg2 = Color(0xFFE6E6EE);
const _kBg3 = Color(0xFFF2F2F6);

Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;

Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
const _kInkSoft = Color(0xFF374151);
Color get _kInk => AppC.text;

const _gradColors = <Color>[
  Color(0xFF6DD5FA), // light blue
  Color(0xFF7C3AED), // violet
  Color(0xFFF59E0B), // amber
  Color(0xFFFF4F6E), // coral
  Color(0xFF6DD5FA), // close the loop, no seam
];

const _kLogoHeroTag = 'tcs_app_logo';

// ─────────────────────────────────────────────────────────────
// Role data
// ─────────────────────────────────────────────────────────────

class _Role {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
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
    title: 'Student',
    subtitle: 'Login with ID & Date of Birth',
    description:
        'Access your feed, study groups, arcade games, and campus events.',
    icon: Icons.school_rounded,
    gradient: [Color(0xFF6DD5FA), Color(0xFF2575FC)],
    perks: [
      'Feed & Announcements',
      'Study Hub & Buddies',
      'Arcade & Leaderboard',
    ],
  ),
  _Role(
    title: 'Staff',
    subtitle: 'Login with ID & Date of Birth',
    description:
        'Manage announcements, monitor students, and engage with campus life.',
    icon: Icons.badge_rounded,
    gradient: [Color(0xFF22C55E), Color(0xFF0F766E)],
    perks: ['Post Announcements', 'Student Groups', 'Campus Events'],
  ),
];

// ═════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final List<Animation<double>> _tileAnims;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _tileAnims = List.generate(_roles.length, (i) {
      final start = 0.2 + (i * 0.15);
      return CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(
          start,
          (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _navigate(_Role role) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            LoginIdScreen(role: role.title.toLowerCase()),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = R(context);
    return Scaffold(
      // Fallback to the lightest gradient stop so nothing dark ever
      // peeks through during route transitions or overscroll bounces.
      backgroundColor: _kBg1,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  // ConstrainedBox forces the inner column to be at least
                  // the viewport height. IntrinsicHeight lets spaceBetween
                  // actually space children to top and bottom — without it,
                  // the column would collapse to its intrinsic content size.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: res.formMaxW + 80,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.isPhone ? 20 : 32,
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // ── Top group: header + role cards ──
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 8),
                                    _buildHeader(res),
                                    SizedBox(height: res.lg),
                                    if (context.isPhone)
                                      ..._roles.asMap().entries.map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 14,
                                          ),
                                          child: _AnimatedTile(
                                            animation: _tileAnims[e.key],
                                            child: _RoleCard(
                                              role: e.value,
                                              shimmer: _shimmerCtrl,
                                              onTap: () => _navigate(e.value),
                                              compact: true,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      _buildGrid(res),
                                  ],
                                ),
                                // ── Bottom: footer pinned ──
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: _buildFooter(res),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(R res) {
    return Column(
      children: [
        // School logo — Hero target; receives the logo flying in from splash.
        Hero(
          tag: _kLogoHeroTag,
          child: _GradientBorderCard(
            animation: _shimmerCtrl,
            radius: 36,
            borderWidth: 2.5,
            innerColor: _kCard,
            padding: const EdgeInsets.all(18),
            child: Icon(Icons.school_rounded, color: _kInk, size: 32),
          ),
        ),
        const SizedBox(height: 22),
        T(
          'Welcome to TCS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Alfa',
            fontSize: res.headingXL + 4,
            color: _kInk,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        T(
          'Taylors College Social & Arcade',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Arch',
            fontSize: res.body,
            color: _kSlate,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        // Pill with gradient border — same trick as AI Hub
        _GradientBorderCard(
          animation: _shimmerCtrl,
          radius: 22,
          borderWidth: 1.2,
          innerColor: _kCard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: T(
            'Select your role to get started',
            style: TextStyle(
              fontFamily: 'Arch',
              fontSize: res.caption + 1,
              color: _kInkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(R res) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: _roles
          .asMap()
          .entries
          .map(
            (e) => _AnimatedTile(
              animation: _tileAnims[e.key],
              child: _RoleCard(
                role: e.value,
                shimmer: _shimmerCtrl,
                onTap: () => _navigate(e.value),
                compact: false,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFooter(R res) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF1D9E75),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            T(
              'Secure login  ·  All data encrypted',
              style: TextStyle(
                fontFamily: 'Arch',
                fontSize: res.caption,
                color: _kSlate2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        T(
          'POWERED BY LUMORA',
          style: TextStyle(
            fontFamily: 'Arch',
            fontSize: 9,
            color: _kSlate2.withOpacity(0.7),
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tile fade+slide entry wrapper
// ─────────────────────────────────────────────────────────────

class _AnimatedTile extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedTile({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Role card — light theme with animated gradient border
// ─────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final _Role role;
  final Animation<double> shimmer;
  final VoidCallback onTap;
  final bool compact;

  const _RoleCard({
    required this.role,
    required this.shimmer,
    required this.onTap,
    required this.compact,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final res = R(context);
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) {
          _pressCtrl.reverse();
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          _pressCtrl.forward();
          widget.onTap();
        },
        onTapCancel: () {
          _pressCtrl.forward();
        },
        child: _GradientBorderCard(
          animation: widget.shimmer,
          radius: 22,
          borderWidth: 1.4,
          innerColor: _kCard,
          padding: EdgeInsets.zero,
          child: widget.compact ? _buildHorizontal(res) : _buildVertical(res),
        ),
      ),
    );
  }

  Widget _buildHorizontal(R res) {
    final g = widget.role.gradient;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Role-coloured icon chip
          Hero(
            tag: 'role_icon_${widget.role.title.toLowerCase()}',
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: g,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: g.last.withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.role.icon, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.role.title,
                  style: TextStyle(
                    fontFamily: 'Alfa',
                    fontSize: res.subheading,
                    color: _kInk,
                    letterSpacing: -0.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.role.subtitle,
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontSize: res.caption,
                    color: _kSlate,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: widget.role.perks
                      .take(2)
                      .map(
                        (p) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: g.last.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: g.last.withOpacity(0.25)),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontFamily: 'Arch',
                              fontSize: 10,
                              color: g.last,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: g,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: g.last.withOpacity(0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVertical(R res) {
    final g = widget.role.gradient;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'role_icon_${widget.role.title.toLowerCase()}',
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: g,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: g.last.withOpacity(0.30),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(widget.role.icon, color: Colors.white, size: 24),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: g.last.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: g.last.withOpacity(0.25)),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: g.last,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.role.title,
            style: TextStyle(
              fontFamily: 'Alfa',
              fontSize: res.subheading + 2,
              color: _kInk,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.role.subtitle,
            style: TextStyle(
              fontFamily: 'Arch',
              fontSize: res.caption,
              color: _kSlate,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.role.perks
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: g.last,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Arch',
                              fontSize: res.caption,
                              color: _kInkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — same as AI Hub
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double radius;
  final double borderWidth;
  final Color? innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color> colors;

  _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor,
    this.padding,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          math.max(0.0, radius - borderWidth),
        ),
        color: innerColor ?? _kCard,
      ),
      padding: padding,
      child: child,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final t = animation.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
              colors: colors,
              startAngle: t,
              endAngle: t + 2 * math.pi,
            ),
          ),
          padding: EdgeInsets.all(borderWidth),
          child: c,
        );
      },
      child: inner,
    );
  }
}
