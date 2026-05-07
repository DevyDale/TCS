// lib/screens/dashboard/dashboard_screen.dart
//
// SECTION 2 FIX — top-down welcome banner.
//
// Before: a "Welcome back, X 🎉" SnackBar fired from login_id_screen
// just before navigating here, sliding up from the BOTTOM. That was
// removed in Section 1 (so there's currently no welcome at all).
//
// Now: a proper banner mounted on the dashboard itself. It slides
// DOWN from above the screen, holds for a beat, then slides back up
// out of view. Tap to dismiss early. Fires once per dashboard mount
// (i.e. once per cold start / once per fresh login).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/groups/groups_study_hub_screen.dart';
import 'package:tcs_app/services/app_localisations.dart';
import '../feed/feed_screen.dart';
import '../arcade/arcade_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/ai_assistant_fab.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

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

  // ── SECTION 2 — top-down welcome banner ───────────────────
  late final AnimationController _welcomeCtrl;
  late final Animation<Offset>   _welcomeSlide;
  late final Animation<double>   _welcomeFade;
  bool _welcomeVisible = false;

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

    // Welcome banner controllers.
    // Begin Offset(0, -1.6) means the banner starts ~1.6 banner-heights
    // ABOVE its rest position; end Offset.zero is its visible rest spot
    // just inside SafeArea.top. Reversed it slides back up off-screen.
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

    // Fire after the first frame so the dashboard body has time to
    // render behind the banner.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runWelcome());
  }

  Future<void> _runWelcome() async {
    if (!mounted) return;
    // Tiny delay so the splash → dashboard fade has settled before
    // the banner animates in.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _welcomeVisible = true);
    HapticFeedback.lightImpact();
    await _welcomeCtrl.forward();

    // Hold time on screen.
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
    super.dispose();
  }

  List<Widget> get _screens => [
        const FeedScreen(),
        const GroupsStudyHubScreen(),
        const ChatListScreen(),
        ProfileScreen(
          fullName: widget.fullName,
          preferredName: widget.preferredName,
          role: widget.role,
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
                end: Offset.zero,
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
          // Existing tab content
          ScaleTransition(
            scale: _tabScaleAnim,
            child: _screens[_currentIndex],
          ),

          // Welcome banner overlay — only mounted while visible so it
          // can never accidentally absorb taps when off-screen.
          if (_welcomeVisible) _buildWelcomeBanner(context),
        ],
      ),
      extendBody: true,
      floatingActionButton: _showFab ? const AiAssistantFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Welcome banner — slides DOWN from above ───────────────
  Widget _buildWelcomeBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve the friendliest available name. Preferred name wins;
    // fall back to first word of full name; final fallback "there".
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
                      // Wave avatar
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
                      // Greeting
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
                      // Close affordance — visual only, the whole card
                      // is tappable to dismiss.
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

  Widget _buildBottomNav(BuildContext context) {
    final l    = AppL10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: l.navFeed,
                index: 0,
                selected: _navIndex == 0,
                onTap: () => _onTabTap(0),
              ),
              _NavItem(
                icon: Icons.groups_rounded,
                label: l.navGroups,
                index: 1,
                selected: _navIndex == 1,
                onTap: () => _onTabTap(1),
              ),
              _ArcadeNavButton(
                label: l.navArcade,
                onTap: () => _onTabTap(2),
              ),
              _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: l.navChat,
                index: 3,
                selected: _navIndex == 3,
                onTap: () => _onTabTap(3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: l.navProfile,
                index: 4,
                selected: _navIndex == 4,
                onTap: () => _onTabTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Individual nav item ───────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selColor   = isDark ? _kG1 : _kG2;
    final unselColor = isDark ? const Color(0xFF555566) : const Color(0xFFB0B0B0);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? selColor.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? selColor : unselColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? selColor : unselColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Centre Arcade button ──────────────────────────────────────

class _ArcadeNavButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  const _ArcadeNavButton({required this.onTap, required this.label});

  @override
  State<_ArcadeNavButton> createState() => _ArcadeNavButtonState();
}

class _ArcadeNavButtonState extends State<_ArcadeNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 72,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -6),
              child: AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (_, child) => Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      colors: const [_kG1, _kG2, _kG3, _kG4, _kG1],
                      startAngle: _shimmerCtrl.value * 6.28,
                      endAngle: _shimmerCtrl.value * 6.28 + 6.28,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kG2.withOpacity(0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8E54E9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}