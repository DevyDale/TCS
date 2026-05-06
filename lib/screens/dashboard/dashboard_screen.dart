// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/groups/groups_study_hub_screen.dart';
import 'package:tcs_app/services/app_localisations.dart';
import 'package:tcs_app/welcome_banner.dart';
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
  late final Animation<double> _tabScaleAnim;

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
  }

  @override
  void dispose() {
    _tabSwitchCtrl.dispose();
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

  int get _navIndex => _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;

  bool get _showFab => _currentIndex == 0 || _currentIndex == 1;

  bool _welcomeDone = false;

@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ScaleTransition(
            scale: _tabScaleAnim,
            child: _screens[_currentIndex],
          ),
          if (!_welcomeDone)
            WelcomeBanner(
              name: widget.preferredName,
              onDismissed: () {
                if (mounted) setState(() => _welcomeDone = true);
              },
            ),
        ],
      ),
      extendBody: true,
      floatingActionButton: _showFab ? const AiAssistantFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(context),
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