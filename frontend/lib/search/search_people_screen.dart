// lib/screens/search/search_people_screen.dart
//
// Phase 4 spec 8.3 — search people by name, ID, or filtered by role.
//
// The backend `/api/users/search/?q=...` already searches across name,
// preferred_name, username, and user_id (see apps/accounts/views.py
// search_users). We add a client-side role filter on top for the
// All / Students / Staff segmentation, since the backend's search view
// returns all roles unfiltered.
//
// Tapping a result opens UserProfileScreen (Phase 3).

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/user_screen_profile.dart';
import '../services/api_service.dart';


const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);

const _kRoleAll      = 'all';
const _kRoleStudent  = 'student';
const _kRoleStaff    = 'staff';

class SearchPeopleScreen extends StatefulWidget {
  const SearchPeopleScreen({super.key});

  @override
  State<SearchPeopleScreen> createState() => _SearchPeopleScreenState();
}

class _SearchPeopleScreenState extends State<SearchPeopleScreen> {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _roleFilter = _kRoleAll;
  bool   _loading = false;
  String _lastQuery = '';
  List<Map<String, dynamic>> _all = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _all = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty || q == _lastQuery) return;
    if (q.length < 2) {
      setState(() => _all = []);
      return;
    }
    _lastQuery = q;

    setState(() => _loading = true);
    try {
      final data = await _api.searchUsers(q) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _all = (data['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _all     = [];
      });
    }
  }

  void _setRole(String role) {
    if (_roleFilter == role) return;
    HapticFeedback.selectionClick();
    setState(() => _roleFilter = role);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_roleFilter == _kRoleAll) return _all;
    return _all.where((u) {
      final r = (u['role'] as String? ?? '').toLowerCase();
      if (_roleFilter == _kRoleStudent) return r == 'student';
      // staff = teaching_staff or non_teaching_staff
      return r.contains('staff') || r.contains('teaching');
    }).toList();
  }

  Future<void> _toggleFollow(int i, Map<String, dynamic> u) async {
    HapticFeedback.lightImpact();
    final id  = u['user_id']?.toString() ?? '';
    if (id.isEmpty) return;
    final was = u['is_following'] as bool? ?? false;

    // Update _all so the change persists across role filter switches.
    final allIdx = _all.indexWhere((x) => x['user_id']?.toString() == id);
    if (allIdx == -1) return;
    setState(() => _all[allIdx] = {..._all[allIdx], 'is_following': !was});

    try {
      await _api.followToggle(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _all[allIdx] = {..._all[allIdx], 'is_following': was});
    }
  }

  void _openProfile(Map<String, dynamic> u) {
    HapticFeedback.lightImpact();
    final id = u['user_id']?.toString() ?? '';
    if (id.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UserProfileScreen(userId: id, initial: u),
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
              gradient: const LinearGradient(colors: [_kG2, _kG4]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.people_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Search People',
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
            hintText: 'Search by name, preferred name, or ID...',
            hintStyle: TextStyle(
                fontFamily: 'Momo', fontSize: 13,
                color: _kSlate.withOpacity(0.5)),
            prefixIcon: const Icon(Icons.search_rounded, color: _kG2),
            suffixIcon: _ctrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _ctrl.clear();
                      setState(() => _all = []);
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

  Widget _buildFilterRow() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        children: [
          _filterChip('All',      _kRoleAll,     Icons.groups_rounded,         _kG2),
          const SizedBox(width: 8),
          _filterChip('Students', _kRoleStudent, Icons.school_rounded,         _kG1),
          const SizedBox(width: 8),
          _filterChip('Staff',    _kRoleStaff,   Icons.work_outline_rounded,   _kG3),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, IconData icon, Color tint) {
    final active = _roleFilter == value;
    return GestureDetector(
      onTap: () => _setRole(value),
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
        icon:    Icons.people_outline,
        title:   'Find people on campus',
        message: 'Type a name, preferred name, or ID to search.',
      );
    }
    if (_ctrl.text.trim().length < 2) {
      return _emptyHint(
        icon:    Icons.keyboard_rounded,
        title:   'Keep typing',
        message: 'At least 2 characters needed to search.',
      );
    }
    final results = _filtered;
    if (results.isEmpty) {
      return _emptyHint(
        icon:    Icons.person_search_rounded,
        title:   'No matches',
        message: _roleFilter == _kRoleAll
            ? 'Try a different name or check the spelling.'
            : 'No ${_roleFilter == _kRoleStudent ? "students" : "staff"} matched. Try "All".',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final u = results[i];
        return _PersonResultCard(
          user:        u,
          onTap:       () => _openProfile(u),
          onFollowTap: () => _toggleFollow(i, u),
        );
      },
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
// PERSON RESULT CARD
// ─────────────────────────────────────────────────────────────

class _PersonResultCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback onFollowTap;
  const _PersonResultCard({
    required this.user,
    required this.onTap,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final name        = user['name']         as String? ?? 'Unknown';
    final preferred   = user['preferred_name'] as String? ?? '';
    final role        = user['role']         as String? ?? '';
    final avatar      = user['avatar_url']   as String? ?? '';
    final isFollowing = user['is_following'] as bool?   ?? false;
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';

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
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_kG1, _kG2]),
            ),
            child: ClipOval(
              child: avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      width: 48, height: 48,
                      errorWidget: (_, __, ___) => _initialFallback(initial),
                    )
                  : _initialFallback(initial),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _kInk,
                      ),
                    ),
                  ),
                  if (preferred.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '"$preferred"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 11,
                          color: _kG2.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  _roleLabel(role),
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onFollowTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isFollowing ? null : const LinearGradient(
                  colors: [_kG1, _kG2],
                ),
                color: isFollowing ? Colors.grey.shade100 : null,
                borderRadius: BorderRadius.circular(10),
                border: isFollowing
                    ? Border.all(color: Colors.grey.shade300)
                    : null,
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isFollowing ? Colors.grey.shade600 : Colors.white,
                ),
              ),
            ),
          ),
        ]),
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
        fontSize: 18,
      ),
    ),
  );

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching Staff';
      case 'non_teaching_staff': return 'Non-Teaching Staff';
      case 'admin':              return 'Admin';
      case 'parent':             return 'Parent';
      case 'visitor':            return 'Visitor';
      default:                   return role.replaceAll('_', ' ');
    }
  }
}
