// lib/screens/search/search_clubs_screen.dart
//
// Phase 5 Slice 2 — REPOINTED from /api/groups/ to /api/clubs/.
//
// Changes vs Phase 4:
//   • Calls api.getClubs(...) instead of api.get('/groups/', ...)
//   • Card uses the new club fields: cover_url, logo_url, tagline,
//     is_verified, members_count, membership.is_member
//   • Tap opens ClubScreen (Phase 5) — NOT the old GroupScreen
//   • Categories list updated to match the new Club.Category enum
//
// The old `groups` study-groups module remains untouched and is
// reachable via its own list screen.

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/club_screen.dart';

import '../../services/api_service.dart';

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);
const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);
const _kVerified = Color(0xFF1DA1F2);

const _kCatAll = 'all';

// Categories now match apps.clubs.Club.Category (Phase 5 backend).
const _kCats = <Map<String, String>>[
  {'value': _kCatAll,         'label': 'All'},
  {'value': 'academic',       'label': 'Academic'},
  {'value': 'sports',         'label': 'Sports'},
  {'value': 'arts',           'label': 'Arts'},
  {'value': 'cultural',       'label': 'Cultural'},
  {'value': 'technology',     'label': 'Tech'},
  {'value': 'social_service', 'label': 'Social Service'},
  {'value': 'business',       'label': 'Business'},
  {'value': 'gaming',         'label': 'Gaming'},
  {'value': 'other',          'label': 'Other'},
];

class SearchClubsScreen extends StatefulWidget {
  const SearchClubsScreen({super.key});

  @override
  State<SearchClubsScreen> createState() => _SearchClubsScreenState();
}

class _SearchClubsScreenState extends State<SearchClubsScreen> {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _category  = _kCatAll;
  bool   _loading   = false;
  String _lastQuery = '';
  String _lastCat   = '';
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    // Show popular public clubs immediately, even before any input.
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    if (q == _lastQuery && _category == _lastCat) return;
    _lastQuery = q;
    _lastCat   = _category;

    setState(() => _loading = true);
    try {
      // ─── REPOINTED — calls /api/clubs/ via the new wrapper ───
      final data = await _api.getClubs(
        filter:   'all',
        q:        q.isNotEmpty ? q : null,
        category: _category == _kCatAll ? null : _category,
      );

      final list = (data is Map && data['results'] is List)
          ? (data['results'] as List).cast<Map<String, dynamic>>()
          : (data is List
              ? data.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[]);

      if (!mounted) return;
      setState(() {
        _results = list;
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

  void _setCategory(String cat) {
    if (_category == cat) return;
    HapticFeedback.selectionClick();
    setState(() => _category = cat);
    _runSearch();
  }

  void _openClub(Map<String, dynamic> club) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClubScreen(id: club['id']?.toString(), club: club),
    ));
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
          _buildCategoryRow(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.groups_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Text('Search Clubs',
            style: TextStyle(
              fontFamily: 'Alfa',
              fontSize: 19,
              color: _kInk,
            )),
      ]),
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
          style: const TextStyle(
              fontFamily: 'Momo', fontSize: 14, color: _kInk),
          decoration: InputDecoration(
            hintText: 'Search clubs by name or tagline...',
            hintStyle: TextStyle(
              fontFamily: 'Momo',
              fontSize: 13,
              color: _kSlate.withOpacity(0.5),
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: _kIndigo),
            suffixIcon: _ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      _runSearch();
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

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        itemCount: _kCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat    = _kCats[i];
          final value  = cat['value']!;
          final label  = cat['label']!;
          final active = _category == value;
          return GestureDetector(
            onTap: () => _setCategory(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _kIndigo : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active ? _kIndigo : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _kIndigo.withOpacity(0.25),
                          blurRadius: 8, offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(label,
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: active ? Colors.white : _kInk,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kIndigo));
    }
    if (_results.isEmpty) {
      final isSearching =
          _ctrl.text.trim().isNotEmpty || _category != _kCatAll;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.groups_outlined,
                size: 56, color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(isSearching ? 'No matching clubs' : 'No clubs yet',
                  style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
              const SizedBox(height: 6),
              Text(
                isSearching
                    ? 'Try a different name, or pick a different category.'
                    : 'Be the first — tap the "+ New Club" button on the clubs list.',
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _results.length,
      itemBuilder: (_, i) => _ClubResultCard(
        club:  _results[i],
        onTap: () => _openClub(_results[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CLUB RESULT CARD — uses Phase 5 fields
// ─────────────────────────────────────────────────────────────

class _ClubResultCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _ClubResultCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name        = club['name']           as String? ?? 'Unnamed';
    final tagline     = club['tagline']        as String? ?? '';
    final category    = club['category']       as String? ?? '';
    final logoUrl     = club['logo_url']       as String?;
    final memberCount = club['members_count']  as int?    ?? 0;
    final isVerified  = club['is_verified']    as bool?   ?? false;
    final isPublic    = club['is_public']      as bool?   ?? true;

    final membership = (club['membership'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final isMember  = membership['is_member']  == true;
    final isPending = membership['is_pending'] == true;
    final isAdmin   = membership['is_admin']   == true;

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _kIndigo.withOpacity(0.10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _logoFallback(initial),
                        placeholder:  (_, __)     => _logoFallback(initial),
                      )
                    : _logoFallback(initial),
              ),
            ),
            const SizedBox(width: 12),

            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _kInk,
                          )),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.verified_rounded,
                            color: _kVerified, size: 13),
                      ),
                    ],
                    if (!isPublic) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.lock_rounded,
                            size: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(_metaLine(memberCount, category),
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      )),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 12,
                          color: _kInk,
                          height: 1.4,
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildBadge(
                isAdmin: isAdmin,
                isMember: isMember,
                isPending: isPending),
          ],
        ),
      ),
    );
  }

  Widget _logoFallback(String initial) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kG2, _kG1],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
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

  Widget _buildBadge({
    required bool isAdmin,
    required bool isMember,
    required bool isPending,
  }) {
    String label;
    Color  bg;
    Color  fg;
    bool   gradient = false;
    if (isAdmin) {
      label = 'Admin';   bg = _kIndigo; fg = Colors.white; gradient = true;
    } else if (isMember) {
      label = 'Joined';  bg = Colors.green.shade50; fg = Colors.green.shade700;
    } else if (isPending) {
      label = 'Pending'; bg = _kG3.withOpacity(0.10); fg = _kG3;
    } else {
      label = 'View';    bg = _kIndigo; fg = Colors.white; gradient = true;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient ? const LinearGradient(
            colors: [_kIndigo, _kDeep]) : null,
        color: gradient ? null : bg,
        borderRadius: BorderRadius.circular(10),
        border: !gradient ? Border.all(
            color: fg.withOpacity(isMember ? 0.30 : 0.20)) : null,
      ),
      child: Text(label,
          style: TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: fg,
          )),
    );
  }

  String _metaLine(int memberCount, String category) {
    final parts = <String>[];
    parts.add('$memberCount member${memberCount == 1 ? "" : "s"}');
    if (category.isNotEmpty) parts.add(_titleCase(category));
    return parts.join(' · ');
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}
