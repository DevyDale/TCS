// lib/screens/search_screen.dart
//
// Search — clean, history-first design with a little life:
//   • Title + a solid filled search field (full-width).
//   • A "History" heading with "Clear all", then an animated segmented
//     tab bar (People · Clubs · Events · Posts).
//   • Each tab view shows that category's recents, grouped Today /
//     Yesterday / Earlier. Recent tiles are gradient-bordered, elevated
//     cards; People recents you opened show avatar + name + role tag.
//     Typing flips the tab views to live results.
//   • Tapping a post result opens it in a full detail view.
//
// Cross-role separation: students never see staff and vice-versa in
// People results (enforced in `_people`, and server-side too).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/screens/arcade/club_screen.dart';
import '../services/api_service.dart';
import '../screens/dashboard/other_user_profile_Screen.dart';

// Brand palette.
const _kG1    = Color(0xFF6DD5FA);  // sky
const _kG2    = Color(0xFF8E54E9);  // purple
const _kG3    = Color(0xFFF7971E);  // amber
const _kG4    = Color(0xFFFF5858);  // coral
const _kInk   = Color(0xFF1A1A2E);
const _kField = Color(0xFFF1F2F6);
const _kSlate = Color(0xFF7A8294);
const _kHair  = Color(0xFFECEDF1);

const _kHistoryKey = 'search_history_v1';

// Tab categories (order = tab order).
const _cats     = ['people', 'clubs', 'events', 'posts'];
const _catLabel = {'people': 'People', 'clubs': 'Clubs',
                   'events': 'Events', 'posts': 'Posts'};
const _catColor = {'people': _kG3, 'clubs': _kG4,
                   'events': _kG1, 'posts': _kG2};
const _catIcon  = {'people': Icons.people_alt_rounded,
                   'clubs': Icons.groups_2_rounded,
                   'events': Icons.celebration_rounded,
                   'posts': Icons.auto_stories_rounded};

/// Returns 'student', 'staff', or 'other' for a role string.
String _groupOf(String role) {
  final r = role.toLowerCase();
  if (r == 'student') return 'student';
  if (r == 'teaching_staff' || r == 'non_teaching_staff') return 'staff';
  return 'other';
}

/// A single saved search. Either a typed term, or a person you opened
/// (which then carries name / avatar / role tag).
class _HistEntry {
  final String  term;     // display label / query
  final String? name;     // person name (set ⇒ render as a person tile)
  final String? avatar;   // person avatar url
  final String? tag;      // 'Student' / 'Staff' / role label
  final String? uid;      // person id
  final int     ts;       // epoch millis

  const _HistEntry({
    required this.term, this.name, this.avatar, this.tag, this.uid,
    required this.ts,
  });

  bool get isPerson => name != null;

  Map<String, dynamic> toJson() => {
        'q': term,
        if (name != null) 'n': name,
        if (avatar != null) 'a': avatar,
        if (tag != null) 't': tag,
        if (uid != null) 'u': uid,
        'ts': ts,
      };

  factory _HistEntry.fromJson(Map<String, dynamic> m) => _HistEntry(
        term: (m['q'] ?? '').toString(),
        name: m['n']?.toString(),
        avatar: m['a']?.toString(),
        tag: m['t']?.toString(),
        uid: m['u']?.toString(),
        ts: m['ts'] is int
            ? m['ts'] as int
            : int.tryParse('${m['ts']}') ?? 0,
      );
}


class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final _api   = ApiService();
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  late final TabController _tab;
  late final AnimationController _grad; // drives the gradient ring

  Timer? _debounce;
  Timer? _histTimer;

  // Raw fetched data.
  List<Map<String, dynamic>> _allPosts  = [];
  List<Map<String, dynamic>> _allPeople = [];
  List<Map<String, dynamic>> _allClubs  = [];
  List<Map<String, dynamic>> _allEvents = [];

  bool   _loading   = false;
  String _lastQuery = '';

  // Per-category device-saved search history.
  final Map<String, List<_HistEntry>> _history = {
    for (final c in _cats) c: <_HistEntry>[]
  };

  /// Viewer's role group: 'student' | 'staff' | 'other'.
  String _myGroup = 'other';
  bool _myReception = false;

  // ─── Lifecycle ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _cats.length, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {}); // refresh hint / heading / icon colours
      });
    _grad = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    _loadMyGroup();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _histTimer?.cancel();
    _tab.dispose();
    _grad.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadMyGroup() async {
    final me = await ApiService.instance.cachedUser;
    if (!mounted) return;
    setState(() {
      _myGroup = _groupOf((me?['role'] as String?) ?? '');
      _myReception =
          ((me?['staff_type'] as String?) ?? '').toLowerCase() == 'reception';
    });
  }

  String get _currentCat => _cats[_tab.index];

  // ─── History (device-local, per category) ──────────────

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHistoryKey);
    if (raw == null || !mounted) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        for (final c in _cats) {
          final list = (m[c] as List?) ?? const [];
          _history[c] = list.map((item) {
            if (item is Map) {
              return _HistEntry.fromJson(item.cast<String, dynamic>());
            }
            // migrate old string-only history → "Earlier" bucket
            return _HistEntry(term: item.toString(), ts: 0);
          }).toList();
        }
      });
    } catch (_) {/* ignore corrupt cache */}
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    final out = {
      for (final c in _cats) c: _history[c]!.map((e) => e.toJson()).toList()
    };
    await p.setString(_kHistoryKey, jsonEncode(out));
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Save a typed search term to a category.
  void _pushTermHistory(String cat, String q) {
    q = q.trim();
    if (q.isEmpty) return;
    final l = _history[cat]!;
    // don't duplicate an existing term or person with the same label
    l.removeWhere((e) => e.term.toLowerCase() == q.toLowerCase());
    l.insert(0, _HistEntry(term: q, ts: _now));
    if (l.length > 12) _history[cat] = l.sublist(0, 12);
    _saveHistory();
  }

  /// Record a person you opened into People history (rich tile).
  void _pushPersonHistory(Map<String, dynamic> u) {
    final name = (u['display_name'] ??
                  u['preferred_name'] ??
                  u['name'] ??
                  u['username'] ??
                  'Unknown').toString();
    if (name.trim().isEmpty) return;
    final avatar = u['avatar_url'] as String?;
    final uidRaw = (u['user_id'] ?? u['userId'] ?? u['id'] ?? '').toString();
    final uid    = uidRaw.isEmpty ? null : uidRaw;
    final tag    = _roleTag((u['role'] ?? '').toString());

    final l = _history['people']!;
    l.removeWhere((e) =>
        (uid != null && e.uid == uid) ||
        e.term.toLowerCase() == name.toLowerCase());
    l.insert(0, _HistEntry(
        term: name, name: name, avatar: avatar, tag: tag, uid: uid, ts: _now));
    if (l.length > 12) _history['people'] = l.sublist(0, 12);
    _saveHistory();
  }

  void _removeHistory(String cat, _HistEntry e) {
    setState(() => _history[cat]!.remove(e));
    _saveHistory();
  }

  void _clearHistory(String cat) {
    setState(() => _history[cat]!.clear());
    _saveHistory();
  }

  String _roleTag(String role) {
    final g = _groupOf(role);
    if (g == 'student') return 'Student';
    if (g == 'staff') return 'Staff';
    if (role.trim().isEmpty) return '';
    return role.replaceAll('_', ' ');
  }

  // ─── Search ────────────────────────────────────────────

  void _onChanged(String q) {
    _debounce?.cancel();
    _histTimer?.cancel();
    setState(() {}); // refresh suffix / heading
    if (q.trim().isEmpty) {
      setState(() {
        _allPosts = []; _allPeople = []; _allClubs = []; _allEvents = [];
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400),
        () => _search(q.trim()));
    // Save the *settled* query so history isn't polluted with partials.
    _histTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final t = _ctrl.text.trim();
      if (t.isNotEmpty) setState(() => _pushTermHistory(_currentCat, t));
    });
  }

  /// Re-open a saved entry: bump it to "Today", refill the field, search.
  void _openHistoryEntry(String cat, _HistEntry e) {
    final l = _history[cat]!;
    l.remove(e);
    l.insert(0, _HistEntry(
        term: e.term, name: e.name, avatar: e.avatar, tag: e.tag,
        uid: e.uid, ts: _now));
    _saveHistory();

    final i = _cats.indexOf(cat);
    if (i >= 0 && _tab.index != i) _tab.animateTo(i);
    _ctrl.text = e.term;
    _ctrl.selection = TextSelection.collapsed(offset: e.term.length);
    setState(() {});
    _search(e.term);
  }

  /// Pull a list out of whatever shape the endpoint returns:
  /// a bare List, a paginated {results:[...]}, or {events/posts/...}.
  List<Map<String, dynamic>> _asList(dynamic r) {
    if (r is List) {
      return r.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (r is Map) {
      for (final k in const ['results', 'events', 'posts', 'people',
                             'users', 'clubs', 'data']) {
        final v = r[k];
        if (v is List) {
          return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _search(String q) async {
    if (q == _lastQuery || q.isEmpty) return;
    _lastQuery = q;
    setState(() => _loading = true);

    Future<dynamic> safe(Future<dynamic> Function() fn, String label) async {
      try {
        return await fn();
      } catch (e) {
        debugPrint('🔎 search $label failed: $e');
        return null;
      }
    }

    try {
      // posts + people keep their dedicated search endpoints.
      // clubs: /clubs/ supports ?q= but filter=all is "discover" (clubs you
      //   haven't joined), so we also query filter=mine and merge — that way
      //   a club you're already in still shows up.
      // events: getEvents uses the `search` param (NOT `q`).
      final res = await Future.wait([
        safe(() => _api.get('/posts/search/', query: {'q': q}), 'posts'),
        safe(() => _api.get('/users/search/', query: {'q': q}), 'people'),
        safe(() => _api.getClubs(filter: 'all',  q: q),         'clubs-all'),
        safe(() => _api.getClubs(filter: 'mine', q: q),         'clubs-mine'),
        safe(() => _api.getEvents(search: q),                   'events'),
      ]);
      if (!mounted) return;

      final lq = q.toLowerCase();

      // Merge + de-dupe clubs by id, then keep name/tagline/category matches
      // (a safety net in case the backend ignores ?q=).
      final clubMap = <String, Map<String, dynamic>>{};
      for (final raw in [res[2], res[3]]) {
        for (final c in _asList(raw)) {
          final hay = [c['name'], c['tagline'], c['category'], c['description']]
              .map((x) => (x ?? '').toString().toLowerCase()).join(' ');
          if (!hay.contains(lq)) continue;
          final id = (c['id'] ?? c['name'] ?? '').toString();
          clubMap[id] = c;
        }
      }

      final events = _asList(res[4]).where((e) {
        final hay = [e['title'], e['location'], e['category'], e['description']]
            .map((x) => (x ?? '').toString().toLowerCase()).join(' ');
        return hay.contains(lq);
      }).toList();

      setState(() {
        _allPosts  = _asList(res[0]);
        _allPeople = _asList(res[1]);
        _allClubs  = clubMap.values.toList();
        _allEvents = events;
        _loading = false;
      });
    } catch (e) {
      debugPrint('🔎 search outer failure: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Derived data ──────────────────────────────────────

  /// People with the cross-role gate applied.
  List<Map<String, dynamic>> get _people {
    Iterable<Map<String, dynamic>> b = _allPeople;
    bool isReception(Map<String, dynamic> u) =>
        (u['staff_type']?.toString().toLowerCase() ?? '') == 'reception';
    if (_myGroup == 'student') {
      // students see students + reception staff
      b = b.where((u) =>
          _groupOf(u['role']?.toString() ?? '') != 'staff' || isReception(u));
    } else if (_myGroup == 'staff' && !_myReception) {
      // non-reception staff see staff only (no students)
      b = b.where((u) => _groupOf(u['role']?.toString() ?? '') != 'student');
    }
    // reception staff and 'other' see everyone
    return b.toList();
  }

  List<Map<String, dynamic>> _listFor(String cat) {
    switch (cat) {
      case 'people': return _people;
      case 'clubs':  return _allClubs;
      case 'events': return _allEvents;
      case 'posts':  return _allPosts;
    }
    return const [];
  }

  bool get _hasQuery => _ctrl.text.trim().isNotEmpty;

  // ─── Reusable animated gradient ring ───────────────────

  Widget _gradientBorder({
    required Widget child,
    double radius = 16,
    double thickness = 2,
  }) {
    return AnimatedBuilder(
      animation: _grad,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius + thickness),
          gradient: SweepGradient(
            colors: const [_kG1, _kG2, _kG4, _kG3, _kG1],
            stops:  const [0.0, 0.28, 0.55, 0.82, 1.0],
            transform: GradientRotation(_grad.value * 2 * math.pi),
          ),
        ),
        padding: EdgeInsets.all(thickness),
        child: child,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildHeadingRow(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSegmented(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: _cats.map(_tabContent).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Title + solid filled search field (full) ───────────
Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kField,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: _kInk,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Search',
              style: TextStyle(
                fontFamily: 'Alfa',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _kInk,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Search field
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: _kField.withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (q) {
              setState(() => _pushTermHistory(_currentCat, q));
              _search(q.trim());
            },
            style: const TextStyle(
              fontFamily: 'Momo',
              fontSize: 15,
              color: _kInk,
            ),
            decoration: InputDecoration(
              hintText: _hint(),
              hintStyle: const TextStyle(
                fontFamily: 'Momo',
                fontSize: 14,
                color: _kSlate,
              ),

              // PREFIX ICON (inside field)
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _kSlate,
                size: 22,
              ),

              // SUFFIX ICON (inside field)
              suffixIcon: (_ctrl.text.isNotEmpty)
                  ? GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() {
                          _allPosts = [];
                          _allPeople = [];
                          _allClubs = [];
                          _allEvents = [];
                          _lastQuery = '';
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kSlate.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _kSlate,
                        ),
                      ),
                    )
                  : null,

              isDense: true,
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 0,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  String _hint() {
    switch (_currentCat) {
      case 'people': return 'Search people…';
      case 'clubs':  return 'Search clubs…';
      case 'events': return 'Search events…';
      case 'posts':  return 'Search posts…';
    }
    return 'Search…';
  }

  // ── "History" / "Results" heading + "Clear all" ────────

  Widget _buildHeadingRow() {
    final showClear = !_hasQuery && _history[_currentCat]!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(children: [
        Icon(_hasQuery ? Icons.auto_awesome_rounded : Icons.history_rounded,
            size: 17, color: _hasQuery ? _kG2 : _kSlate),
        const SizedBox(width: 7),
        Text(_hasQuery ? 'Results' : 'History',
            style: const TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 15, color: _kInk)),
        const Spacer(),
        if (showClear)
          GestureDetector(
            onTap: () => _clearHistory(_currentCat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kG4.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.delete_sweep_rounded, size: 16, color: _kG4),
                SizedBox(width: 5),
                Text('Clear all',
                    style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                        fontWeight: FontWeight.bold, color: _kG4)),
              ]),
            ),
          ),
      ]),
    );
  }

  // ── Animated segmented tab bar (icons + gradient ring) ─

  Widget _buildSegmented() {
    return _gradientBorder(
      radius: 15,
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kField,
          borderRadius: BorderRadius.circular(15),
        ),
        child: TabBar(
          controller: _tab,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          labelColor: _kInk,
          unselectedLabelColor: _kSlate,
          labelStyle: const TextStyle(
              fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Arch', fontWeight: FontWeight.w600, fontSize: 12),
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.07),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          tabs: List.generate(_cats.length, (i) {
            final c   = _cats[i];
            final sel = _tab.index == i;
            return Tab(
              height: 38,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_catIcon[c], size: 14,
                    color: sel ? _catColor[c] : _kSlate),
                const SizedBox(width: 5),
                Text(_catLabel[c]!),
              ]),
            );
          }),
        ),
      ),
    );
  }

  // ── Tab content : history (grouped) or results ─────────

  Widget _tabContent(String cat) {
    if (_hasQuery) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = _listFor(cat);
      if (items.isEmpty) return _emptyResults(cat);
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
        itemCount: items.length,
        itemBuilder: (_, i) => _cardFor(cat, items[i]),
      );
    }

    final hist = _history[cat]!;
    if (hist.isEmpty) return _emptyHistory(cat);

    final now        = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startYest  = startToday.subtract(const Duration(days: 1));
    final today = <_HistEntry>[], yest = <_HistEntry>[], earlier = <_HistEntry>[];
    for (final e in hist) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.ts);
      if (!d.isBefore(startToday)) {
        today.add(e);
      } else if (!d.isBefore(startYest)) {
        yest.add(e);
      } else {
        earlier.add(e);
      }
    }

    final children = <Widget>[];
    void section(String label, List<_HistEntry> items) {
      if (items.isEmpty) return;
      children.add(_bucketHeader(label));
      children.addAll(items.map((e) => _historyTile(cat, e)));
    }
    section('Today', today);
    section('Yesterday', yest);
    section('Earlier', earlier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: children,
    );
  }

  Widget _bucketHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontFamily: 'Arch', fontWeight: FontWeight.w800,
              fontSize: 11, letterSpacing: 0.8, color: _kSlate)),
    );
  }

  // ── Recent tile : gradient border + elevation 2, r10 ───

  Widget _historyTile(String cat, _HistEntry e) {
    final c = _catColor[cat]!;
    final title = e.isPerson ? (e.name ?? e.term) : e.term;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        // gradient border + elevation ≈ 2
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [_kG1, _kG2, _kG4],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.10),
                blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openHistoryEntry(cat, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                if (e.isPerson)
                  _avatar(e.avatar, title, c, 44)
                else
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: c.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(_catIcon[cat], size: 22, color: c),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5, color: _kInk)),
                      const SizedBox(height: 3),
                      if (e.isPerson && (e.tag?.isNotEmpty ?? false))
                        _tagChip(e.tag!, c)
                      else
                        const Text('Recent search',
                            style: TextStyle(fontFamily: 'Momo',
                                fontSize: 11.5, color: _kSlate)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removeHistory(cat, e),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: _kSlate),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text,
          style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
              fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _emptyHistory(String cat) {
    final c = _catColor[cat]!;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 84, height: 84,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: c.withOpacity(0.08)),
        child: Icon(Icons.history_rounded, size: 36, color: c.withOpacity(0.5)),
      ),
      const SizedBox(height: 16),
      const Text('No recent searches',
          style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
              fontSize: 14, color: _kInk)),
      const SizedBox(height: 6),
      Text('Your ${_catLabel[cat]!.toLowerCase()} searches show up here.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Momo', fontSize: 12, color: _kSlate)),
    ]));
  }

  Widget _emptyResults(String cat) {
    final c = _catColor[cat]!;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 84, height: 84,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: c.withOpacity(0.08)),
        child: Icon(_catIcon[cat], size: 34, color: c.withOpacity(0.5)),
      ),
      const SizedBox(height: 16),
      const Text('No results',
          style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
              fontSize: 14, color: _kInk)),
      const SizedBox(height: 6),
      const Text('Try different keywords.',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: _kSlate)),
    ]));
  }

  // ── Cards ──────────────────────────────────────────────

  Widget _cardFor(String type, Map<String, dynamic> m) {
    switch (type) {
      case 'people': return _personCard(m);
      case 'clubs':  return _clubCard(m);
      case 'events': return _eventCard(m);
      case 'posts':  return _postCard(m);
    }
    return const SizedBox.shrink();
  }

  BoxDecoration get _cardBox => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHair),
      );

  // First media item as a rounded preview (image, or video poster with a
  // play overlay). Reads the same `media` list the feed/club screens use.
  Widget _postMedia(Map<String, dynamic> p) {
    final media = (p['media'] as List? ?? []).cast<Map<String, dynamic>>();
    if (media.isEmpty) return const SizedBox.shrink();
    final first = media.first;
    final isVideo = (first['media_type'] ?? first['type'] ?? '')
        .toString().toLowerCase().contains('video');
    // For video the streamable `url` is an mp4 — use the poster thumbnail.
    final img = isVideo
        ? (first['thumbnail_url'] ?? first['url'] ?? '').toString()
        : (first['url'] ?? first['thumbnail_url'] ?? '').toString();
    if (img.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(fit: StackFit.expand, children: [
            Image.network(img, fit: BoxFit.cover,
              loadingBuilder: (c, w, prog) =>
                  prog == null ? w : Container(color: _kField),
              errorBuilder: (c, e, s) => Container(
                  color: _kField,
                  child: const Icon(Icons.image_not_supported_rounded,
                      color: _kSlate)),
            ),
            if (isVideo)
              Container(
                color: Colors.black.withOpacity(0.18),
                child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 46)),
              ),
            if (media.length > 1)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.collections_rounded,
                        color: Colors.white, size: 11),
                    const SizedBox(width: 3),
                    Text('${media.length}',
                        style: const TextStyle(fontFamily: 'Arch', fontSize: 10,
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final content = (p['content'] as String? ?? '').trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _PostDetailScreen(post: p),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: _cardBox,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _avatar(p['author_avatar'] as String?, p['author_name'] as String?, _kG2, 34),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['author_name'] as String? ?? '',
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 13, color: _kInk)),
                Text(p['post_type'] as String? ?? '',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            )),
            _pill(p['post_type'] as String? ?? 'post', _kG2),
          ]),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(content,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Momo',
                    fontSize: 14, color: _kInk, height: 1.4)),
          ],
          _postMedia(p),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.favorite_outline_rounded, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('${p['like_count'] ?? p['likes_count'] ?? 0}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: Colors.grey.shade400)),
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('${p['comment_count'] ?? p['comments_count'] ?? 0}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: Colors.grey.shade400)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _kSlate),
          ]),
        ]),
      ),
    );
  }

  Widget _personCard(Map<String, dynamic> u) {
    final isFollowing = u['is_following'] as bool? ?? false;
    final displayName = (u['display_name'] ??
                         u['preferred_name'] ??
                         u['name'] ??
                         u['username'] ??
                         u['user_id'] ??
                         'Unknown').toString();
    final userId = (u['user_id'] ?? u['userId'] ?? u['id'] ?? '').toString();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _pushPersonHistory(u));
        if (userId.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtherUserProfileScreen(userId: userId, initialData: u),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _cardBox,
        child: Row(children: [
          _avatar(u['avatar_url'] as String?, displayName, _kG1, 44),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
              Text(u['role'] as String? ?? '',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                      color: Colors.grey.shade500)),
            ],
          )),
          GestureDetector(
            onTap: () async {
              if (userId.isEmpty) return;
              try {
                await _api.followToggle(userId);
                final pos = _allPeople.indexWhere(
                    (e) => (e['user_id'] ?? e['id']) == userId);
                if (pos >= 0) {
                  setState(() => _allPeople[pos] = {
                        ..._allPeople[pos], 'is_following': !isFollowing,
                      });
                }
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                      color: isFollowing ? Colors.grey.shade600 : Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _clubCard(Map<String, dynamic> g) {
    final membership = (g['membership'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final isMember = g['is_member'] as bool? ??
        g['is_joined'] as bool? ??
        membership['is_member'] == true;
    final emoji    = (g['theme_icon'] as String?) ??
                     (g['icon'] as String?) ?? '🎯';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClubScreen(id: (g['id'] ?? '').toString(), club: g),
      )),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardBox,
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: _kG4.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g['name'] as String? ?? '',
                style: const TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
            Text('${g['members_count'] ?? 0} members'
                 '${g['category'] != null ? ' · ${g['category']}' : ''}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                    color: Colors.grey.shade500)),
          ])),
        GestureDetector(
          onTap: () async {
            if (!isMember) {
              try {
                await _api.joinGroup(g['id'] as String? ?? '');
                final pos = _allClubs.indexWhere((e) => e['id'] == g['id']);
                if (pos >= 0) {
                  setState(() => _allClubs[pos] = {
                        ..._allClubs[pos], 'is_member': true,
                      });
                }
              } catch (_) {}
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isMember ? Colors.green.shade50 : _kG4.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isMember
                  ? Colors.green.shade300 : _kG4.withOpacity(0.3)),
            ),
            child: Text(isMember ? 'Joined ✓' : 'Join',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 12,
                    color: isMember ? Colors.green.shade700 : _kG4)),
          ),
        ),
      ]),
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final title   = e['title'] as String? ?? '';
    final loc     = e['location'] as String? ?? '';
    final cat     = (e['category'] as String? ?? '').toUpperCase();
    final dt      = DateTime.tryParse(
        (e['start_time'] ?? e['start_at'])?.toString() ?? '');
    final dateStr = dt != null
        ? '${dt.day} ${_month(dt.month)} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardBox,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kG1, _kG2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.event_rounded, color: Colors.white, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14, color: _kInk),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (cat.isNotEmpty) _pill(cat, _kG1),
            ]),
            const SizedBox(height: 4),
            if (dateStr.isNotEmpty)
              Text(dateStr, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: Colors.grey.shade600)),
            if (loc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  Icon(Icons.place_rounded, size: 11, color: Colors.grey.shade400),
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
  }

  String _month(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun',
                   'Jul','Aug','Sep','Oct','Nov','Dec'];
    if (m < 1 || m > 12) return '';
    return names[m - 1];
  }

  Widget _avatar(String? url, String? name, Color color, double size) {
    final initial = (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
        image: url != null && url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || url.isEmpty
          ? Center(child: Text(initial,
              style: TextStyle(color: Colors.white, fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: size * 0.4)))
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


// ═════════════════════════════════════════════════════════════
// POST DETAIL — opens the exact post tapped from search results.
// Full-width media carousel, caption, and a working like button.
// Refreshes from GET /posts/<id>/ so counts/likes are current.
// ═════════════════════════════════════════════════════════════

class _PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostDetailScreen({required this.post});
  @override
  State<_PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<_PostDetailScreen> {
  final _api  = ApiService();
  final _page = PageController();
  late Map<String, dynamic> _p;
  int  _idx  = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _p = Map<String, dynamic>.from(widget.post);
    _refresh();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _media =>
      (_p['media'] as List? ?? []).cast<Map<String, dynamic>>();

  Future<void> _refresh() async {
    final id = (_p['id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      final r = await _api.get('/posts/$id/');
      if (!mounted || r is! Map) return;
      setState(() => _p = {..._p, ...r.cast<String, dynamic>()});
    } catch (_) {/* keep the data we already have */}
  }

  Future<void> _like() async {
    final id = (_p['id'] ?? '').toString();
    if (_busy || id.isEmpty) return;
    final was = _p['is_liked'] as bool? ?? false;
    final cnt = (_p['like_count'] ?? _p['likes_count'] ?? 0) as int;
    setState(() {
      _busy = true;
      _p = {..._p, 'is_liked': !was, 'like_count': was ? cnt - 1 : cnt + 1};
    });
    try {
      final r = await _api.likeToggle(id) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _p = {
            ..._p,
            'is_liked':   r['liked']      ?? !was,
            'like_count': r['like_count'] ?? _p['like_count'],
          });
    } catch (_) {
      if (mounted) setState(() => _p = {..._p, 'is_liked': was, 'like_count': cnt});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isVideo(Map<String, dynamic> m) =>
      (m['media_type'] ?? m['type'] ?? '')
          .toString().toLowerCase().contains('video');

  String _authorId() => (_p['author_id'] ??
          _p['author_user_id'] ??
          (_p['author'] is Map
              ? (_p['author']['user_id'] ?? _p['author']['id'])
              : null) ??
          _p['user_id'] ??
          '')
      .toString();

  /// Last-resort: find the author by name via people search (only resolves
  /// within the viewer's own role group, since cross-role users aren't
  /// reachable anyway).

  Future<String> _resolveAuthorByName() async {
    final name = (_p['author_name'] as String? ?? '').trim();
    if (name.length < 2) return '';
    try {
      final r = await _api.searchUsers(name);
      final list = (r is Map)
          ? (((r as Map)['results'] as List?) ?? const [])
              .cast<Map<String, dynamic>>()
          : (r is List ? r.cast<Map<String, dynamic>>()
                       : const <Map<String, dynamic>>[]);
      final exact = list.where((u) =>
          ((u['name'] ?? u['display_name'] ?? '') as String).trim()
              .toLowerCase() == name.toLowerCase()).toList();
      final pick = exact.isNotEmpty
          ? exact.first
          : (list.length == 1 ? list.first : null);
      if (pick == null) return '';
      return (pick['user_id'] ?? pick['id'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openAuthor() async {
    var uid = _authorId();

    if (uid.isEmpty) {
      final id = (_p['id'] ?? '').toString();
      if (id.isNotEmpty) {
        try {
          final r = await _api.get('/posts/$id/');
          if (r is Map) {
            _p = {..._p, ...r.cast<String, dynamic>()};
            uid = _authorId();
          }
        } catch (_) {/* ignore */}
      }
    }
    if (uid.isEmpty) uid = await _resolveAuthorByName();

    if (!mounted) return;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open this author's profile."),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OtherUserProfileScreen(
        userId: uid,
        initialData: {
          'user_id':      uid,
          'name':         _p['author_name'],
          'display_name': _p['author_name'],
          'avatar_url':   _p['author_avatar'],
          'role':         _p['author_role'],
        },
      ),
    ));
  }

  void _openComments() {
    final id = (_p['id'] ?? '').toString();
    if (id.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostCommentsSheet(
        api: _api,
        postId: id,
        onAdded: () {
          if (!mounted) return;
          final c = (_p['comment_count'] ?? _p['comments_count'] ?? 0) as int;
          setState(() => _p = {..._p, 'comment_count': c + 1});
        },
      ),
    );
  }

  Future<void> _share() async {
    final id = (_p['id'] ?? '').toString();
    if (id.isEmpty) return;
    HapticFeedback.lightImpact();
    final n = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SharePostSheet(api: _api, postId: id),
    );
    if (!mounted || n == null || n <= 0) return;
    final prev = (_p['share_count'] ?? _p['shares_count'] ?? 0) as int;
    setState(() => _p = {..._p, 'share_count': prev + n});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Shared with $n ${n == 1 ? "person" : "people"} ✓'),
      behavior: SnackBarBehavior.floating));
  }

  String _imageFor(Map<String, dynamic> m, bool isVideo) => isVideo
      ? (m['thumbnail_url'] ?? m['url'] ?? '').toString()
      : (m['url'] ?? m['thumbnail_url'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final author  = _p['author_name'] as String? ?? '';
    final avatar  = _p['author_avatar'] as String?;
    final role    = (_p['author_role'] as String?) ??
        (_p['post_type'] as String?) ?? '';
    final content = (_p['content'] as String? ?? '').trim();
    final liked   = _p['is_liked'] as bool? ?? false;
    final likes   = _p['like_count'] ?? _p['likes_count'] ?? 0;
    final cmts    = _p['comment_count'] ?? _p['comments_count'] ?? 0;
    final shrs    = _p['share_count'] ?? _p['shares_count'] ?? 0;
    final media   = _media;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('Post',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Container(
                  // Exquisite gradient frame: 2px gradient border, r2,
                  // with a soft colored glow so the post lifts off-page.
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [_kG1, _kG2, _kG4],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: _kG2.withOpacity(0.18),
                          blurRadius: 18, offset: const Offset(0, 8)),
                      BoxShadow(color: Colors.black.withOpacity(0.06),
                          blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openAuthor,
                  child: Row(children: [
                    _DetailAvatar(url: avatar, name: author),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(author,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Arch',
                                fontWeight: FontWeight.bold, fontSize: 15, color: _kInk)),
                        if (role.isNotEmpty)
                          Text(role,
                              style: TextStyle(fontFamily: 'Momo',
                                  fontSize: 11.5, color: Colors.grey.shade500)),
                      ],
                    )),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: _kSlate),
                  ]),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(content,
                      style: const TextStyle(fontFamily: 'Momo',
                          fontSize: 15, color: _kInk, height: 1.5)),
                ],
                if (media.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(children: [
                        PageView.builder(
                          controller: _page,
                          itemCount: media.length,
                          onPageChanged: (i) => setState(() => _idx = i),
                          itemBuilder: (_, i) {
                            final m   = media[i];
                            final vid = _isVideo(m);
                            final img = _imageFor(m, vid);
                            return Stack(fit: StackFit.expand, children: [
                              if (img.isNotEmpty)
                                Image.network(img, fit: BoxFit.cover,
                                    loadingBuilder: (c, w, prog) =>
                                        prog == null ? w : Container(color: _kField),
                                    errorBuilder: (c, e, s) => Container(
                                        color: _kField,
                                        child: const Icon(
                                            Icons.image_not_supported_rounded,
                                            color: _kSlate)))
                              else
                                Container(color: _kField),
                              if (vid)
                                Container(
                                  color: Colors.black.withOpacity(0.20),
                                  child: const Center(
                                      child: Icon(Icons.play_circle_fill_rounded,
                                          color: Colors.white, size: 58)),
                                ),
                            ]);
                          },
                        ),
                        if (media.length > 1)
                          Positioned(
                            bottom: 10, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(media.length, (i) =>
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _idx ? 18 : 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: i == _idx
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                )),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(height: 1, color: _kHair),
                const SizedBox(height: 14),
                Row(children: [
                  _DetailAction(
                    icon: liked ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                    label: '$likes',
                    color: liked ? _kG4 : _kSlate,
                    onTap: _like,
                  ),
                  const SizedBox(width: 22),
                  _DetailAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '$cmts',
                    color: _kSlate,
                    onTap: _openComments,
                  ),
                  const SizedBox(width: 22),
                  _DetailAction(
                    icon: Icons.share_outlined,
                    label: '$shrs',
                    color: _kSlate,
                    onTap: _share,
                  ),
                ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
 
 
  }
}

class _DetailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DetailAction({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 13, color: _kInk)),
      ]),
    );
  }
}

class _DetailAvatar extends StatelessWidget {
  final String? url;
  final String? name;
  const _DetailAvatar({required this.url, required this.name});
  @override
  Widget build(BuildContext context) {
    final initial = (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_kG2, _kG1]),
        image: (url != null && url!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url!.isEmpty)
          ? Center(child: Text(initial,
              style: const TextStyle(color: Colors.white, fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 18)))
          : null,
    );
  }
}


// ═════════════════════════════════════════════════════════════
// COMMENTS SHEET — list + add a comment on a post (same endpoints
// the feed uses: GET/POST /posts/<id>/comments/).
// ═════════════════════════════════════════════════════════════

class _PostCommentsSheet extends StatefulWidget {
  final ApiService api;
  final String postId;
  final VoidCallback onAdded;
  const _PostCommentsSheet({
    required this.api, required this.postId, required this.onAdded,
  });
  @override
  State<_PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<_PostCommentsSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.getComments(widget.postId);
      final results = d is Map
          ? ((d['results'] as List?) ?? const [])
          : (d is List ? d : const []);
      if (!mounted) return;
      setState(() {
        _comments = results.whereType<Map>()
            .map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _posting) return;
    HapticFeedback.lightImpact();
    setState(() => _posting = true);
    try {
      final c = await widget.api.addComment(widget.postId, t)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _comments.insert(0, c);
        _ctrl.clear();
        _posting = false;
      });
      widget.onAdded();
    } catch (_) {
      if (mounted) setState(() => _posting = false);
    }
  }

  String _ago(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours   < 24) return '${d.inHours}h';
    if (d.inDays    < 7)  return '${d.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _ctrl.text.trim().isNotEmpty && !_posting;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Comments',
                    style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
                        color: _kInk)),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(child: Text('No comments yet. Be the first!',
                          style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                              color: Colors.grey.shade500)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          itemCount: _comments.length,
                          itemBuilder: (_, i) => _commentRow(_comments[i]),
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _ctrl,
                    minLines: 1, maxLines: 4,
                    style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                          color: Colors.grey.shade400),
                      filled: true,
                      fillColor: _kField,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: canSend ? _add : null,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: canSend
                            ? const LinearGradient(colors: [_kG1, _kG2])
                            : null,
                        color: canSend ? null : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: _posting
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _commentRow(Map<String, dynamic> c) {
    final name   = c['author_name'] as String? ?? '';
    final avatar = c['author_avatar'] as String? ?? '';
    final text   = (c['text'] as String?) ?? (c['content'] as String?) ?? '';
    final when   = _ago((c['created_at'] ?? '').toString());
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_kG2, _kG1]),
            image: avatar.isNotEmpty
                ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                : null,
          ),
          child: avatar.isEmpty
              ? Center(child: Text(initial,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 13)))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _kField,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 12.5, color: _kInk))),
              if (when.isNotEmpty)
                Text(when,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                        color: Colors.grey.shade400)),
            ]),
            const SizedBox(height: 3),
            Text(text,
                style: const TextStyle(fontFamily: 'Momo', fontSize: 13,
                    color: _kInk, height: 1.4)),
          ]),
        )),
      ]),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Share-to-people sheet
//
// A search field over the platform's people, with a multi-select list below.
// Pick one or many, hit Share. Returns the number of recipients via
// Navigator.pop so the caller can bump the post's share count.
//
// Cross-role separation is respected: only people in the viewer's own role
// group are listed (students see students, staff see staff).
//
// NOTE: actually *delivering* the post into each recipient's chat + notifying
// them is a backend concern (the /posts/<id>/share/ endpoint must fan the post
// out to recipients and create notifications). This sheet sends the selected
// user_ids; once the backend honours them, recipients will receive + be
// notified.
// ───────────────────────────────────────────────────────────────────────────
class _SharePostSheet extends StatefulWidget {
  final ApiService api;
  final String postId;
  const _SharePostSheet({required this.api, required this.postId});
  @override
  State<_SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<_SharePostSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _myGroup = 'other';
  bool   _myReception = false;
  bool   _loading = true;
  bool   _sending = false;
  String _query   = '';

  List<Map<String, dynamic>> _directory = []; // initial people list
  List<Map<String, dynamic>> _people    = []; // current view
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _ctrl.addListener(() {
      final q = _ctrl.text.trim();
      if (q == _query) return;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final me = await ApiService.instance.cachedUser;
      _myGroup = _groupOf((me?['role'] as String?) ?? '');
      _myReception =
          ((me?['staff_type'] as String?) ?? '').toLowerCase() == 'reception';
    } catch (_) {/* default 'other' → no role filter */}
    await _loadDirectory();
  }

  List<Map<String, dynamic>> _extractUsers(dynamic res) {
    if (res is List) return res.cast<Map<String, dynamic>>();
    if (res is Map) {
      final r = (res['results'] as List?) ?? (res['users'] as List?) ?? const [];
      return r.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  bool _inMyGroup(Map<String, dynamic> u) {
    if (_myGroup == 'other') return true;
    final theirGroup = _groupOf((u['role'] ?? '').toString());
    if (theirGroup == 'other' || theirGroup == _myGroup) return true;
    final theirReception =
        (u['staff_type'] ?? '').toString().toLowerCase() == 'reception';
    return _myGroup == 'staff' ? _myReception : theirReception;
  }

  String _idOf(Map<String, dynamic> u) =>
      (u['user_id'] ?? u['id'] ?? '').toString();

  // Initial "people on the platform" list — suggested users plus a few broad
  // search seeds, merged & deduped (same approach as the All Users screen).
  Future<void> _loadDirectory() async {
    setState(() => _loading = true);
    final acc = <String, Map<String, dynamic>>{};
    try {
      final results = await Future.wait([
        widget.api.getSuggestedUsers(limit: 100).catchError((_) => const []),
        widget.api.searchUsers('a').catchError((_) => const {}),
        widget.api.searchUsers('e').catchError((_) => const {}),
        widget.api.searchUsers('i').catchError((_) => const {}),
        widget.api.searchUsers('o').catchError((_) => const {}),
      ]);
      for (final res in results) {
        for (final u in _extractUsers(res)) {
          final id = _idOf(u);
          if (id.isEmpty || !_inMyGroup(u)) continue;
          acc.putIfAbsent(id, () => u);
        }
      }
    } catch (_) {/* show whatever we got */}

    final list = acc.values.toList()
      ..sort((a, b) => (a['name'] ?? a['display_name'] ?? '')
          .toString().toLowerCase()
          .compareTo((b['name'] ?? b['display_name'] ?? '')
              .toString().toLowerCase()));
    if (!mounted) return;
    setState(() {
      _directory = list;
      _people    = list;
      _loading   = false;
    });
  }

  Future<void> _runSearch(String q) async {
    _query = q;
    if (q.isEmpty) {
      setState(() => _people = _directory);
      return;
    }
    if (q.length < 2) return;
    setState(() => _loading = true);
    try {
      final res   = await widget.api.searchUsers(q);
      final users = _extractUsers(res).where(_inMyGroup).toList();
      if (!mounted) return;
      setState(() { _people = users; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggle(Map<String, dynamic> u) {
    final id = _idOf(u);
    if (id.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _doShare() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      await widget.api.sharePost(widget.postId, _selected.toList());
      if (!mounted) return;
      Navigator.pop(context, _selected.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not share. Try again.'),
        behavior: SnackBarBehavior.floating));
    }
  }

  String _prettyRole(String r) {
    switch (r.toLowerCase()) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching staff';
      case 'non_teaching_staff': return 'Non-teaching staff';
      default: return r.isEmpty ? '' : r[0].toUpperCase() + r.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _kHair, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Share with',
                    style: TextStyle(
                        fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                    color: _kField, borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 14, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'Search people…',
                    hintStyle: TextStyle(
                        fontFamily: 'Momo', color: _kSlate.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.search_rounded, color: _kG2),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kG2))
                  : _people.isEmpty
                      ? Center(
                          child: Text('No people found',
                              style: TextStyle(
                                  fontFamily: 'Momo', color: _kSlate)))
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: _people.length,
                          itemBuilder: (_, i) => _personRow(_people[i]),
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GestureDetector(
                  onTap: _selected.isEmpty ? null : _doShare,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _selected.isEmpty ? 0.5 : 1,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_kG1, _kG2]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: _kG2.withOpacity(0.30),
                              blurRadius: 12, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _selected.isEmpty
                                    ? 'Select people to share'
                                    : 'Share with ${_selected.length}'
                                        '${_selected.length == 1 ? " person" : " people"}',
                                style: const TextStyle(
                                    fontFamily: 'Arch',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _personRow(Map<String, dynamic> u) {
    final id      = _idOf(u);
    final name    = (u['name'] ?? u['display_name'] ?? 'Unknown').toString();
    final role    = (u['role'] ?? '').toString();
    final avatar  = (u['avatar_url'] ?? '').toString();
    final sel     = _selected.contains(id);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(u),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? _kG2.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: sel ? _kG2.withOpacity(0.5) : _kHair, width: 1.4),
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_kG1, _kG2]),
              image: avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null,
            ),
            child: avatar.isEmpty
                ? Center(child: Text(initial, style: const TextStyle(
                    color: Colors.white, fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 17)))
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
              if (role.isNotEmpty)
                Text(_prettyRole(role),
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 11.5, color: _kSlate)),
            ],
          )),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? _kG2 : Colors.transparent,
              border: Border.all(color: sel ? _kG2 : _kSlate, width: 2),
            ),
            child: sel
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ]),
      ),
    );
  }
}