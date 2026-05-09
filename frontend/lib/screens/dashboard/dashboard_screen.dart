// lib/screens/dashboard/dashboard_screen.dart
//
// Nav bar redesign — floating pill matching the supplied reference.
//
// Visual structure:
//   • Pill-shaped bar (22px radius), white surface, _kBorder outline,
//     soft drop shadow. Floats with 16px horizontal margin and 10px
//     bottom margin so the device edge shows through.
//   • 5 slots: Home · Groups · [Arcade centre] · Chat · Profile.
//     Icons only (per the reference image) — l10n strings still flow
//     through as Tooltip semantic labels for accessibility.
//   • Active slot: soft _kCardLo pill behind the icon + ink colour.
//   • Centre Arcade button: 56x56 rounded square (16px radius),
//     rotating SweepGradient through the arcade palette, white 3px
//     ring so it pops on the pale bar, dual shadow underneath. Raised
//     ~14px above the bar surface; tapping launches the Arcade modal
//     (existing behaviour preserved).
//
// Welcome banner — kept as-is. Same SECTION 2 controllers, animation
// curves, and gradient. Only swap is the colour aliases below.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/groups/groups_study_hub_screen.dart';
import 'package:tcs_app/services/app_localisations.dart';
import '../feed/feed_screen.dart';
import '../arcade/arcade_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/ai_assistant_fab.dart';

// Arcade palette (used by the centre button + welcome banner)
const _kBlue   = Color(0xFF6DD5FA);
const _kPurple = Color(0xFF7C3AED);
const _kAmber  = Color(0xFFF59E0B);
const _kCoral  = Color(0xFFFF4F6E);

// Legacy aliases — welcome banner gradient still references these
const _kG1 = _kBlue;
const _kG2 = Color(0xFF8E54E9);

// Light theme surfaces (matches arcade + profile)
const _kCard   = Color(0xFFFFFFFF);
const _kCardLo = Color(0xFFF5F5F8);
const _kBorder = Color(0xFFE5E7EB);
const _kInk    = Color(0xFF0D0D1A);
const _kSlate2 = Color(0xFF9CA3AF);

class DashboardScreen extends StatefulWidget {
  final String fullName;
  final String preferredName;
  final String role;

  const DashboardScreen({
    super.key,
    required this.fullName,
    required this.preferredName,
    required this.role,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late final AnimationController _tabSwitchCtrl;
  late final Animation<double>   _tabScaleAnim;

  // Welcome banner controllers (preserved)
  late final AnimationController _welcomeCtrl;
  late final Animation<Offset>   _welcomeSlide;
  late final Animation<double>   _welcomeFade;
  bool _welcomeVisible = false;

  // Sweep gradient controller for the centre Arcade button
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    _tabSwitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
      lowerBound: 0.96,
      upperBound: 1.0,
    );
    _tabScaleAnim = CurvedAnimation(
      parent: _tabSwitchCtrl,
      curve: Curves.easeOut,
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _welcomeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, -1.6),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent:       _welcomeCtrl,
      curve:        Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _welcomeFade = CurvedAnimation(
      parent:       _welcomeCtrl,
      curve:        const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _runWelcome());
  }

  Future<void> _runWelcome() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _welcomeVisible = true);
    HapticFeedback.lightImpact();
    await _welcomeCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    await _welcomeCtrl.reverse();
    if (!mounted) return;
    setState(() => _welcomeVisible = false);
  }

  Future<void> _dismissWelcome() async {
    if (!_welcomeVisible || !mounted) return;
    HapticFeedback.selectionClick();
    await _welcomeCtrl.reverse();
    if (!mounted) return;
    setState(() => _welcomeVisible = false);
  }

  @override
  void dispose() {
    _tabSwitchCtrl.dispose();
    _welcomeCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  List<Widget> get _screens => [
        const FeedScreen(),
        const GroupsStudyHubScreen(),
        const ChatListScreen(),
        ProfileScreen(
          fullName:      widget.fullName,
          preferredName: widget.preferredName,
          role:          widget.role,
        ),
      ];

  Future<void> _onTabTap(int index) async {
    if (index == 2) {
      HapticFeedback.mediumImpact();
      await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => const ArcadeScreen(),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end:   Offset.zero,
              ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      return;
    }

    final screenIndex = index > 2 ? index - 1 : index;
    if (screenIndex == _currentIndex) return;

    HapticFeedback.selectionClick();
    await _tabSwitchCtrl.reverse();
    setState(() => _currentIndex = screenIndex);
    _tabSwitchCtrl.forward();
  }

  int  get _navIndex => _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;
  bool get _showFab  => _currentIndex == 0 || _currentIndex == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ScaleTransition(
            scale: _tabScaleAnim,
            child: _screens[_currentIndex],
          ),
          if (_welcomeVisible) _buildWelcomeBanner(context),
        ],
      ),
      extendBody: true,
      backgroundColor: Colors.transparent,
      
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Welcome banner (preserved) ────────────────────────────

  Widget _buildWelcomeBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raw  = widget.preferredName.trim();
    final full = widget.fullName.trim();
    final name = raw.isNotEmpty
        ? raw
        : (full.isNotEmpty ? full.split(' ').first : 'there');

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _welcomeSlide,
          child: FadeTransition(
            opacity: _welcomeFade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: GestureDetector(
                onTap: _dismissWelcome,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kG1, _kG2],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: _kG2.withOpacity(isDark ? 0.45 : 0.32),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.45),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text('👋', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'WELCOME BACK',
                              style: TextStyle(
                                fontFamily:    'Arch',
                                fontSize:      10,
                                fontWeight:    FontWeight.bold,
                                color:         Colors.white.withOpacity(0.85),
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Alfa',
                                fontSize:   19,
                                color:      Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.85),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Floating pill nav bar ─────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    final l = AppL10n.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // The pill bar itself
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    _NavSlot(
                      icon: Icons.home_rounded,
                      label: l.navFeed,
                      selected: _navIndex == 0,
                      onTap: () => _onTabTap(0),
                    ),
                    _NavSlot(
                      icon: Icons.groups_rounded,
                      label: l.navGroups,
                      selected: _navIndex == 1,
                      onTap: () => _onTabTap(1),
                    ),
                    // Spacer slot beneath the raised centre button
                    const Expanded(child: SizedBox.shrink()),
                    _NavSlot(
                      icon: Icons.chat_bubble_rounded,
                      label: l.navChat,
                      selected: _navIndex == 3,
                      onTap: () => _onTabTap(3),
                    ),
                    _NavSlot(
                      icon: Icons.person_rounded,
                      label: l.navProfile,
                      selected: _navIndex == 4,
                      onTap: () => _onTabTap(4),
                    ),
                  ]),
                ),
              ),

              // Raised centre Arcade button
              Positioned(
                bottom: 18,
                child: GestureDetector(
                  onTap: () => _onTabTap(2),
                  child: Tooltip(
                    message: l.navArcade,
                    child: AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, child) => Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: const [_kBlue, _kPurple, _kAmber, _kCoral, _kBlue],
                            startAngle: _shimmerCtrl.value * 6.28,
                            endAngle:   _shimmerCtrl.value * 6.28 + 6.28,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kCard, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _kPurple.withOpacity(0.40),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: _kCoral.withOpacity(0.20),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: const Icon(
                        Icons.sports_esports_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single nav slot (regular icon, non-centre) ───────────────

class _NavSlot extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const _NavSlot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Center(
            child: Tooltip(
              message: label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: selected ? _kCardLo : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? _kInk : _kSlate2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}