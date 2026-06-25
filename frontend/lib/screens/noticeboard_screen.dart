// lib/screens/noticeboard_screen.dart
//
// Student-facing Digital Notice Board — a pinned sticky-note board of
// announcements. Opened from an announcement push notification (pass
// highlightId to auto-open that note) or as a standalone screen.
// Uses CacheStore so it paints instantly on repeat visits.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kInk = Color(0xFF1A1A2E);
const _bgTop = Color(0xFF241247);
const _bgBot = Color(0xFF130A26);

const _kCacheKey = '/announcements/';

/// Set by the FCM handler in main.dart when the app is cold-launched by an
/// announcement push (terminated state). Consumed once by the splash after it
/// routes to the dashboard, then cleared. Null when there is nothing pending.
String? pendingAnnouncementId;

class NoticeboardScreen extends StatefulWidget {
  final String? highlightId;
  const NoticeboardScreen({super.key, this.highlightId});

  @override
  State<NoticeboardScreen> createState() => _NoticeboardScreenState();
}

class _NoticeboardScreenState extends State<NoticeboardScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _query = '';
  bool _highlightOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    CacheStore.I.swr(
      _kCacheKey,
      fetch: () => _api.get(_kCacheKey),
      onData: (data, fresh) {
        if (!mounted) return;
        final list = (data as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _items = list;
          _loading = false;
        });
        _maybeOpenHighlight();
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  void _maybeOpenHighlight() {
    if (_highlightOpened || widget.highlightId == null) return;
    final match = _items.where((a) => a['id'] == widget.highlightId).toList();
    if (match.isNotEmpty) {
      _highlightOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(match.first));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((a) =>
        (a['title'] ?? '').toString().toLowerCase().contains(q) ||
        (a['body'] ?? '').toString().toLowerCase().contains(q) ||
        (a['category_label'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  // ── Category styling ──────────────────────────────────────
  Color _cardColor(Map<String, dynamic> a) {
    final accent = (a['accent'] ?? '').toString();
    if (accent.startsWith('#') && (accent.length == 7 || accent.length == 9)) {
      try {
        final hex = accent.replaceFirst('#', '');
        return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      } catch (_) {}
    }
    switch ((a['category'] ?? 'general').toString()) {
      case 'academic':  return const Color(0xFFA5D6A7);
      case 'event':     return const Color(0xFFCE93D8);
      case 'job':       return const Color(0xFF90CAF9);
      case 'community': return const Color(0xFFF48FB1);
      case 'urgent':    return const Color(0xFFFFAB91);
      default:          return const Color(0xFFFFF59D);
    }
  }

  Color _pinColor(Map<String, dynamic> a) {
    switch ((a['category'] ?? 'general').toString()) {
      case 'academic':  return const Color(0xFF388E3C);
      case 'event':     return const Color(0xFF8E24AA);
      case 'job':       return const Color(0xFF1976D2);
      case 'community': return const Color(0xFFD81B60);
      case 'urgent':    return const Color(0xFFE64A19);
      default:          return const Color(0xFFF9A825);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBot],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _ConfettiPainter())),
          SafeArea(
            child: Column(children: [
              _header(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _kG1))
                    : _filtered.isEmpty
                        ? _empty()
                        : _board(),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        const Expanded(child: T('Notices',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white))),
      ]),
      const SizedBox(height: 6),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: T('Digital Notice Board',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 26, color: Colors.white)),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          style: const TextStyle(fontFamily: 'Momo', color: Colors.white, fontSize: 14),
          cursorColor: _kG1,
          decoration: InputDecoration(
            hintText: TranslationService.I.tr('Search notices'),
            hintStyle: TextStyle(fontFamily: 'Momo', color: Colors.white.withOpacity(.5)),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(.6)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
    ]),
  );

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const T('📌', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      T('No notices yet',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
              color: Colors.white.withOpacity(.9))),
      const SizedBox(height: 6),
      T('Announcements from staff will appear here',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: Colors.white.withOpacity(.5))),
    ]),
  );

  // Two-column masonry: each card goes into the shorter column.
  Widget _board() {
    final items = _filtered;
    final left = <Widget>[];
    final right = <Widget>[];
    var hL = 0.0, hR = 0.0;
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      final est = _estimateHeight(a);
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _NoteCard(
          data: a, color: _cardColor(a), pin: _pinColor(a),
          tilt: ((i % 5) - 2) * 0.012,
          onTap: () => _openDetail(a),
        ),
      );
      if (hL <= hR) { left.add(card); hL += est; } else { right.add(card); hR += est; }
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: 12),
          Expanded(child: Column(children: right)),
        ]),
      ],
    );
  }

  double _estimateHeight(Map<String, dynamic> a) {
    final body = (a['body'] ?? '').toString();
    final hasImg = (a['image_url'] ?? '').toString().isNotEmpty;
    return 110 + (hasImg ? 150 : 0) + (body.length / 28).clamp(0, 8) * 18;
  }

  void _openDetail(Map<String, dynamic> a) {
    HapticFeedback.selectionClick();
    // Fire-and-forget detail fetch to bump the view counter.
    final id = a['id']?.toString();
    if (id != null) { _api.get('/announcements/$id/').catchError((_) => null); }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(data: a, color: _cardColor(a), pin: _pinColor(a)),
    );
  }
}

// ── Sticky note card ─────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color, pin;
  final double tilt;
  final VoidCallback onTap;
  const _NoteCard({required this.data, required this.color, required this.pin,
      required this.tilt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = (data['image_url'] ?? '').toString();
    final pinned = data['is_pinned'] == true;
    final cat = (data['category_label'] ?? '').toString();
    return Transform.rotate(
      angle: tilt,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35),
                blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(Icons.push_pin_rounded, size: 22, color: pin),
              ),
            ),
            if (img.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(img, height: 120, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (cat.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pin.withOpacity(.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(cat.toUpperCase(),
                          style: TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold, fontSize: 8.5,
                              letterSpacing: .8, color: pin)),
                    ),
                  if (pinned) ...[
                    const Spacer(),
                    Icon(Icons.star_rounded, size: 14, color: pin),
                  ],
                ]),
                const SizedBox(height: 8),
                Text((data['title'] ?? '').toString(),
                    style: const TextStyle(fontFamily: 'Alfa', fontSize: 14,
                        color: _kInk, height: 1.2)),
                const SizedBox(height: 6),
                Text((data['body'] ?? '').toString(),
                    maxLines: 6, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        height: 1.35, color: _kInk.withOpacity(.8))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Detail bottom sheet ──────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color, pin;
  const _DetailSheet({required this.data, required this.color, required this.pin});

  @override
  Widget build(BuildContext context) {
    final img = (data['image_url'] ?? '').toString();
    return DraggableScrollableSheet(
      initialChildSize: .7, minChildSize: .4, maxChildSize: .95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: Container(width: 44, height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.push_pin_rounded, color: pin, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color,
                    borderRadius: BorderRadius.circular(10)),
                child: Text((data['category_label'] ?? '').toString().toUpperCase(),
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 10,
                        letterSpacing: .8, color: _kInk)),
              ),
            ]),
            const SizedBox(height: 14),
            if (img.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(14),
                child: Image.network(img, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            const SizedBox(height: 14),
            Text((data['title'] ?? '').toString(),
                style: const TextStyle(fontFamily: 'Alfa', fontSize: 22, color: _kInk)),
            const SizedBox(height: 10),
            Text((data['body'] ?? '').toString(),
                style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                    height: 1.5, color: _kInk.withOpacity(.85))),
            const SizedBox(height: 20),
            Row(children: [
              const Icon(Icons.verified_rounded, size: 16, color: _kG2),
              const SizedBox(width: 6),
              Text((data['author_name'] ?? 'Staff').toString(),
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 12, color: Colors.grey.shade700)),
            ]),
          ]),
      ),
    );
  }
}

// ── Confetti backdrop ────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [_kG1, _kG2, Color(0xFFF7971E), Color(0xFFFF5858), Color(0xFF43E97B)];
    final p = Paint();
    var seed = 7;
    double rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed % 1000) / 1000; }
    for (var i = 0; i < 46; i++) {
      p.color = colors[i % colors.length].withOpacity(.16);
      final x = rnd() * size.width;
      final y = rnd() * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd() * 3.14);
      canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 7, 3), const Radius.circular(1)), p);
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
