// lib/screens/visitor/visitor_dashboard_screen.dart
//
// The ONLY screen a visitor/parent sees: a read-only campus showcase of
// club-authored public posts (PII-stripped server-side), with like/dislike and
// a tightly-restricted Dale cloud. No nav, no chat, no profiles, no search.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/auth/role_selection_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);

class VisitorDashboardScreen extends StatefulWidget {
  const VisitorDashboardScreen({super.key});

  @override
  State<VisitorDashboardScreen> createState() => _VisitorDashboardScreenState();
}

class _VisitorDashboardScreenState extends State<VisitorDashboardScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _daleOpen = false;

  @override
  void initState() { super.initState(); _load(); }

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
    // optimistic
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
    } catch (_) { _load(); /* revert via reload on failure */ }
  }

  Future<void> _logout() async {
    try { await _api.logout(); } catch (_) {}
    Get.offAll(() => const RoleSelectionScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: _daleFab(),
      body: Stack(children: [
        RefreshIndicator(
          color: _kG2, onRefresh: _load,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: _kG2)))
            else if (_posts.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _empty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12),
                      child: _postCard(_posts[i])),
                  childCount: _posts.length)),
              ),
          ]),
        ),
        // Dale chat cloud overlay — anchored above the FAB, dismiss on scrim tap.
        if (_daleOpen) ...[
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _daleOpen = false),
            child: Container(color: Colors.black.withValues(alpha: 0.35)))),
          Positioned(
            right: 14, left: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom + 12
                : MediaQuery.of(context).padding.bottom + 96,
            child: _VisitorDaleCloud(
                onClose: () => setState(() => _daleOpen = false)),
          ),
        ],
      ]),
    );
  }

  Widget _daleFab() {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick();
        setState(() => _daleOpen = !_daleOpen); },
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_kG1, _kG2],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: _kG2.withValues(alpha: 0.45),
              blurRadius: 18, offset: const Offset(0, 8))]),
        padding: const EdgeInsets.all(8),
        child: Lottie.asset('assets/images/robot.json', fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.smart_toy_rounded, color: Colors.white, size: 30)),
      ),
    );
  }

  Widget _header() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 18, 16, 22),
      decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [_kG1, _kG2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Campus Showcase', style: TextStyle(fontFamily: 'Alfa',
                fontSize: 24, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Clubs & events at Taylors College Sydney',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.9))),
          ])),
        GestureDetector(
          onTap: _logout,
          child: Container(
            width: 42, height: 42, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
            child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20)),
        ),
      ]),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.celebration_rounded, size: 52, color: AppC.faint),
        const SizedBox(height: 12),
        Text('Nothing posted yet', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 18, color: AppC.text)),
        const SizedBox(height: 6),
        Text('Club posts and events will show up here.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
      ]));

  Widget _postCard(Map<String, dynamic> p) {
    final image = (p['image'] ?? '').toString();
    final likes = (p['likes'] as int?) ?? 0;
    final dislikes = (p['dislikes'] as int?) ?? 0;
    final mine = p['my_reaction'];
    return Container(
      decoration: BoxDecoration(color: AppC.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Image.network(image, width: double.infinity, height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 26, height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _kG2.withValues(alpha: 0.15),
                    image: (p['club_logo'] ?? '').toString().isNotEmpty
                        ? DecorationImage(image: NetworkImage(p['club_logo']),
                            fit: BoxFit.cover) : null),
                alignment: Alignment.center,
                child: (p['club_logo'] ?? '').toString().isEmpty
                    ? const Icon(Icons.local_activity_rounded, size: 14, color: _kG2)
                    : null),
              const SizedBox(width: 8),
              Text((p['club_name'] ?? 'Club').toString(),
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 12.5, color: AppC.text)),
            ]),
            if ((p['text'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text((p['text']).toString(),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 13, height: 1.4,
                      color: AppC.text.withValues(alpha: 0.9))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _reactBtn(Icons.thumb_up_rounded, likes, mine == 'like',
                  const Color(0xFF22C55E), () => _react(p, 'like')),
              const SizedBox(width: 10),
              _reactBtn(Icons.thumb_down_rounded, dislikes, mine == 'dislike',
                  const Color(0xFFFF5858), () => _react(p, 'dislike')),
            ]),
          ])),
      ]),
    );
  }

  Widget _reactBtn(IconData icon, int count, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.14) : AppC.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : AppC.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: active ? color : AppC.sub),
        const SizedBox(width: 6),
        Text('$count', style: TextStyle(fontFamily: 'Arch', fontSize: 12,
            fontWeight: FontWeight.bold, color: active ? color : AppC.sub)),
      ]),
    ));
  }

}

class _VisitorDaleCloud extends StatefulWidget {
  final VoidCallback onClose;
  const _VisitorDaleCloud({required this.onClose});
  @override
  State<_VisitorDaleCloud> createState() => _VisitorDaleCloudState();
}

class _VisitorDaleCloudState extends State<_VisitorDaleCloud>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  final _msgs = <Map<String, String>>[]; // {role, content}
  bool _busy = false;

  static const _chips = [
    'What clubs does TCS have?', 'What events are coming up?',
    'Tell me about campus life', 'How do I use this app?',
  ];

  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320))..forward();

  @override
  void dispose() { _ctrl.dispose(); _pop.dispose(); super.dispose(); }

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
      if (mounted) setState(() => _msgs.add({'role': 'dale', 'content': resp}));
    } catch (_) {
      if (mounted) setState(() => _msgs.add({'role': 'dale',
          'content': "I can only share general info about clubs and events here."}));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    // Speech-bubble cloud: a rounded card with a tail pointing down toward the
    // robot FAB at the bottom-right.
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: _pop,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Material(
            color: Colors.transparent,
            child: Container(
              height: (kb > 0 ? (h - kb - 120) : h * 0.52).clamp(300.0, 520.0),
              decoration: BoxDecoration(
                color: AppC.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppC.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 26, offset: const Offset(0, 12))]),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  decoration: const BoxDecoration(gradient: LinearGradient(
                      colors: [_kG1, _kG2],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Row(children: [
                    SizedBox(width: 30, height: 30, child: Lottie.asset(
                        'assets/images/robot.json', fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.smart_toy_rounded, color: Colors.white, size: 22))),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Ask Dale',
                        style: TextStyle(fontFamily: 'Alfa', fontSize: 17,
                            color: Colors.white))),
                    Text('clubs & events only', style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: widget.onClose,
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20)),
                  ]),
                ),
                Expanded(child: _msgs.isEmpty
                    ? _starters()
                    : ListView.builder(
                        padding: const EdgeInsets.all(14), itemCount: _msgs.length,
                        itemBuilder: (_, i) => _bubble(_msgs[i]))),
                _inputBar(),
              ]),
            ),
          ),
          // Tail pointing to the FAB (bottom-right)
          Padding(
            padding: const EdgeInsets.only(right: 26),
            child: Align(
              alignment: Alignment.centerRight,
              child: ClipPath(
                clipper: _TailClipper(),
                child: Container(width: 22, height: 12, color: AppC.card),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _starters() => Padding(padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Try asking…', style: TextStyle(fontFamily: 'Arch', fontSize: 12,
          fontWeight: FontWeight.bold, color: AppC.sub)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in _chips)
          GestureDetector(onTap: () => _send(c), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: AppC.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppC.border)),
            child: Text(c, style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                color: AppC.text)))),
      ]),
    ]));

  Widget _bubble(Map<String, String> m) {
    final isUser = m['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? _kG2 : AppC.bg,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: AppC.border)),
        child: Text(m['content'] ?? '', style: TextStyle(fontFamily: 'Momo',
            fontSize: 13, height: 1.4,
            color: isUser ? Colors.white : AppC.text)),
      ),
    );
  }

  Widget _inputBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: AppC.card,
        border: Border(top: BorderSide(color: AppC.border))),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppC.bg,
            borderRadius: BorderRadius.circular(22)),
        child: TextField(controller: _ctrl, minLines: 1, maxLines: 3,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13.5, color: AppC.text),
          decoration: InputDecoration(border: InputBorder.none, isDense: true,
              hintText: 'Ask about clubs or events…',
              hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 12)),
          onSubmitted: _send),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _busy ? null : () => _send(_ctrl.text),
        child: Container(width: 46, height: 46,
          decoration: const BoxDecoration(color: _kG2, shape: BoxShape.circle),
          child: _busy
              ? const Padding(padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22)),
      ),
    ]),
  );
}

// Small downward triangle tail for the Dale chat cloud.
class _TailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width / 2, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
