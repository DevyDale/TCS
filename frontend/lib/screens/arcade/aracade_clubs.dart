// lib/screens/arcade/arcade_clubs_screen.dart
//
// Clubs hub — redesigned layout.
//
// Hosts everything club-related that used to live in the Arcade "Clubs" tab:
// the user's clubs, featured gaming clubs, trending clubs, and a live
// activity feed (merged posts + events). Self-contained theme tokens keep it
// visually consistent with the Arcade without depending on its private widgets.
//
// Layout (top → bottom):
//   • Compact pinned bar (back · Clubs · refresh)
//   • Hero  — headline, subtitle, and the two primary actions (Discover / Start)
//   • My clubs   — legible horizontal rail (or an inviting empty state)
//   • Featured   — premium cover-image carousel of gaming clubs
//   • Trending   — ranked vertical list
//   • Activity   — live feed of posts & events from your clubs
//
// Data wiring, state, API calls and navigation are unchanged from the
// original — this is a presentation-only redesign.

import 'dart:math' as math;
import 'package:tcs_app/widgets/t_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';

import 'club_list.dart';
import 'club_screen.dart';
import 'create_club_page.dart';
import 'arcade_Effects.dart';

// ═════════════════════════════════════════════════════════════
// THEME
// ═════════════════════════════════════════════════════════════

class _T {
  final Color bg1, bg2, bg3;
  final Color card, cardLo;
  final Color border;
  final Color ink, inkSoft, slate, slate2;
  final bool  isDark;

  const _T({
    required this.bg1, required this.bg2, required this.bg3,
    required this.card, required this.cardLo,
    required this.border,
    required this.ink, required this.inkSoft,
    required this.slate, required this.slate2,
    required this.isDark,
  });

  static const light = _T(
    bg1:     Color(0xFFFAFAFC),
    bg2:     Color(0xFFE6E6EE),
    bg3:     Color(0xFFF2F2F6),
    card:    Color(0xFFFFFFFF),
    cardLo:  Color(0xFFF5F5F8),
    border:  Color(0xFFE5E7EB),
    ink:     Color(0xFF0D0D1A),
    inkSoft: Color(0xFF374151),
    slate:   Color(0xFF6B7280),
    slate2:  Color(0xFF9CA3AF),
    isDark:  false,
  );

  static const dark = _T(
    bg1:     Color(0xFF0D0D1A),
    bg2:     Color(0xFF161628),
    bg3:     Color(0xFF1E1E38),
    card:    Color(0xFF161628),
    cardLo:  Color(0xFF1E1E38),
    border:  Color(0xFF2A2A3F),
    ink:     Color(0xFFFFFFFF),
    inkSoft: Color(0xE6FFFFFF),
    slate:   Color(0xB3FFFFFF),
    slate2:  Color(0x80FFFFFF),
    isDark:  true,
  );
}

class _ThemeScope extends InheritedWidget {
  final _T theme;
  const _ThemeScope({required super.child, required this.theme});

  static _T of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeScope>()?.theme
      ?? _T.light;

  @override
  bool updateShouldNotify(_ThemeScope old) =>
      theme.isDark != old.theme.isDark;
}

// ═════════════════════════════════════════════════════════════
// ACCENTS
// ═════════════════════════════════════════════════════════════

const _kBlue     = Color(0xFF6DD5FA);
const _kPurple   = Color(0xFF7C3AED);
const _kAmber    = Color(0xFFF59E0B);
const _kCoral    = Color(0xFFFF4F6E);
const _kVerified = Color(0xFF1DA1F2);
const _kGreen    = Color(0xFF22C55E);

const _gradColors = <Color>[
  Color(0xFF6DD5FA), Color(0xFF7C3AED),
  Color(0xFFF59E0B), Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

const _kPrefDark = 'arcade_dark_mode';

// ═════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════

class ArcadeClubsScreen extends StatefulWidget {
  const ArcadeClubsScreen({super.key});
  @override
  State<ArcadeClubsScreen> createState() => _ArcadeClubsScreenState();
}

class _ArcadeClubsScreenState extends State<ArcadeClubsScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();

  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _fadeAnim;

  bool _isDark = false;

  bool _loadingClubs = true;
  bool _loadingHub   = false;

  List<Map<String, dynamic>> _myClubs       = [];
  List<Map<String, dynamic>> _gamingClubs   = [];
  List<Map<String, dynamic>> _trendingClubs = [];
  List<Map<String, dynamic>> _hubItems      = [];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _loadPrefs();
    _loadClubs();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Persistence (mirror Arcade dark-mode pref) ────────────

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _isDark = prefs.getBool(_kPrefDark) ?? false);
    } catch (_) {/* default light */}
  }

  // ── Data loading ──────────────────────────────────────────

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    setState(() => _loadingClubs = true);
    await _loadClubs();
  }

  Future<void> _loadClubs() async {
    try {
      final results = await Future.wait([
        _api.getClubs(filter: 'mine'),
        _api.getClubs(filter: 'all', category: 'gaming'),
        _api.getClubs(filter: 'all'),
      ]);
      if (!mounted) return;
      final mine   = _extractList(results[0]);
      final gaming = _extractList(results[1]);
      final all    = _extractList(results[2]);
      final gamingIds = gaming.map((c) => c['id']?.toString()).toSet();
      final trending  = all
          .where((c) => !gamingIds.contains(c['id']?.toString()))
          .take(5)
          .toList();
      setState(() {
        _myClubs       = mine;
        _gamingClubs   = gaming.take(8).toList();
        _trendingClubs = trending;
        _loadingClubs  = false;
      });
      _loadActivityHub();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClubs = false);
    }
  }

  Future<void> _loadActivityHub() async {
    if (_myClubs.isEmpty) {
      if (!mounted) return;
      setState(() { _hubItems = []; _loadingHub = false; });
      return;
    }
    setState(() => _loadingHub = true);
    try {
      final capped = _myClubs.take(5).toList();
      final feeds  = await Future.wait(
        capped.map((c) async {
          final id = c['id']?.toString();
          if (id == null || id.isEmpty) return <String, dynamic>{};
          try {
            return await _api.getClubFeed(id) as Map<String, dynamic>;
          } catch (_) { return <String, dynamic>{}; }
        }),
      );
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < capped.length; i++) {
        final club     = capped[i];
        final feed     = feeds[i];
        final clubName = club['name'] as String? ?? '';
        for (final p in (feed['posts'] as List? ?? [])) {
          final m = (p as Map).cast<String, dynamic>();
          items.add({...m, '_kind': 'post', '_club': club,
              '_club_name': clubName,
              '_sort_at': m['created_at']?.toString() ?? ''});
        }
        for (final e in (feed['events'] as List? ?? [])) {
          final m = (e as Map).cast<String, dynamic>();
          items.add({...m, '_kind': 'event', '_club': club,
              '_club_name': clubName,
              '_sort_at': m['start_time']?.toString() ?? ''});
        }
      }
      items.sort((a, b) =>
          (b['_sort_at'] as String).compareTo(a['_sort_at'] as String));
      if (!mounted) return;
      setState(() {
        _hubItems   = items.take(20).toList();
        _loadingHub = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHub = false);
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    return <Map<String, dynamic>>[];
  }

  // ── Navigation ────────────────────────────────────────────

  void _openClub(Map<String, dynamic> club) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ClubScreen(id: club['id']?.toString(), club: club)))
        .then((_) => _loadClubs());
  }

  void _openClubsList() {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ClubsListScreen()))
        .then((_) => _loadClubs());
  }

  Future<void> _openCreateClub() async {
    HapticFeedback.lightImpact();
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CreateClubPage()));
    if (created != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ClubScreen(id: created['id']?.toString(), club: created)));
      await _loadClubs();
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = _isDark ? _T.dark : _T.light;
    return _ThemeScope(
      theme: theme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [theme.bg1, theme.bg2, theme.bg3],
              stops: const [0.0, 0.55, 1.0]),
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: theme.ink,
              backgroundColor: theme.card,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  _buildAppBar(theme),
                  SliverToBoxAdapter(child: _buildHero(theme)),
                  SliverToBoxAdapter(child: _buildBody(theme)),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Compact pinned bar ────────────────────────────────────

  Widget _buildAppBar(_T t) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: t.bg1,
      surfaceTintColor: t.bg1,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Row(children: [
            _circleIconButton(
              t: t,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
            ),
            const SizedBox(width: 12),
            T('Clubs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: t.ink, letterSpacing: -0.3)),
            const Spacer(),
            _circleIconButton(
              t: t,
              icon: Icons.refresh_rounded,
              onTap: _refresh,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required _T t,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 14, borderWidth: 1.2,
        innerColor: t.card,
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: t.ink, size: 16),
      ),
    );
  }

  // ── Hero: headline + subtitle + primary actions ───────────

  Widget _buildHero(_T t) {
    final n = _myClubs.length;
    final sub = _loadingClubs
        ? 'Your communities and what is happening on campus.'
        : (n > 0
            ? 'You are in $n club${n == 1 ? "" : "s"}. Here is what is happening.'
            : 'Find your people. Join a club or start your own.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        T('CAMPUS COMMUNITIES',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900,
                letterSpacing: 2.0, color: t.slate2)),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: [_kPurple, _kCoral, _kAmber, _kBlue],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight).createShader(b),
          blendMode: BlendMode.srcIn,
          child: const T('Clubs',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                  letterSpacing: -1.2, height: 1.0, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(sub,
            style: TextStyle(fontSize: 13, color: t.slate, height: 1.45)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _heroAction(t,
              icon: Icons.explore_rounded, label: 'Discover',
              filled: false, onTap: _openClubsList)),
          const SizedBox(width: 12),
          Expanded(child: _heroAction(t,
              icon: Icons.add_rounded, label: 'Start a club',
              filled: true, onTap: _openCreateClub)),
        ]),
      ]),
    );
  }

  Widget _heroAction(_T t, {
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: filled ? t.ink : t.card,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: t.border),
          boxShadow: filled
              ? [BoxShadow(
                  color: t.ink.withOpacity(t.isDark ? 0.0 : 0.18),
                  blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          filled
              ? Icon(icon, size: 18, color: t.isDark ? t.bg1 : Colors.white)
              : ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                      colors: [_kPurple, _kBlue]).createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Icon(icon, size: 18, color: Colors.white)),
          const SizedBox(width: 8),
          Flexible(child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: filled ? (t.isDark ? t.bg1 : Colors.white) : t.ink))),
        ]),
      ),
    );
  }

  // ── Body sections ─────────────────────────────────────────

  Widget _buildBody(_T t) {
    if (_loadingClubs) return _buildSkeleton(t);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── My clubs ────────────────────────────────────────
      _sectionHeader(t, 'My clubs',
          count: _myClubs.isEmpty ? null : _myClubs.length,
          action: _myClubs.isNotEmpty ? 'See all' : null,
          onAction: _myClubs.isNotEmpty ? _openClubsList : null),
      if (_myClubs.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _emptyMyClubsCard(t))
      else
        SizedBox(height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _myClubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _MyClubCard(
              club: _myClubs[i], onTap: () => _openClub(_myClubs[i])),
          )),
      const SizedBox(height: 28),

      // ── Featured (gaming) ───────────────────────────────
      if (_gamingClubs.isNotEmpty) ...[
        _sectionHeader(t, 'Featured',
            icon: Icons.auto_awesome_rounded, accent: _kAmber),
        SizedBox(height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _gamingClubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _FeaturedClubCard(
              club: _gamingClubs[i],
              onTap: () => _openClub(_gamingClubs[i])),
          )),
        const SizedBox(height: 28),
      ],

      // ── Trending ────────────────────────────────────────
      if (_trendingClubs.isNotEmpty) ...[
        _sectionHeader(t, 'Trending now',
            icon: Icons.trending_up_rounded, accent: _kCoral),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            for (var i = 0; i < _trendingClubs.length; i++)
              Padding(padding: const EdgeInsets.only(bottom: 10),
                child: _TrendingRow(
                  rank: i + 1, club: _trendingClubs[i],
                  onTap: () => _openClub(_trendingClubs[i]))),
          ])),
        const SizedBox(height: 28),
      ],

      // ── Activity feed ───────────────────────────────────
      _sectionHeader(t, 'Activity',
          icon: Icons.bolt_rounded, accent: _kPurple,
          trailing: _loadingHub
              ? SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.ink))
              : null),
      if (_loadingHub && _hubItems.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerLoader(
                height: 70, borderRadius: BorderRadius.circular(16))))))
      else if (_hubItems.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _emptyHubCard(t))
      else
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            for (final it in _hubItems)
              Padding(padding: const EdgeInsets.only(bottom: 10),
                child: _ActivityRow(item: it, onTap: () {
                  final club = it['_club'] as Map<String, dynamic>?;
                  if (club != null) _openClub(club);
                })),
          ])),
    ]);
  }

  // ── Section header ────────────────────────────────────────

  Widget _sectionHeader(_T t, String title, {
    int? count,
    IconData? icon,
    Color? accent,
    String? action,
    VoidCallback? onAction,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: (accent ?? t.ink).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: accent ?? t.ink)),
          const SizedBox(width: 9),
        ],
        Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                color: t.ink, letterSpacing: -0.5)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.cardLo, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border)),
            child: Text('$count',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    color: t.slate, fontFamily: 'monospace'))),
        ],
        const Spacer(),
        if (trailing != null)
          trailing
        else if (action != null && onAction != null)
          GestureDetector(onTap: onAction,
            child: Row(children: [
              Text(action,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: t.inkSoft, letterSpacing: -0.1)),
              Icon(Icons.chevron_right_rounded, size: 16, color: t.inkSoft),
            ])),
      ]),
    );
  }

  // ── Empty states ──────────────────────────────────────────

  Widget _emptyMyClubsCard(_T t) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
    decoration: BoxDecoration(
      color: t.card, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: t.border)),
    child: Column(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _kPurple.withOpacity(0.16), _kBlue.withOpacity(0.16)]),
          borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.groups_rounded, color: _kPurple, size: 28)),
      const SizedBox(height: 14),
      T('No clubs yet', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w900,
          color: t.ink, letterSpacing: -0.3)),
      const SizedBox(height: 6),
      T('Join one from Trending below, or browse everything on campus.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: t.slate, height: 1.5)),
      const SizedBox(height: 16),
      GestureDetector(onTap: _openClubsList,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: t.ink, borderRadius: BorderRadius.circular(13)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.explore_rounded, size: 15,
                color: t.isDark ? t.bg1 : Colors.white),
            const SizedBox(width: 7),
            T('Discover clubs', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: t.isDark ? t.bg1 : Colors.white, letterSpacing: -0.2)),
          ]))),
    ]),
  );

  Widget _emptyHubCard(_T t) {
    final hasAnyClubs = _myClubs.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border)),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: _kPurple.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.bolt_rounded, color: _kPurple, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hasAnyClubs ? 'All quiet for now' : 'Nothing here yet',
              style: TextStyle(fontSize: 13.5,
                  fontWeight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 3),
          Text(
            hasAnyClubs
                ? 'Posts and events from your clubs will appear here.'
                : 'Join clubs to see their posts and events stream in.',
            style: TextStyle(fontSize: 11.5, color: t.slate, height: 1.5)),
        ])),
      ]),
    );
  }

  // ── Loading skeleton ──────────────────────────────────────

  Widget _buildSkeleton(_T t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShimmerLoader(width: 110, height: 18,
            borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 16),
        SizedBox(height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => ShimmerLoader(
                width: 128, height: 140,
                borderRadius: BorderRadius.circular(18)),
          )),
        const SizedBox(height: 28),
        ShimmerLoader(width: 130, height: 18,
            borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 16),
        ShimmerLoader(width: double.infinity, height: 188,
            borderRadius: BorderRadius.circular(20)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard
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
    this.innerColor = Colors.white,
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
        final v = animation.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
              colors: colors, startAngle: v, endAngle: v + 2 * math.pi),
          ),
          padding: EdgeInsets.all(borderWidth),
          child: c,
        );
      },
      child: inner,
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Shared helpers
// ═════════════════════════════════════════════════════════════

Widget _logoFallback(String initial, {double fontSize = 16}) => Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_kPurple, _kBlue])),
      child: Center(child: Text(initial, style: TextStyle(
          fontSize: fontSize, fontWeight: FontWeight.w800,
          color: Colors.white))));

Widget _clubLogo(String? url, String initial,
    {required double size, double radius = 12, double fontSize = 16}) {
  final fallback = _logoFallback(initial, fontSize: fontSize);
  return SizedBox(
    width: size, height: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
              width: size, height: size,
              errorWidget: (_, __, ___) => fallback,
              placeholder: (_, __) => fallback)
          : fallback,
    ),
  );
}

// ═════════════════════════════════════════════════════════════
// _MyClubCard — legible rail card for the user's own clubs
// ═════════════════════════════════════════════════════════════

class _MyClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _MyClubCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final name        = club['name']          as String? ?? 'Club';
    final logoUrl     = club['logo_url']      as String?;
    final memberCount = club['members_count'] as int?    ?? 0;
    final isVerified  = club['is_verified']   as bool?   ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final membership =
        (club['membership'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isAdmin = membership['is_admin'] == true;

    return GestureDetector(onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: t.card, borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isAdmin ? _kPurple.withOpacity(0.40) : t.border,
              width: isAdmin ? 1.4 : 1)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isAdmin
                    ? const LinearGradient(colors: [_kPurple, _kBlue])
                    : null,
                color: isAdmin ? null : t.cardLo),
              child: ClipOval(
                child: _clubLogo(logoUrl, initial, size: 54,
                    radius: 27, fontSize: 20)),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w800, color: t.ink,
                      letterSpacing: -0.2))),
              if (isVerified) ...[
                const SizedBox(width: 3),
                const Icon(Icons.verified_rounded, color: _kVerified, size: 11),
              ],
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isAdmin
                    ? _kPurple.withOpacity(0.12)
                    : t.cardLo,
                borderRadius: BorderRadius.circular(20)),
              child: Text(
                  isAdmin ? 'ADMIN' : '$memberCount member${memberCount == 1 ? "" : "s"}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isAdmin ? _kPurple : t.slate,
                      letterSpacing: isAdmin ? 0.5 : 0)),
            ),
          ]),
      ));
  }
}

// ═════════════════════════════════════════════════════════════
// _FeaturedClubCard — premium cover-image card with overlay
// ═════════════════════════════════════════════════════════════

class _FeaturedClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _FeaturedClubCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final name        = club['name']           as String? ?? 'Club';
    final tagline     = club['tagline']        as String? ?? '';
    final coverUrl    = club['cover_url']      as String?;
    final logoUrl     = club['logo_url']       as String?;
    final memberCount = club['members_count']  as int?    ?? 0;
    final isVerified  = club['is_verified']    as bool?   ?? false;
    final membership =
        (club['membership'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isMember = membership['is_member'] == true;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    final cover = (coverUrl != null && coverUrl.isNotEmpty)
        ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _coverFallback(),
            placeholder: (_, __) => _coverFallback())
        : _coverFallback();

    return GestureDetector(onTap: onTap,
      child: SizedBox(
        width: 268, height: 196,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(fit: StackFit.expand, children: [
            cover,
            // legibility scrim
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x14000000), Color(0xE6000000)],
                stops: [0.0, 0.45, 1.0]))),
            // top badges
            Positioned(top: 12, left: 12, right: 12,
              child: Row(children: [
                _glassPill(
                    label: isMember ? 'JOINED' : 'GAMING',
                    color: isMember ? _kGreen : _kPurple),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_alt_rounded,
                        size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$memberCount',
                        style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w800, color: Colors.white,
                            fontFamily: 'monospace')),
                  ])),
              ])),
            // bottom content
            Positioned(left: 14, right: 14, bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.85), width: 1.5)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9.5),
                        child: _clubLogo(logoUrl, initial,
                            size: 38, radius: 9.5, fontSize: 15)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Row(children: [
                      Flexible(child: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w900, color: Colors.white,
                              letterSpacing: -0.4))),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            color: Colors.white, size: 14),
                      ],
                    ])),
                  ]),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(tagline, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.35)),
                  ],
                ]),
            ),
          ]),
        ),
      ));
  }

  Widget _glassPill({required String label, required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.92),
      borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontSize: 8.5,
        fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6)));

  Widget _coverFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_kPurple, _kBlue],
              begin: Alignment.topLeft, end: Alignment.bottomRight)));
}

// ═════════════════════════════════════════════════════════════
// _TrendingRow — ranked discovery row
// ═════════════════════════════════════════════════════════════

class _TrendingRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _TrendingRow({required this.rank, required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final name        = club['name']           as String? ?? 'Club';
    final tagline     = club['tagline']        as String? ?? '';
    final category    = club['category']       as String? ?? '';
    final logoUrl     = club['logo_url']       as String?;
    final memberCount = club['members_count']  as int?    ?? 0;
    final isVerified  = club['is_verified']    as bool?   ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    final membership =
        (club['membership'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isMember  = membership['is_member']  == true;
    final isPending = membership['is_pending'] == true;

    return GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: t.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 22,
            child: Text('$rank', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                    color: t.slate2, fontFamily: 'monospace'))),
          const SizedBox(width: 8),
          _clubLogo(logoUrl, initial, size: 50, radius: 13, fontSize: 19),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Flexible(child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: t.ink, letterSpacing: -0.3))),
                if (isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, color: _kVerified, size: 12),
                ],
              ]),
              const SizedBox(height: 2),
              Text(_meta(memberCount, category),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: t.slate)),
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(tagline, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11,
                        color: t.inkSoft, height: 1.3)),
              ],
            ])),
          const SizedBox(width: 10),
          _stateBadge(t: t, isMember: isMember, isPending: isPending),
        ]),
      ));
  }

  Widget _stateBadge({required _T t, required bool isMember, required bool isPending}) {
    String label; Color bg, fg;
    if (isMember) {
      label = 'JOINED';
      bg = _kGreen.withOpacity(0.12);
      fg = t.isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    } else if (isPending) {
      label = 'PENDING'; bg = _kAmber.withOpacity(0.12); fg = _kAmber;
    } else {
      label = 'VIEW'; bg = _kPurple.withOpacity(0.10); fg = _kPurple;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 9,
          fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.5)));
  }

  String _meta(int memberCount, String category) {
    final parts = <String>[];
    parts.add('$memberCount member${memberCount == 1 ? "" : "s"}');
    if (category.isNotEmpty) parts.add(_titleCase(category));
    return parts.join(' · ');
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}

// ═════════════════════════════════════════════════════════════
// _ActivityRow — feed row showing the club logo + post/event
// ═════════════════════════════════════════════════════════════

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _ActivityRow({required this.item, required this.onTap});

  bool   get _isEvent  => item['_kind'] == 'event';
  String get _clubName => item['_club_name'] as String? ?? '';

  String get _title {
    if (_isEvent) return item['title'] as String? ?? 'Event';
    final content = item['content'] as String? ?? '';
    return content.isNotEmpty ? content : 'New post';
  }

  String get _whenLabel {
    final raw = (item['_sort_at'] as String?) ?? '';
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      if (_isEvent) {
        const months = ['Jan','Feb','Mar','Apr','May','Jun',
                        'Jul','Aug','Sep','Oct','Nov','Dec'];
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '${dt.day} ${months[dt.month - 1]} · $hh:$mm';
      }
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 7)  return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final tint = _isEvent ? _kAmber : _kPurple;
    final kindIcon = _isEvent
        ? Icons.event_rounded
        : Icons.chat_bubble_rounded;
    final tag = _isEvent ? 'EVENT' : 'POST';
    final club = (item['_club'] as Map?)?.cast<String, dynamic>() ?? const {};
    final logoUrl = club['logo_url'] as String?;
    final initial = _clubName.isNotEmpty ? _clubName[0].toUpperCase() : 'C';
    final when = _whenLabel;

    return GestureDetector(onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // colored kind accent bar
            Container(width: 4, color: tint),
            Expanded(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // club logo with kind badge
                  Stack(clipBehavior: Clip.none, children: [
                    _clubLogo(logoUrl, initial, size: 40, radius: 12, fontSize: 15),
                    Positioned(bottom: -3, right: -3, child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: tint, shape: BoxShape.circle,
                        border: Border.all(color: t.card, width: 2)),
                      child: Icon(kindIcon, size: 9, color: Colors.white))),
                  ]),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Expanded(child: Text(_clubName,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w800, color: t.ink,
                                letterSpacing: -0.2))),
                        if (when.isNotEmpty)
                          Text(when, style: TextStyle(
                              fontSize: 10, color: t.slate2,
                              fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      Text(_title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5,
                              color: t.inkSoft, height: 1.4)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: tint.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(tag, style: TextStyle(fontSize: 8,
                            fontWeight: FontWeight.w900, color: tint,
                            letterSpacing: 0.5))),
                    ])),
                ]),
            )),
          ]),
        ),
      ));
  }
}