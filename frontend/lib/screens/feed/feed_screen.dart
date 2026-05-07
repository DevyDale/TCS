// lib/screens/feed/feed_screen.dart
//
// §6 fixes:
//   1. Media renders inline (CachedNetworkImage / video thumb with play
//      overlay) instead of delegating to MediaItemView. Every slide has a
//      placeholder + error fallback so the card center is never blank.
//   2. Fweets get their distinctive colored block with bold centered text
//      (matching the create page), so they actually appear in the feed.
//   3. Layout is Instagram-style: author row on top (no longer overlaid),
//      then media/fweet block, then caption, then location chip, then
//      actions. Caption and location display naturally with the media.
//   4. New _ago format: "5m ago" / "3h ago" / "2d ago", then actual date
//      (e.g. "May 7" or "May 7, 2025") after 7 days. No more "X weeks ago".

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/highlight_card.dart';
import 'package:tcs_app/screens/event_details.dart';
import 'package:tcs_app/screens/suggestion_box_screen.dart';
import 'package:tcs_app/search/search_screen.dart';
import '../../services/api_service.dart';
import '../profile/profile_screen.dart' show deletedPostIds;


// ── Palette ───────────────────────────────────────────────────
const _kInk    = Color(0xFF0D0D1A);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);
const _kCard   = Colors.white;
const _kViolet = Color(0xFF7C3AED);
const _kBlue   = Color(0xFF3B82F6);
const _kCoral  = Color(0xFFFF4F6E);
const _kMint   = Color(0xFF10B981);
const _kAmber  = Color(0xFFF59E0B);
const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF7C3AED);
const _kG3     = Color(0xFFF59E0B);
const _kG4     = Color(0xFFFF4F6E);

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin {
  final _api        = ApiService();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _posts      = [];
  List<Map<String, dynamic>> _highlights = [];

  bool _feedLoading  = true;
  bool _feedHasMore  = true;
  bool _fetchingMore = false;
  int  _feedPage     = 1;
  int  _feedTab      = 0; // 0=All 1=Following 2=Trending

  final _carouselCtrl = PageController(viewportFraction: 0.92);
  int  _carouselPage  = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadHighlights();
    _scrollCtrl.addListener(_onScroll);
    deletedPostIds.addListener(_onPostsDeleted);
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    deletedPostIds.removeListener(_onPostsDeleted);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_highlights.length <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_carouselCtrl.hasClients) return;
      final next = (_carouselPage + 1) % _highlights.length;
      _carouselCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic);
    });
  }

  void _onScroll() {
    final px = _scrollCtrl.position.pixels;
    if (px >= _scrollCtrl.position.maxScrollExtent - 200 &&
        _feedHasMore && !_fetchingMore) {
      _fetchingMore = true;
      _feedPage++;
      _loadFeed().then((_) => _fetchingMore = false);
    }
  }

  void _onPostsDeleted() {
    final deleted = deletedPostIds.value;
    if (deleted.isEmpty) return;
    setState(() =>
        _posts.removeWhere((p) => deleted.contains(p['id']?.toString())));
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _feedPage = 1;
        _feedHasMore = true;
        _feedLoading = true;
      });
    }
    final types = ['home', 'following', 'trending'];
    final type  = types[_feedTab];
    try {
      final data = await _api.getFeed(type: type, page: _feedPage)
          as Map<String, dynamic>;
      final results = (data['results'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        if (refresh || _feedPage == 1) {
          _posts = results;
        } else {
          _posts.addAll(results);
        }
        _feedHasMore = data['next'] != null;
        _feedLoading = false;
      });
    } catch (_) {
      setState(() => _feedLoading = false);
    }
  }

  Future<void> _loadHighlights() async {
    // Phase 2 spec 10.3: events + announcements unified in one carousel.
    try {
      final data = await _api.getCampusHighlights(limit: 10)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _highlights = (data['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
      });
      _startCarouselTimer();
    } catch (_) {/* swallow — empty state covers it */}
  }

  Future<void> _toggleLike(int i) async {
    HapticFeedback.lightImpact();
    final post = _posts[i];
    final id   = post['id']?.toString() ?? '';
    final was  = post['is_liked'] as bool? ?? false;
    final cnt  = post['like_count'] as int? ?? 0;
    setState(() {
      _posts[i] = {
        ..._posts[i],
        'is_liked':   !was,
        'like_count': was ? cnt - 1 : cnt + 1,
      };
    });
    try {
      final res = await _api.likeToggle(id) as Map<String, dynamic>;
      setState(() {
        _posts[i] = {
          ..._posts[i],
          'is_liked':   res['liked'] ?? !was,
          'like_count': res['like_count'] ?? _posts[i]['like_count'],
        };
      });
    } catch (_) {
      setState(() {
        _posts[i] = {..._posts[i], 'is_liked': was, 'like_count': cnt};
      });
    }
  }

  void _showComments(Map<String, dynamic> post) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(api: _api, post: post));

  void _showShare(Map<String, dynamic> post) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(api: _api, post: post));

  void _openHighlight(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    final kind = item['kind'] as String? ?? '';
    final id   = item['id']?.toString() ?? '';

    if (kind == 'event') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventDetailsScreen(eventId: id, initial: item),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(item['title']?.toString() ?? 'Announcement',
            style: const TextStyle(fontFamily: 'Momo')),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kViolet,
        displacement: 100,
        onRefresh: () async {
          await Future.wait([
            _loadFeed(refresh: true),
            _loadHighlights(),
          ]);
        },
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [

            SliverToBoxAdapter(child: _buildHeader(topPad)),
            SliverToBoxAdapter(child: _buildHighlightsSection()),
            SliverToBoxAdapter(child: _buildFeedLabel()),

            if (_feedLoading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: _kViolet)))
            else if (_posts.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    if (i == _posts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(
                            color: _kViolet, strokeWidth: 2)));
                    }
                    return _AnimatedPostEntry(
                      index: i,
                      child: _PostCard(
                        post:      _posts[i],
                        index:     i,
                        onLike:    () => _toggleLike(i),
                        onComment: () => _showComments(_posts[i]),
                        onShare:   () => _showShare(_posts[i]),
                      ),
                    );
                  },
                  childCount: _posts.length + (_feedHasMore ? 1 : 0),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader(double topPad) {
    return Container(
      color: _kCard,
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(_greeting, style: TextStyle(
                fontFamily: 'Momo', fontSize: 12, color: _kSlate)),
            const Text('StudentHub', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 28, color: _kInk, height: 1.1)),
          ])),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SuggestionBoxScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kViolet.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kViolet.withOpacity(0.15))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lightbulb_outline_rounded, color: _kViolet, size: 16),
                const SizedBox(width: 6),
                Text('Suggest', style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, color: _kViolet, fontSize: 12)),
              ]))),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Icon(Icons.search_rounded,
                  color: _kSlate.withOpacity(0.5), size: 19),
              const SizedBox(width: 10),
              Expanded(child: Text('Search posts, people, clubs...',
                  style: TextStyle(fontFamily: 'Momo',
                      color: _kSlate.withOpacity(0.5), fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kViolet, _kBlue],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3))]),
                child: const Text('Search', style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 11))),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Highlights (events + announcements) ───────────────────

  Widget _buildHighlightsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 26),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CAMPUS UPDATES', style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 10, color: _kViolet, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            const Text('Highlights', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
          ]),
          const Spacer(),
          if (_highlights.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _kViolet.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_highlights.length} active',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 11, color: _kViolet))),
        ]),
      ),
      if (_highlights.isEmpty)
        _buildEmptyHighlights()
      else
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _carouselCtrl,
            itemCount: _highlights.length,
            onPageChanged: (p) => setState(() => _carouselPage = p),
            itemBuilder: (_, i) {
              final item = _highlights[i];
              return HighlightCard(
                item: item,
                onTap: () => _openHighlight(item),
              );
            },
          ),
        ),
      if (_highlights.length > 1) ...[
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_highlights.length, (i) {
            final active = i == _carouselPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 24 : 6, height: 6,
              decoration: BoxDecoration(
                gradient: active ? const LinearGradient(
                    colors: [_kViolet, _kBlue]) : null,
                color: active ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3)));
          })),
      ],
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildEmptyHighlights() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 100,
        decoration: BoxDecoration(color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.campaign_outlined, color: Colors.grey.shade300, size: 26),
          const SizedBox(width: 10),
          Text('No highlights right now',
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: Colors.grey.shade400)),
        ])),
    );
  }

  // ── Feed label + tabs ─────────────────────────────────────

  Widget _buildFeedLabel() {
    const tabs = ['All', 'Following', 'Trending'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LATEST', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 10,
                color: _kViolet, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            const Text('Campus Feed', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
          ]),
          const Spacer(),
          if (_posts.isNotEmpty)
            Text('${_posts.length} posts',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: _kSlate)),
        ]),
      ),
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: tabs.length,
          itemBuilder: (_, i) {
            final active = i == _feedTab;
            return GestureDetector(
              onTap: () {
                if (_feedTab == i) return;
                HapticFeedback.selectionClick();
                setState(() {
                  _feedTab     = i;
                  _feedPage    = 1;
                  _feedHasMore = true;
                  _posts       = [];
                  _feedLoading = true;
                });
                _loadFeed();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: active ? const LinearGradient(
                      colors: [_kViolet, _kBlue],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight) : null,
                  color: active ? null : _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? Colors.transparent : Colors.grey.shade200),
                  boxShadow: active ? [BoxShadow(color: _kViolet.withOpacity(0.3),
                      blurRadius: 10, offset: const Offset(0, 4))] : []),
                child: Text(tabs[i], style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: active ? Colors.white : _kSlate)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _buildEmptyState() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(
            color: _kViolet.withOpacity(0.06), shape: BoxShape.circle),
          child: const Center(child: Text('📭',
              style: TextStyle(fontSize: 34)))),
        const SizedBox(height: 20),
        const Text('No posts yet', style: TextStyle(
            fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
        const SizedBox(height: 8),
        Text('Be the first to share something with campus',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: _kSlate)),
      ]),
    ));
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () => HapticFeedback.mediumImpact(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kViolet, _kBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.45),
              blurRadius: 20, offset: const Offset(0, 8))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_rounded, color: Colors.white, size: 17),
          SizedBox(width: 8),
          Text('Create Post', style: TextStyle(fontFamily: 'Arch',
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STAGGERED ENTRY ANIMATION
// ─────────────────────────────────────────────────────────────

class _AnimatedPostEntry extends StatefulWidget {
  final int index; final Widget child;
  const _AnimatedPostEntry({required this.index, required this.child});
  @override State<_AnimatedPostEntry> createState() => _AnimatedPostEntryState();
}

class _AnimatedPostEntryState extends State<_AnimatedPostEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: Duration(
            milliseconds: 380 + widget.index.clamp(0, 5) * 40));
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(
        Duration(milliseconds: widget.index.clamp(0, 6) * 55),
        () { if (mounted) _ctrl.forward(); });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child));
}

// ═════════════════════════════════════════════════════════════
// POST CARD
// ─────────────────────────────────────────────────────────────
// New layout (top → bottom):
//   1. Author row (avatar, name, time, role badge)
//   2. Visual block — media carousel OR fweet colored block (whichever
//      applies). Plain text posts skip this.
//   3. Caption text (skipped for fweets — the text lives in the block)
//   4. Location chip
//   5. Action bar (like / comment / share / bookmark)
// ─────────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int index;
  final VoidCallback onLike, onComment, onShare;
  const _PostCard({required this.post, required this.index,
      required this.onLike, required this.onComment, required this.onShare});
  @override State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  late final Animation<double>   _heartScale;
  bool _expanded   = false;
  bool _bookmarked = false;
  int  _mediaPage  = 0;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 200),
        lowerBound: 0.75, upperBound: 1.0, value: 1.0);
    _heartScale = CurvedAnimation(
        parent: _heartCtrl, curve: Curves.elasticOut);
  }
  @override void dispose() { _heartCtrl.dispose(); super.dispose(); }

  Future<void> _handleLike() async {
    await _heartCtrl.animateTo(0.75,
        duration: const Duration(milliseconds: 80));
    widget.onLike();
    _heartCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 200), curve: Curves.elasticOut);
  }

  void _handleBookmark() {
    HapticFeedback.lightImpact();
    setState(() => _bookmarked = !_bookmarked);
  }

  static List<Color> _roleGrad(String role) {
    switch (role.toLowerCase()) {
      case 'student':            return [const Color(0xFF10B981), const Color(0xFF6DD5FA)];
      case 'teaching_staff':     return [const Color(0xFF7C3AED), const Color(0xFF3B82F6)];
      case 'non_teaching_staff': return [const Color(0xFFF59E0B), const Color(0xFFFF6B35)];
      case 'admin':              return [const Color(0xFFFF4F6E), const Color(0xFF7C3AED)];
      default:                   return [const Color(0xFF64687A), const Color(0xFF9CA3AF)];
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Format: "5m ago" / "3h ago" / "2d ago" within the first week,
  /// then the actual date ("May 7" or "May 7, 2025") after that.
  /// Never returns "weeks ago".
  static String _ago(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final d   = now.difference(dt);
      if (d.isNegative)        return 'Just now';
      if (d.inSeconds < 60)    return 'Just now';
      if (d.inMinutes < 60)    return '${d.inMinutes}m ago';
      if (d.inHours   < 24)    return '${d.inHours}h ago';
      if (d.inDays    < 7)     return '${d.inDays}d ago';
      // After 7 days → exact date
      if (dt.year == now.year) {
        return '${_months[dt.month - 1]} ${dt.day}';
      }
      return '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  /// Parse "#RRGGBB" / "#AARRGGBB" / "RRGGBB" → Color, or null.
  static Color? _parseHex(String hex) {
    if (hex.isEmpty) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    try { return Color(int.parse(h, radix: 16)); }
    catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.post;
    final name     = (p['author_name']     as String? ?? 'Unknown').trim();
    final role     = (p['author_role']     as String? ?? '').trim();
    final avatar   = (p['author_avatar']   as String? ?? '').trim();
    final content  = (p['content']         as String? ?? '').trim();
    final location = (p['location']        as String? ?? '').trim();
    final bgHex    = (p['background_color'] as String? ?? '').trim();
    final likes    = p['like_count']    as int?    ?? 0;
    final comments = p['comment_count'] as int?    ?? 0;
    final shares   = p['share_count']   as int?    ?? 0;
    final isLiked  = p['is_liked']      as bool?   ?? false;
    final isFweet  = p['post_type']     == 'fweet';
    final timeAgo  = _ago(p['created_at'] as String? ?? '');
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final grad     = _roleGrad(role);
    final bgColor  = _parseHex(bgHex);

    final media      = (p['media'] as List? ?? []).cast<Map<String, dynamic>>();
    final hasMedia   = media.isNotEmpty;
    // A fweet renders as a colored block. We require a non-empty caption
    // because the block centers on the text; an empty fweet would just
    // be a blank colored box.
    final hasFweetBg = isFweet && bgColor != null && content.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 4, offset: const Offset(0, 2)),
        ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // 1. AUTHOR ROW — always at the top (no longer overlaid on media)
          _buildAuthorRow(avatar, initial, name, role, grad, isFweet, timeAgo),

          // 2. VISUAL BLOCK — media carousel OR fweet colored block
          if (hasMedia) ...[
            const SizedBox(height: 12),
            _buildMediaCarousel(media),
          ] else if (hasFweetBg) ...[
            const SizedBox(height: 12),
            _buildFweetBlock(content, bgColor!),
          ],

          // 3. CAPTION — shown for everything except fweet blocks
          //    (fweet text lives inside the block already)
          if (content.isNotEmpty && !hasFweetBg) ...[
            SizedBox(height: hasMedia ? 14 : 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(content,
                  maxLines: _expanded ? null : 4,
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                      color: _kInk.withOpacity(0.85), height: 1.6)),
              ),
            ),
          ],

          // 4. LOCATION CHIP
          if (location.isNotEmpty) ...[
            SizedBox(height: (content.isNotEmpty && !hasFweetBg) ? 10 : 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kCoral.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kCoral.withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded, size: 12, color: _kCoral),
                    const SizedBox(width: 4),
                    Flexible(child: Text(location,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Momo',
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: _kCoral))),
                  ]),
                ),
              ),
            ),
          ],

          // Divider
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Divider(height: 1, color: Colors.grey.shade100)),

          // 5. ACTIONS
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              ScaleTransition(scale: _heartScale,
                child: _ActionBtn(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  label: _fmt(likes),
                  color: isLiked ? _kCoral : _kSlate,
                  onTap: _handleLike,
                  filled: isLiked,
                  fillColor: _kCoral.withOpacity(0.07))),
              const SizedBox(width: 4),
              _ActionBtn(icon: Icons.chat_bubble_outline_rounded,
                  label: _fmt(comments), color: _kViolet,
                  onTap: widget.onComment),
              const SizedBox(width: 4),
              _ActionBtn(
                  icon: Icons.ios_share_rounded,
                  label: shares > 0 ? _fmt(shares) : 'Share',
                  color: _kAmber, onTap: widget.onShare),
              const Spacer(),
              _ActionBtn(
                icon: _bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                label: '',
                color: _bookmarked ? _kViolet : _kSlate,
                onTap: _handleBookmark,
                filled: _bookmarked,
                fillColor: _kViolet.withOpacity(0.08)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // AUTHOR ROW
  // ─────────────────────────────────────────────────────────

  Widget _buildAuthorRow(String avatar, String initial, String name,
      String role, List<Color> grad, bool isFweet, String timeAgo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        // Avatar
        Stack(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: grad,
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: avatar.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: avatar, fit: BoxFit.cover,
                    width: 44, height: 44,
                    placeholder: (_, __) =>
                        Container(color: grad.first.withOpacity(0.3)),
                    errorWidget: (_, __, ___) => Center(child: Text(initial,
                        style: const TextStyle(color: Colors.white,
                            fontFamily: 'Arch', fontWeight: FontWeight.bold,
                            fontSize: 17)))))
                : Center(child: Text(initial,
                    style: const TextStyle(color: Colors.white,
                        fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 17)))),
          Positioned(bottom: 1, right: 1, child: Container(
            width: 13, height: 13,
            decoration: BoxDecoration(color: _kMint,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)))),
        ]),
        const SizedBox(width: 11),
        // Name + time
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: Text(name, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14,
                      color: _kInk))),
              if (isFweet) ...[
                const SizedBox(width: 5),
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _kCoral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('⚡ Fweet', style: TextStyle(
                      fontFamily: 'Arch', fontSize: 9,
                      fontWeight: FontWeight.bold, color: _kCoral))),
              ],
            ]),
            if (timeAgo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(timeAgo, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11, color: _kSlate)),
            ],
          ])),
        // Role badge
        if (role.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: grad.map((c) => c.withOpacity(0.1)).toList()),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: grad.first.withOpacity(0.25))),
            child: Text(role.replaceAll('_', ' '),
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 9,
                  color: grad.last))),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  // MEDIA CAROUSEL — renders inline so it can never end up empty.
  // Each slide has its own placeholder + error fallback.
  // ─────────────────────────────────────────────────────────

  Widget _buildMediaCarousel(List<Map<String, dynamic>> media) {
    final multi = media.length > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 5,        // tall-ish, like Instagram
          child: Stack(children: [
            PageView.builder(
              itemCount: media.length,
              onPageChanged: (p) => setState(() => _mediaPage = p),
              itemBuilder: (_, i) => _buildMediaSlide(media[i]),
            ),
            // Counter (top-right)
            if (multi)
              Positioned(top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${_mediaPage + 1} / ${media.length}',
                      style: const TextStyle(color: Colors.white,
                          fontFamily: 'Momo', fontSize: 11,
                          fontWeight: FontWeight.bold)))),
            // Dots (bottom-centre)
            if (multi)
              Positioned(bottom: 10, left: 0, right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(media.length, (i) {
                    final active = i == _mediaPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6, height: 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3)));
                  }))),
          ]),
        ),
      ),
    );
  }

  Widget _buildMediaSlide(Map<String, dynamic> item) {
    final url       = (item['url']            as String? ?? '').trim();
    final thumb     = (item['thumbnail_url']  as String? ?? '').trim();
    final mediaType = (item['media_type']     as String? ?? 'image').trim();
    final isVideo   = mediaType == 'video';

    if (url.isEmpty) {
      return _mediaPlaceholder(
          Icons.broken_image_rounded, 'Media unavailable');
    }

    if (isVideo) {
      // Show thumbnail with a play overlay. If there's no thumbnail
      // URL, fall back to the video URL itself (Cloudinary will serve
      // a JPEG when you swap the extension; the CachedNetworkImage
      // errorWidget covers the failure case).
      final imageUrl = thumb.isNotEmpty ? thumb : url;
      return Container(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade900),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Icon(Icons.movie_rounded,
                  color: Colors.white.withOpacity(0.4), size: 56),
            ),
          ),
          // Play overlay
          Center(child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 36),
          )),
          // VIDEO badge
          Positioned(top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.videocam_rounded, color: Colors.white, size: 11),
                SizedBox(width: 4),
                Text('VIDEO', style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 10)),
              ]))),
        ]),
      );
    }

    // Image
    return Container(
      color: Colors.grey.shade100,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Center(child: SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
              color: _kViolet.withOpacity(0.5), strokeWidth: 2.5))),
        errorWidget: (_, __, ___) => _mediaPlaceholder(
            Icons.broken_image_rounded, "Couldn't load image"),
      ),
    );
  }

  Widget _mediaPlaceholder(IconData icon, String label) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.grey.shade400, size: 38),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontFamily: 'Momo',
            fontSize: 12, color: Colors.grey.shade500)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  // FWEET BLOCK — colored card with bold centered text, matching the
  // create page. Without this, fweets in the feed looked identical to
  // plain text posts and the user reported them as "not appearing".
  // ─────────────────────────────────────────────────────────

  Widget _buildFweetBlock(String content, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              bgColor,
              bgColor.withOpacity(0.78),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Center(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(content,
                textAlign: TextAlign.center,
                maxLines: _expanded ? null : 6,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Momo',
                    fontSize: 18, color: Colors.white,
                    fontWeight: FontWeight.bold, height: 1.4)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  final VoidCallback onTap; final bool filled; final Color? fillColor;
  const _ActionBtn({required this.icon, required this.label,
      required this.color, required this.onTap,
      this.filled = false, this.fillColor});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
          horizontal: label.isNotEmpty ? 12 : 10, vertical: 9),
      decoration: BoxDecoration(
        color: filled
            ? (fillColor ?? color.withOpacity(0.08))
            : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// COMMENTS SHEET
// ─────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final ApiService api; final Map<String, dynamic> post;
  const _CommentsSheet({required this.api, required this.post});
  @override State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true, _posting = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await widget.api.getComments(
          widget.post['id']?.toString() ?? '') as Map<String, dynamic>;
      setState(() {
        _comments = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading  = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _post() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _posting) return;
    HapticFeedback.lightImpact();
    setState(() => _posting = true);
    try {
      final c = await widget.api.addComment(
          widget.post['id']?.toString() ?? '', t) as Map<String, dynamic>;
      setState(() { _comments.insert(0, c); _ctrl.clear(); _posting = false; });
    } catch (_) { setState(() => _posting = false); }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(
            color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('Comments', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: _kViolet.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_comments.length}', style: const TextStyle(
                  fontFamily: 'Arch', fontSize: 12,
                  fontWeight: FontWeight.bold, color: _kViolet))),
          ])),
        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade100),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kViolet))
            : _comments.isEmpty
                ? Center(child: Text('No comments yet', style: TextStyle(
                    fontFamily: 'Momo', fontSize: 13, color: _kSlate)))
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (_, i) => _CommentTile(
                        comment: _comments[i]))),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16,
              MediaQuery.of(context).viewInsets.bottom + 16),
          decoration: BoxDecoration(color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            Expanded(child: Container(
              decoration: BoxDecoration(color: _kBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _ctrl,
                enableSuggestions: false, autocorrect: false,
                style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(fontFamily: 'Momo',
                      color: _kSlate.withOpacity(0.4), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12)),
                onChanged: (_) => setState(() {})))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _post,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: _ctrl.text.trim().isNotEmpty
                      ? const LinearGradient(colors: [_kViolet, _kBlue])
                      : const LinearGradient(
                          colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)])),
                child: _posting
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 19))),
          ]),
        ),
      ]),
    ),
  );
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});
  @override
  Widget build(BuildContext context) {
    final name    = comment['author_name']   as String? ?? '';
    final text    = comment['text']          as String? ?? '';
    final avatar  = comment['author_avatar'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34,
          decoration: const BoxDecoration(shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_kViolet, _kBlue])),
          child: ClipOval(child: avatar.isNotEmpty
              ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover,
                  width: 34, height: 34,
                  errorWidget: (_, __, ___) => Center(child: Text(initial,
                      style: const TextStyle(color: Colors.white,
                          fontFamily: 'Arch', fontWeight: FontWeight.bold,
                          fontSize: 13))))
              : Center(child: Text(initial, style: const TextStyle(
                  color: Colors.white, fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13))))),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(name, style: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 13, color: _kInk)),
          const SizedBox(height: 3),
          Text(text, style: TextStyle(fontFamily: 'Momo',
              fontSize: 13, color: _kSlate, height: 1.45)),
        ])),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────
// SHARE SHEET
// ─────────────────────────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  final ApiService api; final Map<String, dynamic> post;
  const _ShareSheet({required this.api, required this.post});
  @override State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  List<Map<String, dynamic>> _people   = [];
  final Set<String>          _selected = {};
  bool _loading = true, _sharing = false;

  @override void initState() { super.initState(); _loadTargets(); }

  Future<void> _loadTargets() async {
    try {
      final results = await Future.wait([
        widget.api.getStudyBuddies(),
        widget.api.getSuggestedUsers()]);
      final seen = <String>{}; final all = <Map<String, dynamic>>[];
      final buddiesRaw = results[0];
      final buddies = buddiesRaw is List
          ? buddiesRaw.cast<Map<String, dynamic>>()
          : ((buddiesRaw as Map<String, dynamic>?)?['results'] as List? ?? [])
              .cast<Map<String, dynamic>>();
      final suggested = (results[1] as List? ?? []).cast<Map<String, dynamic>>();
      for (final u in [...buddies, ...suggested]) {
        final id = u['user_id']?.toString() ?? u['id']?.toString() ?? '';
        if (id.isNotEmpty && seen.add(id)) all.add(u);
      }
      setState(() { _people = all; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _share() async {
    if (_selected.isEmpty || _sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    try {
      await widget.api.sharePost(
          widget.post['id']?.toString() ?? '', _selected.toList());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Shared with ${_selected.length} people ✓',
              style: const TextStyle(fontFamily: 'Momo')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kMint,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16)));
      }
    } catch (_) { setState(() => _sharing = false); }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.4,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(
            color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('Share Post', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
            const Spacer(),
            if (_selected.isNotEmpty)
              Text('${_selected.length} selected',
                style: const TextStyle(fontFamily: 'Arch', fontSize: 12,
                    color: _kViolet, fontWeight: FontWeight.bold)),
          ])),
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Share with followers or study buddies',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: _kSlate))),
        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade100),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kViolet))
            : _people.isEmpty
                ? Center(child: Text('Nobody to share with yet',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 13, color: _kSlate)))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _people.length,
                    itemBuilder: (_, i) {
                      final u   = _people[i];
                      final id  = u['user_id']?.toString()
                          ?? u['id']?.toString() ?? '';
                      final sel    = _selected.contains(id);
                      final name   = u['name']       as String? ?? '';
                      final role   = u['role']       as String? ?? '';
                      final avatar = u['avatar_url'] as String? ?? '';
                      final initial = name.isNotEmpty
                          ? name[0].toUpperCase() : '?';
                      return GestureDetector(
                        onTap: () => setState(() => sel
                            ? _selected.remove(id) : _selected.add(id)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          color: sel ? _kViolet.withOpacity(0.04)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Row(children: [
                            Container(width: 42, height: 42,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                      colors: [_kViolet, _kBlue])),
                              child: ClipOval(child: avatar.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: avatar, fit: BoxFit.cover,
                                      width: 42, height: 42,
                                      errorWidget: (_, __, ___) =>
                                          Center(child: Text(initial,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Arch',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16))))
                                  : Center(child: Text(initial,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Arch',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(name, style: const TextStyle(
                                  fontFamily: 'Arch',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, color: _kInk)),
                              if (role.isNotEmpty)
                                Text(role.replaceAll('_', ' '),
                                  style: TextStyle(fontFamily: 'Momo',
                                      fontSize: 12, color: _kSlate)),
                            ])),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: sel ? const LinearGradient(
                                    colors: [_kViolet, _kBlue]) : null,
                                border: sel ? null : Border.all(
                                    color: Colors.grey.shade300, width: 1.5)),
                              child: sel ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 13) : null),
                          ])));
                    })),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20,
              MediaQuery.of(context).padding.bottom + 16),
          child: GestureDetector(
            onTap: _selected.isEmpty ? null : _share,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                gradient: _selected.isNotEmpty
                    ? const LinearGradient(colors: [_kViolet, _kBlue],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight)
                    : const LinearGradient(
                        colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: _selected.isNotEmpty ? [BoxShadow(
                    color: _kViolet.withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 5))] : []),
              child: Center(child: _sharing
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      _selected.isEmpty
                          ? 'Select people to share'
                          : 'Share with ${_selected.length} '
                            '${_selected.length == 1 ? "person" : "people"}',
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, color: Colors.white,
                          fontSize: 14)))))),
      ]),
    ),
  );
}
