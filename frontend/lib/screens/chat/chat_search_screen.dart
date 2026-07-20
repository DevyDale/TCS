// lib/screens/chat/chat_search_screen.dart
//
// Themed to match Arcade (light):
//   • Soft white/light-grey surfaces, fine borders, dark ink
//   • Animated sweep-gradient border on the search bar
//   • Filter pills: All / Online / Connected
//   • Recent section (horizontal) loaded from /chat/rooms/
//   • Results list filtered client-side by selected pill
//
// Recents loader is defensive — silent if the endpoint shape differs.

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

// ── Arcade palette (light) ──
Color get _kBg1 => AppC.bg;
Color get _kBg2 => AppC.bg;
Color get _kBg3 => AppC.bg;
Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;
Color get _kBorder => AppC.border;
Color get _kInk => AppC.text;
Color get _kInkSoft => AppC.text;
Color get _kSlate => AppC.sub;
Color get _kSlate2 => AppC.sub;

// Gradient accents (constant across themes in arcade)
const _kBlue   = Color(0xFF6DD5FA);
const _kPurple = Color(0xFF7C3AED);
const _kAmber  = Color(0xFFF59E0B);
const _kCoral  = Color(0xFFFF4F6E);

const _gradColors = <Color>[
  _kBlue, _kPurple, _kAmber, _kCoral, _kBlue,
];

// Filter values
enum _Filter { all, online, connected }

extension on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:       return 'All';
      case _Filter.online:    return 'Online';
      case _Filter.connected: return 'Connected';
    }
  }

  IconData get icon {
    switch (this) {
      case _Filter.all:       return Icons.apps_rounded;
      case _Filter.online:    return Icons.circle_rounded;
      case _Filter.connected: return Icons.link_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case _Filter.all:       return _kPurple;
      case _Filter.online:    return const Color(0xFF22C55E);
      case _Filter.connected: return _kCoral;
    }
  }
}

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});
  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen>
    with TickerProviderStateMixin {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  // Empty-search filter caches (loaded on demand)
  List<Map<String, dynamic>> _onlineUsers    = [];
  List<Map<String, dynamic>> _connectedUsers = [];
  bool _loadingOnline    = false;
  bool _loadingConnected = false;

  late final AnimationController _shimmerCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recents = [];
  bool _loading        = false;
  bool _loadingRecents = true;
  _Filter _filter      = _Filter.all;

  // Track pending requests sent this session
  final Set<String> _requestSent = {};

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _loadRecents();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _shimmerCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _loadRecents() async {
    try {
      final res = await _api.get('/chat/rooms/');
      final raw = res is List
          ? res
          : (res is Map ? (res['results'] as List? ?? []) : <dynamic>[]);
      final out = <Map<String, dynamic>>[];
      for (final r in raw.take(15)) {
        if (r is! Map) continue;
        final m = r.cast<String, dynamic>();
        // Defensive shape — try the common keys.
        final user =
            (m['other_user'] as Map?)?.cast<String, dynamic>() ??
            (m['recipient'] as Map?)?.cast<String, dynamic>();
        out.add({
          'user_id'     : user?['user_id']    ?? m['other_user_id']    ?? m['user_id']    ?? '',
          'name'        : user?['name']       ?? m['other_user_name']  ?? m['name']       ?? m['title'] ?? 'Unknown',
          'role'        : user?['role']       ?? m['other_user_role']  ?? m['role']       ?? '',
          'avatar_url'  : user?['avatar_url'] ?? m['other_user_avatar']?? m['avatar_url'] ?? '',
          'is_online'   : user?['is_online']  ?? m['is_online']        ?? false,
          'room_id'     : m['id']?.toString() ?? m['room_id']?.toString(),
          'is_connected': true,
        });
      }
      if (!mounted) return;
      setState(() { _recents = out; _loadingRecents = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRecents = false);
    }
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350),
        () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/chat/dm/search/',
          query: {'q': q}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _results = (res['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    HapticFeedback.lightImpact();
    final roomId = user['room_id'] as String?;
    if (roomId != null) {
      Navigator.pop(context, {
        'action': 'open_room', 'room_id': roomId,
        'user_name': user['name'], 'user_id': user['user_id'],
      });
      return;
    }
    try {
      final room = await _api.startDM(user['user_id'] as String)
          as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.pop(context, {
        'action': 'open_room', 'room_id': room['id'],
        'user_name': user['name'], 'user_id': user['user_id'],
      });
    } catch (_) {}
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    HapticFeedback.lightImpact();
    final uid = user['user_id'] as String? ?? '';
    setState(() => _requestSent.add(uid));
    try {
      await _api.post('/chat/requests/send/', body: {
        'user_id': uid,
        'message': 'Hi! I\'d like to chat with you on TCS 👋',
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _requestSent.remove(uid));
    }
  }

  // ── Filter logic ──────────────────────────────────────────

  Future<void> _loadOnlineUsers() async {
    if (_loadingOnline) return;
    setState(() => _loadingOnline = true);
    try {
      final res = await _api.get('/chat/users/online/');
      if (!mounted) return;
      final list = (res is Map ? res['results'] as List? : res as List?) ?? const [];
      setState(() {
        _onlineUsers = list.cast<Map<String, dynamic>>().toList();
        _loadingOnline = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOnline = false);
    }
  }

  Future<void> _loadConnectedUsers() async {
    if (_loadingConnected) return;
    setState(() => _loadingConnected = true);
    try {
      final res = await _api.get('/chat/users/connected/');
      if (!mounted) return;
      final list = (res is Map ? res['results'] as List? : res as List?) ?? const [];
      setState(() {
        _connectedUsers = list.cast<Map<String, dynamic>>().toList();
        _loadingConnected = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingConnected = false);
    }
  }

  List<Map<String, dynamic>> get _visibleResults {
    final hasQuery = _ctrl.text.trim().isNotEmpty;

    // Search active → filter the search results client-side (legacy path).
    if (hasQuery) {
      if (_filter == _Filter.all) return _results;
      return _results.where((u) {
        final online  = u['is_online']    as bool? ?? false;
        final hasRoom = u['room_id'] != null;
        final isConn  = u['is_connected'] as bool? ?? false;
        switch (_filter) {
          case _Filter.online:    return online;
          case _Filter.connected: return hasRoom || isConn;
          case _Filter.all:       return true;
        }
      }).toList();
    }

    // No search query → pills fetch their own data on demand.
    switch (_filter) {
      case _Filter.online:
        if (_onlineUsers.isEmpty && !_loadingOnline) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnlineUsers());
        }
        return _onlineUsers;
      case _Filter.connected:
        if (_connectedUsers.isEmpty && !_loadingConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadConnectedUsers());
        }
        return _connectedUsers;
      case _Filter.all:
        return _results;
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              _buildTopBar(),
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilterPills(),
              const SizedBox(height: 4),
              Expanded(child: _buildBody()),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
          child: _GradientBorderBox(
            animation: _shimmerCtrl,
            radius: 14, borderWidth: 1.2, innerColor: _kCard,
            padding: const EdgeInsets.all(11),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: _kInk, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ShaderMask(
            shaderCallback: (b) => const LinearGradient(
                colors: [_kPurple, _kCoral, _kAmber, _kBlue],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight).createShader(b),
            blendMode: BlendMode.srcIn,
            child: const T('FIND PEOPLE',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  letterSpacing: 2.5, color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ── Search bar ────────────────────────────────────────────
// ── Search bar ────────────────────────────────────────────

Widget _buildSearchBar() {
  // Invisible border with rounded corners — rounds the filled
  // background so it matches the gradient border outside.
  final rounded = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide.none,
  );

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: _GradientBorderBox(
      animation: _shimmerCtrl,
      radius: 16, borderWidth: 1.4, innerColor: _kCard,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _kCard,
            border:         rounded,
            enabledBorder:  rounded,
            focusedBorder:  rounded,
            disabledBorder: rounded,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: _kPurple,
            selectionColor: Color(0x33A78BFA),
            selectionHandleColor: _kPurple,
          ),
        ),
        child: Material(
          color: _kCard,
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: TextField(
            controller: _ctrl, autofocus: true,
            enableSuggestions: false, autocorrect: false,
            onChanged: _onChanged,
            cursorColor: _kPurple,
            style: TextStyle(
                fontFamily: 'Momo', fontSize: 15, color: _kInk),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kCard,
              hintText: TranslationService.I.tr('Search by name or student ID...'),
              hintStyle: TextStyle(
                  fontFamily: 'Momo', fontSize: 14,
                  color: _kSlate2),
              prefixIcon: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                    colors: [_kBlue, _kPurple]).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 22),
              ),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        _onChanged('');
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: _kCardLo,
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.close_rounded,
                            color: _kSlate, size: 18),
                      ),
                    )
                  : null,
              border:         rounded,
              enabledBorder:  rounded,
              focusedBorder:  rounded,
              disabledBorder: rounded,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ),
    ),
  );
}
  // ── Filter pills ──────────────────────────────────────────

  Widget _buildFilterPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _Filter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f   = _Filter.values[i];
          final sel = _filter == f;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filter = f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? f.accent.withOpacity(0.12) : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? f.accent.withOpacity(0.5) : _kBorder,
                  width: sel ? 1.4 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(f.icon,
                    size: 13,
                    color: sel ? f.accent : _kSlate),
                const SizedBox(width: 6),
                Text(f.label,
                    style: TextStyle(
                        fontFamily: 'Arch',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: sel ? f.accent : _kInkSoft)),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────

  Widget _buildBody() {
    final searching = _ctrl.text.trim().isNotEmpty;

    if (searching) {
      if (_loading) {
        return const Center(
            child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2.4));
      }
      final visible = _visibleResults;
      if (visible.isEmpty) {
        return _emptyResults();
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: visible.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _userCard(visible[i]),
        ),
      );
    }

    // Empty search → recents + helper.
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        if (_loadingRecents)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(height: 96,
              child: Row(children: List.generate(4, (_) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _RecentSkeleton(),
              )))),
          )
        else if (_recents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: _sectionLabel('Recent', Icons.history_rounded),
          ),
          SizedBox(
            height: 102,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _recents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _recentCard(_recents[i]),
            ),
          ),
          const SizedBox(height: 22),
        ],
        // Helper / placeholder when search empty
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _GradientBorderBox(
            animation: _shimmerCtrl,
            radius: 18, borderWidth: 1.4, innerColor: _kCard,
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kBlue, _kPurple]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: _kPurple.withOpacity(0.25),
                      blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.person_search_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 14),
              T('Find someone to chat with',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: _kInk, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              T('Type a name or student ID. Use the filters above\n'
                   'to narrow by status.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: _kSlate, height: 1.5)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _emptyResults() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded,
            size: 56, color: _kSlate2.withOpacity(0.5)),
        const SizedBox(height: 14),
        T('No people found',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
        const SizedBox(height: 4),
        Text(
          _filter == _Filter.all
              ? 'Try a different name or ID.'
              : 'No matches with the "${_filter.label}" filter.',
          style: TextStyle(fontSize: 12, color: _kSlate),
          textAlign: TextAlign.center,
        ),
        if (_filter != _Filter.all) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _filter = _Filter.all),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _kInk, borderRadius: BorderRadius.circular(11)),
              child: T('Clear filter',
                  style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.w800,
                      color: AppC.bg, fontSize: 12)),
            ),
          ),
        ],
      ]),
    ),
  );

  // ── Section label ─────────────────────────────────────────

  Widget _sectionLabel(String label, IconData icon) => Row(children: [
    Icon(icon, color: _kInk, size: 16),
    const SizedBox(width: 8),
    Text(label,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w900,
            color: _kInk, letterSpacing: -0.4)),
  ]);

  // ── Recent card (horizontal pill) ─────────────────────────

  Widget _recentCard(Map<String, dynamic> u) {
    final name      = u['name'] as String? ?? '?';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarUrl = u['avatar_url'] as String? ?? '';
    final online    = u['is_online'] as bool? ?? false;
    final accent    = _accentForName(name);

    return GestureDetector(
      onTap: () => _openChat(u),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [accent.withOpacity(0.85), accent]),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover)
                      : null,
                  boxShadow: [BoxShadow(
                      color: accent.withOpacity(0.25),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: avatarUrl.isEmpty
                    ? Center(child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)))
                    : null,
              ),
              if (online)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kCard, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 7),
            Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: _kInk, letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }

  // ── User card (vertical row) ──────────────────────────────

  Widget _userCard(Map<String, dynamic> u) {
    final isConnected = u['is_connected'] as bool? ?? false;
    final hasRoom     = u['room_id'] != null;
    final canChat     = isConnected || hasRoom;
    final uid         = u['user_id'] as String? ?? '';
    final sent        = _requestSent.contains(uid);
    final name        = u['name'] as String? ?? 'Unknown';
    final role        = u['role'] as String? ?? '';
    final avatarUrl   = u['avatar_url'] as String? ?? '';
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final online      = u['is_online'] as bool? ?? false;
    final accent      = _accentForName(name);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Stack(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [accent.withOpacity(0.85), accent]),
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                  : null,
              boxShadow: [BoxShadow(
                  color: accent.withOpacity(0.25),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: avatarUrl.isEmpty
                ? Center(child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.w800,
                        fontSize: 19)))
                : null,
          ),
          if (online)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kCard, width: 2),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Arch',
                    fontSize: 14, fontWeight: FontWeight.w900,
                    color: _kInk, letterSpacing: -0.3)),
            const SizedBox(height: 3),
            Row(children: [
              if (role.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(role.toUpperCase(),
                      style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w900,
                          color: accent, letterSpacing: 0.5)),
                ),
                const SizedBox(width: 6),
              ],
              if (!isConnected && !hasRoom)
                Flexible(
                  child: T('Not in your network',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: _kSlate)),
                ),
            ]),
          ],
        )),
        const SizedBox(width: 10),
        if (canChat)
          GestureDetector(
            onTap: () => _openChat(u),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kBlue, _kPurple]),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [BoxShadow(
                    color: _kPurple.withOpacity(0.30),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: const T('Chat',
                  style: TextStyle(
                      fontFamily: 'Arch',
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.2)),
            ),
          )
        else
          GestureDetector(
            onTap: sent ? null : () => _sendRequest(u),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sent
                    ? const Color(0xFF22C55E).withOpacity(0.12)
                    : _kAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: sent
                        ? const Color(0xFF22C55E).withOpacity(0.45)
                        : _kAmber.withOpacity(0.45)),
              ),
              child: Text(sent ? 'Sent ✓' : 'Request',
                  style: TextStyle(
                      fontFamily: 'Arch',
                      fontSize: 12, fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: sent
                          ? const Color(0xFF15803D)
                          : _kAmber)),
            ),
          ),
      ]),
    );

    // Connected users get an animated gradient border for emphasis.
    if (canChat) {
      return _GradientBorderBox(
        animation: _shimmerCtrl,
        radius: 16, borderWidth: 1.4,
        innerColor: _kCard,
        padding: EdgeInsets.zero,
        child: card,
      );
    }
    return card;
  }

  // Pick a stable accent based on the name's hash.
  Color _accentForName(String name) {
    const palette = [_kPurple, _kBlue, _kAmber, _kCoral];
    return palette[name.hashCode.abs() % palette.length];
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderBox — same idea as arcade's _GradientBorderCard
// (animated sweep gradient border around an inner surface).
// ═════════════════════════════════════════════════════════════

class _GradientBorderBox extends StatelessWidget {
  final Animation<double>   animation;
  final Widget              child;
  final double              radius;
  final double              borderWidth;
  final Color?               innerColor;
  final EdgeInsetsGeometry  padding;
  final List<Color>         colors;

  _GradientBorderBox({
    required this.animation,
    required this.child,
    this.radius = 16,
    this.borderWidth = 1.4,
    this.innerColor,
    this.padding = EdgeInsets.zero,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            math.max(0.0, radius - borderWidth)),
        color: innerColor ?? _kCard,
      ),
      padding: padding,
      child: child,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final v = animation.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
                colors: colors, startAngle: v, endAngle: v + 2 * math.pi),
          ),
          padding: EdgeInsets.all(borderWidth),
          child: c,
        );
      },
      child: inner,
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _RecentSkeleton — placeholder card while recents load.
// ═════════════════════════════════════════════════════════════

class _RecentSkeleton extends StatelessWidget {
  // Intentionally NOT invoked as `const` at the call site: the body reads
  // theme-aware AppC getters, and a const instance would be canonicalised and
  // skipped on rebuild, so it wouldn't repaint on a light/dark switch.
  const _RecentSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    width: 84,
    decoration: BoxDecoration(
      color: _kCardLo,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
  );
}