// lib/screens/search/search_posts_screen.dart
//
// Phase 4 spec 8.2 — search posts by caption or location.
//
// User picks a filter (Caption / Location / All) via a small chip row.
// The query is sent to GET /api/posts/search/?q=...&field=...
// (added in Phase 4 backend patch).

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';


const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);

const _kFieldAll      = 'all';
const _kFieldCaption  = 'caption';
const _kFieldLocation = 'location';

class SearchPostsScreen extends StatefulWidget {
  const SearchPostsScreen({super.key});

  @override
  State<SearchPostsScreen> createState() => _SearchPostsScreenState();
}

class _SearchPostsScreenState extends State<SearchPostsScreen> {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _field   = _kFieldAll;
  bool   _loading = false;
  String _lastQuery = '';
  String _lastField = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    if (q == _lastQuery && _field == _lastField) return;
    _lastQuery = q;
    _lastField = _field;

    setState(() => _loading = true);
    try {
      final data = await _api.get('/posts/search/', query: {
        'q':     q,
        'field': _field,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _results = (data['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = [];
      });
    }
  }

  void _setField(String field) {
    if (_field == field) return;
    HapticFeedback.selectionClick();
    setState(() => _field = field);
    if (_ctrl.text.trim().isNotEmpty) _runSearch();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          _buildSearchBar(),
          _buildFilterRow(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kG1, _kG2]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.article_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const T(
            'Search Posts',
            style: TextStyle(
              fontFamily: 'Alfa',
              fontSize: 19,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          enableSuggestions: false,
          autocorrect: false,
          onChanged: _onChanged,
          style: const TextStyle(fontFamily: 'Momo', fontSize: 14, color: _kInk),
          decoration: InputDecoration(
            hintText: _hintForField(),
            hintStyle: TextStyle(
                fontFamily: 'Momo', fontSize: 13,
                color: _kSlate.withOpacity(0.5)),
            prefixIcon: const Icon(Icons.search_rounded, color: _kG2),
            suffixIcon: _ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      setState(() => _results = []);
                    },
                    child: Icon(Icons.close_rounded,
                        color: Colors.grey.shade400),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  String _hintForField() {
    switch (_field) {
      case _kFieldCaption:  return 'Search post captions...';
      case _kFieldLocation: return 'Search by location...';
      default:              return 'Search posts...';
    }
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        children: [
          _filterChip('All',      _kFieldAll,      Icons.all_inclusive_rounded, _kG2),
          const SizedBox(width: 8),
          _filterChip('Caption',  _kFieldCaption,  Icons.text_snippet_rounded,  _kG1),
          const SizedBox(width: 8),
          _filterChip('Location', _kFieldLocation, Icons.location_on_rounded,   _kG3),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, IconData icon, Color tint) {
    final active = _field == value;
    return GestureDetector(
      onTap: () => _setField(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? tint : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? tint : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: active ? [
            BoxShadow(
              color: tint.withOpacity(0.25),
              blurRadius: 8, offset: const Offset(0, 3),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: active ? Colors.white : tint),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: active ? Colors.white : _kInk,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_ctrl.text.trim().isEmpty) {
      return _emptyHint(
        icon:    Icons.article_outlined,
        title:   'Start typing',
        message: _field == _kFieldLocation
            ? 'Find posts mentioning a place — "library", "Block A"…'
            : _field == _kFieldCaption
                ? 'Search inside post captions for any phrase.'
                : 'Search captions and locations together.',
      );
    }
    if (_results.isEmpty) {
      return _emptyHint(
        icon:    Icons.search_off_rounded,
        title:   'No matching posts',
        message: 'Try a different word, or switch to "All" to widen the search.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _results.length,
      itemBuilder: (_, i) => _PostResultCard(post: _results[i]),
    );
  }

  Widget _emptyHint({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 18,
              color: _kInk,
            )),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POST RESULT CARD
// ─────────────────────────────────────────────────────────────

class _PostResultCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostResultCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author   = post['author_name']   as String? ?? 'Unknown';
    final avatar   = post['author_avatar'] as String? ?? '';
    final content  = post['content']       as String? ?? '';
    final location = post['location']      as String? ?? '';
    final type     = post['post_type']     as String? ?? 'post';
    final likes    = post['like_count']    as int?    ?? 0;
    final comments = post['comment_count'] as int?    ?? 0;
    final initial  = author.isNotEmpty ? author[0].toUpperCase() : '?';

    final media = (post['media'] as List? ?? []).cast<Map<String, dynamic>>();
    final firstUrl = media.isNotEmpty
        ? (media.first['url'] as String? ?? '')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_kG1, _kG2]),
              ),
              child: ClipOval(
                child: avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        width: 36, height: 36,
                        errorWidget: (_, __, ___) => _initialFallback(initial),
                      )
                    : _initialFallback(initial),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _kInk,
                    ),
                  ),
                  Text(
                    _typeLabel(type),
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (type == 'fweet')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kG4.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const T(
                  '⚡ Fweet',
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: _kG4,
                  ),
                ),
              ),
          ]),
          if (firstUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: firstUrl,
                width: double.infinity, height: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    height: 140, color: const Color(0xFFEDEEF3)),
                errorWidget: (_, __, ___) => Container(
                    height: 140, color: const Color(0xFFEDEEF3)),
              ),
            ),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Momo',
                fontSize: 13,
                color: _kInk,
                height: 1.45,
              ),
            ),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_rounded, size: 13, color: _kG3),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.favorite_outline_rounded,
                size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('$likes', style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 11,
              color: Colors.grey.shade400,
            )),
            const SizedBox(width: 14),
            Icon(Icons.chat_bubble_outline_rounded,
                size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('$comments', style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 11,
              color: Colors.grey.shade400,
            )),
          ]),
        ],
      ),
    );
  }

  Widget _initialFallback(String initial) => Center(
    child: Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Arch',
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );

  String _typeLabel(String type) {
    switch (type) {
      case 'fweet':         return 'Fweet';
      case 'announcement':  return 'Announcement';
      case 'arcade_clip':   return 'Arcade Clip';
      default:              return 'Post';
    }
  }
}
