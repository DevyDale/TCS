// lib/screens/arcade/arcade_screen.dart
// ignore_for_file: unused_local_variable
//
// Arcade — preset-avatar edition. GAMES ONLY.
//
// All club-related features (gaming clubs, my clubs, trending, the club
// activity hub) have been moved to arcade_clubs_screen.dart. The Arcade now
// has three tabs — Games, Ranks, Stats — and a Clubs button in the header
// that opens the dedicated Clubs page.
//
// Avatar system uses the shared kAvatars list (100 presets) from
// data/avators.dart, rendered via AvatarView.preset(). _avatarId is int?.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/avator/avator_view.dart';
import 'package:tcs_app/data/avators.dart';
import 'package:tcs_app/screens/arcade/aracade_clubs.dart';

import '../../services/api_service.dart';

import 'arcade_Effects.dart';
import 'campus_Craft_game.dart';
import 'memory_rush_game.dart';
import 'player_tag_screen.dart';
import 'quiz_battle_game.dart';
import 'spirit_racers_game.dart';
import 'ninja_tag_game.dart';
import 'sushi_rush_game.dart';
import 'battle_bots_game.dart';
import 'pool_royale_game.dart';
import 'snake_game.dart';
import 'number_guesser_game.dart';
import 'texas_poker_game.dart';
import 'game_engine.dart';
import 'tic_Tac_toe.dart';

import 'game_requests_screen.dart';
import 'live_matches_screen.dart';
import 'sent_invites_screen.dart';
import 'transfer_token_screen.dart';

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

const _gradColors = <Color>[
  Color(0xFF6DD5FA), Color(0xFF7C3AED),
  Color(0xFFF59E0B), Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

// ═════════════════════════════════════════════════════════════
// GAME REGISTRY
// ═════════════════════════════════════════════════════════════

final _playableGames = {
  'quiz-battle':     (BuildContext ctx) => const QuizBattleGame(),
  'spirit-racers':   (BuildContext ctx) => const SpiritRacersGame(),
  'ninja-tag':       (BuildContext ctx) => const NinjaTagGame(),
  'sushi-rush':      (BuildContext ctx) => const SushiRushGame(),
  'battle-bots':     (BuildContext ctx) => const BattleBotsGame(),
  'pool-royale':     (BuildContext ctx) => const PoolRoyaleGame(),
  'snake':           (BuildContext ctx) => const SnakeGame(),
  'memory-match':    (BuildContext ctx) => const MemoryMatchGame(),
  'number-guesser':  (BuildContext ctx) => const NumberGuesserGame(),
  'tic-tac-toe':     (BuildContext ctx) => const TicTacToeGame(),
  'campus-craft':    (BuildContext ctx) => const CampusCraftGame(),
  'texas-poker':     (BuildContext ctx) => const TexasPokerGame(),
};

const _gameEmoji = {
  'quiz-battle': '🧠', 'tic-tac-toe': '⭕', 'memory-match': '🃏',
  'snake': '🐍', 'number-guesser': '🔢', 'campus-craft': '🏗️',
  'ninja-tag': '🥷', 'sushi-rush': '🍣', 'battle-bots': '🤖',
  'spirit-racers': '🏎️', 'pool-royale': '🎱',
  'texas-poker': '🃏', 'basketball': '🏀',
};

const _catGradients = {
  'trivia':     [Color(0xFF8E54E9), Color(0xFF6B2FD9)],
  'puzzle':     [Color(0xFF6DD5FA), Color(0xFF2575FC)],
  'strategy':   [Color(0xFF4CAF50), Color(0xFF2E7D32)],
  'action':     [Color(0xFFFF5858), Color(0xFFFF6B6B)],
  'racing':     [Color(0xFF6DD5FA), Color(0xFF00B4DB)],
  'coop':       [Color(0xFFF7971E), Color(0xFFFF5858)],
  'sports':     [Color(0xFFCE93D8), Color(0xFF7B1FA2)],
  'multiplayer':[Color(0xFF42A5F5), Color(0xFF1976D2)],
};

List<Color> _gradientFor(String cat) =>
    _catGradients[cat.toLowerCase()] ??
    [const Color(0xFF6DD5FA), const Color(0xFF8E54E9)];

const _kPrefDark   = 'arcade_dark_mode';
const _kPrefAvatar = 'arcade_avatar_id_v2'; // bumped: now int (kAvatars index)

// ═════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});
  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _fadeAnim;

  bool _loadingGames  = true;
  bool _loadingStats  = true;
  bool _loadingLb     = true;

  int _pendingRequests = 0;

  Map<String, dynamic>       _stats       = {};
  List<Map<String, dynamic>> _games       = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _topGamers   = [];

  // Theme + avatar (persisted)
  bool _isDark   = false;
  int? _avatarId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _tabCtrl.addListener(() => setState(() {}));
    _loadPrefs();
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ───────────────────────────────────────────

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _isDark   = prefs.getBool(_kPrefDark) ?? false;
        _avatarId = prefs.getInt(_kPrefAvatar);
      });
    } catch (_) {/* defaults are fine */}
  }

  Future<void> _toggleTheme() async {
    HapticFeedback.lightImpact();
    setState(() => _isDark = !_isDark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefDark, _isDark);
    } catch (_) {}
  }

  Future<void> _saveAvatar(int id) async {
    setState(() => _avatarId = id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefAvatar, id);
    } catch (_) {}
  }

  // ── Data loading ──────────────────────────────────────────

  Future<void> _loadAll() => Future.wait([
        _loadStats(),
        _loadGames(),
        _loadLeaderboard(),
        _loadPendingRequests(),
      ]);

  void _refreshAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _loadingStats = true;
      _loadingGames = true;
      _loadingLb    = true;
    });
    _loadAll();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _api.getPlayerStats() as Map<String, dynamic>;
      if (!mounted) return;
      setState(() { _stats = data; _loadingStats = false; });
      if ((data['gamer_tag'] as String? ?? '').isEmpty && mounted) {
        _promptPlayerTag();
      }
    } catch (_) { if (mounted) setState(() => _loadingStats = false); }
  }

  Future<void> _loadGames() async {
    try {
      final data = await _api.getGames() as List;
      if (!mounted) return;
      setState(() { _games = data.cast<Map<String, dynamic>>(); _loadingGames = false; });
    } catch (_) { if (mounted) setState(() => _loadingGames = false); }
  }

  Future<void> _loadLeaderboard() async {
    try {
      final data = await _api.getLeaderboard(limit: 15) as List;
      if (!mounted) return;
      setState(() {
        _leaderboard = data.cast<Map<String, dynamic>>();
        _topGamers   = data.take(10).cast<Map<String, dynamic>>().toList();
        _loadingLb   = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingLb = false); }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final data = await _api.getGameRequests() as List? ?? const [];
      if (!mounted) return;
      setState(() => _pendingRequests = data.length);
    } catch (_) {}
  }

  // ── Navigation ────────────────────────────────────────────

  Future<void> _promptPlayerTag() async {
    final tag = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const PlayerTagScreen()));
    if (tag != null && mounted) _loadStats();
  }

  Future<void> _pickAvatar() async {
    HapticFeedback.lightImpact();
    final newId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AvatarPickerSheet(currentId: _avatarId),
    );
    if (newId != null && newId != _avatarId) {
      await _saveAvatar(newId);
    }
  }

  void _launchGame(Map<String, dynamic> game) {
    final slug    = game['slug'] as String? ?? '';
    final builder = _playableGames[slug];
    HapticFeedback.heavyImpact();
    if (builder != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: builder))
          .then((_) => _loadAll());
    } else {
      _showComingSoon(game['name'] as String? ?? '');
    }
  }

  Future<void> _openChallenges() async {
    HapticFeedback.lightImpact();
    final tokens = _stats['tokens'] as int? ?? 0;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => GameRequestsScreen(myTokens: tokens)),
    );
    if (!mounted) return;
    await _loadAll();
    if (result != null && result['action'] == 'start_game') {
      final session = result['session'] as Map<String, dynamic>?;
      final slug    = session?['game_slug'] as String?;
      if (slug == null || !mounted) return;
      final game = _games.firstWhere(
        (g) => g['slug'] == slug,
        orElse: () => {
          'slug': slug,
          'name': session?['game_name'] as String? ?? slug,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        content: Text('⚔ Match starting · pot 🪙 ${session?['pot'] ?? 0}',
            style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
        duration: const Duration(seconds: 2),
      ));
      Future.delayed(const Duration(milliseconds: 250),
          () { if (mounted) _launchGame(game); });
    }
  }

  void _openSendTokens() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransferTokensScreen()),
    ).then((_) { if (mounted) _loadStats(); });
  }

  void _openLiveMatches() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LiveMatchesScreen()),
    );
  }

  void _openSentInvites() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SentInvitesScreen()),
    ).then((_) { if (mounted) _loadAll(); });
  }

  void _openClubs() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArcadeClubsScreen()),
    );
  }

  void _showComingSoon(String name) {
    final t = _isDark ? _T.dark : _T.light;
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎮', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w800, color: t.ink, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text('Coming soon!',
              style: TextStyle(fontSize: 13, color: t.slate)),
          const SizedBox(height: 20),
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                  color: t.ink, borderRadius: BorderRadius.circular(12)),
              child: Text('OK', style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.isDark ? t.bg1 : Colors.white,
                  fontSize: 13)))),
        ])),
    ));
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
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(theme),
                SliverToBoxAdapter(child: _buildIdentityCard(theme)),
                SliverToBoxAdapter(child: _buildQuickActions(theme)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    isDark: _isDark,
                    height: 60,
                    builder: (ctx) => _buildTabBar(theme),
                  ),
                ),
                SliverToBoxAdapter(child: _buildTabContent()),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────

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
            Expanded(child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [_kPurple, _kCoral, _kAmber, _kBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight).createShader(b),
              blendMode: BlendMode.srcIn,
              child: const Text('ARCADE',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                      letterSpacing: 3, color: Colors.white)))),
            _circleIconButton(
              t: t,
              icon: Icons.groups_rounded,
              onTap: _openClubs,
            ),
            const SizedBox(width: 8),
            _circleIconButton(
              t: t,
              icon: t.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              onTap: _toggleTheme,
            ),
            const SizedBox(width: 8),
            _circleIconButton(
              t: t,
              icon: Icons.refresh_rounded,
              onTap: _refreshAll,
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

  // ── Identity card ─────────────────────────────────────────

  Widget _buildIdentityCard(_T t) {
    final tag      = _stats['gamer_tag'] as String? ?? '';
    final level    = _stats['level']     as int?    ?? 1;
    final xp       = _stats['total_xp']  as int?    ?? 0;
    final tokens   = _stats['tokens']    as int?    ?? 0;
    final progress = (xp % 500) / 500.0;
    final xpToNext = 500 - (xp % 500);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 20, borderWidth: 1.4,
        innerColor: t.card,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: _loadingStats
          ? const _IdentitySkeleton()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Avatar — opens preset picker on tap
                GestureDetector(
                  onTap: _pickAvatar,
                  child: _avatarId != null
                      ? AvatarView.preset(_avatarId!, size: 52)
                      : Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_kPurple, _kBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [BoxShadow(
                                color: _kPurple.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3))],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 24),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(child: GestureDetector(
                  onTap: _promptPlayerTag,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tag.isNotEmpty ? '#$tag' : 'Set gamer tag',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: t.ink, letterSpacing: -0.4)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kPurple.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6)),
                          child: Text('LV.$level',
                              style: const TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _kPurple, letterSpacing: 0.5,
                                  fontFamily: 'monospace')),
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: Text('$xp XP total',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11,
                                color: t.slate))),
                      ]),
                    ]),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kAmber.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _kAmber.withOpacity(0.30))),
                  child: Row(children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    AnimatedCounter(
                      value: tokens,
                      style: TextStyle(
                          fontSize: 13, color: t.ink,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace')),
                  ])),
              ]),
              const SizedBox(height: 14),
              Stack(children: [
                Container(height: 6, decoration: BoxDecoration(
                    color: t.cardLo,
                    borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(height: 6, decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kBlue, _kPurple, _kCoral]),
                    borderRadius: BorderRadius.circular(4)))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w800, color: t.inkSoft,
                        fontFamily: 'monospace')),
                const SizedBox(width: 6),
                Text('· $xpToNext XP to Lv.${level + 1}',
                    style: TextStyle(fontSize: 10,
                        color: t.slate, fontWeight: FontWeight.w600)),
              ]),
            ]),
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────

  Widget _buildQuickActions(_T t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: SizedBox(
        height: 130,
        child: Row(children: [
          _quickAction(t: t, label: 'Challenges',
              icon: Icons.sports_esports_rounded,
              accent: _kPurple, badge: _pendingRequests, onTap: _openChallenges),
          const SizedBox(width: 10),
          _quickAction(t: t, label: 'Send 🪙', icon: Icons.send_rounded,
              accent: _kAmber, onTap: _openSendTokens),
          const SizedBox(width: 10),
          _quickAction(t: t, label: 'My Invites', icon: Icons.outbox_rounded,
              accent: _kBlue, onTap: _openSentInvites),
        ]),
      ),
    );
  }

  Widget _quickAction({
    required _T           t,
    required String       label,
    required IconData     icon,
    required Color        accent,
    required VoidCallback onTap,
    int                   badge = 0,
    bool                  pulse = false,
  }) {
    final pill = _GradientBorderCard(
      animation: _shimmerCtrl,
      radius: 18, borderWidth: 1.4,
      innerColor: t.card,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: pulse
                  ? Border.all(color: accent.withOpacity(0.5), width: 1.6)
                  : null,
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(height: 11),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: t.ink, letterSpacing: -0.2)),
        ],
      ),
    );

    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            pill,
            if (badge > 0)
              Positioned(top: -5, right: -5, child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                constraints: const BoxConstraints(minWidth: 22),
                decoration: BoxDecoration(
                  color: _kCoral,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.bg1, width: 2),
                  boxShadow: [BoxShadow(
                      color: _kCoral.withOpacity(0.4), blurRadius: 10)]),
                child: Center(child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.white,
                      fontSize: 10, fontFamily: 'monospace'))))),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────

  Widget _buildTabBar(_T t) {
    const labels = ['Games', 'Ranks', 'Stats'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.cardLo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: AnimatedBuilder(
          animation: _tabCtrl.animation!,
          builder: (_, __) {
            final pos = _tabCtrl.animation!.value.clamp(0.0, 2.0);
            return LayoutBuilder(builder: (_, c) {
              final segW = c.maxWidth / 3;
              return Stack(children: [
                Positioned(
                  left: pos * segW,
                  top: 0, bottom: 0, width: segW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.ink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(children: [
                  for (int i = 0; i < 3; i++)
                    Expanded(child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _tabCtrl.animateTo(i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                            color: Color.lerp(
                              t.slate,
                              t.isDark ? t.bg1 : Colors.white,
                              1.0 - (pos - i).abs().clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                      ),
                    )),
                ]),
              ]);
            });
          },
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(animation: _tabCtrl, builder: (_, __) {
      switch (_tabCtrl.index) {
        case 0:  return _buildGamesTab();
        case 1:  return _buildRanksTab();
        case 2:  return _buildStatsTab();
        default: return const SizedBox.shrink();
      }
    });
  }

  // ── Games tab ─────────────────────────────────────────────

  Widget _buildGamesTab() {
    final t = _ThemeScope.of(context);
    if (_loadingGames) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(t, 'Loading games…'),
          const SizedBox(height: 12),
          ...List.generate(2, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerLoader(
                height: 86, borderRadius: BorderRadius.circular(16)),
          )),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: List.generate(4, (_) => ShimmerLoader(
                borderRadius: BorderRadius.circular(18))),
          ),
        ]),
      );
    }

    final playable = _games.where((g) => _playableGames.containsKey(g['slug'])).toList();
    final featured = _games.where((g) => g['is_featured'] == true &&
        !_playableGames.containsKey(g['slug'])).toList();
    final hasAny   = playable.isNotEmpty || featured.isNotEmpty || _games.isNotEmpty;

    if (!hasAny) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Column(children: [
          Icon(Icons.videogame_asset_off_rounded, color: t.slate2, size: 40),
          const SizedBox(height: 12),
          Text('No games seeded yet',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: t.ink)),
          const SizedBox(height: 4),
          Text('Run python manage.py seed_games on the backend',
              style: TextStyle(fontSize: 11, color: t.slate)),
        ])),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (playable.isNotEmpty) ...[
          _sectionLabel(t, 'Playable Now'),
          const SizedBox(height: 12),
          ...playable.map((g) => _FeaturedTile(
              game: g, onTap: () => _launchGame(g),
              shimmer: _shimmerCtrl)),
          const SizedBox(height: 18),
        ],
        if (featured.isNotEmpty) ...[
          _sectionLabel(t, 'Featured'),
          const SizedBox(height: 12),
          ...featured.map((g) => _FeaturedTile(
              game: g, onTap: () => _launchGame(g))),
          const SizedBox(height: 18),
        ],
        _sectionLabel(t, 'All Games'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: _games.map((g) => _GameGridCard(
              game: g,
              isPlayable: _playableGames.containsKey(g['slug'] as String? ?? ''),
              onTap: () => _launchGame(g))).toList()),
      ]),
    );
  }

  // ── Ranks tab ─────────────────────────────────────────────

  Widget _buildRanksTab() {
    final t = _ThemeScope.of(context);
    if (_loadingLb) {
      return Padding(padding: const EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(
            color: t.ink, strokeWidth: 2.4)));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_topGamers.isNotEmpty) ...[
          _sectionLabel(t, 'Top Players'),
          const SizedBox(height: 12),
          SizedBox(height: 132,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _topGamers.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _GamerCard(
                  gamer: _topGamers[i],
                  rank: i + 1,
                  shimmer: _shimmerCtrl,
                ),
              ))),
          const SizedBox(height: 22),
        ],
        _sectionLabel(t, 'Global XP rankings'),
        const SizedBox(height: 14),
        if (_leaderboard.isEmpty)
          Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(
              'No rankings yet.\nPlay games to appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.slate2))))
        else
          ..._leaderboard.asMap().entries.map((e) {
            final i  = e.key;
            final r  = e.value;
            final rank  = r['rank'] as int? ?? i + 1;
            final name  = (r['gamer_tag'] as String?)?.isNotEmpty == true
                ? '#${r['gamer_tag']}' : r['display_name'] ?? 'Unknown';
            final pts   = r['score'] ?? 0;
            final level = r['level'] ?? 1;
            final isTop = rank <= 3;
            final medals = ['🥇','🥈','🥉'];

            final row = Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(14),
                border: isTop ? null : Border.all(color: t.border)),
              child: Row(children: [
                SizedBox(width: 32, child: Center(child: Text(
                    isTop ? medals[rank - 1] : '#$rank',
                    style: TextStyle(
                        fontSize: isTop ? 20 : 12,
                        fontWeight: FontWeight.w800,
                        color: isTop ? null : t.slate2)))),
                const SizedBox(width: 8),
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      _gradColors[i % 4], _gradColors[(i + 1) % 4]
                    ])),
                  child: Center(child: Text(
                      name.isNotEmpty
                          ? name[name.startsWith('#') ? 1 : 0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 14)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800,
                            color: t.ink, fontSize: 13, letterSpacing: -0.2)),
                    Text('Level $level', style: TextStyle(
                        fontSize: 11, color: t.slate)),
                  ])),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: t.ink.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$pts XP', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: t.ink, fontFamily: 'monospace'))),
              ]),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: isTop
                  ? _GradientBorderCard(
                      animation: _shimmerCtrl,
                      radius: 14, borderWidth: 1.4,
                      innerColor: t.card, child: row)
                  : row,
            );
          }),
      ]),
    );
  }

  // ── Stats tab ─────────────────────────────────────────────

  Widget _buildStatsTab() {
    final t = _ThemeScope.of(context);
    if (_loadingStats) {
      return Padding(padding: const EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(
            color: t.ink, strokeWidth: 2.4)));
    }

    final tag        = _stats['gamer_tag']   as String? ?? '';
    final level      = _stats['level']       as int?    ?? 1;
    final xp         = _stats['total_xp']    as int?    ?? 0;
    final tokens     = _stats['tokens']      as int?    ?? 0;
    final games      = _stats['total_games'] as int?    ?? 0;
    final wins       = _stats['total_wins']  as int?    ?? 0;
    final winRate    = (_stats['win_rate'] as num?)?.toDouble() ?? 0.0;
    final recent     = (_stats['recent']      as List? ?? []).cast<Map<String, dynamic>>();
    final bestScores = (_stats['best_scores'] as List? ?? []).cast<Map<String, dynamic>>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _StatCard(label: 'Games',  value: '$games',
              icon: Icons.sports_esports_rounded, accent: _kPurple),
          const SizedBox(width: 10),
          _StatCard(label: 'Wins',   value: '$wins',
              icon: Icons.emoji_events_rounded, accent: _kAmber),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _StatCard(label: 'Win rate', value: '${winRate.toStringAsFixed(0)}%',
              icon: Icons.percent_rounded, accent: _kBlue),
          const SizedBox(width: 10),
          _StatCard(label: 'Tokens', value: '$tokens',
              icon: Icons.monetization_on_rounded, accent: _kCoral),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _StatCard(label: 'Level', value: '$level',
              icon: Icons.military_tech_rounded, accent: const Color(0xFF7986CB)),
          const SizedBox(width: 10),
          _StatCard(label: 'Total XP', value: '$xp',
              icon: Icons.bolt_rounded, accent: _kPurple),
        ]),
        if (bestScores.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionLabel(t, 'Best scores'),
          const SizedBox(height: 12),
          ...bestScores.map((s) {
            final slug  = s['slug']  as String? ?? '';
            final emoji = _gameEmoji[slug] ?? '🎮';
            return Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border)),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(s['game'] as String? ?? '',
                    style: TextStyle(fontWeight: FontWeight.w800,
                        color: t.ink, fontSize: 13))),
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: t.ink.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${s['score']} pts', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: t.ink, fontFamily: 'monospace'))),
              ]));
          }),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionLabel(t, 'Recent games'),
          const SizedBox(height: 12),
          ...recent.map((r) {
            final slug  = r['game_slug'] as String? ?? '';
            final emoji = _gameEmoji[slug] ?? '🎮';
            final score = r['score'] as int? ?? 0;
            return Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.border)),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: t.cardLo, borderRadius: BorderRadius.circular(11)),
                  child: Center(child: Text(emoji,
                      style: const TextStyle(fontSize: 20)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['game'] as String? ?? '', style: TextStyle(
                      fontWeight: FontWeight.w800, color: t.ink, fontSize: 13)),
                  Text('$score pts', style: TextStyle(
                      fontSize: 11, color: t.slate)),
                ])),
                Text(_timeAgo(r['played_at'] as String? ?? ''),
                    style: TextStyle(fontSize: 10, color: t.slate2)),
              ]));
          }),
        ],
      ]),
    );
  }

  Widget _sectionLabel(_T t, String label) => Text(label,
      style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800,
          color: t.ink, letterSpacing: -0.4));

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}

// ═════════════════════════════════════════════════════════════
// Sticky tab bar delegate
// ═════════════════════════════════════════════════════════════

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;
  final double height;
  final bool   isDark;
  _StickyTabBarDelegate({
    required this.builder,
    required this.height,
    required this.isDark,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = _ThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(bottom: BorderSide(color: t.border, width: 0.5)),
      ),
      child: builder(context),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate old) =>
      old.height != height || old.isDark != isDark;
}

// ═════════════════════════════════════════════════════════════
// Identity skeleton
// ═════════════════════════════════════════════════════════════

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      ShimmerLoader(width: 52, height: 52,
          borderRadius: BorderRadius.circular(26)),
      const SizedBox(width: 14),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShimmerLoader(width: 130, height: 16,
            borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 6),
        ShimmerLoader(width: 80, height: 11,
            borderRadius: BorderRadius.circular(4)),
      ])),
      const SizedBox(width: 8),
      ShimmerLoader(width: 70, height: 32,
          borderRadius: BorderRadius.circular(11)),
    ]),
    const SizedBox(height: 14),
    ShimmerLoader(width: double.infinity, height: 6,
        borderRadius: BorderRadius.circular(4)),
    const SizedBox(height: 6),
    ShimmerLoader(width: 100, height: 10,
        borderRadius: BorderRadius.circular(4)),
  ]);
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
// Top players card
// ═════════════════════════════════════════════════════════════

class _GamerCard extends StatelessWidget {
  final Map<String, dynamic> gamer;
  final int rank;
  final Animation<double>? shimmer;

  const _GamerCard({required this.gamer, required this.rank, this.shimmer});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final name = (gamer['gamer_tag'] as String?)?.isNotEmpty == true
        ? '#${gamer['gamer_tag']}' : gamer['display_name'] ?? 'Player';
    final level = gamer['level'] as int? ?? 1;
    final medals = ['🥇', '🥈', '🥉'];
    final initial = name.isNotEmpty
        ? name[name.startsWith('#') ? 1 : 0].toUpperCase() : '?';

    final accent = [_kAmber, _kPurple, _kCoral, _kBlue][rank % 4];
    final isTop  = rank <= 3;

    final inner = Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: isTop ? null : Border.all(color: t.border)),
      child: Column(mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [accent.withOpacity(0.85), accent])),
            child: Center(child: Text(initial,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 15)))),
          const SizedBox(height: 7),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800,
                  color: t.ink, fontSize: 10, letterSpacing: -0.1)),
          Text('Lv.$level',
              style: TextStyle(fontSize: 9, color: accent,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (isTop)
            Text(medals[rank - 1], style: const TextStyle(fontSize: 14))
          else
            Text('#$rank', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 11, color: t.slate2)),
        ]),
    );

    if (isTop && shimmer != null) {
      return _GradientBorderCard(
        animation: shimmer!,
        radius: 14, borderWidth: 1.5,
        innerColor: t.card, child: inner);
    }
    return inner;
  }
}

// ═════════════════════════════════════════════════════════════
// _FeaturedTile / _GameGridCard / _StatCard
// ═════════════════════════════════════════════════════════════

class _FeaturedTile extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;
  final Animation<double>? shimmer;

  const _FeaturedTile({
    required this.game, required this.onTap, this.shimmer});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final slug     = game['slug']          as String? ?? '';
    final name     = game['name']          as String? ?? '';
    final desc     = game['description']   as String? ?? '';
    final cat      = game['category']      as String? ?? 'puzzle';
    final xp       = game['xp_reward']     as int?    ?? 0;
    final tokens   = game['token_reward']  as int?    ?? 0;
    final best     = game['my_best_score'] as int?;
    final emoji    = _gameEmoji[slug]      ?? '🎮';
    final grad     = _gradientFor(cat);
    final playable = _playableGames.containsKey(slug);

    final body = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: playable && shimmer == null
            ? Border.all(color: grad.first.withOpacity(0.35), width: 1.4)
            : (!playable ? Border.all(color: t.border) : null),
      ),
      child: Row(children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(13)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w900, color: t.ink,
                    letterSpacing: -0.3))),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: grad.first.withOpacity(0.15),
                borderRadius: BorderRadius.circular(5)),
              child: Text(cat.toUpperCase(),
                  style: TextStyle(fontSize: 8,
                      fontWeight: FontWeight.w800, color: grad.first,
                      letterSpacing: 0.3))),
            if (playable) ...[
              const SizedBox(width: 4),
              Container(padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5)),
                child: Text('LIVE', style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w800,
                    color: t.isDark
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF15803D),
                    letterSpacing: 0.3))),
            ],
          ]),
          const SizedBox(height: 3),
          if (desc.isNotEmpty)
            Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: t.slate)),
          const SizedBox(height: 6),
          Wrap(spacing: 10, children: [
            Text('⚡ $xp XP', style: const TextStyle(fontSize: 10,
                color: kXpColor, fontWeight: FontWeight.w700)),
            Text('🪙 $tokens', style: const TextStyle(fontSize: 10,
                color: kTokenColor, fontWeight: FontWeight.w700)),
            if (best != null)
              Text('Best $best', style: TextStyle(fontSize: 10,
                  color: t.slate2)),
          ]),
        ])),
        const SizedBox(width: 10),
        Container(padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10)),
          child: Text(playable ? 'Play' : 'Soon',
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: playable && shimmer != null
            ? _GradientBorderCard(
                animation: shimmer!,
                radius: 16, borderWidth: 1.4,
                innerColor: t.card, child: body)
            : body,
      ),
    );
  }
}

class _GameGridCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final bool isPlayable;
  final VoidCallback onTap;
  const _GameGridCard({required this.game, required this.isPlayable,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    final slug  = game['slug']      as String? ?? '';
    final name  = game['name']      as String? ?? '';
    final cat   = game['category']  as String? ?? '';
    final xp    = game['xp_reward'] as int?    ?? 0;
    final emoji = _gameEmoji[slug]  ?? '🎮';
    final grad  = _gradientFor(cat);

    return GestureDetector(onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isPlayable
              ? grad.first.withOpacity(0.30) : t.border)),
        child: Column(children: [
          Container(height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: grad,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17))),
            child: Stack(children: [
              Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
              if (isPlayable)
                Positioned(top: 8, right: 8, child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(5)),
                  child: const Text('LIVE',
                      style: TextStyle(fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D), letterSpacing: 0.3)))),
            ])),
          Expanded(child: Padding(padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: t.ink,
                      fontSize: 12, letterSpacing: -0.2)),
              Text(cat, style: TextStyle(fontSize: 9, color: grad.first,
                  fontWeight: FontWeight.w700)),
              const Spacer(),
              Row(children: [
                Text('⚡$xp', style: const TextStyle(fontSize: 10,
                    color: kXpColor, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad,
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(isPlayable ? 'Play' : 'Soon',
                      style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w800, color: Colors.white))),
              ]),
            ]))),
        ])));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accent;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = _ThemeScope.of(context);
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border)),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accent, size: 18)),
        const SizedBox(width: 10),
        Flexible(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900,
              color: t.ink, letterSpacing: -0.3)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: t.slate)),
        ])),
      ])));
  }
}

// ═════════════════════════════════════════════════════════════
// Avatar picker bottom sheet — uses kAvatars (100 presets)
// ═════════════════════════════════════════════════════════════

class _AvatarPickerSheet extends StatefulWidget {
  final int? currentId;
  const _AvatarPickerSheet({this.currentId});

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  int?   _selected;
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _selected = widget.currentId;
  }

  List<AvatarDef> get _filtered {
    if (_category == 'all') return kAvatars;
    return kAvatars.where((a) => a.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t        = _ThemeScope.of(context);
    final mq       = MediaQuery.of(context);
    final maxH     = mq.size.height * 0.85;
    final cats     = kAvatarCategoryLabels.keys.toList();
    final filtered = _filtered;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Choose your avatar',
                  style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900,
                    color: t.ink, letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick one — you can change it any time',
                  style: TextStyle(fontSize: 12, color: t.slate),
                ),
                const SizedBox(height: 16),
              ]),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c      = cats[i];
                  final active = c == _category;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _category = c);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? t.ink : t.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? Colors.transparent : t.border,
                        ),
                      ),
                      child: Text(
                        kAvatarCategoryLabels[c] ?? c,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: active
                              ? (t.isDark ? t.bg1 : Colors.white)
                              : t.ink,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a          = filtered[i];
                  final isSelected = a.id == _selected;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selected = a.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? t.ink : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: AvatarView.preset(a.id, size: 56),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 16, 20, mq.padding.bottom + 16,
              ),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: t.ink, letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _selected == null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop(_selected);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 50,
                      decoration: BoxDecoration(
                        color: _selected == null ? t.border : t.ink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _selected == null
                            ? 'Pick one above'
                            : 'Use this avatar',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: _selected == null
                              ? t.slate
                              : (t.isDark ? t.bg1 : Colors.white),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}