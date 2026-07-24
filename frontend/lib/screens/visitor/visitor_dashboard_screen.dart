// lib/screens/visitor/visitor_dashboard_screen.dart
//
// The ONLY screen a visitor/parent sees: a read-only campus showcase of
// club-authored public posts (PII-stripped server-side), with like/dislike and
// a tightly-restricted Dale cloud. No nav, no chat, no profiles, no search.
//
// Recreated to match the web "Campus Showcase" (dashboard.html): a dark layout
// with a brand top-bar, a gradient-text hero + personalised greeting, cards
// carrying a club logo, timestamp and "Campus" badge, and an Ask-Dale sheet.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/auth/role_selection_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFFF5858);

String _timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}

class VisitorDashboardScreen extends StatefulWidget {
  const VisitorDashboardScreen({super.key});

  @override
  State<VisitorDashboardScreen> createState() => _VisitorDashboardScreenState();
}

class _VisitorDashboardScreenState extends State<VisitorDashboardScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _name = '';

  @override
  void initState() { super.initState(); _load(); _loadName(); }

  Future<void> _loadName() async {
    try {
      final me = (await _api.getMyProfile() as Map).cast<String, dynamic>();
      final n = (me['name'] ?? me['display_name'] ?? '').toString().trim();
      if (mounted && n.isNotEmpty) setState(() => _name = n.split(' ').first);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final d = (await _api.get('/showcase/feed/')
          .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _posts = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _react(Map<String, dynamic> p, String reaction) async {
    final id = (p['id'] ?? '').toString();
    final prev = p['my_reaction'];
    setState(() {
      if (prev == reaction) {
        p['my_reaction'] = null;
        p['${reaction}s'] = ((p['${reaction}s'] as int?) ?? 1) - 1;
      } else {
        if (prev != null) p['${prev}s'] = ((p['${prev}s'] as int?) ?? 1) - 1;
        p['my_reaction'] = reaction;
        p['${reaction}s'] = ((p['${reaction}s'] as int?) ?? 0) + 1;
      }
    });
    HapticFeedback.selectionClick();
    try {
      await _api.post('/showcase/$id/react/', body: {'reaction': reaction});
    } catch (_) { _load(); }
  }

  Future<void> _logout() async {
    try { await _api.logout(); } catch (_) {}
    Get.offAll(() => const RoleSelectionScreen());
  }

  void _openDale() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _VisitorDaleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: _kG2, onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _topBar()),
          SliverToBoxAdapter(child: _hero()),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kG2)))
          else if (_posts.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _empty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(padding: const EdgeInsets.only(bottom: 16),
                    child: _postCard(_posts[i])),
                childCount: _posts.length)),
            ),
        ]),
      ),
    );
  }

  // ── Brand top bar ────────────────────────────────────────────────
  Widget _topBar() {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 14, 16, 8),
      child: Row(children: [
        // TCS gradient wordmark + eyebrow
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [_kG1, _kG2, _kG3, _kRed]).createShader(b),
              child: const Text('TCS', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 22, color: Colors.white, height: 1)),
            ),
            const SizedBox(height: 4),
            Text('CAMPUS SHOWCASE', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 9.5, letterSpacing: 2,
                color: AppC.sub)),
          ]),
        const Spacer(),
        // Ask Dale pill
        GestureDetector(onTap: _openDale, child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
          decoration: BoxDecoration(
            color: _kG2.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _kG2.withValues(alpha: 0.45))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 26, height: 26, child: Lottie.asset(
                'assets/images/robot.json', fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.smart_toy_rounded, color: Color(0xFFC6B3F5), size: 20))),
            const SizedBox(width: 6),
            const Text('Ask Dale', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFC6B3F5))),
          ]),
        )),
        const SizedBox(width: 10),
        // Log out pill
        GestureDetector(onTap: _logout, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppC.border)),
          child: Text('Log out', style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 12, color: AppC.sub)),
        )),
      ]),
    );
  }

  // ── Hero: eyebrow + gradient title + personalised subtitle ───────
  Widget _hero() {
    final who = _name.isNotEmpty ? _name : 'friend';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TAYLORS COLLEGE SYDNEY', style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 3, color: _kG1)),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: [_kG1, _kG2, _kG3]).createShader(b),
          child: const Text('Campus Showcase', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 38, height: 1.02, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Text('A window into life at TCS — clubs, events and the moments '
            'that make campus, $who.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 14, height: 1.5,
                color: AppC.sub)),
      ]),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎉', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 14),
        Text('Nothing posted yet', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 20, color: AppC.text)),
        const SizedBox(height: 8),
        Text('Club posts and events will show up here.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.sub)),
      ]));

  // ── Showcase card (web-matched) ──────────────────────────────────
  Widget _postCard(Map<String, dynamic> p) {
    final image = (p['image'] ?? '').toString();
    final logo  = (p['club_logo'] ?? '').toString();
    final likes = (p['likes'] as int?) ?? 0;
    final dislikes = (p['dislikes'] as int?) ?? 0;
    final mine = p['my_reaction'];
    final text = (p['text'] ?? '').toString().trim();
    return Container(
      decoration: BoxDecoration(color: AppC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppC.border)),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Head: logo · name/time · Campus badge
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: logo.isEmpty
                    ? const LinearGradient(colors: [_kG2, _kG1]) : null,
                image: logo.isNotEmpty
                    ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover) : null),
            alignment: Alignment.center,
            child: logo.isEmpty
                ? Text((p['club_name'] ?? 'C').toString().characters.first.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Alfa', color: Colors.white, fontSize: 16))
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
              Text((p['club_name'] ?? 'TCS Campus').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 14.5, color: AppC.text)),
              const SizedBox(height: 1),
              Text(_timeAgo(p['created_at']?.toString()),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, color: AppC.faint)),
            ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: _kG2.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7)),
            child: const Text('CAMPUS', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 1, color: _kG2)),
          ),
        ]),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(text, style: TextStyle(fontFamily: 'Momo', fontSize: 14.5, height: 1.5,
              color: AppC.text)),
        ],
        if (image.isNotEmpty) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(aspectRatio: 16 / 9,
              child: Image.network(image, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          _reactBtn(Icons.thumb_up_rounded, likes, mine == 'like', _kGreen,
              () => _react(p, 'like')),
          const SizedBox(width: 10),
          _reactBtn(Icons.thumb_down_rounded, dislikes, mine == 'dislike', _kRed,
              () => _react(p, 'dislike')),
        ]),
      ]),
    );
  }

  Widget _reactBtn(IconData icon, int count, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? color.withValues(alpha: 0.5) : AppC.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: active ? color : AppC.sub),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(fontFamily: 'Arch', fontSize: 13,
            fontWeight: FontWeight.bold, color: active ? color : AppC.sub)),
      ]),
    ));
  }
}

// ── Ask Dale sheet — clubs & events only ───────────────────────────
class _VisitorDaleSheet extends StatefulWidget {
  const _VisitorDaleSheet();
  @override
  State<_VisitorDaleSheet> createState() => _VisitorDaleSheetState();
}

class _VisitorDaleSheetState extends State<_VisitorDaleSheet> {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  final _msgs = <Map<String, String>>[];
  bool _busy = false;

  static const _chips = [
    'What clubs does TCS have?', 'What events are coming up?',
    'How do I join a club?', 'Tell me about campus life',
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send(String text) async {
    final m = text.trim();
    if (m.isEmpty || _busy) return;
    setState(() { _msgs.add({'role': 'user', 'content': m}); _busy = true; });
    _ctrl.clear();
    try {
      final hist = _msgs.where((e) => e['role'] != 'error').toList();
      final d = (await _api.post('/showcase/ai/', body: {
        'message': m, 'history': hist,
      }) as Map).cast<String, dynamic>();
      final resp = (d['response'] ?? d['error'] ?? '').toString();
      if (mounted) { setState(() => _msgs.add({'role': 'dale', 'content': resp})); }
    } catch (_) {
      if (mounted) {
        setState(() => _msgs.add({'role': 'dale',
            'content': "I can only share general info about clubs and events here."}));
      }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        height: (h * 0.72).clamp(360.0, 640.0),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppC.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [_kG2, _kG1], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(children: [
              SizedBox(width: 32, height: 32, child: Lottie.asset(
                  'assets/images/robot.json', fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded, color: Colors.white, size: 24))),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                  Text('Ask Dale', style: TextStyle(fontFamily: 'Alfa', fontSize: 17,
                      color: Colors.white)),
                  Text('Clubs & events only', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 10.5, color: Colors.white70)),
                ])),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
            ]),
          ),
          Expanded(child: _msgs.isEmpty
              ? _starters()
              : ListView.builder(
                  padding: const EdgeInsets.all(16), itemCount: _msgs.length,
                  itemBuilder: (_, i) => _bubble(_msgs[i]))),
          _inputBar(),
        ]),
      ),
    );
  }

  Widget _starters() => Padding(padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TRY ASKING…', style: TextStyle(fontFamily: 'Arch', fontSize: 11,
          fontWeight: FontWeight.bold, letterSpacing: 1.4, color: AppC.faint)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in _chips)
          GestureDetector(onTap: () => _send(c), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppC.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppC.border)),
            child: Text(c, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: AppC.text)))),
      ]),
    ]));

  Widget _bubble(Map<String, String> m) {
    final isUser = m['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          gradient: isUser ? const LinearGradient(colors: [_kG2, _kG1]) : null,
          color: isUser ? null : AppC.card2,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: AppC.border)),
        child: Text(m['content'] ?? '', style: TextStyle(fontFamily: 'Momo',
            fontSize: 13.5, height: 1.45,
            color: isUser ? Colors.white : AppC.text)),
      ),
    );
  }

  Widget _inputBar() => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(color: AppC.card,
        border: Border(top: BorderSide(color: AppC.border))),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppC.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppC.border)),
        child: TextField(controller: _ctrl, minLines: 1, maxLines: 3,
          style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: AppC.text),
          decoration: InputDecoration(border: InputBorder.none, isDense: true,
              hintText: 'Ask about clubs or events…',
              hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 13.5),
              contentPadding: const EdgeInsets.symmetric(vertical: 13)),
          onSubmitted: _send),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _busy ? null : () => _send(_ctrl.text),
        child: Container(width: 46, height: 46,
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kG2, _kG1]), shape: BoxShape.circle),
          child: _busy
              ? const Padding(padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22)),
      ),
    ]),
  );
}
