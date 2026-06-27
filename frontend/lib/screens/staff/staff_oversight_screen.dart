// lib/screens/staff/staff_oversight_screen.dart
//
// OVERSIGHT — searchable student roster with an engagement signal (online /
// last seen). Filter All / Active / Quiet. Tap a student to view their profile.
// Data: GET /api/moderation/staff/roster/?q=&filter=.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/csv_export.dart';
import 'package:tcs_app/screens/dashboard/other_user_profile_Screen.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kIndigo = kStaffG1;
const _kDeep   = kStaffG2;
const _kGreen  = Color(0xFF22C55E);

class StaffOversightScreen extends StatefulWidget {
  final String initialFilter; // all | active | quiet
  const StaffOversightScreen({super.key, this.initialFilter = 'all'});

  @override
  State<StaffOversightScreen> createState() => _StaffOversightScreenState();
}

class _StaffOversightScreenState extends State<StaffOversightScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  int _count = 0;
  bool _loading = true;
  late String _filter;
  Timer? _debounce;
  Map<String, dynamic>? _engagement;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    try {
      final d = await _api.get('/moderation/staff/engagement/')
          as Map<String, dynamic>;
      if (mounted) setState(() => _engagement = d);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.get('/moderation/staff/roster/', query: {
        'filter': _filter,
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _students = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _count = (d['count'] as num?)?.toInt() ?? _students.length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _export() async {
    final rows = <List<String>>[
      ['Name', 'Student ID', 'Online', 'Last seen', 'Suspended'],
      ..._students.map((s) => [
            (s['name'] ?? '').toString(),
            (s['user_id'] ?? '').toString(),
            s['is_online'] == true ? 'yes' : 'no',
            (s['last_seen'] ?? '').toString(),
            s['suspended'] == true ? 'yes' : 'no',
          ]),
    ];
    try {
      await exportCsv(filename: 'tcs_roster_$_filter.csv', rows: rows);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _header(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kDeep))
              : _students.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      color: _kDeep,
                      onRefresh: () async {
                        await Future.wait([_load(), _loadEngagement()]);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: _students.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) return _engagementCard();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _studentCard(_students[i - 1]));
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 12,
      horizontal: const EdgeInsets.only(left: 6, right: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop()),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            T('Student Roster',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 19,
                    color: Colors.white)),
          ])),
          Text('$_count',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 20,
                  color: Colors.white.withOpacity(0.9))),
          if (_students.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white,
                  size: 20),
              tooltip: 'Export CSV',
              onPressed: _export),
        ]),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: const TextStyle(fontFamily: 'Momo', fontSize: 14,
                color: Color(0xFF1F2937)),
            cursorColor: const Color(0xFF7C3AED),
            decoration: InputDecoration(
              hintText: 'Search students by name or ID…',
              hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF7C3AED), size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () { _searchCtrl.clear(); _onSearch(''); },
                      child: Icon(Icons.close_rounded,
                          color: Colors.grey.shade500, size: 18))
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const SizedBox(width: 8),
          _filterPill('all', 'All'),
          const SizedBox(width: 8),
          _filterPill('active', 'Active'),
          const SizedBox(width: 8),
          _filterPill('quiet', 'Quiet'),
        ]),
      ]),
    );
  }

  Widget _filterPill(String key, String label) {
    final sel = _filter == key;
    return GestureDetector(
      onTap: () {
        if (_filter == key) return;
        HapticFeedback.selectionClick();
        setState(() => _filter = key);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
            fontWeight: FontWeight.bold,
            color: sel ? _kDeep : Colors.white)),
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.people_outline_rounded, size: 52, color: AppC.border),
      const SizedBox(height: 14),
      Text('No students match', style: TextStyle(fontFamily: 'Momo',
          fontSize: 13.5, color: AppC.sub)),
    ]),
  );

  Widget _engagementCard() {
    final e = _engagement;
    if (e == null) {
      return const SizedBox.shrink();
    }
    final series = ((e['series'] as List?) ?? []).cast<Map<String, dynamic>>();
    final total = (e['total'] as num?)?.toInt() ?? 0;
    final posts = (e['posts_total'] as num?)?.toInt() ?? 0;
    final msgs = (e['messages_total'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          T('Cohort activity',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 15,
                  color: AppC.text)),
          const Spacer(),
          Text('last 14 days', style: TextStyle(fontFamily: 'Momo',
              fontSize: 10.5, color: AppC.faint)),
        ]),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$total', style: TextStyle(fontFamily: 'Alfa', fontSize: 26,
              color: AppC.text)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('actions · $posts posts · $msgs messages',
                style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                    color: AppC.sub)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarChartPainter(
              values: series.map((s) => (s['total'] as num?)?.toDouble() ?? 0)
                  .toList(),
              barColor: _kIndigo,
              trackColor: AppC.card2),
          ),
        ),
        const SizedBox(height: 4),
        if (series.isNotEmpty)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text((series.first['label'] ?? '').toString(),
                style: TextStyle(fontFamily: 'Momo', fontSize: 9,
                    color: AppC.faint)),
            Text('today', style: TextStyle(fontFamily: 'Momo', fontSize: 9,
                color: AppC.faint)),
          ]),
      ]),
    );
  }

  Widget _studentCard(Map<String, dynamic> s) {
    final name = (s['name'] ?? 'Student').toString();
    final uid = (s['user_id'] ?? '').toString();
    final online = s['is_online'] == true;
    final suspended = s['suspended'] == true;
    final avatar = (s['avatar_url'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () {
        if (uid.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtherUserProfileScreen(userId: uid)));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppC.border)),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
                shape: BoxShape.circle,
                image: avatar.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatar), fit: BoxFit.cover)
                    : null),
              child: avatar.isEmpty
                  ? Center(child: Text(initial,
                      style: const TextStyle(color: Colors.white,
                          fontFamily: 'Arch', fontWeight: FontWeight.bold)))
                  : null),
            if (online)
              Positioned(bottom: 0, right: 0, child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle,
                    border: Border.all(color: AppC.card, width: 2)))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Flexible(child: Text(name, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 14, color: AppC.text))),
              if (suspended) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFE11D48)
                      .withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('SUSPENDED', style: TextStyle(fontFamily: 'Arch',
                      fontSize: 8, fontWeight: FontWeight.bold,
                      color: Color(0xFFE11D48))),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text('$uid · ${_lastSeen(s['last_seen'] as String?, online)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: AppC.sub)),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 20),
        ]),
      ),
    );
  }

  String _lastSeen(String? iso, bool online) {
    if (online) return 'online now';
    if (iso == null) return 'never seen';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return 'seen ${d.inMinutes}m ago';
    if (d.inHours < 24) return 'seen ${d.inHours}h ago';
    if (d.inDays < 7) return 'seen ${d.inDays}d ago';
    return 'quiet ${d.inDays}d';
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final Color barColor, trackColor;
  _BarChartPainter({
    required this.values,
    required this.barColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final n = values.length;
    final gap = 4.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final track = Paint()..color = trackColor;
    final bar = Paint()..color = barColor;
    for (var i = 0; i < n; i++) {
      final x = i * (barW + gap);
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barW, size.height),
          const Radius.circular(3));
      canvas.drawRRect(r, track);
      final h = maxV <= 0 ? 0.0 : (values[i] / maxV) * size.height;
      // Fade older bars slightly so "today" pops.
      bar.color = barColor.withValues(alpha: 0.45 + 0.55 * (i / (n - 1)));
      final br = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(3));
      canvas.drawRRect(br, bar);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.values != values || old.barColor != barColor;
}
