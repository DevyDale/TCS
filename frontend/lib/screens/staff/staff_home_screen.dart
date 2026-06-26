// lib/screens/staff/staff_home_screen.dart
//
// HOME tab — the staff Cohort Command Center.
// Header greeting + notifications/Dale buttons, live pulse strip, even gradient
// quick actions, and a "Run your cohort" auto-advancing carousel that fills the
// space down to JUST ABOVE the bottom nav (never under it).
// Pulse data: GET /api/moderation/staff/overview/.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/splash_screen.dart';
import 'package:tcs_app/screens/staff/staff_announcements_screen.dart';
import 'package:tcs_app/screens/staff/staff_moderation_screen.dart';
import 'package:tcs_app/screens/staff/suggestions_review_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';
import 'package:tcs_app/screens/dashboard/events_screen.dart';
import 'package:tcs_app/screens/staff/staff_oversight_screen.dart';
import 'package:tcs_app/screens/staff/staff_audit_screen.dart';
import 'package:tcs_app/screens/staff/staff_permissions_screen.dart';
import 'package:tcs_app/screens/staff/staff_needs_attention_screen.dart';
import 'package:tcs_app/screens/notification_Screen.dart';
import 'package:tcs_app/screens/staff/staff_dale_screen.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/widgets/welcome_banner.dart';
import 'package:tcs_app/widgets/dale_greeting_cloud.dart';

// Dale animation — the same robot Lottie used across the app. Falls back to an
// icon if the asset is ever missing.
const _kDaleLottie = 'assets/images/robot.json';

class StaffHomeScreen extends StatefulWidget {
  final String fullName;
  final String preferredName;
  final String role;
  const StaffHomeScreen({
    super.key,
    required this.fullName,
    required this.preferredName,
    required this.role,
  });

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _api = ApiService();
  int? _activeToday, _flagsPending, _upcomingEvents;
  bool _loading = true;

  final _cohortCtrl = PageController(viewportFraction: 0.82);
  int _cohortPage = 0;
  Timer? _autoTimer;
  bool _showWelcome = true; // welcome banner, once per app launch
  bool _showDaleCloud = false; // Dale greeting cloud, after the welcome banner

  @override
  void initState() {
    super.initState();
    _load();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _cohortCtrl.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_cohortCtrl.hasClients) return;
      final count = _cohortItems().length;
      final next = (_cohortPage + 1) % count;
      _cohortCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _load() async {
    try {
      final d = (await _api.get('/moderation/staff/overview/') as Map)
          .cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _activeToday    = (d['active_today'] as num?)?.toInt();
        _flagsPending   = (d['flags_pending'] as num?)?.toInt();
        _upcomingEvents = (d['upcoming_events'] as num?)?.toInt();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _firstName {
    final p = widget.preferredName.trim();
    final f = p.isNotEmpty ? p : widget.fullName.trim();
    return f.isEmpty ? 'there' : f.split(' ').first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _push(Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Log out?',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Text('You\'ll need to sign in again to use the staff console.',
            style: TextStyle(fontFamily: 'Momo', color: AppC.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out',
                  style: TextStyle(color: Color(0xFFE11D48),
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    try { await _api.logout(); } catch (_) {/* clear locally regardless */}
    Get.offAll(() => const SplashScreen());
  }

  // Dale animation with a safe icon fallback if the asset isn't present.
  Widget _daleVisual({required double size, required Color fallbackColor}) {
    return Lottie.asset(
      _kDaleLottie,
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.auto_awesome_rounded, color: fallbackColor, size: size * 0.62),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reserve room so the carousel ends ABOVE the bottom nav bar.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const navBarHeight = 64.0;
    final cohortHeight = (MediaQuery.of(context).size.height * 0.30)
        .clamp(220.0, 300.0);

    return Scaffold(
      backgroundColor: AppC.bg,
      body: Stack(children: [
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Column(children: [
                _pulseStrip(),
                const SizedBox(height: 24),
                _sectionLabel('Quick actions'),
                _quickActions(),
                const SizedBox(height: 26),
                _sectionLabel('Run your cohort'),
                const SizedBox(height: 6),
                SizedBox(height: cohortHeight, child: _cohort()),
                SizedBox(height: navBarHeight + bottomInset + 12),
              ]),
            ),
          ],
        ),
        if (_showWelcome)
          WelcomeBanner(
            name: _firstName,
            onDismissed: () {
              if (mounted) setState(() {
                _showWelcome = false;
                _showDaleCloud = true; // then Dale pops out of his button
              });
            },
          ),
        if (_showDaleCloud)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: DaleGreetingCloud(
              tailFromRight: 26,
              onTap: () => _push(const StaffDaleScreen()),
              onDismiss: () {
                if (mounted) setState(() => _showDaleCloud = false);
              },
            ),
          ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _header() {
    return StaffHeader(
      bottomPad: 26,
      horizontal: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 12),
              SizedBox(width: 5),
              Text('STAFF',
                  style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5,
                      color: Colors.white)),
            ]),
          ),
          const Spacer(),
          _headerButton(
              child: const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 20),
              onTap: () => _push(const NotificationsScreen()),
              dot: (_flagsPending ?? 0) > 0),
          const SizedBox(width: 10),
          _headerButton(
              child: const Icon(Icons.logout_rounded,
                  color: Colors.white, size: 19),
              onTap: _logout),
          const SizedBox(width: 10),
          _headerButton(
              child: _daleVisual(size: 30, fallbackColor: Colors.white),
              onTap: () => _push(const StaffDaleScreen())),
        ]),
        const SizedBox(height: 20),
        Text('$_greeting,',
            style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 12),
        Text(_firstName,
            style: const TextStyle(fontFamily: 'Alfa', fontSize: 30,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.bolt_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text("Here's what needs you today",
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _headerButton({
    required Widget child,
    required VoidCallback onTap,
    bool dot = false,
  }) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 42, height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: child),
        if (dot)
          Positioned(right: -1, top: -1, child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48), shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.6)))),
      ]),
    );
  }

  // ── Pulse strip ───────────────────────────────────────────
  Widget _pulseStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _pulseTile('Active today', _activeToday, Icons.bolt_rounded,
            const Color(0xFF22C55E),
            onTap: () => _push(
                const StaffOversightScreen(initialFilter: 'active'))),
        const SizedBox(width: 10),
        _pulseTile('Flags pending', _flagsPending, Icons.flag_rounded,
            const Color(0xFFE11D48),
            onTap: () => _push(const StaffNeedsAttentionScreen())),
        const SizedBox(width: 10),
        _pulseTile('Upcoming', _upcomingEvents, Icons.event_rounded,
            const Color(0xFFF59E0B),
            onTap: () => _push(const EventsScreen())),
      ]),
    );
  }

  Widget _pulseTile(String label, int? value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: staffCard(),
          child: Column(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: color, size: 18)),
            const SizedBox(height: 9),
            Text(_loading ? '—' : '${value ?? 0}',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 23,
                    color: AppC.text, height: 1)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                    fontWeight: FontWeight.bold, letterSpacing: 0.3,
                    color: AppC.sub)),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => StaffSectionLabel(t);

  // ── Quick actions (even-height gradient tiles) ────────────
  Widget _quickActions() {
    final actions = <(IconData, String, List<Color>, VoidCallback)>[
      (Icons.campaign_rounded, 'Post announcement',
          [const Color(0xFFA78BFA), const Color(0xFF8E54E9)],
          () => _push(const StaffAnnouncementsScreen())),
      (Icons.event_available_rounded, 'Create event',
          [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
          () => _push(const EventsScreen())),
      (Icons.school_rounded, 'Train Dale',
          [const Color(0xFF2DD4BF), const Color(0xFF0EA5A4)],
          () => _push(const StaffKnowledgeScreen())),
    ];
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); a.$4(); },
            child: Container(
              width: 124,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: a.$3,
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: a.$3.last.withValues(alpha: 0.35),
                    blurRadius: 16, offset: const Offset(0, 8))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(a.$1, color: Colors.white, size: 21)),
                  const Spacer(),
                  Text(a.$2, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Arch',
                          fontSize: 12.5, fontWeight: FontWeight.bold,
                          height: 1.2, color: Colors.white)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Run your cohort (auto-advancing carousel) ─────────────
  List<_CohortItem> _cohortItems() {
    final items = <_CohortItem>[
      _CohortItem(Icons.shield_rounded, 'Moderation', 'Flags, hide & remove',
          [const Color(0xFFFB7185), const Color(0xFFE11D48)],
          () => _push(const StaffModerationScreen())),
      _CohortItem(Icons.lightbulb_rounded, 'Suggestions',
          'Student ideas to the school',
          [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
          () => _push(const SuggestionsReviewScreen())),
      _CohortItem(Icons.campaign_rounded, 'Announcements',
          'Official posts & push',
          [const Color(0xFFA78BFA), const Color(0xFF8E54E9)],
          () => _push(const StaffAnnouncementsScreen())),
      _CohortItem(Icons.school_rounded, 'Train Dale', 'Tutor from your notes',
          [const Color(0xFF2DD4BF), const Color(0xFF0EA5A4)],
          () => _push(const StaffKnowledgeScreen())),
      _CohortItem(Icons.insights_rounded, 'Oversight', 'Roster & engagement',
          [const Color(0xFF60A5FA), const Color(0xFF2575FC)],
          () => _push(const StaffOversightScreen())),
      _CohortItem(Icons.receipt_long_rounded, 'Audit log',
          'Every staff action, logged',
          [const Color(0xFF94A3B8), const Color(0xFF64748B)],
          () => _push(const StaffAuditScreen())),
    ];
    if (widget.role.toLowerCase().trim() == 'admin') {
      items.add(_CohortItem(Icons.key_rounded, 'Permissions',
          'Assign staff tiers',
          [const Color(0xFFFBBF24), const Color(0xFFB45309)],
          () => _push(const StaffPermissionsScreen())));
    }
    return items;
  }

  Widget _cohort() {
    final items = _cohortItems();
    return Listener(
      onPointerDown: (_) => _autoTimer?.cancel(),
      onPointerUp: (_) => _startAutoScroll(),
      child: PageView.builder(
        controller: _cohortCtrl,
        onPageChanged: (i) => setState(() => _cohortPage = i),
        itemCount: items.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _cohortTile(items[i]),
        ),
      ),
    );
  }

  Widget _cohortTile(_CohortItem it) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); it.onTap(); },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: it.gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
              color: it.gradient.last.withValues(alpha: 0.22),
              blurRadius: 22, offset: const Offset(0, 12))]),
        padding: const EdgeInsets.all(1.6),
        child: Container(
          decoration: BoxDecoration(
            color: AppC.card,
            borderRadius: BorderRadius.circular(22.6)),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: it.gradient,
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                      color: it.gradient.last.withValues(alpha: 0.40),
                      blurRadius: 14, offset: const Offset(0, 6))]),
                child: Icon(it.icon, color: Colors.white, size: 28)),
              const Spacer(),
              Text(it.title,
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 20,
                      color: AppC.text)),
              const SizedBox(height: 7),
              Text(it.subtitle,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                      color: AppC.sub, height: 1.3)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: it.gradient.last.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Open',
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: it.gradient.last)),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded, size: 13,
                      color: it.gradient.last),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CohortItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  _CohortItem(this.icon, this.title, this.subtitle, this.gradient, this.onTap);
}
