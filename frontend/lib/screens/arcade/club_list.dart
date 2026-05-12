// lib/screens/clubs/clubs_list_screen.dart
//
// Phase 5 Slice 2 — Clubs discovery + management screen.
//
// Three filter modes (chip row across the top):
//   • Discover — public clubs you haven't joined
//   • My Clubs — clubs where you're an active member
//   • Pending  — your join requests awaiting approval
//
// Plus a category chip strip below to narrow results, and a FAB to
// create a new club.

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'club_screen.dart';
import 'create_club_page.dart';

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

const _kFilterDiscover = 'all';
const _kFilterMine     = 'mine';
const _kFilterPending  = 'pending';

const _kCatAll = 'all';
const _kCats = <Map<String, String>>[
  {'value': _kCatAll,         'label': 'All'},
  {'value': 'academic',       'label': 'Academic'},
  {'value': 'sports',         'label': 'Sports'},
  {'value': 'arts',           'label': 'Arts'},
  {'value': 'cultural',       'label': 'Cultural'},
  {'value': 'technology',     'label': 'Technology'},
  {'value': 'social_service', 'label': 'Social Service'},
  {'value': 'business',       'label': 'Business'},
  {'value': 'gaming',         'label': 'Gaming'},
  {'value': 'other',          'label': 'Other'},
];

class ClubsListScreen extends StatefulWidget {
  const ClubsListScreen({super.key});
  @override
  State<ClubsListScreen> createState() => _ClubsListScreenState();
}

class _ClubsListScreenState extends State<ClubsListScreen> {
  final _api = ApiService();

  String _filter   = _kFilterDiscover;
  String _category = _kCatAll;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool   _loading  = true;
  bool   _refreshing = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _runQuery();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _runQuery() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await _api.getClubs(
        filter:   _filter,
        category: _category == _kCatAll ? null : _category,
      );
      if (!mounted) return;
      final list = (data is Map && data['results'] is List)
          ? (data['results'] as List).cast<Map<String, dynamic>>()
          : (data is List
              ? data.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[]);
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _runQuery();
    if (mounted) setState(() => _refreshing = false);
  }

  void _setFilter(String f) {
    if (_filter == f) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = f);
    _runQuery();
  }

  void _setCategory(String c) {
    if (_category == c) return;
    HapticFeedback.selectionClick();
    setState(() => _category = c);
    _runQuery();
  }

  void _openClub(Map<String, dynamic> club) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) =>
                ClubScreen(id: club['id']?.toString(), club: club)))
        .then((_) => _runQuery());
  }

  Future<void> _openCreate() async {
    HapticFeedback.lightImpact();
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CreateClubPage()));
    if (created != null && mounted) {
      // Jump straight to the new club
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ClubScreen(id: created['id']?.toString(), club: created)));
      await _runQuery();
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _kIndigo,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Club',
          style: TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildFilterRow(),
          _buildSearchBar(),
          _buildCategoryRow(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            width: 38, height: 38,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _kIndigo.withOpacity(0.30),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.groups_rounded,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'CAMPUS COMMUNITIES',
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    color: _kIndigo,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Clubs',
                    style: TextStyle(
                      fontFamily: 'Alfa',
                      fontSize: 24,
                      color: _kInk,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode filter row ───────────────────────────────────────

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(children: [
        _modeChip('Discover',  _kFilterDiscover, Icons.explore_rounded),
        const SizedBox(width: 8),
        _modeChip('My Clubs',  _kFilterMine,     Icons.bookmark_rounded),
        const SizedBox(width: 8),
        _modeChip('Pending',   _kFilterPending,  Icons.hourglass_top_rounded),
      ]),
    );
  }

  Widget _modeChip(String label, String value, IconData icon) {
    final active = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFilter(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [_kIndigo, _kDeep])
                : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.transparent : Colors.grey.shade200,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13,
                  color: active ? Colors.white : _kIndigo),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: active ? Colors.white : _kInk,
                  )),
            ],
          ),
        ),
      ),
    );
  }


  // ── Search bar ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 3))]),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
          style: const TextStyle(fontFamily: 'Momo', fontSize: 14, color: _kInk),
          decoration: InputDecoration(
            hintText: 'Search clubs by name or tagline...',
            hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                color: _kSlate.withOpacity(0.5)),
            prefixIcon: const Icon(Icons.search_rounded, color: _kIndigo),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchCtrl.clear();
                        setState(() => _searchQuery = ''); },
                    child: Icon(Icons.close_rounded, color: Colors.grey.shade400))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Category filter row ───────────────────────────────────

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        itemCount: _kCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat   = _kCats[i];
          final value = cat['value']!;
          final label = cat['label']!;
          final active = _category == value;
          return GestureDetector(
            onTap: () => _setCategory(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? _kG2 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _kG2 : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: active ? Colors.white : _kInk,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredResults {
    if (_searchQuery.isEmpty) return _results;
    return _results.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final tag  = (c['tagline'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) || tag.contains(_searchQuery);
    }).toList();
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kIndigo));
    }

    if (_results.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: _kIndigo,
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filteredResults.length,
        itemBuilder: (_, i) =>
            _ClubCard(club: _filteredResults[i], onTap: () => _openClub(_filteredResults[i])),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String message;
    IconData icon;
    switch (_filter) {
      case _kFilterMine:
        icon    = Icons.bookmark_outline_rounded;
        title   = 'No clubs yet';
        message = 'Tap "Discover" to browse clubs and join one.';
        break;
      case _kFilterPending:
        icon    = Icons.hourglass_empty_rounded;
        title   = 'No pending requests';
        message = 'Requests you make to private clubs will show up here.';
        break;
      default:
        icon    = Icons.search_off_rounded;
        title   = 'No clubs found';
        message = _category == _kCatAll
            ? 'Try a different category, or be the first to create a club.'
            : 'No clubs in this category yet.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.5,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CLUB CARD
// ─────────────────────────────────────────────────────────────

class _ClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final VoidCallback onTap;
  const _ClubCard({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name        = club['name']           as String? ?? 'Club';
    final tagline     = club['tagline']        as String? ?? '';
    final category    = club['category']       as String? ?? '';
    final coverUrl    = club['cover_url']      as String?;
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover banner ───────────────────────────────
            SizedBox(
              height: 86,
              width:  double.infinity,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _coverFallback(),
                      placeholder:  (_, __)     => _coverFallback(),
                    )
                  : _coverFallback(),
            ),

            // ── Body ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 6, offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(width: 12),

                  // Name + tagline + meta
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
                                  fontFamily: 'Alfa',
                                  fontSize: 15,
                                  color: _kInk,
                                )),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.verified_rounded,
                                  color: _kVerified, size: 14),
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
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(tagline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                height: 1.4,
                              )),
                        ],
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _miniChip(
                            '$memberCount '
                                'member${memberCount == 1 ? "" : "s"}',
                            _kIndigo,
                          ),
                          if (category.isNotEmpty)
                            _miniChip(_titleCase(category), _kG2),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // State badge
                  _buildStateBadge(
                      isAdmin: isAdmin,
                      isMember: isMember,
                      isPending: isPending),
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
            colors: [_kIndigo, _kDeep],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
        ),
      );

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

  Widget _miniChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: color,
            )),
      );

  Widget _buildStateBadge({
    required bool isAdmin,
    required bool isMember,
    required bool isPending,
  }) {
    if (isAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _kIndigo,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: 11),
          SizedBox(width: 4),
          Text('ADMIN',
              style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 9,
                color: Colors.white,
                letterSpacing: 0.5,
              )),
        ]),
      );
    }
    if (isMember) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_rounded,
              color: Colors.green.shade700, size: 11),
          const SizedBox(width: 4),
          Text('JOINED',
              style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 9,
                color: Colors.green.shade700,
                letterSpacing: 0.5,
              )),
        ]),
      );
    }
    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _kG3.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kG3.withOpacity(0.30)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_top_rounded, color: _kG3, size: 11),
          SizedBox(width: 4),
          Text('PENDING',
              style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 9,
                color: _kG3,
                letterSpacing: 0.5,
              )),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('VIEW',
          style: TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 9,
            color: Colors.white,
            letterSpacing: 0.5,
          )),
    );
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}
