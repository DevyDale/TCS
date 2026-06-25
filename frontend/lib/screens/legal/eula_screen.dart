// lib/screens/legal/eula_screen.dart
//
// Apple App Review Guideline 1.2 — a EULA / terms-of-use agreement must be
// presented BEFORE the user registers or logs in, with an explicit
// acknowledgement that there is ZERO tolerance for objectionable content or
// abusive users.
//
// Usage — gate app entry on this screen. In your splash / initial routing
// (e.g. main.dart or splash_screen.dart), before sending the user to role
// selection / login:
//
//   if (!await EulaGate.isAccepted()) {
//     final ok = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(builder: (_) => const EulaScreen()),
//     );
//     if (ok != true) return;            // user declined → don't proceed
//   }
//   // ...continue to RoleSelectionScreen()
//
// EulaScreen pops `true` on accept and `false` on decline.

import 'dart:math' as math;
import 'package:tcs_app/widgets/t_text.dart';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Brand palette (matches role_selection_screen / AI Hub light theme) ──
const Color _kG1  = Color(0xFF6DD5FA); // cyan
const Color _kG2  = Color(0xFF8E54E9); // purple
const Color _kG3  = Color(0xFFF7971E); // amber
const Color _kG4  = Color(0xFFFF5858); // red
const Color _kInk = Color(0xFF1A1A2E);
const Color _kBg  = Color(0xFFF7F8FA);

/// Persists EULA acceptance. Bump the key suffix if the terms change
/// materially and you need users to re-accept.
class EulaGate {
  static const _key = 'tcs_eula_accepted_v1';

  static Future<bool> isAccepted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markAccepted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }
}

// ── Section content model ──────────────────────────────────────────────
class _SectionData {
  final IconData icon;
  final Color    accent;
  final String   title;
  final String   body;
  final bool     highlight;
  const _SectionData(this.icon, this.accent, this.title, this.body,
      {this.highlight = false});
}

const List<_SectionData> _sections = [
  _SectionData(
    Icons.waving_hand_rounded, _kG1,
    'Welcome to TCS',
    'TCS (Taylors College Social) is a community platform for the Taylors '
    'College community. By creating an account or logging in, you agree to '
    'these Terms of Use and our Community Rules.',
  ),
  _SectionData(
    Icons.gpp_bad_rounded, _kG4,
    'Zero Tolerance for Objectionable Content',
    'You agree not to create, upload, post, or share content that is '
    'unlawful, harassing, threatening, hateful, defamatory, sexually '
    'explicit, or otherwise objectionable. TCS enforces a ZERO-TOLERANCE '
    'policy for objectionable content and for abusive behaviour towards '
    'other users.',
    highlight: true,
  ),
  _SectionData(
    Icons.flag_rounded, _kG2,
    'Reporting & Blocking',
    'Every post and every user profile includes tools to report '
    'objectionable content and to block abusive users. Blocking a user '
    'immediately removes their content from your feed and prevents further '
    'contact. Reports are sent to our moderation team for review.',
  ),
  _SectionData(
    Icons.gavel_rounded, _kG3,
    'Moderation & Enforcement',
    'We review reported content and act on objectionable content within 24 '
    'hours. We may remove content and suspend or permanently remove accounts '
    'that violate these terms, without prior notice. Automated filtering may '
    'also hold suspected content for review before it appears in feeds.',
  ),
  _SectionData(
    Icons.account_circle_rounded, _kG1,
    'Your Responsibilities',
    'You are responsible for the content you post and for your conduct. You '
    'must be authorised to use the account you sign in with, must not '
    'impersonate others, and must not attempt to circumvent moderation or '
    'blocking.',
  ),
  _SectionData(
    Icons.lock_rounded, _kG2,
    'Privacy',
    'We process your data to operate TCS. We do not sell your personal '
    'information. See the in-app Privacy Policy for details on what we '
    'collect and how it is used.',
  ),
  _SectionData(
    Icons.support_agent_rounded, _kG3,
    'Contact',
    'Questions or concerns about these terms or about content on TCS can be '
    'raised through the in-app support / suggestion box.',
  ),
];

class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _entry;

  late final Animation<double>      _headerFade;
  late final Animation<Offset>      _headerSlide;
  late final List<Animation<double>> _sectionAnims;

  bool   _agreed     = false;  // checkbox
  bool   _reachedEnd = false;  // scrolled the terms to the bottom
  double _progress   = 0;      // 0..1 reading progress

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _headerFade = CurvedAnimation(
        parent: _entry, curve: const Interval(0, 0.45, curve: Curves.easeOut));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entry,
            curve: const Interval(0, 0.5, curve: Curves.easeOutCubic)));

    // Staggered reveal for each clause card.
    _sectionAnims = List.generate(_sections.length, (i) {
      final start = (0.18 + i * 0.07).clamp(0.0, 0.65);
      final end   = (start + 0.42).clamp(0.0, 1.0);
      return CurvedAnimation(
          parent: _entry, curve: Interval(start, end, curve: Curves.easeOutCubic));
    });

    _scroll.addListener(_onScroll);
    _entry.forward();

    // If the terms fit on screen (large devices), there's nothing to scroll —
    // unlock the gate after the first frame so the user isn't stuck.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0) {
        setState(() {
          _reachedEnd = true;
          _progress = 1;
        });
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final p = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    final atEnd = max <= 0 || _scroll.offset >= max - 24;
    if (p != _progress || (atEnd && !_reachedEnd)) {
      setState(() {
        _progress = p;
        if (atEnd) _reachedEnd = true;
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _entry.dispose();
    super.dispose();
  }

  bool get _canContinue => _agreed && _reachedEnd;

  Future<void> _accept() async {
    HapticFeedback.mediumImpact();
    await EulaGate.markAccepted();
    if (mounted) Navigator.pop(context, true);
  }

  void _decline() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, false);
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) return;
    HapticFeedback.selectionClick();
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toggleAgree() {
    if (!_reachedEnd) return;
    HapticFeedback.selectionClick();
    setState(() => _agreed = !_agreed);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildHeader(topInset),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _sections.length; i++)
                              _animatedCard(i),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildJumpButton(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader(double topInset) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons while the gradient sits behind the status bar.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android
        statusBarBrightness: Brightness.dark,      // iOS
      ),
      child: FadeTransition(
        opacity: _headerFade,
        child: SlideTransition(
          position: _headerSlide,
          // The reading-progress indicator is painted ON the header's rounded
          // bottom edge (foregroundPainter), tracing its 30px corner radius
          // and filling left → right as the user reads.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (_, value, child) => CustomPaint(
              foregroundPainter:
                  _HeaderCurveProgressPainter(progress: value),
              child: child,
            ),
            child: Container(
            width: double.infinity,
            // Extend the gradient up behind the status bar / notch, while
            // keeping the title clear of it.
            padding: EdgeInsets.fromLTRB(24, 26 + topInset, 24, 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kG1, _kG2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x338E54E9),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                T(
                  'Terms of Use &\nCommunity Rules',
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    height: 1.15,
                    color: AppC.text,
                  ),
                ),
                const SizedBox(height: 8),
                T(
                  'Please read these terms before continuing to TCS.',
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 13,
                    color: AppC.text.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  // ── Clause card (with stagger animation) ────────────────────────────────
  Widget _animatedCard(int i) {
    final anim = _sectionAnims[i];
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(anim),
        child: _SectionCard(_sections[i]),
      ),
    );
  }

  // ── Floating "skip to end" button ───────────────────────────────────────
  Widget _buildJumpButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: IgnorePointer(
        ignoring: _reachedEnd,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _reachedEnd ? 0 : 1,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 250),
            scale: _reachedEnd ? 0.7 : 1,
            child: GestureDetector(
              onTap: _jumpToEnd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG1, _kG2]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: _kG2.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    T(
                      'Skip to end',
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppC.text,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.keyboard_double_arrow_down_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Footer: status + agree + actions ────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusRow(),
          const SizedBox(height: 10),
          _buildAgreeRow(),
          const SizedBox(height: 12),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _reachedEnd
          ? Row(
              key: const ValueKey('done'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF1D9E75), size: 18),
                SizedBox(width: 8),
                Text(
                  "You've read the full terms",
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: Color(0xFF1D9E75),
                  ),
                ),
              ],
            )
          : Row(
              key: const ValueKey('reading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 16, color: AppC.faint),
                const SizedBox(width: 8),
                Text(
                  'Scroll to read all terms · ${(_progress * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 12.5,
                    color: AppC.faint,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAgreeRow() {
    final enabled = _reachedEnd;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleAgree,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              gradient: _agreed
                  ? const LinearGradient(colors: [_kG1, _kG2])
                  : null,
              color: _agreed ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _agreed
                    ? Colors.transparent
                    : (enabled
                        ? _kG2.withOpacity(0.55)
                        : AppC.border),
                width: 2,
              ),
            ),
            child: _agreed
                ? const Icon(Icons.check_rounded,
                    size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: T(
              'I agree to the Terms of Use and accept that there is zero '
              'tolerance for objectionable content or abusive behaviour.',
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 12.5,
                height: 1.4,
                color: enabled ? _kInk : AppC.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _decline,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: T(
              'Decline',
              style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppC.sub,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _canContinue ? _accept : null,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: _canContinue ? 1 : 0.98,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _canContinue ? 1 : 0.45,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kG1, _kG2]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: _canContinue
                        ? [
                            BoxShadow(
                              color: _kG2.withOpacity(0.40),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: T(
                    'Agree & Continue',
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppC.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Single clause card ─────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final _SectionData d;
  const _SectionCard(this.d);

  @override
  Widget build(BuildContext context) {
    final hl = d.highlight;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hl ? d.accent.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hl
              ? d.accent.withOpacity(0.30)
              : Colors.black.withOpacity(0.05),
          width: hl ? 1.4 : 1,
        ),
        boxShadow: hl
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [d.accent.withOpacity(0.85), d.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: d.accent.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(d.icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        d.title,
                        style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          height: 1.2,
                          color: _kInk,
                        ),
                      ),
                    ),
                    if (hl) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: d.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: T(
                          'IMPORTANT',
                          style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                            color: d.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  d.body,
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 13,
                    height: 1.5,
                    color: AppC.sub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Curved reading-progress indicator ───────────────────────────────────
// Draws reading progress as a stroke that traces the header's rounded bottom
// outline (matching its 30px bottom corner radius) and fills left → right as
// the user scrolls through the terms. Replaces the old straight bar.
class _HeaderCurveProgressPainter extends CustomPainter {
  final double progress; // 0..1
  _HeaderCurveProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const double r     = 30; // header bottom corner radius
    const double inset = 3;  // keep the stroke just inside the gradient edge
    const double rr    = r - inset;
    final double w = size.width;
    final double h = size.height;

    final Offset blCenter = Offset(inset + rr, h - inset - rr);
    final Offset brCenter = Offset(w - inset - rr, h - inset - rr);

    // Left edge → bottom-left corner → bottom edge → bottom-right corner →
    // right edge. One continuous contour, so PathMetrics has a single entry.
    final Path path = Path()
      ..moveTo(inset, h - inset - rr)
      ..arcTo(Rect.fromCircle(center: blCenter, radius: rr),
          math.pi, -math.pi / 2, false)
      ..lineTo(w - inset - rr, h - inset)
      ..arcTo(Rect.fromCircle(center: brCenter, radius: rr),
          math.pi / 2, -math.pi / 2, false);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.22);
    canvas.drawPath(path, track);

    final double p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final metric = path.computeMetrics().first;
    final Path filled = metric.extractPath(0, metric.length * p);
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawPath(filled, fill);
  }

  @override
  bool shouldRepaint(covariant _HeaderCurveProgressPainter old) =>
      old.progress != progress;
}
