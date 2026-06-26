// lib/screens/staff/staff_feed_screen.dart
//
// Staff oversight feed — a read-only monitor of what students are posting
// across the platform (the global public firehose, newest first). This is a
// deliberately staff-shaped view: compact monitoring cards with author, role,
// time, content, media and engagement — NOT the student composing/feed UI.
//   GET /posts/  (paginated, newest-first public posts)

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class StaffFeedScreen extends StatefulWidget {
  const StaffFeedScreen({super.key});

  @override
  State<StaffFeedScreen> createState() => _StaffFeedScreenState();
}

class _StaffFeedScreenState extends State<StaffFeedScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _query = '';
  final List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _end = false;
  int _page = 1;

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _posts;
    return _posts.where((p) {
      final hay = '${p['author_name']} ${p['text']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

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
    _search.dispose();
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

  String _ago(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'teaching_staff':
      case 'non_teaching_staff': return 'Staff';
      case 'admin': return 'Admin';
      default: return 'Student';
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
            if (!_loading)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: StaffSearchBar(
                    controller: _search,
                    hint: 'Search posts & authors…',
                    onChanged: (v) => setState(() => _query = v)),
              )),
            if (_loading)
              const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED))))
            else if (_posts.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty())
            else if (_filtered.isEmpty)
              SliverToBoxAdapter(child: staffNoResults('No posts match.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final list = _filtered;
                    if (i == list.length) {
                      // Only paginate when not actively filtering.
                      if (_query.isNotEmpty) return const SizedBox.shrink();
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
                      child: _postCard(list[i]),
                    );
                  },
                  childCount: _filtered.length + 1,
                )),
              ),
          ],
        ),
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
          Text('What students are posting on the platform',
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

  Widget _postCard(Map<String, dynamic> p) {
    final name = (p['author_name'] ?? 'Student').toString();
    final role = (p['author_role'] ?? 'student').toString();
    final avatar = (p['author_avatar'] ?? '').toString();
    final text = (p['text'] ?? '').toString();
    final media = (p['media'] as List?) ?? const [];
    final likes = (p['like_count'] as int?) ?? 0;
    final comments = (p['comment_count'] as int?) ?? 0;
    final isStaff = role != 'student';

    return Container(
      decoration: staffCard(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _avatar(avatar, name),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Flexible(child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Arch', fontSize: 13.5,
                        fontWeight: FontWeight.bold, color: AppC.text))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isStaff ? const Color(0xFF7C3AED)
                        : AppC.faint).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(_roleLabel(role),
                      style: TextStyle(fontFamily: 'Arch', fontSize: 8.5,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5,
                          color: isStaff ? const Color(0xFF7C3AED) : AppC.sub)),
                ),
              ]),
              Text(_ago((p['created_at'] ?? '').toString()),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                      color: AppC.faint)),
            ],
          )),
        ]),
        if (text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(text,
              style: TextStyle(fontFamily: 'Momo', fontSize: 13, height: 1.4,
                  color: AppC.text.withValues(alpha: 0.9))),
        ],
        if (media.isNotEmpty) ...[
          const SizedBox(height: 10),
          _mediaThumb((media.first as Map).cast<String, dynamic>()),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.favorite_rounded, size: 14, color: AppC.faint),
          const SizedBox(width: 4),
          Text('$likes', style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: AppC.sub)),
          const SizedBox(width: 16),
          Icon(Icons.mode_comment_rounded, size: 13, color: AppC.faint),
          const SizedBox(width: 4),
          Text('$comments', style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: AppC.sub)),
        ]),
      ]),
    );
  }

  Widget _avatar(String url, String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
        image: url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null),
      alignment: Alignment.center,
      child: url.isNotEmpty ? null : Text(initial,
          style: const TextStyle(fontFamily: 'Alfa', fontSize: 15,
              color: Color(0xFF7C3AED))),
    );
  }

  Widget _mediaThumb(Map<String, dynamic> m) {
    final isVideo = (m['media_type'] ?? '') == 'video';
    final url = (isVideo ? (m['thumbnail_url'] ?? m['url']) : m['url'] ?? '')
        .toString();
    if (url.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(alignment: Alignment.center, children: [
        Image.network(url,
            width: double.infinity, height: 180, fit: BoxFit.cover,
            loadingBuilder: (c, child, prog) => prog == null ? child
                : Container(height: 180, color: AppC.card2,
                    child: const Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
            errorBuilder: (c, e, s) => Container(height: 120, color: AppC.card2,
                child: Icon(Icons.broken_image_rounded, color: AppC.faint))),
        if (isVideo)
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 28)),
      ]),
    );
  }
}
