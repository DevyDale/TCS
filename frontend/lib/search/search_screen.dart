// lib/screens/search_screen.dart
//
// §8 Search refactor.
//
// Old layout: three tabs (Posts / People / Groups) all searched at once.
// New layout: a "mode-first" picker —
//   • A pill strip lets the user choose ONE search mode from
//     Posts / People / Clubs / Events.
//   • A filter-chip strip below the pills shows filters relevant to
//     the active mode (e.g. date for Posts, role for People, theme
//     for Clubs, category+date for Events).
//   • A single results list below renders only the active mode.
//
// Backend reality: there is no separate Clubs app yet — clubs live
// inside the existing `groups` table as `category='club'`. This screen
// filters the search response client-side to only show those rows in
// the Clubs mode. Other study groups are searched via the dedicated
// Study Hub search screen, not here.
//
// Cross-role separation (post-staff-role-restoration):
//   • In PEOPLE mode, students can't see staff and vice versa.
//     The "Students" filter chip is hidden from staff users; the
//     "Staff" chip is hidden from students.
//   • Posts, Clubs, and Events stay open across roles — clubs are
//     an explicit exception, and filtering posts/events by role
//     would hide legitimate cross-role content (announcements,
//     campus-wide events, club posts, etc.).
//   • The backend `search_users` view also enforces this for People.

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this

// Brand colours — kept consistent with the rest of the app.
const _kG1 = Color(0xFF6DD5FA);  // sky
const _kG2 = Color(0xFF8E54E9);  // purple
const _kG3 = Color(0xFFF7971E);  // amber
const _kG4 = Color(0xFFFF5858);  // coral
const _kInk = Color(0xFF1A1A2E);

/// Returns 'student', 'staff', or 'other' for a role string.
String _groupOf(String role) {
  final r = role.toLowerCase();
  if (r == 'student') return 'student';
  if (r == 'teaching_staff' || r == 'non_teaching_staff') return 'staff';
  return 'other';
}


// ─── Mode definitions ───────────────────────────────────────
class _ModeSpec {
  final String   key;
  final String   label;
  final IconData icon;
  final Color    color;
  const _ModeSpec(this.key, this.label, this.icon, this.color);
}

const _modes = [
  _ModeSpec('posts',  'Posts',  Icons.article_rounded,  _kG2),
  _ModeSpec('people', 'People', Icons.people_rounded,   _kG3),
  _ModeSpec('clubs',  'Clubs',  Icons.groups_2_rounded, _kG4),
  _ModeSpec('events', 'Events', Icons.event_rounded,    _kG1),
];


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _mode = 'posts';

  // Raw fetched data
  List<Map<String, dynamic>> _allPosts  = [];
  List<Map<String, dynamic>> _allPeople = [];
  List<Map<String, dynamic>> _allClubs  = [];
  List<Map<String, dynamic>> _allEvents = [];

  // Filter state per mode
  String _postsDate    = 'all';   // 'all' | 'today' | 'week' | 'month'
  String _peopleRole   = 'all';   // 'all' | 'student' | 'staff'
  String _clubsTheme   = 'all';   // 'all' | a theme key
  String _eventsDate   = 'all';   // 'all' | 'upcoming' | 'week' | 'month'
  String _eventsCat    = 'all';   // 'all' | category key

  bool   _loading   = false;
  String _lastQuery = '';

  /// Current viewer's role group: 'student' | 'staff' | 'other'.
  /// Drives cross-role filtering in People mode.
  String _myGroup = 'other';

  // ─── Lifecycle ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadMyGroup();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyGroup() async {
    final me = await ApiService.instance.cachedUser;
    if (!mounted) return;
    final role  = (me?['role'] as String?) ?? '';
    final group = _groupOf(role);
    setState(() {
      _myGroup = group;
      // If the People filter is currently set to a value the viewer
      // isn't allowed to use, reset it.
      if (group == 'student' && _peopleRole == 'staff') {
        _peopleRole = 'all';
      } else if (group == 'staff' && _peopleRole == 'student') {
        _peopleRole = 'all';
      }
    });
  }

  // ─── Search ────────────────────────────────────────────

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _allPosts = []; _allPeople = []; _allClubs = []; _allEvents = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400),
        () => _search(q.trim()));
  }
  Future<void> _search(String q) async {
    if (q == _lastQuery || q.isEmpty) return;
    _lastQuery = q;
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _api.get('/posts/search/', query: {'q': q}).catchError((_) => <String, dynamic>{}),
        _api.get('/search/people/', query: {'q': q}).catchError((_) => <String, dynamic>{}),
        _api.get('/groups/', query: {'q': q, 'category': 'club'}).catchError((_) => <String, dynamic>{}),
        _api.get('/events/', query: {'q': q}).catchError((_) => <String, dynamic>{}),
      ]);

      final postsData  = results[0] as Map<String, dynamic>? ?? {};
      final peopleData = results[1] as Map<String, dynamic>? ?? {};
      final groupsData = results[2] as Map<String, dynamic>? ?? {};
      final eventsData = results[3] as Map<String, dynamic>? ?? {};

      if (!mounted) return;

      setState(() {
        _allPosts  = (postsData['results']  as List? ?? []).cast<Map<String, dynamic>>();
        _allPeople = (peopleData['results'] as List? ?? []).cast<Map<String, dynamic>>();
        
        final allGroups = (groupsData['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _allClubs = allGroups.where((g) =>
            (g['category']?.toString() ?? '').toLowerCase() == 'club').toList();

        _allEvents = (eventsData['results'] as List? ?? eventsData['events'] as List? ?? [])
            .cast<Map<String, dynamic>>();

        _loading = false;
      });
    } catch (e) {
      print('Search error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
  // ─── Filtering ─────────────────────────────────────────

  List<Map<String, dynamic>> get _visibleResults {
    switch (_mode) {
      case 'posts':  return _filterPosts(_allPosts);
      case 'people': return _filterPeople(_allPeople);
      case 'clubs':  return _filterClubs(_allClubs);
      case 'events': return _filterEvents(_allEvents);
    }
    return const [];
  }

  int _countFor(String mode) {
    switch (mode) {
      case 'posts':  return _filterPosts(_allPosts).length;
      case 'people': return _filterPeople(_allPeople).length;
      case 'clubs':  return _filterClubs(_allClubs).length;
      case 'events': return _filterEvents(_allEvents).length;
    }
    return 0;
  }

  List<Map<String, dynamic>> _filterPosts(List<Map<String, dynamic>> src) {
    if (_postsDate == 'all') return src;
    final now = DateTime.now();
    final cutoff = switch (_postsDate) {
      'today' => DateTime(now.year, now.month, now.day),
      'week'  => now.subtract(const Duration(days: 7)),
      'month' => DateTime(now.year, now.month - 1, now.day),
      _       => DateTime(2000),
    };
    return src.where((p) {
      final raw = p['created_at']?.toString();
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw);
      return dt != null && dt.isAfter(cutoff);
    }).toList();
  }

  List<Map<String, dynamic>> _filterPeople(List<Map<String, dynamic>> src) {
    // Cross-role gate first: students never see staff and vice versa.
    Iterable<Map<String, dynamic>> base = src;
    if (_myGroup == 'student') {
      base = base.where(
          (u) => _groupOf(u['role']?.toString() ?? '') != 'staff');
    } else if (_myGroup == 'staff') {
      base = base.where(
          (u) => _groupOf(u['role']?.toString() ?? '') != 'student');
    }

    if (_peopleRole == 'all') return base.toList();
    return base.where((u) {
      final r = (u['role']?.toString() ?? '').toLowerCase();
      if (_peopleRole == 'student') return r.contains('student');
      if (_peopleRole == 'staff')   return r.contains('staff') || r.contains('teach');
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _filterClubs(List<Map<String, dynamic>> src) {
    if (_clubsTheme == 'all') return src;
    return src.where((g) =>
        (g['theme']?.toString() ?? '').toLowerCase() == _clubsTheme).toList();
  }

  List<Map<String, dynamic>> _filterEvents(List<Map<String, dynamic>> src) {
    Iterable<Map<String, dynamic>> r = src;
    if (_eventsCat != 'all') {
      r = r.where((e) =>
          (e['category']?.toString() ?? '').toLowerCase() == _eventsCat);
    }
    if (_eventsDate != 'all') {
      final now = DateTime.now();
      r = r.where((e) {
        final raw = (e['start_time'] ?? e['start_at'])?.toString();
        if (raw == null) return false;
        final dt = DateTime.tryParse(raw);
        if (dt == null) return false;
        switch (_eventsDate) {
          case 'upcoming': return dt.isAfter(now);
          case 'week':     return dt.isAfter(now) &&
                                  dt.isBefore(now.add(const Duration(days: 7)));
          case 'month':    return dt.isAfter(now) &&
                                  dt.isBefore(now.add(const Duration(days: 30)));
        }
        return true;
      });
    }
    return r.toList();
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        _buildSearchBar(),
        _buildModePills(),
        _buildFilterStrip(),
        const Divider(height: 1),
        Expanded(child: _buildResults()),
      ]),
    );
  }

  // ── Search bar ────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 8, right: 16, bottom: 12,
      ),
      color: Colors.white,
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_rounded,
                color: _kInk, size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              enableSuggestions: false,
              onChanged: _onChanged,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 15,
                  color: _kInk),
              decoration: InputDecoration(
                hintText: _hintForMode(),
                hintStyle: TextStyle(fontFamily: 'Momo',
                    color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey.shade400),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() {
                            _allPosts = []; _allPeople = [];
                            _allClubs = []; _allEvents = [];
                            _lastQuery = '';
                          });
                        },
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey.shade400))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  String _hintForMode() {
    switch (_mode) {
      case 'people': return 'Search people…';
      case 'clubs':  return 'Search clubs…';
      case 'events': return 'Search events…';
      case 'posts':
      default:       return 'Search posts…';
    }
  }

  // ── Mode pills ─────────────────────────────────────────

  Widget _buildModePills() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: SizedBox(height: 44, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m         = _modes[i];
          final selected  = _mode == m.key;
          final count     = _countFor(m.key);
          final hasResult = _ctrl.text.isNotEmpty;
          return GestureDetector(
            onTap: () => setState(() => _mode = m.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: [m.color, m.color.withOpacity(0.75)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: selected ? null : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.grey.shade200, width: 1.2),
                boxShadow: selected
                    ? [BoxShadow(color: m.color.withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(m.icon, size: 16,
                    color: selected ? Colors.white : m.color),
                const SizedBox(width: 6),
                Text(m.label, style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selected ? Colors.white : Colors.grey.shade700)),
                if (hasResult) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.25)
                          : m.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('$count',
                        style: TextStyle(fontFamily: 'Momo',
                            fontSize: 10, fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : m.color)),
                  ),
                ],
              ]),
            ),
          );
        },
      )),
    );
  }

  // ── Filter chip strip (varies per mode) ────────────────

  Widget _buildFilterStrip() {
    final List<(String, String)> chips;
    final String selected;
    final void Function(String) onSet;

    switch (_mode) {
      case 'posts':
        chips    = const [('all','All time'), ('today','Today'),
                          ('week','This week'), ('month','This month')];
        selected = _postsDate;
        onSet    = (v) => setState(() => _postsDate = v);
        break;
      case 'people':
        // Cross-role gate: hide the chip the viewer isn't allowed
        // to filter to. Students don't see "Staff", staff don't see
        // "Students".
        if (_myGroup == 'student') {
          chips = const [('all','Everyone'), ('student','Students')];
        } else if (_myGroup == 'staff') {
          chips = const [('all','Everyone'), ('staff','Staff')];
        } else {
          chips = const [('all','Everyone'), ('student','Students'),
                         ('staff','Staff')];
        }
        selected = _peopleRole;
        onSet    = (v) => setState(() => _peopleRole = v);
        break;
      case 'clubs':
        chips    = const [
          ('all','All'), ('sports','Sports'), ('arts','Arts'),
          ('technology','Tech'), ('mathematics','Math'),
          ('science','Science'), ('music','Music'),
          ('business','Business'), ('language','Language'),
          ('gaming','Gaming'), ('general','General'),
        ];
        selected = _clubsTheme;
        onSet    = (v) => setState(() => _clubsTheme = v);
        break;
      case 'events':
        // For events we render TWO strips (date + category) stacked.
        return Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(children: [
            _chipStrip(
              chips: const [('all','All time'), ('upcoming','Upcoming'),
                            ('week','This week'), ('month','This month')],
              selected: _eventsDate,
              onSet: (v) => setState(() => _eventsDate = v),
              color: _kG1,
            ),
            const SizedBox(height: 6),
            _chipStrip(
              chips: const [
                ('all','All'), ('academic','Academic'), ('sports','Sports'),
                ('club','Club'), ('social','Social'),
                ('arcade','Arcade'), ('other','Other'),
              ],
              selected: _eventsCat,
              onSet: (v) => setState(() => _eventsCat = v),
              color: _kG2,
            ),
          ]),
        );
      default:
        return const SizedBox(height: 8);
    }

    return Container(color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: _chipStrip(
        chips: chips, selected: selected, onSet: onSet,
        color: _modeColor(),
      ),
    );
  }

  Widget _chipStrip({
    required List<(String, String)> chips,
    required String selected,
    required void Function(String) onSet,
    required Color color,
  }) {
    return SizedBox(height: 30, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final c   = chips[i];
        final sel = selected == c.$1;
        return GestureDetector(
          onTap: () => onSet(c.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.12) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: sel ? color.withOpacity(0.4)
                             : Colors.grey.shade200,
                  width: 1.2),
            ),
            child: Text(c.$2,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? color : Colors.grey.shade600)),
          ),
        );
      },
    ));
  }

  Color _modeColor() {
    for (final m in _modes) {
      if (m.key == _mode) return m.color;
    }
    return _kG2;
  }

  // ── Results ─────────────────────────────────────────────
  Widget _buildResults() {
    if (_loading && _ctrl.text.isNotEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visibleResults;
    if (_ctrl.text.isEmpty) {
      return _emptyState('Search ${_modeLabel().toLowerCase()}', 
                         _modeIcon(), _modeColor());
    }

    if (visible.isEmpty) {
      return _emptyState('No ${_modeLabel().toLowerCase()} found', 
                         _modeIcon(), _modeColor(), 
                         sub: 'Try different keywords or filters.');
    }

    switch (_mode) {
      case 'posts':  return _buildPostList(visible);
      case 'people': return _buildPeopleList(visible);
      case 'clubs':  return _buildClubList(visible);
      case 'events': return _buildEventList(visible);
      default:       return const SizedBox.shrink();
    }
  }
  String _modeLabel() {
    for (final m in _modes) {
      if (m.key == _mode) return m.label;
    }
    return 'results';
  }

  IconData _modeIcon() {
    for (final m in _modes) {
      if (m.key == _mode) return m.icon;
    }
    return Icons.search;
  }

  // ── Posts result list (kept close to original look) ───

  Widget _buildPostList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final p = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _avatar(p['author_avatar'] as String?,
                          p['author_name']   as String?, _kG2, 34),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['author_name'] as String? ?? '',
                          style: const TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 13, color: _kInk)),
                      Text(p['post_type'] as String? ?? '',
                          style: TextStyle(fontFamily: 'Momo',
                              fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  )),
                  _pill(p['post_type'] as String? ?? 'post', _kG2),
                ]),
                const SizedBox(height: 10),
                Text(p['content'] as String? ?? '',
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Momo',
                        fontSize: 14, color: _kInk, height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.favorite_outline_rounded,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${p['like_count'] ?? p['likes_count'] ?? 0}',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(width: 12),
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${p['comment_count'] ?? p['comments_count'] ?? 0}',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 11, color: Colors.grey.shade400)),
                ]),
              ]),
        );
      },
    );
  }

  // ── People result list ────────────────────────────────

  Widget _buildPeopleList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final u = items[i];
        final isFollowing = u['is_following'] as bool? ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            _avatar(u['avatar_url'] as String?, u['name'] as String?, _kG1, 44),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] as String? ?? '',
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 14, color: _kInk)),
                Text(u['role'] as String? ?? '',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                        color: Colors.grey.shade500)),
              ],
            )),
            GestureDetector(
              onTap: () async {
                final id = u['user_id'] as String? ?? '';
                if (id.isEmpty) return;
                try {
                  await _api.followToggle(id);
                  final pos = _allPeople.indexWhere(
                      (e) => e['user_id'] == id);
                  if (pos >= 0) {
                    setState(() => _allPeople[pos] = {
                          ..._allPeople[pos],
                          'is_following': !isFollowing,
                        });
                  }
                } catch (_) {}
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isFollowing ? null
                      : const LinearGradient(colors: [_kG1, _kG2]),
                  color: isFollowing ? Colors.grey.shade100 : null,
                  borderRadius: BorderRadius.circular(10),
                  border: isFollowing
                      ? Border.all(color: Colors.grey.shade300) : null,
                ),
                child: Text(isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 12,
                        color: isFollowing
                            ? Colors.grey.shade600 : Colors.white)),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Clubs result list (Groups filtered to category=club) ──

  Widget _buildClubList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final g        = items[i];
        final isMember = g['is_member'] as bool? ?? g['is_joined'] as bool? ?? false;
        final emoji    = (g['theme_icon'] as String?) ??
                         (g['icon']       as String?) ?? '🎯';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _kG4.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(emoji,
                  style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['name'] as String? ?? '',
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 14, color: _kInk)),
                Text('${g['members_count'] ?? 0} members'
                     '${g['theme'] != null ? ' · ${g['theme']}' : ''}',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: Colors.grey.shade500)),
              ])),
            GestureDetector(
              onTap: () async {
                if (!isMember) {
                  try {
                    await _api.joinGroup(g['id'] as String? ?? '');
                    final pos = _allClubs.indexWhere(
                        (e) => e['id'] == g['id']);
                    if (pos >= 0) {
                      setState(() => _allClubs[pos] = {
                            ..._allClubs[pos], 'is_member': true,
                          });
                    }
                  } catch (_) {}
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isMember
                      ? Colors.green.shade50
                      : _kG4.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isMember
                      ? Colors.green.shade300 : _kG4.withOpacity(0.3)),
                ),
                child: Text(isMember ? 'Joined ✓' : 'Join',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 12,
                        color: isMember
                            ? Colors.green.shade700 : _kG4)),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Events result list ────────────────────────────────

  Widget _buildEventList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final e        = items[i];
        final title    = e['title'] as String? ?? '';
        final loc      = e['location'] as String? ?? '';
        final cat      = (e['category'] as String? ?? '').toUpperCase();
        final dt       = DateTime.tryParse(
            (e['start_time'] ?? e['start_at'])?.toString() ?? '');
        final dateStr  = dt != null
            ? '${dt.day} ${_month(dt.month)} · ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'
            : '';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.event_rounded,
                  color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(title,
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14, color: _kInk),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (cat.isNotEmpty) _pill(cat, _kG1),
                ]),
                const SizedBox(height: 4),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 12, color: Colors.grey.shade600)),
                if (loc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.place_rounded,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Expanded(child: Text(loc,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Momo',
                              fontSize: 11, color: Colors.grey.shade500))),
                    ]),
                  ),
              ],
            )),
          ]),
        );
      },
    );
  }

  String _month(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
    if (m < 1 || m > 12) return '';
    return names[m - 1];
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _emptyState(String label, IconData icon, Color color,
      {String? sub}) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: color.withOpacity(0.25)),
      const SizedBox(height: 14),
      Text(label, style: TextStyle(fontFamily: 'Alfa',
          fontSize: 16, color: color.withOpacity(0.5))),
      if (sub != null) ...[
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(sub, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: Colors.grey.shade500)),
        ),
      ],
    ]));
  }

  Widget _avatar(String? url, String? name, Color color, double size) {
    final initial = (name?.isNotEmpty == true)
        ? name![0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape:    BoxShape.circle,
        gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
        image: url != null && url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || url.isEmpty
          ? Center(child: Text(initial,
              style: TextStyle(color: Colors.white,
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: size * 0.4)))
          : null,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label.toUpperCase(),
          style: TextStyle(fontFamily: 'Momo', fontSize: 9,
              fontWeight: FontWeight.bold, color: color)),
    );
  }
}