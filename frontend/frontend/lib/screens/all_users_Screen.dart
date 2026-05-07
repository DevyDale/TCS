// lib/screens/feed/all_users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kBg     = Color(0xFFF4F5F9);
const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});
  @override State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen>
    with SingleTickerProviderStateMixin {
  final _api        = ApiService();
  final _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading  = true;
  String _filter = 'all'; // 'all' | 'student' | 'staff'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _filter = ['all', 'student', 'staff'][_tabCtrl.index];
          _applyFilter();
        });
      }
    });
    _loadUsers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      // Load suggested users + search for empty string to get all users
      final results = await Future.wait([
        _api.getSuggestedUsers(limit: 100),
        _api.searchUsers('a'),
        _api.searchUsers('e'),
        _api.searchUsers('i'),
      ]);

      final seen = <String>{};
      final all  = <Map<String, dynamic>>[];

      for (final result in results) {
        List<Map<String, dynamic>> users = [];
        if (result is List) {
          users = result.cast<Map<String, dynamic>>();
        } else if (result is Map) {
          users = ((result['results'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
        }
        for (final u in users) {
          final id = u['user_id']?.toString() ?? u['id']?.toString() ?? '';
          if (id.isNotEmpty && seen.add(id)) all.add(u);
        }
      }

      setState(() {
        _all      = all;
        _filtered = all;
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((u) {
        final name = (u['name'] ?? u['display_name'] ?? '').toString().toLowerCase();
        final role = (u['role'] ?? '').toString().toLowerCase();
        final matchesSearch = q.isEmpty || name.contains(q);
        final matchesTab = _filter == 'all' ||
            (_filter == 'student' && role == 'student') ||
            (_filter == 'staff' && (role.contains('staff') || role.contains('teaching')));
        return matchesSearch && matchesTab;
      }).toList();
    });
  }

  Future<void> _toggleFollow(int i) async {
    HapticFeedback.mediumImpact();
    final u   = _filtered[i];
    final id  = u['user_id']?.toString() ?? u['id']?.toString() ?? '';
    final was = u['is_following'] as bool? ?? false;
    // Update in both lists
    final allIdx = _all.indexWhere((x) =>
        (x['user_id'] ?? x['id']).toString() == id);
    setState(() {
      _filtered[i] = {..._filtered[i], 'is_following': !was};
      if (allIdx != -1) _all[allIdx] = {..._all[allIdx], 'is_following': !was};
    });
    try {
      await _api.followToggle(id);
    } catch (_) {
      setState(() {
        _filtered[i] = {..._filtered[i], 'is_following': was};
        if (allIdx != -1) _all[allIdx] = {..._all[allIdx], 'is_following': was};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [

        // ── Header ─────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kIndigo, _kDeep, Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft:  Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [

                // Back + title
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('All Members',
                        style: TextStyle(fontFamily: 'Alfa',
                            fontSize: 20, color: Colors.white)),
                    Text('${_all.length} people on campus',
                        style: TextStyle(fontFamily: 'Momo',
                            fontSize: 11, color: Colors.white.withOpacity(0.65))),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      '${_filtered.length} shown',
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 11, color: Colors.white),
                    ),
                  ),
                ]),

                const SizedBox(height: 14),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _applyFilter(),
                    style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      hintStyle: TextStyle(
                          fontFamily: 'Momo', color: Colors.grey.shade400,
                          fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Colors.grey.shade400, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _applyFilter();
                              },
                              child: Icon(Icons.close_rounded,
                                  color: Colors.grey.shade400, size: 18))
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: _kIndigo,
                    unselectedLabelColor: Colors.white.withOpacity(0.7),
                    labelStyle: const TextStyle(
                        fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 12),
                    unselectedLabelStyle: const TextStyle(
                        fontFamily: 'Arch', fontSize: 12),
                    tabs: [
                      Tab(text: 'All  (${_all.length})'),
                      Tab(text: 'Students'),
                      Tab(text: 'Staff'),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── User list ───────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🔍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('No results',
                          style: TextStyle(fontFamily: 'Alfa',
                              fontSize: 18, color: _kInk)),
                      const SizedBox(height: 6),
                      Text('Try a different search or filter',
                          style: TextStyle(fontFamily: 'Momo',
                              fontSize: 13, color: Colors.grey.shade400)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _UserTile(
                        user:     _filtered[i],
                        onFollow: () => _toggleFollow(i),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// User tile — horizontal card for the list
// ─────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onFollow;
  const _UserTile({required this.user, required this.onFollow});

  static List<Color> _gradient(String role) {
    switch (role.toLowerCase()) {
      case 'student':            return [Color(0xFF6DD5FA), Color(0xFF2575FC)];
      case 'teaching_staff':     return [Color(0xFF8E54E9), Color(0xFF43C6AC)];
      case 'non_teaching_staff': return [Color(0xFFF7971E), Color(0xFFFF5858)];
      default:                   return [Color(0xFF868F96), Color(0xFF596164)];
    }
  }

  static String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching Staff';
      case 'non_teaching_staff': return 'Non-Teaching Staff';
      default:                   return role.replaceAll('_', ' ');
    }
  }

  static IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'student':            return Icons.school_rounded;
      case 'teaching_staff':     return Icons.badge_rounded;
      case 'non_teaching_staff': return Icons.work_rounded;
      default:                   return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name        = user['name']            as String? ?? user['display_name'] as String? ?? 'Unknown';
    final role        = user['role']            as String? ?? '';
    final avatarUrl   = user['avatar_url']      as String? ?? '';
    final isFollowing = user['is_following']    as bool?   ?? false;
    final followers   = user['followers_count'] as int?    ?? 0;
    final isOnline    = user['is_online']       as bool?   ?? false;
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final gradient    = _gradient(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [

          // Avatar
          Stack(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: avatarUrl.isEmpty
                  ? Center(child: Text(initial, style: const TextStyle(
                      color: Colors.white, fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 20)))
                  : null,
            ),
            if (isOnline)
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  width: 13, height: 13,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ]),

          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 14, color: _kInk)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(_roleIcon(role), size: 11, color: gradient.last),
                const SizedBox(width: 4),
                Flexible(child: Text(_roleLabel(role),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                        color: gradient.last))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.people_outline_rounded,
                    size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Text(
                  followers > 0 ? '$followers followers' : 'No followers yet',
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              ]),
            ],
          )),

          const SizedBox(width: 10),

          // Follow button
          GestureDetector(
            onTap: onFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: isFollowing ? null : LinearGradient(
                    colors: gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                color: isFollowing ? Colors.grey.shade100 : null,
                borderRadius: BorderRadius.circular(12),
                border: isFollowing
                    ? Border.all(color: Colors.grey.shade300)
                    : null,
                boxShadow: isFollowing ? null : [
                  BoxShadow(color: gradient.last.withOpacity(0.3),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                  size: 13,
                  color: isFollowing ? Colors.grey.shade500 : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isFollowing ? 'Following' : 'Connect',
                  style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isFollowing ? Colors.grey.shade500 : Colors.white,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}