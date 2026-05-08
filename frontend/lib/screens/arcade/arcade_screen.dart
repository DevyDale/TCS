// lib/screens/arcade/arcade_screen.dart
// ignore_for_file: unused_local_variable
//
// Arcade — redesigned per master spec §11.
// "Arcade includes: Games · Clubs section · Club activities hub.
//  Not just entertainment — also community engagement."
//
// Tabs:  Games · Leaderboard · Clubs · My Stats
// Carousel:  Token Wallet · Gamer Card · Leaderboard · My Clubs
//
// ARCADE OVERHAUL (this revision): added a Quick Actions strip
// between the carousel and Top Players for entry points to the new
// flow — Challenges (incoming + new), Send Tokens, Live Matches,
// My Invites. Pending challenge count drives a badge on the
// Challenges card. Token Wallet carousel card now opens the
// transfer screen (which shows balance + history + send) instead
// of jumping to the Stats tab.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';



import '../../services/api_service.dart';

// ── Phase 1 visual layer ─────────────────────────────────────


// ── Existing playable games ──────────────────────────────────
import '../club_list.dart';
import '../club_screen.dart';
import '../create_club_page.dart';
import '_arcade_carousel_card.dart';
import 'animated_starfield.dart';
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

// ── Phase 4: newly built games ───────────────────────────────
import 'snake_game.dart';
import 'number_guesser_game.dart';

// ── Phase 4: existing-but-unwired games (already in your codebase) ──
import 'texas_poker_game.dart';

import 'game_engine.dart';
import 'tic_Tac_toe.dart';

// ── Arcade overhaul: token economy + multiplayer + spectator ─
import 'game_requests_screen.dart';
import 'live_matches_screen.dart';
import 'sent_invites_screen.dart';
import 'transfer_token_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _darkBg    = Color(0xFF0D0D1A);
const _darkCard  = Color(0xFF161628);
const _darkCard2 = Color(0xFF1E1E38);
const _kVerified = Color(0xFF1DA1F2);

final _playableGames = {
  // Existing 6
  'quiz-battle':    (BuildContext ctx) => const QuizBattleGame(),
  'spirit-racers':  (BuildContext ctx) => const SpiritRacersGame(),
  'ninja-tag':      (BuildContext ctx) => const NinjaTagGame(),
  'sushi-rush':     (BuildContext ctx) => const SushiRushGame(),
  'battle-bots':    (BuildContext ctx) => const BattleBotsGame(),
  'pool-royale':    (BuildContext ctx) => const PoolRoyaleGame(),
  // Phase 4 — newly built
  'snake':           (BuildContext ctx) => const SnakeGame(),
  'memory-match':    (BuildContext ctx) => const MemoryMatchGame(),
  'number-guesser':  (BuildContext ctx) => const NumberGuesserGame(),
  // Phase 4 — already-existing-but-wasn't-registered
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

// ─────────────────────────────────────────────────────────────
class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});
  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabCtrl;
  late final PageController _carouselCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;

  int  _carouselIndex = 0;
  bool _loadingGames  = true;
  bool _loadingStats  = true;
  bool _loadingLb     = true;
  bool _loadingClubs  = true;

  // Arcade overhaul: count of incoming pending challenges.
  // Drives a badge on the Quick Actions "Challenges" card.
  int _pendingRequests = 0;

  Map<String, dynamic>       _stats         = {};
  List<Map<String, dynamic>> _games         = [];
  List<Map<String, dynamic>> _leaderboard   = [];
  List<Map<String, dynamic>> _topGamers     = [];
  List<Map<String, dynamic>> _myClubs       = [];
  List<Map<String, dynamic>> _gamingClubs   = [];
  List<Map<String, dynamic>> _trendingClubs = [];

  // ── §11 — Club Activity Hub ───────────────────────────────
  // Aggregated stream of recent posts + upcoming events from every
  // club the user is a member of. Built by _loadActivityHub() which
  // fans out to /api/clubs/<id>/feed/ for each entry in _myClubs and
  // merges the results, sorted newest-first. Each item is tagged with
  // `_kind` ('post' | 'event'), `_club_name`, and `_club` (the club
  // map for navigation).
  List<Map<String, dynamic>> _hubItems = [];
  bool _loadingHub = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl      = TabController(length: 4, vsync: this);
    _carouselCtrl = PageController(viewportFraction: 0.88);
    _entryCtrl    = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    _fadeAnim     = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _tabCtrl.addListener(() => setState(() {}));
    _loadAll();
    _autoScroll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _carouselCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([
        _loadStats(),
        _loadGames(),
        _loadLeaderboard(),
        _loadClubs(),
        _loadPendingRequests(),
      ]);

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

  /// Arcade overhaul: poll incoming challenges so the badge stays
  /// fresh. Failure is silent — if the endpoint is unreachable we
  /// just don't show a badge.
  Future<void> _loadPendingRequests() async {
    try {
      final data = await _api.getGameRequests() as List? ?? const [];
      if (!mounted) return;
      setState(() => _pendingRequests = data.length);
    } catch (_) {/* non-fatal */}
  }

  /// Loads three slices of clubs in parallel:
  ///   • my clubs (joined)
  ///   • gaming-category clubs (featured prominently in arcade context)
  ///   • trending clubs (top by member count, excluding ones already shown)
  ///
  /// Once `_myClubs` is populated, we kick off the Club Activity Hub
  /// fan-out so it always reflects the latest membership.
  Future<void> _loadClubs() async {
    try {
      final results = await Future.wait([
        _api.getClubs(filter: 'mine'),
        _api.getClubs(filter: 'all', category: 'gaming'),
        _api.getClubs(filter: 'all'),
      ]);
      if (!mounted) return;

      final mine     = _extractList(results[0]);
      final gaming   = _extractList(results[1]);
      final all      = _extractList(results[2]);

      // Trending = top non-gaming clubs the user hasn't already joined.
      // We don't filter member-of since people might want to see they're
      // already in a hot club, but we deduplicate against gamingClubs.
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

      // §11 — refresh the hub now that we know the joined clubs.
      // Fire-and-forget; the hub manages its own loading flag.
      _loadActivityHub();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClubs = false);
    }
  }

  /// §11 — Club Activity Hub fan-out.
  ///
  /// For each club in `_myClubs` (capped at 5 to keep launch responsive),
  /// fetches GET /api/clubs/<id>/feed/ in parallel and merges the
  /// returned posts + events into a single timeline, newest-first.
  /// Each item is decorated with `_kind`, `_club_name`, and `_club` so
  /// the row renderer can show context and the tap handler can navigate.
  ///
  /// Failures are absorbed silently per-club: one broken feed shouldn't
  /// kill the whole hub. If the user hasn't joined any clubs, the empty
  /// state in `_buildClubsTab()` handles the messaging.
  Future<void> _loadActivityHub() async {
    if (_myClubs.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hubItems   = [];
        _loadingHub = false;
      });
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
          } catch (_) {
            return <String, dynamic>{};
          }
        }),
      );

      // Flatten into a single list with type tags + a sortable timestamp.
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < capped.length; i++) {
        final club     = capped[i];
        final feed     = feeds[i];
        final clubName = club['name'] as String? ?? '';

        for (final p in (feed['posts'] as List? ?? [])) {
          final m = (p as Map).cast<String, dynamic>();
          items.add({
            ...m,
            '_kind':      'post',
            '_club':      club,
            '_club_name': clubName,
            '_sort_at':   m['created_at']?.toString() ?? '',
          });
        }
        for (final e in (feed['events'] as List? ?? [])) {
          final m = (e as Map).cast<String, dynamic>();
          items.add({
            ...m,
            '_kind':      'event',
            '_club':      club,
            '_club_name': clubName,
            '_sort_at':   m['start_time']?.toString() ?? '',
          });
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

  void _autoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      if (!_carouselCtrl.hasClients) return mounted;
      _carouselIndex = (_carouselIndex + 1) % _carouselItems.length;
      try {
        await _carouselCtrl.animateToPage(_carouselIndex,
            duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      } catch (_) {}
      return mounted;
    });
  }

  Future<void> _promptPlayerTag() async {
    final tag = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const PlayerTagScreen()));
    if (tag != null && mounted) _loadStats();
  }

  void _launchGame(Map<String, dynamic> game) {
    final slug    = game['slug'] as String? ?? '';
    final builder = _playableGames[slug];
    HapticFeedback.heavyImpact();
    if (builder != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: builder))
          .then((_) => _loadAll());
    } else {
      _showComingSoon(game['name'] as String? ?? '');
    }
  }

  // ══════════════════════════════════════════════════════════
  // ARCADE OVERHAUL — navigation entry points
  // ══════════════════════════════════════════════════════════

  /// Open the challenges screen (Incoming + New tabs). If the user
  /// accepts a challenge, the screen pops with `start_game` + a
  /// session map — we then launch the corresponding game widget.
  ///
  /// Note: each game widget needs to be wired to accept the session
  /// for true PvP semantics (server-side win determination, wager
  /// settlement on finish). See SETUP.md §2.d for the patch on
  /// `game_engine.dart`. Until that's done we just launch the game
  /// solo and the player who scores higher in their separate runs
  /// wins on the server.
  Future<void> _openChallenges() async {
    HapticFeedback.lightImpact();
    final tokens = _stats['tokens'] as int? ?? 0;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => GameRequestsScreen(myTokens: tokens),
      ),
    );
    if (!mounted) return;
    // Reload — wager may have been escrowed on accept, refunded on
    // decline, or balance otherwise changed.
    await _loadAll();

    if (result != null && result['action'] == 'start_game') {
      final session = result['session'] as Map<String, dynamic>?;
      final slug    = session?['game_slug'] as String?;
      if (slug == null || !mounted) return;
      // Find the catalog entry for this game
      final game = _games.firstWhere(
        (g) => g['slug'] == slug,
        orElse: () => {
          'slug': slug,
          'name': session?['game_name'] as String? ?? slug,
        },
      );
      // Tiny notice so it doesn't feel sudden
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        content: Text('⚔ Match starting · pot 🪙 ${session?['pot'] ?? 0}',
            style: const TextStyle(fontFamily: 'Momo')),
        duration: const Duration(seconds: 2),
      ));
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _launchGame(game);
      });
    }
  }

  /// Peer-to-peer token transfer (TransferTokensScreen also doubles as
  /// a wallet detail view: balance + history).
  void _openSendTokens() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TransferTokensScreen()),
    ).then((_) {
      if (mounted) _loadStats();
    });
  }

  /// Browse currently-active matches and spectate.
  void _openLiveMatches() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LiveMatchesScreen()),
    );
  }

  /// View invites I've sent (cancel + refund pending ones).
  void _openSentInvites() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SentInvitesScreen()),
    ).then((_) {
      if (mounted) _loadAll();
    });
  }

  void _openClub(Map<String, dynamic> club) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                ClubScreen(id: club['id']?.toString(), club: club)))
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

  void _showComingSoon(String name) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: _darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(28), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎮', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Coming soon!', style: TextStyle(fontFamily: 'Momo',
              fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 20),
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG2, _kG1]),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('OK', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)))),
        ])),
    ));
  }

  // ── Carousel items — now 4 cards ─────────────────────────

  List<Map<String, dynamic>> get _carouselItems => [
    {
      'title': 'My Token Wallet', 'icon': Icons.account_balance_wallet_rounded,
      'gradient': const LinearGradient(colors: [_kG3, _kG4],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      'content': _loadingStats ? 'Loading...'
          : '🪙 ${_stats['tokens'] ?? 0} tokens  ·  ⚡ ${_stats['total_xp'] ?? 0} XP',
      'active': true,
    },
    {
      'title': 'My Gamer Card', 'icon': Icons.card_membership_rounded,
      'gradient': const LinearGradient(colors: [_kG2, _kG1],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      'content': _loadingStats ? 'Loading...'
          : 'Level ${_stats['level'] ?? 1}  ·  ${_stats['win_rate'] ?? 0}% win rate',
      'active': false,
    },
    {
      'title': 'Global Leaderboard', 'icon': Icons.emoji_events_rounded,
      'gradient': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      'content': _leaderboard.isNotEmpty
          ? '🥇 ${_leaderboard.first['gamer_tag']?.isNotEmpty == true
              ? _leaderboard.first['gamer_tag'] : _leaderboard.first['display_name']}'
          : 'Be the first on the leaderboard!',
      'active': false,
    },
    {
      'title': 'My Clubs', 'icon': Icons.groups_rounded,
      'gradient': const LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF512DA8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      'content': _loadingClubs
          ? 'Loading...'
          : _myClubs.isEmpty
              ? 'Join clubs to engage with campus communities'
              : '${_myClubs.length} club${_myClubs.length == 1 ? "" : "s"} joined  ·  Tap to explore',
      'active': false,
    },
  ];

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      // ── Phase 1: Stack the scrollable arcade over a twinkling starfield.
      // The stars sit behind everything and drift slowly. Performance cost
      // is near-zero (single CustomPaint with 200 cheap circles).
      body: Stack(children: [
        const Positioned.fill(
          child: AnimatedStarfield(starCount: 200, driftSpeed: 1.0),
        ),
        FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildCarousel()),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildActiveGamers()),
              SliverToBoxAdapter(child: _buildTabBar()),
              SliverToBoxAdapter(child: _buildTabContent()),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── AppBar ────────────────────────────────────────────────

  Widget _buildAppBar() {
    final tag    = _stats['gamer_tag'] as String? ?? '';
    final level  = _stats['level']    as int?    ?? 1;
    final tokens = _stats['tokens']   as int?    ?? 0;

    return SliverAppBar(
      pinned: true, backgroundColor: _darkBg, elevation: 0,
      expandedHeight: 130, automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: LinearGradient(
              colors: [_darkBg, _kG2.withOpacity(0.12)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70, size: 16))),
                const SizedBox(width: 8),
                GestureDetector(onTap: _promptPlayerTag,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _kG2.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kG2.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                            colors: [_kG1, _kG2]).createShader(b),
                        blendMode: BlendMode.srcIn,
                        child: Text(tag.isNotEmpty ? '#$tag' : '+ Set Tag',
                            style: const TextStyle(fontFamily: 'Alfa',
                                fontSize: 14, color: Colors.white))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _kG3.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('Lv.$level', style: const TextStyle(fontFamily: 'Momo',
                            fontSize: 10, fontWeight: FontWeight.bold, color: _kG3))),
                    ])),
                ),
                const Spacer(),
                // ── Phase 1: AnimatedCounter so tokens tick up after games ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: _kG3.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kG3.withOpacity(0.2))),
                  child: Row(children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    AnimatedCounter(
                      value: tokens,
                      style: const TextStyle(fontFamily: 'Alfa',
                          fontSize: 14, color: _kG3),
                    ),
                  ])),
                const SizedBox(width: 8),
                _iconBtn(Icons.refresh_rounded, () {
                  HapticFeedback.lightImpact(); _loadAll();
                }),
              ]),
              const SizedBox(height: 10),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                    colors: [_kG1, _kG2, _kG3, _kG4],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('ARCADE', style: TextStyle(fontFamily: 'Alfa',
                    fontSize: 30, color: Colors.white, letterSpacing: 4))),
              Text(
                  '${_games.length} games  ·  '
                  '${_gamingClubs.length + _trendingClubs.length + _myClubs.length} clubs  ·  '
                  '${_leaderboard.length} ranked',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                      color: Colors.white.withOpacity(0.4))),
            ]),
          )),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 38, height: 38,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Icon(icon, color: Colors.white60, size: 18)));

  // ── Carousel ──────────────────────────────────────────────

  Widget _buildCarousel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: _sectionLabel('Overview')),
      SizedBox(height: 140,
        child: PageView.builder(
          controller: _carouselCtrl,
          itemCount: _carouselItems.length,
          onPageChanged: (i) => setState(() => _carouselIndex = i),
          itemBuilder: (_, i) {
            final item = _carouselItems[i];
            return ArcadeCarouselCard(
              title:    item['title']    as String,
              icon:     item['icon']     as IconData,
              gradient: item['gradient'] as LinearGradient,
              content:  item['content']  as String,
              isActive: item['active']   == true,
              onTap: () {
                // Tab indices: Games=0, Leaderboard=1, Clubs=2, Stats=3
                if (i == 0) {
                  // Token Wallet → wallet detail / transfer screen.
                  // (TransferTokensScreen shows balance + history at the
                  // top, so it doubles as a wallet view.)
                  _openSendTokens();
                } else if (i == 1) {
                  _promptPlayerTag();      // Gamer Card → set/edit tag
                } else if (i == 2) {
                  _tabCtrl.animateTo(1);  // Leaderboard → Leaderboard tab
                } else if (i == 3) {
                  _tabCtrl.animateTo(2);  // My Clubs → Clubs tab
                }
              },
            );
          },
        )),
      const SizedBox(height: 8),
      Center(child: CarouselDotIndicator(
          count: _carouselItems.length, current: _carouselIndex,
          activeColor: _kG2)),
    ]);
  }

  // ── Quick Actions (arcade overhaul) ───────────────────────
  //
  // Four action cards that surface the new arcade flow:
  //   • Challenges   — incoming + new (badge = pending count)
  //   • Send Tokens  — peer-to-peer transfer
  //   • Live         — spectate active matches
  //   • My Invites   — sent invites (cancel + refund)
  //
  // Sits right under the carousel so it's the first interactive
  // surface after the user lands. Without it, the new screens
  // are invisible.

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Quick Actions'),
        const SizedBox(height: 12),
        Row(children: [
          _quickAction(
            label:    'Challenges',
            icon:     Icons.sports_esports_rounded,
            gradient: const [_kG2, _kG1],
            badge:    _pendingRequests,
            onTap:    _openChallenges,
          ),
          const SizedBox(width: 10),
          _quickAction(
            label:    'Send 🪙',
            icon:     Icons.send_rounded,
            gradient: const [_kG3, _kG4],
            onTap:    _openSendTokens,
          ),
          const SizedBox(width: 10),
          _quickAction(
            label:    'Live',
            icon:     Icons.visibility_rounded,
            gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            pulse:    true,
            onTap:    _openLiveMatches,
          ),
          const SizedBox(width: 10),
          _quickAction(
            label:    'My Invites',
            icon:     Icons.outbox_rounded,
            gradient: const [Color(0xFF3F51B5), Color(0xFF512DA8)],
            onTap:    _openSentInvites,
          ),
        ]),
      ]),
    );
  }

  Widget _quickAction({
    required String           label,
    required IconData         icon,
    required List<Color>      gradient,
    required VoidCallback     onTap,
    int                       badge = 0,
    bool                      pulse = false,
  }) {
    final pill = Container(
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gradient.first.withOpacity(0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: gradient.first.withOpacity(0.30),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(height: 6),
          Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily:    'Arch',
              fontWeight:    FontWeight.bold,
              color:         Colors.white,
              fontSize:      10.5,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          // Optional pulse glow for "Live"
          if (pulse)
            Positioned.fill(child: IgnorePointer(child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: gradient.first.withOpacity(0.18),
                    blurRadius: 18, spreadRadius: 1)],
              ),
            ))),
          pill,
          if (badge > 0)
            Positioned(top: -5, right: -5, child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: _kG4,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _darkBg, width: 2),
                boxShadow: [BoxShadow(
                    color: _kG4.withOpacity(0.45), blurRadius: 8)],
              ),
              child: Center(child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  fontFamily:    'Momo',
                  fontWeight:    FontWeight.bold,
                  color:         Colors.white,
                  fontSize:      9.5,
                ),
              )),
            )),
        ]),
      ),
    );
  }

  // ── Active Gamers ─────────────────────────────────────────

  Widget _buildActiveGamers() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(children: [
          _sectionLabel('Top Players'),
          const Spacer(),
          GestureDetector(onTap: () => _tabCtrl.animateTo(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG1, _kG2]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Leaderboard →',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                      color: Colors.white, fontWeight: FontWeight.bold)))),
        ])),
      _loadingLb
          ? SizedBox(height: 134,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ShimmerLoader(
                    width: 100,
                    height: 134,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ))
          : SizedBox(height: 134,
              child: _topGamers.isEmpty
                  ? Center(child: Text('No players yet',
                      style: TextStyle(fontFamily: 'Momo', color: Colors.white38)))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _topGamers.length,
                      itemBuilder: (_, i) => _GamerCard(
                          gamer: _topGamers[i], rank: i + 1))),
    ]);
  }

  // ── Tab bar — now 4 tabs ──────────────────────────────────

  Widget _buildTabBar() {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SegmentedTabControl(
        controller: _tabCtrl,
        barDecoration: BoxDecoration(color: _darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06))),
        indicatorDecoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kG2, _kG1],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(10)),
        tabTextColor: Colors.white38,
        selectedTabTextColor: Colors.white,
        tabs: const [
          SegmentTab(label: 'Games'),
          SegmentTab(label: 'Ranks'),
          SegmentTab(label: 'Clubs'),
          SegmentTab(label: 'Stats'),
        ],
      ));
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(animation: _tabCtrl, builder: (_, __) {
      switch (_tabCtrl.index) {
        case 0:  return _buildGamesTab();
        case 1:  return _buildLeaderboardTab();
        case 2:  return _buildClubsTab();
        case 3:  return _buildStatsTab();
        default: return const SizedBox.shrink();
      }
    });
  }

  // ── Games Tab ─────────────────────────────────────────────

  Widget _buildGamesTab() {
    if (_loadingGames) {
      // ── Phase 1: shimmer skeletons matching the actual content shape ──
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('🎮 Loading games...'),
          const SizedBox(height: 12),
          // Featured-tile-shaped skeletons
          ...List.generate(2, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerLoader(
              height: 90,
              borderRadius: BorderRadius.circular(16),
            ),
          )),
          const SizedBox(height: 16),
          // Grid skeletons
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: List.generate(4, (_) => ShimmerLoader(
              borderRadius: BorderRadius.circular(18),
            )),
          ),
        ]),
      );
    }

    final playable = _games.where((g) =>  _playableGames.containsKey(g['slug'])).toList();
    final featured = _games.where((g) =>  g['is_featured'] == true &&
        !_playableGames.containsKey(g['slug'])).toList();

    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (playable.isNotEmpty) ...[
          _sectionLabel('🎮 Playable Now'), const SizedBox(height: 12),
          ...playable.map((g) => _FeaturedTile(game: g, onTap: () => _launchGame(g))),
          const SizedBox(height: 20),
        ],
        if (featured.isNotEmpty) ...[
          _sectionLabel('⭐ Featured'), const SizedBox(height: 12),
          ...featured.map((g) => _FeaturedTile(game: g, onTap: () => _launchGame(g))),
          const SizedBox(height: 20),
        ],
        _sectionLabel('All Games'), const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: _games.map((g) => _GameGridCard(
            game: g,
            isPlayable: _playableGames.containsKey(g['slug'] as String? ?? ''),
            onTap: () => _launchGame(g))).toList()),
      ]));
  }

  // ── Leaderboard Tab ───────────────────────────────────────

  Widget _buildLeaderboardTab() {
    if (_loadingLb) {
      return const Padding(padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _kG2)));
    }

    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        _sectionLabel('🌍 Global XP Rankings'), const SizedBox(height: 16),
        if (_leaderboard.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40),
            child: Text('No rankings yet!\nPlay games to appear here!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                    color: Colors.white.withOpacity(0.4)))))
        else
          ..._leaderboard.asMap().entries.map((e) {
            final i     = e.key;
            final r     = e.value;
            final rank  = r['rank'] as int? ?? i + 1;
            final name  = (r['gamer_tag'] as String?)?.isNotEmpty == true
                ? '#${r['gamer_tag']}' : r['display_name'] ?? 'Unknown';
            final pts   = r['score'] ?? 0;
            final level = r['level'] ?? 1;
            final isTop = rank <= 3;
            final medals= ['🥇','🥈','🥉'];
            final grad  = [_kG1, _kG2, _kG3, _kG4];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isTop ? _kG2.withOpacity(0.06) : _darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isTop
                    ? _kG2.withOpacity(0.2) : Colors.white.withOpacity(0.05))),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: isTop ? Colors.transparent : Colors.white.withOpacity(0.04)),
                  child: Center(child: Text(isTop ? medals[rank - 1] : '#$rank',
                      style: TextStyle(fontFamily: 'Alfa',
                          fontSize: isTop ? 20 : 12,
                          color: isTop ? null : Colors.white38)))),
                const SizedBox(width: 10),
                Container(width: 38, height: 38,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [grad[i % 4], grad[(i + 1) % 4]]),
                      shape: BoxShape.circle),
                  child: Center(child: Text(
                      name.isNotEmpty
                          ? name[name.startsWith('#') ? 1 : 0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Level $level', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 11, color: Colors.white38)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _kG2.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$pts XP', style: const TextStyle(fontFamily: 'Momo',
                      fontSize: 11, fontWeight: FontWeight.bold, color: _kG1))),
              ]),
            );
          }),
      ]));
  }

  // ── Clubs Tab — NEW per spec §11 ──────────────────────────

  Widget _buildClubsTab() {
    if (_loadingClubs) {
      return const Padding(padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _kG2)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── GAMING CLUBS — featured first because this is the arcade ──
        if (_gamingClubs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _sectionLabel('🎮 Gaming Clubs'),
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _gamingClubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _BigClubCard(
                club: _gamingClubs[i],
                onTap: () => _openClub(_gamingClubs[i]),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── MY CLUBS — horizontal logo strip ────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            _sectionLabel('My Clubs'),
            const Spacer(),
            if (_myClubs.isNotEmpty)
              GestureDetector(onTap: _openClubsList,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF3F51B5), Color(0xFF512DA8)]),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('See all →',
                      style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                          color: Colors.white, fontWeight: FontWeight.bold)))),
          ]),
        ),
        if (_myClubs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _emptyMyClubsCard(),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _myClubs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SmallClubCard(
                club: _myClubs[i],
                onTap: () => _openClub(_myClubs[i]),
              ),
            ),
          ),
        const SizedBox(height: 24),

        // ── TRENDING CLUBS — vertical list with cover banners ──
        if (_trendingClubs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _sectionLabel('🔥 Trending'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: _trendingClubs
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TrendingClubCard(
                        club: c,
                        onTap: () => _openClub(c),
                      ),
                    ))
                .toList()),
          ),
          const SizedBox(height: 24),
        ],

        // ── ACTION BUTTONS ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _openClubsList,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore_rounded,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text('Browse All',
                          style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _openCreateClub,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3F51B5), Color(0xFF512DA8)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3F51B5).withOpacity(0.40),
                        blurRadius: 10, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Start a Club',
                          style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ══════════════════════════════════════════════════════
        // §11 — CLUB ACTIVITY HUB (live)
        //
        // Replaces the old "lands here soon" placeholder. Shows a
        // newest-first stream of posts + events from every joined
        // club. Header always visible (with a tiny spinner while
        // loading); body is either an empty card or a list of rows.
        // ══════════════════════════════════════════════════════
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            const Icon(Icons.dynamic_feed_rounded, color: _kG2, size: 16),
            const SizedBox(width: 8),
            _sectionLabel('Club Activity Hub'),
            const Spacer(),
            if (_loadingHub)
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kG2)),
          ]),
        ),

        if (!_loadingHub && _hubItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _emptyHubCard(),
          ),

        if (!_loadingHub && _hubItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _hubItems
                  .map((it) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HubItemRow(
                          item: it,
                          onTap: () {
                            final club =
                                it['_club'] as Map<String, dynamic>?;
                            if (club != null) _openClub(club);
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),

        // While the hub is initially loading and we haven't shown
        // anything yet, render a couple of shimmer rows so the area
        // doesn't collapse to 0px and jump when content arrives.
        if (_loadingHub && _hubItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ShimmerLoader(
                height: 64,
                borderRadius: BorderRadius.circular(14),
              ),
            ))),
          ),

        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _emptyMyClubsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF3F51B5).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.groups_outlined,
              color: Color(0xFF7986CB), size: 24),
        ),
        const SizedBox(height: 10),
        const Text('No clubs joined yet',
            style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            )),
        const SizedBox(height: 4),
        Text('Join clubs from the Trending list above\nto get involved with campus communities.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 11,
              color: Colors.white.withOpacity(0.45),
              height: 1.5,
            )),
      ]),
    );
  }

  /// §11 — empty card for the Club Activity Hub.
  /// Copy adapts to whether the user has joined any clubs at all:
  /// before joining, "join to see activity"; after joining, "be the
  /// first to post or schedule an event".
  Widget _emptyHubCard() {
    final hasAnyClubs = _myClubs.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kG2.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kG2.withOpacity(0.18)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _kG2.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.dynamic_feed_rounded,
              color: _kG2, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nothing yet',
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  )),
              const SizedBox(height: 3),
              Text(
                hasAnyClubs
                    ? 'Posts and events from your clubs\nwill stream here as they happen.'
                    : 'Join clubs to see their posts and\nevents stream in here.',
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.55),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Stats Tab ─────────────────────────────────────────────

  Widget _buildStatsTab() {
    if (_loadingStats) {
      return const Padding(padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _kG2)));
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
    final xpToNext   = 500 - (xp % 500);
    final clubCount  = _myClubs.length;

    return Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Identity card
        GestureDetector(onTap: _promptPlayerTag,
          child: Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_darkCard2, Color(0xFF252545)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kG2.withOpacity(0.2))),
            child: Row(children: [
              Container(width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG2, _kG1]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _kG2.withOpacity(0.4), blurRadius: 16)]),
                child: Center(child: Text(tag.isNotEmpty ? tag[0].toUpperCase() : '?',
                    style: const TextStyle(fontFamily: 'Alfa',
                        fontSize: 28, color: Colors.white)))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                      colors: [_kG1, _kG2]).createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Text(tag.isNotEmpty ? '#$tag' : 'Set Your Tag',
                      style: const TextStyle(fontFamily: 'Alfa',
                          fontSize: 18, color: Colors.white))),
                Text('Level $level  ·  $xp XP total',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: (xp % 500) / 500,
                      minHeight: 5, backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(_kG1))),
                const SizedBox(height: 3),
                Text('$xpToNext XP to Level ${level + 1}',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: Colors.white38)),
              ])),
              const Icon(Icons.edit_rounded, color: Colors.white30, size: 16),
            ])),
        ),
        const SizedBox(height: 16),

        // Stat grid — now 6 cells (added Clubs)
        Row(children: [
          _StatCard(label: 'Games',   value: '$games', icon: Icons.sports_esports_rounded, color: _kG2),
          const SizedBox(width: 12),
          _StatCard(label: 'Wins',    value: '$wins',  icon: Icons.emoji_events_rounded,   color: _kG3),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard(label: 'Win Rate', value: '${winRate.toStringAsFixed(0)}%',
              icon: Icons.percent_rounded, color: _kG1),
          const SizedBox(width: 12),
          _StatCard(label: 'Tokens 🪙', value: '$tokens',
              icon: Icons.monetization_on_rounded, color: _kG4),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatCard(label: 'Clubs Joined', value: '$clubCount',
              icon: Icons.groups_rounded, color: const Color(0xFF7986CB)),
          const SizedBox(width: 12),
          _StatCard(label: 'Total XP', value: '$xp',
              icon: Icons.bolt_rounded, color: _kG2),
        ]),

        // Best scores
        if (bestScores.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel('🏆 Best Scores'),
          const SizedBox(height: 12),
          ...bestScores.map((s) {
            final slug  = s['slug']  as String? ?? '';
            final emoji = _gameEmoji[slug] ?? '🎮';
            return Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: _darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05))),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text(s['game'] as String? ?? '',
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _kG2.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${s['score']} pts', style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 12,
                      fontWeight: FontWeight.bold, color: _kG1))),
              ]));
          }),
        ],

        // Recent games
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel('Recent Games'),
          const SizedBox(height: 12),
          ...recent.map((r) {
            final slug  = r['game_slug'] as String? ?? '';
            final emoji = _gameEmoji[slug] ?? '🎮';
            final score = r['score'] as int? ?? 0;
            return Container(margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05))),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: _kG2.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['game'] as String? ?? '', style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                  Text('$score pts', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 11, color: Colors.white38)),
                ])),
                Text(_timeAgo(r['played_at'] as String? ?? ''),
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: Colors.white38)),
              ]));
          }),
        ],
      ]));
  }

  Widget _sectionLabel(String label) => Text(label, style: TextStyle(
      fontFamily: 'Alfa', fontSize: 16, color: Colors.white.withOpacity(0.85)));

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}

// ─────────────────────────────────────────────────────────────
// _GamerCard
// ─────────────────────────────────────────────────────────────

class _GamerCard extends StatelessWidget {
  final Map<String, dynamic> gamer;
  final int rank;
  const _GamerCard({required this.gamer, required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = [_kG1, _kG2, _kG3, _kG4];
    final color  = colors[rank % colors.length];
    final name   = (gamer['gamer_tag'] as String?)?.isNotEmpty == true
        ? '#${gamer['gamer_tag']}' : gamer['display_name'] ?? 'Player';
    final level  = gamer['level'] as int? ?? 1;
    final medals = ['🥇', '🥈', '🥉'];
    final initial = name.isNotEmpty
        ? name[name.startsWith('#') ? 1 : 0].toUpperCase() : '?';

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank <= 3
              ? color.withOpacity(0.35)
              : Colors.white.withOpacity(0.05),
          width: 1.5)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color])),
            child: Center(child: Text(initial, style: const TextStyle(
                color: Colors.white, fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 15)))),
          const SizedBox(height: 5),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  color: Colors.white, fontSize: 9)),
          Text('Lv.$level', style: TextStyle(fontFamily: 'Momo',
              fontSize: 9, color: color)),
          const SizedBox(height: 4),
          if (rank <= 3)
            Text(medals[rank - 1], style: const TextStyle(fontSize: 15))
          else
            Text('#$rank', style: TextStyle(fontFamily: 'Alfa',
                fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _FeaturedTile
// ─────────────────────────────────────────────────────────────

class _FeaturedTile extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;
  const _FeaturedTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: grad.map((c) => c.withOpacity(0.1)).toList(),
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: grad.first.withOpacity(playable ? 0.4 : 0.15), width: 1.5)),
        child: Row(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: grad,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 28)))),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name,
                  style: const TextStyle(fontFamily: 'Alfa',
                      fontSize: 15, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: grad.first.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(cat.toUpperCase(), style: TextStyle(fontFamily: 'Momo',
                    fontSize: 8, fontWeight: FontWeight.bold, color: grad.first))),
              if (playable) ...[
                const SizedBox(width: 4),
                // ── Phase 1: pulsing LIVE badge ─────────────────
                NeonPulse(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(5),
                  intensity: 0.7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade900,
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('LIVE', style: TextStyle(fontFamily: 'Momo',
                        fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(desc, style: TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: Colors.white38),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(spacing: 10, children: [
              Text('⚡ $xp XP', style: const TextStyle(fontFamily: 'Momo',
                  fontSize: 10, color: kXpColor, fontWeight: FontWeight.bold)),
              Text('🪙 $tokens', style: const TextStyle(fontFamily: 'Momo',
                  fontSize: 10, color: kTokenColor, fontWeight: FontWeight.bold)),
              if (best != null)
                Text('Best: $best', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 10, color: Colors.white38)),
            ]),
          ])),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(gradient: LinearGradient(colors: grad),
                borderRadius: BorderRadius.circular(10)),
            child: Text(playable ? 'Play' : 'Soon', style: const TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.white, fontSize: 12))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _GameGridCard
// ─────────────────────────────────────────────────────────────

class _GameGridCard extends StatelessWidget {
  final Map<String, dynamic> game;
  final bool isPlayable;
  final VoidCallback onTap;
  const _GameGridCard({required this.game, required this.isPlayable,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final slug  = game['slug']      as String? ?? '';
    final name  = game['name']      as String? ?? '';
    final cat   = game['category']  as String? ?? '';
    final xp    = game['xp_reward'] as int?    ?? 0;
    final emoji = _gameEmoji[slug]  ?? '🎮';
    final grad  = _gradientFor(cat);

    return GestureDetector(onTap: onTap,
      child: Container(decoration: BoxDecoration(color: _darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPlayable
            ? grad.first.withOpacity(0.3) : Colors.white.withOpacity(0.05))),
        child: Column(children: [
          Container(height: 76, decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Stack(children: [
              Center(child: Text(emoji, style: const TextStyle(fontSize: 34))),
              if (isPlayable)
                // ── Phase 1: pulsing LIVE badge ────────────────────
                Positioned(top: 8, right: 8, child: NeonPulse(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(5),
                  intensity: 0.7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade900,
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('LIVE', style: TextStyle(fontFamily: 'Momo',
                        fontSize: 7, fontWeight: FontWeight.bold, color: Colors.green))))),
            ])),
          Expanded(child: Padding(padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(cat, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 9, color: grad.first)),
              const Spacer(),
              Row(children: [
                Text('⚡$xp', style: const TextStyle(fontFamily: 'Momo',
                    fontSize: 10, color: kXpColor, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: grad),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(isPlayable ? 'Play' : 'Soon',
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          color: Colors.white, fontSize: 9))),
              ]),
            ]))),
        ])));
  }
}

// ─────────────────────────────────────────────────────────────
// _StatCard
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5)),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 10),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontFamily: 'Momo',
            fontSize: 10, color: Colors.white38),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ])));
}

// ═════════════════════════════════════════════════════════════
// CLUB CARDS — dark-themed for arcade context
// ═════════════════════════════════════════════════════════════

/// Big card for the Gaming Clubs horizontal strip.
/// Cover banner on top + logo overlap + name + tagline + chips.
class _BigClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _BigClubCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            SizedBox(
              height: 70,
              width: double.infinity,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _coverFallback(),
                      placeholder: (_, __) => _coverFallback(),
                    )
                  : _coverFallback(),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: _darkBg,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _darkBg, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logoUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _logoFallback(initial),
                                placeholder: (_, __) =>
                                    _logoFallback(initial),
                              )
                            : _logoFallback(initial),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Alfa',
                                    fontSize: 12,
                                    color: Colors.white,
                                  )),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified_rounded,
                                  color: _kVerified, size: 11),
                            ],
                          ]),
                          Text(
                            '$memberCount member${memberCount == 1 ? "" : "s"}',
                            style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.55),
                          height: 1.4,
                        )),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMember
                          ? Colors.green.withOpacity(0.15)
                          : _kG2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      isMember ? 'JOINED' : 'GAMING',
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isMember ? Colors.greenAccent : _kG1,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kG2, _kG1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  Widget _logoFallback(String initial) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kG2, _kG1],
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      );
}

/// Compact card for the My Clubs strip — logo + name + member count.
class _SmallClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _SmallClubCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name        = club['name']          as String? ?? 'Club';
    final logoUrl     = club['logo_url']      as String?;
    final memberCount = club['members_count'] as int?    ?? 0;
    final isVerified  = club['is_verified']   as bool?   ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    final membership =
        (club['membership'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isAdmin = membership['is_admin'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAdmin
                ? const Color(0xFF7986CB).withOpacity(0.40)
                : Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _darkBg,
              ),
              child: ClipOval(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        width: 46, height: 46,
                        errorWidget: (_, __, ___) => _logoFallback(initial),
                        placeholder: (_, __) => _logoFallback(initial),
                      )
                    : _logoFallback(initial),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 10,
                      )),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.verified_rounded,
                      color: _kVerified, size: 9),
                ],
              ],
            ),
            const SizedBox(height: 2),
            if (isAdmin)
              Text('ADMIN',
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7986CB),
                    letterSpacing: 0.5,
                  ))
            else
              Text(
                '$memberCount mem',
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logoFallback(String initial) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kG2, _kG1],
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      );
}

/// Wide card for the Trending list — cover banner background, logo, info.
class _TrendingClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _TrendingClubCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name        = club['name']           as String? ?? 'Club';
    final tagline     = club['tagline']        as String? ?? '';
    final category    = club['category']       as String? ?? '';
    final coverUrl    = club['cover_url']      as String?;
    final logoUrl     = club['logo_url']       as String?;
    final memberCount = club['members_count']  as int?    ?? 0;
    final isVerified  = club['is_verified']    as bool?   ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    final membership =
        (club['membership'] as Map?)?.cast<String, dynamic>() ?? const {};
    final isMember  = membership['is_member']  == true;
    final isPending = membership['is_pending'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Cover background
          if (coverUrl != null && coverUrl.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.32,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  placeholder: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
          // Dark gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_darkCard, _darkCard.withOpacity(0.7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10),
                      width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _logoFallback(initial),
                          placeholder: (_, __) => _logoFallback(initial),
                        )
                      : _logoFallback(initial),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Alfa',
                              fontSize: 14,
                              color: Colors.white,
                            )),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            color: _kVerified, size: 12),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      _meta(memberCount, category),
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                    if (tagline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.65),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _stateBadge(isMember: isMember, isPending: isPending),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stateBadge({required bool isMember, required bool isPending}) {
    String label;
    Color bg;
    Color fg;
    if (isMember) {
      label = 'JOINED'; bg = Colors.green.withOpacity(0.15); fg = Colors.greenAccent;
    } else if (isPending) {
      label = 'PENDING'; bg = _kG3.withOpacity(0.15); fg = _kG3;
    } else {
      label = 'VIEW'; bg = _kG2.withOpacity(0.18); fg = _kG1;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label,
          style: TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 9,
            color: fg,
            letterSpacing: 0.5,
          )),
    );
  }

  String _meta(int memberCount, String category) {
    final parts = <String>[];
    parts.add('$memberCount member${memberCount == 1 ? "" : "s"}');
    if (category.isNotEmpty) parts.add(_titleCase(category));
    return parts.join(' · ');
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

  Widget _logoFallback(String initial) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kG2, _kG1],
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// §11 — Club Activity Hub row
//
// One row in the live activity stream. Renders both posts and
// events; appearance is driven by the synthetic `_kind` key set
// during the fan-out in _loadActivityHub().
//   • icon tint → coral for events, violet for posts
//   • subtitle  → first line of post content / event title
//   • metadata  → club name + relative timestamp
//   • tap       → open the parent club screen
// ═════════════════════════════════════════════════════════════

class _HubItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _HubItemRow({required this.item, required this.onTap});

  bool   get _isEvent  => item['_kind'] == 'event';
  String get _clubName => item['_club_name'] as String? ?? '';

  String get _title {
    if (_isEvent) {
      return item['title'] as String? ?? 'Event';
    }
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
      // Posts use a relative "Xm/h/d ago" format.
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 7)  return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = _isEvent ? _kG3 : _kG2;
    final icon = _isEvent
        ? Icons.event_rounded
        : Icons.chat_bubble_outline_rounded;
    final tag  = _isEvent ? 'EVENT' : 'POST';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: tint, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top line: club name (left) + tag pill (right)
                  Row(children: [
                    Expanded(
                      child: Text(
                        _clubName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tint.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: tint,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  // Title / first line of content
                  Text(
                    _title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 12,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  if (_whenLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _whenLabel,
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.40),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}