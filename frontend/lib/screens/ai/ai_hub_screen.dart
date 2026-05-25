// lib/screens/ai/ai_hub_screen.dart
//
// Theme: LIGHT gradient page (white → soft grey → white) with
// animated SweepGradient borders on every card surface.
//
// LAYOUT (this revision): single-screen, NO scrolling. Everything is
// visible at first glance:
//   • Compact header   — back button (if poppable) + Dale brand + greeting
//   • Sage             — wide featured tile (your personal mentor)
//   • 2×2 grid         — AI Assistant · Code Helper · Companions · Image Gen
//   • Usage footer     — hourly quota bar pinned to the bottom
// The body is a fixed Column with Expanded tool regions, so the tiles
// scale to fill the available height on any device without overflowing.
//
// Performance note:
//   ONE shared AnimationController (_shimmerCtrl) drives every gradient
//   border. Each _GradientBorderCard listens via AnimatedBuilder and uses
//   the `child` param so the static interior is built once.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';
import '../../../../services/api_service.dart';
import 'code_assistant_screen.dart';
import 'companion_list_Screen.dart';
import 'image_generator_Screen.dart';
import 'mentor_screen.dart';

// ── Light palette ────────────────────────────────────────────
const _kBg1      = Color(0xFFFAFAFC); // gradient start (near-white)
const _kBg2      = Color(0xFFE6E6EE); // gradient mid (soft grey)
const _kBg3      = Color(0xFFF2F2F6); // gradient end (light grey)

const _kCard     = Color(0xFFFFFFFF); // tile / footer card
const _kCardLo   = Color(0xFFF5F5F8); // raised surfaces inside cards

const _kBorder   = Color(0xFFE5E7EB); // soft hairline (back button)

const _kSlate2   = Color(0xFF9CA3AF); // tertiary text
const _kSlate    = Color(0xFF6B7280); // secondary text
const _kInkSoft  = Color(0xFF374151); // mid text / icons
const _kInk      = Color(0xFF0D0D1A); // primary text

// Sweep gradient colors used for ALL animated borders on this page.
const _gradColors = <Color>[
  Color(0xFF6DD5FA), // G1 — light blue
  Color(0xFF7C3AED), // G2 — violet
  Color(0xFFF59E0B), // G3 — amber
  Color(0xFFFF4F6E), // G4 — coral
  Color(0xFF6DD5FA), // close the loop (G1 again, no seam)
];

// ── Tool definitions ─────────────────────────────────────────

class _Tool {
  final String           name;
  final String           tagline;
  final IconData         icon;
  final Widget Function() builder;

  const _Tool({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.builder,
  });
}

final _tools = <_Tool>[
  _Tool(
    name:    'Sage',
    tagline: 'Your personal mentor — talk, reflect, get support',
    icon:    Icons.self_improvement_rounded,
    builder: () => const MentorScreen(),
  ),
  _Tool(
    name:    'AI Assistant',
    tagline: 'Ask anything about campus, study, life',
    icon:    Icons.auto_awesome_rounded,
    builder: () => const AiAssistantScreen(),
  ),
  _Tool(
    name:    'Code Helper',
    tagline: 'Snippets, debugging, code reviews',
    icon:    Icons.code_rounded,
    builder: () => const CodeAssistantScreen(),
  ),
  _Tool(
    name:    'Companions',
    tagline: 'Chat with Einstein, Shakespeare & more',
    icon:    Icons.groups_rounded,
    builder: () => const CompanionListScreen(),
  ),
  _Tool(
    name:    'Image Generator',
    tagline: 'Turn text into images with FLUX',
    icon:    Icons.image_rounded,
    builder: () => const ImageGeneratorScreen(),
  ),
];

// ═════════════════════════════════════════════════════════════

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});
  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();

  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl; // ← shared by every border
  late final List<Animation<double>> _tileAnims;

  String? _userName;
  int _used  = 0;
  int _limit = 60;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..forward();

    _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 6),
    )..repeat();

    _tileAnims = List.generate(_tools.length, (i) {
      final start = 0.1 + (i * 0.12);
      return CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic),
      );
    });

    _fetchStatus();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await _api.get('/ai/status/');
      if (!mounted || data is! Map) return;
      setState(() {
        _used  = data['messages_used'] as int? ?? 0;
        _limit = data['limit']         as int? ?? 60;
      });
      try {
        final me = await _api.get('/auth/me/');
        if (mounted && me is Map && me['name'] != null) {
          setState(() => _userName = me['name'] as String);
        }
      } catch (_) {}
    } catch (_) {}
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _open(_Tool tool) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => tool.builder()),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent so our gradient Container shows through.
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops:  [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildToolsArea()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Brand row (back button inline) ──────────────────
          Row(
            children: [
              if (canPop) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width:  38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:        _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: _kBorder),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset:     const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _kInk,
                      size:  15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Robot Lottie chip with gradient border
              _GradientBorderCard(
                animation: _shimmerCtrl,
                radius: 12,
                borderWidth: 1.2,
                innerColor: _kCard,
                padding: const EdgeInsets.all(6),
                child: const SizedBox(
                  width: 22, height: 22,
                  child: _SafeRobotLottie(),
                ),
              ),
              const SizedBox(width: 10),

              const Flexible(
                child: Text(
                  'Dale',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            _userName != null
                ? '$_greeting, $_userName 👋'
                : '$_greeting 👋',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _kInkSoft,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'What can I help with today?',
            style: TextStyle(color: _kSlate, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  /// Fixed, non-scrolling tool region. Expanded flexes let the tiles fill
  /// the height the header + footer leave behind, so nothing scrolls.
  Widget _buildToolsArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          // Featured — Sage (wide)
          Expanded(
            flex: 18,
            child: _animatedTile(
              0,
              _ToolTile(
                tool: _tools[0],
                wide: true,
                animation: _shimmerCtrl,
                onTap: () => _open(_tools[0]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Row 1 — AI Assistant · Code Helper
          Expanded(
            flex: 26,
            child: Row(
              children: [
                Expanded(
                  child: _animatedTile(
                    1,
                    _ToolTile(
                      tool: _tools[1],
                      animation: _shimmerCtrl,
                      onTap: () => _open(_tools[1]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _animatedTile(
                    2,
                    _ToolTile(
                      tool: _tools[2],
                      animation: _shimmerCtrl,
                      onTap: () => _open(_tools[2]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Row 2 — Companions · Image Generator
          Expanded(
            flex: 26,
            child: Row(
              children: [
                Expanded(
                  child: _animatedTile(
                    3,
                    _ToolTile(
                      tool: _tools[3],
                      animation: _shimmerCtrl,
                      onTap: () => _open(_tools[3]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _animatedTile(
                    4,
                    _ToolTile(
                      tool: _tools[4],
                      animation: _shimmerCtrl,
                      onTap: () => _open(_tools[4]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedTile(int i, Widget child) {
    final anim = _tileAnims[i];
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) {
        final v = anim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - v)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildFooter() {
    final pct = (_limit == 0 ? 0.0 : _used / _limit).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 16,
        borderWidth: 1.2,
        innerColor: _kCard,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: _kInkSoft, size: 15),
                const SizedBox(width: 6),
                const Text('Hourly usage',
                    style: TextStyle(
                        color: _kInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$_used / $_limit',
                    style: const TextStyle(
                        color: _kSlate,
                        fontSize: 12,
                        fontFamily: 'monospace')),
              ],
            ),
            const SizedBox(height: 8),
            // Mono progress bar — dark fill on light grey track.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: _kCardLo,
                valueColor: const AlwaysStoppedAnimation(_kInkSoft),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: _kSlate2, size: 11),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Free for every TCS student. Powered by Gemini & FLUX.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _kSlate2, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// SAFE ROBOT LOTTIE — fallback now in light tones
// ═════════════════════════════════════════════════════════════

class _SafeRobotLottie extends StatelessWidget {
  const _SafeRobotLottie();

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/images/robot.json',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _kCardLo,
        ),
        child: const Icon(
          Icons.smart_toy_rounded,
          color: _kInkSoft,
          size: 14,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _ToolTile — white card, gradient border, dark icon
//   wide == true  → horizontal featured layout (Sage)
//   wide == false → compact vertical layout (grid tiles)
// ═════════════════════════════════════════════════════════════

class _ToolTile extends StatefulWidget {
  final _Tool             tool;
  final VoidCallback      onTap;
  final Animation<double> animation;
  final bool              wide;
  const _ToolTile({
    required this.tool,
    required this.onTap,
    required this.animation,
    this.wide = false,
  });
  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _pressed = false;

  Widget _iconChip(IconData icon, double box, double glyph) => Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          color: _kInk.withOpacity(0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _kInk.withOpacity(0.08), width: 1),
        ),
        child: Icon(icon, color: _kInk, size: glyph),
      );

  Widget _wideContent(_Tool t) => Row(
        children: [
          _iconChip(t.icon, 50, 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _kInk,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3)),
                const SizedBox(height: 3),
                Text(t.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _kSlate, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_rounded,
              color: _kInkSoft, size: 18),
        ],
      );

  Widget _compactContent(_Tool t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconChip(t.icon, 40, 21),
          const Spacer(),
          Text(t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _kInk,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2)),
          const SizedBox(height: 3),
          Text(t.tagline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _kSlate, fontSize: 11, height: 1.3)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _GradientBorderCard(
          animation: widget.animation,
          radius: widget.wide ? 22 : 18,
          borderWidth: 1.4,
          innerColor: _kCard,
          padding: const EdgeInsets.all(14),
          child: widget.wide ? _wideContent(t) : _compactContent(t),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — animated SweepGradient border around a child.
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double>   animation;
  final Widget              child;
  final double              radius;
  final double              borderWidth;
  final Color               innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color>         colors;

  const _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor = _kCard,
    this.padding,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          math.max(0.0, radius - borderWidth)),
        color: innerColor,
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
