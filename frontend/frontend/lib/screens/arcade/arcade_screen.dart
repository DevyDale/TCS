// lib/screens/arcade/arcade_screen.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';
import 'package:tcs_app/screens/arcade/_arcade_carousel_card.dart';
import '../../services/api_service.dart';
import 'player_tag_screen.dart';
import 'quiz_battle_game.dart';

import 'spirit_racers_game.dart';
import 'ninja_tag_game.dart';
import 'sushi_rush_game.dart';
import 'battle_bots_game.dart';
import 'pool_royale_game.dart';
import 'game_engine.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _darkBg    = Color(0xFF0D0D1A);
const _darkCard  = Color(0xFF161628);
const _darkCard2 = Color(0xFF1E1E38);

final _playableGames = {
  'quiz-battle':    (BuildContext ctx) => const QuizBattleGame(),
  'spirit-racers': (BuildContext ctx) => const SpiritRacersGame(),
  'ninja-tag':     (BuildContext ctx) => const NinjaTagGame(),
  'sushi-rush':    (BuildContext ctx) => const SushiRushGame(),
  'battle-bots':   (BuildContext ctx) => const BattleBotsGame(),
  'pool-royale':   (BuildContext ctx) => const PoolRoyaleGame(),
};

const _gameEmoji = {
  'quiz-battle': '🧠', 'tic-tac-toe': '⭕', 'memory-match': '🃏',
  'snake': '🐍', 'number-guesser': '🔢', 'campus-craft': '🏗️',
  'ninja-tag': '🥷', 'sushi-rush': '🍣', 'battle-bots': '🤖',
  'spirit-racers': '🏎️', 'pool-royale': '🎱',
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

  Map<String, dynamic>       _stats       = {};
  List<Map<String, dynamic>> _games       = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _topGamers   = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl      = TabController(length: 3, vsync: this);
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

  Future<void> _loadAll() =>
      Future.wait([_loadStats(), _loadGames(), _loadLeaderboard()]);

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
  ];

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildCarousel()),
            SliverToBoxAdapter(child: _buildActiveGamers()),
            SliverToBoxAdapter(child: _buildTabBar()),
            SliverToBoxAdapter(child: _buildTabContent()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: _kG3.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kG3.withOpacity(0.2))),
                  child: Row(children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 5),
                    Text('$tokens', style: const TextStyle(fontFamily: 'Alfa',
                        fontSize: 14, color: _kG3)),
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
              Text('${_games.length} games  ·  ${_leaderboard.length} players ranked',
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
                if (i == 0) {
                  _tabCtrl.animateTo(2);
                } else if (i == 1) _promptPlayerTag();
                else if (i == 2) _tabCtrl.animateTo(1);
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
      // FIX: height 120 → 134 to give gamer cards enough room
      _loadingLb
          ? const SizedBox(height: 134, child: Center(
              child: CircularProgressIndicator(color: _kG2, strokeWidth: 2)))
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

  // ── Tab bar ───────────────────────────────────────────────

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
          SegmentTab(label: 'Leaderboard'),
          SegmentTab(label: 'My Stats'),
        ],
      ));
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(animation: _tabCtrl, builder: (_, __) {
      switch (_tabCtrl.index) {
        case 0:  return _buildGamesTab();
        case 1:  return _buildLeaderboardTab();
        case 2:  return _buildStatsTab();
        default: return const SizedBox.shrink();
      }
    });
  }

  // ── Games Tab ─────────────────────────────────────────────

  Widget _buildGamesTab() {
    if (_loadingGames) {
      return const Padding(padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: _kG2)));
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

        // Stat grid
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
// _GamerCard — FIX: use LayoutBuilder to avoid fixed-height overflow
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
      // FIX: Column with mainAxisSize.min inside a fixed-height parent
      // was overflowing. Use a Column with no Spacer + even distribution.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color])),
            child: Center(child: Text(initial, style: const TextStyle(
                color: Colors.white, fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 15)))),
          const SizedBox(height: 5),
          // Name
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  color: Colors.white, fontSize: 9)),
          // Level
          Text('Lv.$level', style: TextStyle(fontFamily: 'Momo',
              fontSize: 9, color: color)),
          const SizedBox(height: 4),
          // Medal or rank
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
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('LIVE', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green))),
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
          // Header gradient
          Container(height: 76, decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Stack(children: [
              Center(child: Text(emoji, style: const TextStyle(fontSize: 34))),
              if (isPlayable)
                Positioned(top: 8, right: 8, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade900,
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('LIVE', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 7, fontWeight: FontWeight.bold, color: Colors.green)))),
            ])),
          // Info
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