// lib/screens/staff/staff_feed_screen.dart
//
// Staff oversight feed — a read-only monitor of every post made on the platform
// (the global public firehose, newest first). Posts render with the SAME rich
// tile as the student feed (PlatformPostCard), and the search opens the SAME
// platform search screen, so staff see exactly what students see.
//   GET /posts/  (paginated, newest-first public posts)

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/feed/feed_screen.dart' show PlatformPostCard;
import 'package:tcs_app/search/search_screen.dart';

class StaffFeedScreen extends StatefulWidget {
  const StaffFeedScreen({super.key});

  @override
  State<StaffFeedScreen> createState() => _StaffFeedScreenState();
}

class _StaffFeedScreenState extends State<StaffFeedScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _end = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 400 &&
          !_loadingMore && !_end) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1; _end = false;
    } else {
      if (_loadingMore || _end) return;
      setState(() => _loadingMore = true);
    }
    try {
      final res = await _api.getPosts(page: _page);
      final list = (res is Map ? (res['results'] as List?) : (res as List?)) ?? [];
      final batch = list.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(batch);
        _loading = false;
        _loadingMore = false;
        if (batch.isEmpty) { _end = true; } else { _page++; }
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: const Color(0xFF7C3AED),
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _searchPill(),
            )),
            if (_loading)
              const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED))))
            else if (_posts.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i == _posts.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: _end
                            ? Text('That\'s everything',
                                style: TextStyle(fontFamily: 'Momo',
                                    fontSize: 11.5, color: AppC.faint))
                            : const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF7C3AED)))),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PlatformPostCard(post: _posts[i], index: i),
                    );
                  },
                  childCount: _posts.length + 1,
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchPill() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppC.border)),
        child: Row(children: [
          Icon(Icons.search_rounded, color: AppC.sub, size: 19),
          const SizedBox(width: 8),
          Text('Search posts, people, clubs & events…',
              style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.faint)),
        ]),
      ),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 22,
      horizontal: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20)),
          ),
          const Spacer(),
          const Icon(Icons.dynamic_feed_rounded, color: Colors.white70, size: 22),
        ]),
        const SizedBox(height: 14),
        const Text('Feed',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.visibility_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text('Every post made on the platform',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.dynamic_feed_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 12),
          Text('No posts yet',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
                  color: AppC.text)),
          const SizedBox(height: 6),
          Text('When students post, it shows up here.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                  color: AppC.sub)),
        ]),
      );
}
