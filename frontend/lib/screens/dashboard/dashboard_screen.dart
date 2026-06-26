// lib/screens/dashboard/dashboard_screen.dart
//
// CHANGE LOG (this revision):
//   • Nav-bar dimensions are no longer hardcoded. Every value (height,
//     slot row height, arcade button size, arcade bottom offset, top
//     radius, slot icon size, active-slot pill size, pill radius) now
//     reads from the existing R helpers in responsive_helper.dart, so
//     the bar adapts as the screen-class changes (phone → tablet →
//     desktop). Phones vary 320–430px wide and tablets/laptops are
//     even bigger; this stops the bar from looking cramped on small
//     phones and tiny on iPad.
//   • The geometric invariant for the raised arcade button is
//     preserved at every tier:
//         barH − arcadeBottom − arcadeSize == 0
//     …so the button's top edge always sits flush with the bar top.
//   • _NavSlot now takes iconSize / pillSize / pillRadius so it scales
//     in lockstep with the rest of the bar.
//   • responsive_helper.dart was NOT modified — this file pulls from
//     existing R getters only (btnH, sm, radiusLg, iconMd, radiusSm,
//     radiusMd).
//   • Welcome banner, animations, and routing logic are untouched.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/groups/groups_study_hub_screen.dart';
import 'package:tcs_app/services/app_warmup.dart';
import 'package:tcs_app/services/app_localisations.dart';
import '../feed/feed_screen.dart';
import '../arcade/arcade_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../staff/staff_home_screen.dart';
import '../../widgets/emergency_banner.dart';
import '../staff/staff_protect_screen.dart';
import '../staff/staff_connect_screen.dart';
import '../../utils/responsive_helper.dart';

// Arcade palette (used by the centre button + welcome banner)
const _kBlue   = Color(0xFF6DD5FA);
const _kPurple = Color(0xFF7C3AED);
const _kAmber  = Color(0xFFF59E0B);
const _kCoral  = Color(0xFFFF4F6E);

// Legacy aliases — welcome banner gradient still references these

// Light theme surfaces (matches arcade + profile)
Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;
Color get _kInk => AppC.text;
Color get _kSlate2 => AppC.sub;

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

  // Sweep gradient controller for the centre Arcade button
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();

    // Warm the hot endpoints once, right after the user lands on the
    // dashboard (the shared destination for both splash-resume and
    // fresh login). Fire-and-forget: failures just fall back to each
    // screen's normal first-load fetch.
    unawaited(AppWarmup.run());

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

  }

      @override
  void dispose() {
    _tabSwitchCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  List<Widget> get _screens => _isStaff
      ? [
          StaffHomeScreen(
            fullName:      widget.fullName,
            preferredName: widget.preferredName,
            role:          widget.role,
          ),
          const StaffProtectScreen(),
          const StaffConnectScreen(),
        ]
      : [
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
    // Staff nav: all 5 slots (incl. the centre 'Connect') are real tabs.
    if (_isStaff) {
      if (index == _currentIndex) return;
      HapticFeedback.selectionClick();
      await _tabSwitchCtrl.reverse();
      setState(() => _currentIndex = index);
      _tabSwitchCtrl.forward();
      return;
    }
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

  // Staff have 5 real tabs (centre included) → nav position == screen index.
  // Students map 4 screens onto 5 slots, skipping the centre Arcade push.
  int  get _navIndex => _isStaff
      ? _currentIndex
      : (_currentIndex >= 2 ? _currentIndex + 1 : _currentIndex);

  // Staff-only: additive entry point to the command-center console. Students
  // never see it; staff keep the normal dashboard as home.
  bool get _isStaff => const {'teaching_staff', 'non_teaching_staff', 'admin'}
      .contains(widget.role.toLowerCase().trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ScaleTransition(
            scale: _tabScaleAnim,
            child: _screens[_currentIndex],
          ),
          // Students see live emergency alerts on any tab.
          if (!_isStaff) const EmergencyBanner(),
        ],
      ),
      // Body still draws behind the bar so transparent scrims and gradients
      // can show through near the bar's rounded top edge.
      extendBody: true,
      backgroundColor: Colors.transparent,
      bottomNavigationBar:
          _isStaff ? _buildStaffNav(context) : _buildBottomNav(context),
    );
  }

  // ── Staff nav: a flat 4-tab bar (Home · Protect · Connect · Campus).
  // Dale lives on Home's header button instead of in the bar.
  Widget _buildStaffNav(BuildContext context) {
    final r = R(context);
    final double barH       = r.btnH + r.sm;
    final double slotsH     = r.btnH;
    final double topRadius  = r.radiusLg;
    final double slotIcon   = r.iconMd;
    final double slotPill   = slotsH - 8;
    final double pillRadius = r.radiusSm;

    _NavSlot slot(IconData icon, String label, int i) => _NavSlot(
          icon: icon, label: label,
          selected: _navIndex == i,
          onTap: () => _onTabTap(i),
          iconSize: slotIcon, pillSize: slotPill, pillRadius: pillRadius,
        );

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(topRadius),
          topRight: Radius.circular(topRadius)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barH,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: slotsH,
              child: Row(children: [
                slot(Icons.dashboard_rounded, 'Home', 0),
                slot(Icons.shield_rounded, 'Protect', 1),
                slot(Icons.forum_rounded, 'Connect', 2),
              ]),
            ),
          ),
        ),
      ),
    );
  }

    // ── Flush-bottom nav bar (responsive via R helpers) ───────
  //
  // Every dimension below derives from R(context) so the bar scales
  // automatically when the device class changes. Phone values are the
  // smallest; tablet and desktop tiers grow proportionally.
  //
  //   barH         = r.btnH + r.sm   →  64 / 72 / 80   (phone/tablet/desktop)
  //   slotsH       = r.btnH          →  52 / 56 / 60
  //   arcadeSize   = r.btnH          →  52 / 56 / 60
  //   arcadeBot    = r.sm            →  12 / 16 / 20
  //   topRadius    = r.radiusLg      →  20 / 24 / 28
  //   slotIcon     = r.iconMd        →  22 / 26 / 28
  //   slotPill     = slotsH − 8      →  44 / 48 / 52
  //   pillRadius   = r.radiusSm      →  12 / 14 / 14
  //   arcadeRadius = r.radiusMd      →  16 / 18 / 18
  //
  // Geometric invariant at every tier:
  //   barH − arcadeBot − arcadeSize == 0
  // → arcade button top edge sits flush with bar top edge.

  Widget _buildBottomNav(BuildContext context) {
    final l = AppL10n.of(context);
    final r = R(context);

    // Resolve once per build so every child reads the same numbers.
    final double barH         = r.btnH + r.sm;
    final double slotsH       = r.btnH;
    final double arcadeSize   = r.btnH;
    final double arcadeBot    = r.sm;
    final double topRadius    = r.radiusLg;
    final double slotIcon     = r.iconMd;
    final double slotPill     = slotsH - 8;
    final double pillRadius   = r.radiusSm;
    final double arcadeRadius = r.radiusMd;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        // Round only the top corners — bottom is flat against the screen.
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(topRadius),
          topRight: Radius.circular(topRadius),
        ),
        // Single soft shadow casting UPWARD onto the body for separation.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        // We only care about the bottom inset here — the top of the bar
        // sits inside the body, no system status bar to worry about.
        top: false,
        child: SizedBox(
          height: barH,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // ── Slots row ────────────────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: slotsH,
                child: Row(children: [
                  _NavSlot(
                    icon: _isStaff ? Icons.dashboard_rounded : Icons.home_rounded,
                    label: _isStaff ? 'Home' : l.navFeed,
                    selected: _navIndex == 0,
                    onTap: () => _onTabTap(0),
                    iconSize: slotIcon,
                    pillSize: slotPill,
                    pillRadius: pillRadius,
                  ),
                  _NavSlot(
                    icon: _isStaff ? Icons.shield_rounded : Icons.groups_rounded,
                    label: _isStaff ? 'Protect' : l.navGroups,
                    selected: _navIndex == 1,
                    onTap: () => _onTabTap(1),
                    iconSize: slotIcon,
                    pillSize: slotPill,
                    pillRadius: pillRadius,
                  ),
                  // Spacer beneath the centre arcade button.
                  const Expanded(child: SizedBox.shrink()),
                  _NavSlot(
                    icon: _isStaff ? Icons.gps_fixed_rounded : Icons.chat_bubble_rounded,
                    label: _isStaff ? 'Campus' : l.navChat,
                    selected: _navIndex == 3,
                    onTap: () => _onTabTap(3),
                    iconSize: slotIcon,
                    pillSize: slotPill,
                    pillRadius: pillRadius,
                  ),
                  _NavSlot(
                    icon: _isStaff ? Icons.smart_toy_rounded : Icons.person_rounded,
                    label: _isStaff ? 'Dale' : l.navProfile,
                    selected: _navIndex == 4,
                    onTap: () => _onTabTap(4),
                    iconSize: slotIcon,
                    pillSize: slotPill,
                    pillRadius: pillRadius,
                  ),
                ]),
              ),

              // ── Centre Arcade button ─────────────────────────
              // Square equal to slotsH, raised by arcadeBot. Because
              // barH = slotsH + arcadeBot, the button's TOP touches the
              // bar's TOP — same lifted-focal vibe as before, just
              // scaling automatically with screen size.
              Positioned(
                bottom: arcadeBot,
                child: GestureDetector(
                  onTap: () => _onTabTap(2),
                  child: Tooltip(
                    message: _isStaff ? 'Connect' : l.navArcade,
                    child: AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, child) => Container(
                        width: arcadeSize, height: arcadeSize,
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: const [
                              _kBlue, _kPurple, _kAmber, _kCoral, _kBlue,
                            ],
                            startAngle: _shimmerCtrl.value * 6.28,
                            endAngle:   _shimmerCtrl.value * 6.28 + 6.28,
                          ),
                          borderRadius: BorderRadius.circular(arcadeRadius),
                          // White ring (matches bar surface) so the button
                          // pops cleanly out of the pale background.
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
                      // Icon scales with the slot icons so the centre
                      // button stays in proportion across screen sizes.
                      child: Icon(
                        _isStaff
                            ? Icons.forum_rounded
                            : Icons.sports_esports_rounded,
                        color: Colors.white,
                        size: slotIcon + 4, // a touch larger than slot icons
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
//
// Now takes iconSize / pillSize / pillRadius from the parent, which
// resolves them via R(context). Kept stateless and parameter-driven
// so the responsive logic stays in one place (the parent build).

class _NavSlot extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  // Responsive measurements — passed in by parent.
  final double iconSize;
  final double pillSize;
  final double pillRadius;

  const _NavSlot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.iconSize,
    required this.pillSize,
    required this.pillRadius,
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
                width: pillSize, height: pillSize,
                decoration: BoxDecoration(
                  color: selected ? _kCardLo : Colors.transparent,
                  borderRadius: BorderRadius.circular(pillRadius),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
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