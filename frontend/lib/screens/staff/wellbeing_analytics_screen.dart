// lib/screens/staff/wellbeing_analytics_screen.dart
//
// Wellbeing analytics for designated safeguarding staff: an urgent triage queue
// (named, severity-sorted) pinned at the top, then anonymous aggregate breakdown
// (index, tiers, themes). Every case action is audited server-side. The AI is a
// triage signal — every flag needs human review; immediate danger → a crisis
// line, not in-app handling.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kCoral = Color(0xFFFF5858);
const _kTiers = <String, (String, Color)>{
  'thriving':   ('Thriving',   Color(0xFF22C55E)),
  'okay':       ('Okay',       Color(0xFF6DD5FA)),
  'struggling': ('Struggling', Color(0xFFF7971E)),
  'at_risk':    ('At-risk',    _kCoral),
};

class WellbeingAnalyticsScreen extends StatefulWidget {
  const WellbeingAnalyticsScreen({super.key});

  @override
  State<WellbeingAnalyticsScreen> createState() => _WellbeingAnalyticsScreenState();
}

class _WellbeingAnalyticsScreenState extends State<WellbeingAnalyticsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _cases = [];
  bool _loading = true;
  bool _forbidden = false;
  String _range = '7d';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final o = await _api.get('/wellbeing/overview/?range=$_range')
          .catchError((_) => <String, dynamic>{});
      final c = await _api.get('/wellbeing/cases/')
          .catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      final om = (o as Map?)?.cast<String, dynamic>() ?? {};
      if (om['error'] != null) {
        setState(() { _forbidden = true; _loading = false; });
        return;
      }
      setState(() {
        _overview = om;
        _cases = (((c as Map?)?['results'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _call(String n) async {
    final u = Uri(scheme: 'tel', path: n.replaceAll(' ', ''));
    if (await canLaunchUrl(u)) await launchUrl(u);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: _kCoral, onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()), padding: EdgeInsets.zero, children: [
          _header(),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: _kCoral)))
          else if (_forbidden)
            _forbiddenView()
          else ...[
            const SizedBox(height: 14),
            _rangeChips(),
            const SizedBox(height: 14),
            if (_cases.isNotEmpty) _urgentQueue(),
            _indexCard(),
            _tierBars(),
            _themes(),
            _helpSeeking(),
            const SizedBox(height: 40),
          ],
        ]),
      ),
    );
  }

  Widget _header() => StaffHeader(
        bottomPad: 22,
        horizontal: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(onTap: () => Navigator.of(context).maybePop(),
              child: Container(width: 40, height: 40, decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
            const Spacer(),
            const Icon(Icons.favorite_rounded, color: Colors.white70, size: 22),
          ]),
          const SizedBox(height: 14),
          const Text('Wellbeing', style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
              color: Colors.white, shadows: [Shadow(color: Colors.black26,
                  blurRadius: 8, offset: Offset(0, 3))])),
          const SizedBox(height: 6),
          Text('Campus signal · a triage aid, not a clinical tool',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
      );

  Widget _forbiddenView() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 0),
        child: Column(children: [
          Icon(Icons.lock_person_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 14),
          Text('Designated staff only', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 18, color: AppC.text)),
          const SizedBox(height: 8),
          Text('Wellbeing cases name students, so this is restricted to '
              'safeguarding staff. Ask an admin for access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: AppC.sub, height: 1.5)),
        ]),
      );

  Widget _rangeChips() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final r in const ['7d', '30d', '90d'])
            Padding(padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { setState(() => _range = r); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: _range == r ? _kCoral : AppC.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _range == r ? _kCoral : AppC.border)),
                  child: Text(r, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _range == r ? Colors.white : AppC.sub)),
                ),
              )),
        ]),
      );

  // ── Urgent queue ──────────────────────────────────────────
  Widget _urgentQueue() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCoral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCoral.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.priority_high_rounded, color: _kCoral, size: 18),
          const SizedBox(width: 6),
          Text('Urgent — needs review', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 15, color: _kCoral)),
        ]),
        const SizedBox(height: 10),
        for (final c in _cases) _caseRow(c),
      ]),
    );
  }

  Color _sevColor(String s) => s == 'critical' ? _kCoral
      : s == 'high' ? const Color(0xFFF7971E) : const Color(0xFF6DD5FA);

  Widget _caseRow(Map<String, dynamic> c) {
    final sev = (c['severity'] ?? 'watch').toString();
    return GestureDetector(
      onTap: () => _openCase(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppC.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppC.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _sevColor(sev).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(sev.toUpperCase(), style: TextStyle(fontFamily: 'Arch',
                  fontSize: 8.5, fontWeight: FontWeight.bold, color: _sevColor(sev)))),
            const SizedBox(width: 8),
            Expanded(child: Text((c['student'] ?? 'Student').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13, color: AppC.text))),
            Text((c['status'] ?? '').toString(),
                style: TextStyle(fontFamily: 'Momo', fontSize: 9.5, color: AppC.faint)),
          ]),
          if ((c['snippet'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('“${c['snippet']}”', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, height: 1.35,
                    color: AppC.sub, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 4),
          Text((c['ai_reason'] ?? '').toString(),
              style: TextStyle(fontFamily: 'Momo', fontSize: 10.5, color: AppC.faint)),
        ]),
      ),
    );
  }

  void _openCase(Map<String, dynamic> c) {
    showModalBottomSheet(context: context, backgroundColor: AppC.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _CaseSheet(api: _api, caseId: c['id'].toString(),
          onChanged: _load, call: _call));
  }

  // ── Aggregate ─────────────────────────────────────────────
  Widget _indexCard() {
    final idx = _overview?['wellbeing_index'];
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(padding: const EdgeInsets.all(16), decoration: staffCard(),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wellbeing index', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 11, fontWeight: FontWeight.bold, color: AppC.sub)),
              const SizedBox(height: 4),
              Text(idx == null ? '—' : '${(idx * 100).round()}',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 30, color: AppC.text)),
            ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_overview?['signals'] ?? 0} signals', style: TextStyle(
                fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
            Text('${_overview?['open_cases'] ?? 0} open cases', style: TextStyle(
                fontFamily: 'Momo', fontSize: 11, color: _kCoral)),
          ]),
        ]),
      ));
  }

  Widget _tierBars() {
    final tiers = (_overview?['tiers'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = tiers.values.fold<int>(0, (s, v) => s + ((v as int?) ?? 0));
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(padding: const EdgeInsets.all(16), decoration: staffCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sentiment tiers', style: TextStyle(fontFamily: 'Arch', fontSize: 11,
              fontWeight: FontWeight.bold, color: AppC.sub)),
          const SizedBox(height: 12),
          for (final e in _kTiers.entries)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              SizedBox(width: 72, child: Text(e.value.$1, style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11, color: AppC.text))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : ((tiers[e.key] as int?) ?? 0) / total,
                  minHeight: 9, backgroundColor: AppC.bg, color: e.value.$2))),
              const SizedBox(width: 8),
              SizedBox(width: 26, child: Text('${tiers[e.key] ?? 0}',
                  textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Arch',
                      fontSize: 11, fontWeight: FontWeight.bold, color: AppC.sub))),
            ])),
        ]),
      ));
  }

  Widget _themes() {
    final themes = ((_overview?['themes'] as List?) ?? []).cast<Map<String, dynamic>>();
    if (themes.isEmpty) return const SizedBox.shrink();
    final maxC = themes.map((t) => (t['count'] as int?) ?? 0).fold<int>(1, (a, b) => b > a ? b : a);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(padding: const EdgeInsets.all(16), decoration: staffCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top themes', style: TextStyle(fontFamily: 'Arch', fontSize: 11,
              fontWeight: FontWeight.bold, color: AppC.sub)),
          const SizedBox(height: 12),
          for (final t in themes.take(8))
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              SizedBox(width: 96, child: Text((t['theme'] ?? '').toString(),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.text))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ((t['count'] as int?) ?? 0) / maxC, minHeight: 9,
                  backgroundColor: AppC.bg, color: const Color(0xFF8E54E9)))),
              const SizedBox(width: 8),
              Text('${t['count'] ?? 0}', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 11, fontWeight: FontWeight.bold, color: AppC.sub)),
            ])),
        ]),
      ));
  }

  Widget _helpSeeking() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(padding: const EdgeInsets.all(14), decoration: staffCard(),
          child: Row(children: [
            const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF22C55E), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('${_overview?['help_seeking'] ?? 0} students engaged '
                'Dale on a wellbeing topic', style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: AppC.text))),
          ]),
        ),
      );
}

class _CaseSheet extends StatefulWidget {
  final ApiService api;
  final String caseId;
  final VoidCallback onChanged;
  final Future<void> Function(String) call;
  const _CaseSheet({required this.api, required this.caseId,
      required this.onChanged, required this.call});
  @override
  State<_CaseSheet> createState() => _CaseSheetState();
}

class _CaseSheetState extends State<_CaseSheet> {
  Map<String, dynamic>? _c;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final d = (await widget.api.get('/wellbeing/cases/${widget.caseId}/')
        .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
    if (mounted) setState(() => _c = d);
  }

  Future<void> _act(String action, {String? note}) async {
    setState(() => _busy = true);
    try {
      await widget.api.post('/wellbeing/cases/${widget.caseId}/action/',
          body: {'action': action, if (note != null) 'note': note});
      widget.onChanged();
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {} finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _dismiss() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppC.card,
      title: Text('Dismiss as false positive?', style: TextStyle(fontFamily: 'Alfa',
          color: AppC.text, fontSize: 16)),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(hintText: 'Reason (required)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss', style: TextStyle(color: _kCoral))),
      ],
    ));
    if (ok == true && ctrl.text.trim().isNotEmpty) _act('dismiss', note: ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return DraggableScrollableSheet(expand: false, initialChildSize: 0.8,
      maxChildSize: 0.95, minChildSize: 0.5,
      builder: (ctx, scroll) => c == null
          ? const Center(child: Padding(padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _kCoral)))
          : ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text((c['student'] ?? 'Student').toString(), style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 20, color: AppC.text)),
              const SizedBox(height: 4),
              Text('${c['severity']} · ${c['status']}', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11.5, color: _kCoral)),
              const SizedBox(height: 16),
              if ((c['snippet'] ?? '').toString().isNotEmpty)
                Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppC.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppC.border)),
                  child: Text('“${c['snippet']}”', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 13, height: 1.5, color: AppC.text,
                      fontStyle: FontStyle.italic))),
              const SizedBox(height: 10),
              Text((c['ai_reason'] ?? '').toString(), style: TextStyle(
                  fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
              const SizedBox(height: 18),
              // Crisis routing — prominent.
              GestureDetector(onTap: () => widget.call('13 11 14'),
                child: Container(padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _kCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kCoral.withValues(alpha: 0.4))),
                  child: Row(children: [
                    const Icon(Icons.emergency_share_rounded, color: _kCoral, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Immediate danger? Call Lifeline 13 11 14 — '
                        'do not handle acute risk in-app.',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                            height: 1.4, color: AppC.text))),
                  ]))),
              const SizedBox(height: 18),
              if (_busy)
                const Center(child: CircularProgressIndicator(color: _kCoral))
              else ...[
                Row(children: [
                  _btn('Acknowledge', const Color(0xFF6DD5FA),
                      () => _act('acknowledge')),
                  const SizedBox(width: 8),
                  _btn('Assign to me', const Color(0xFF8E54E9), () => _act('assign')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _btn('Escalate', const Color(0xFFF7971E), () => _act('escalate')),
                  const SizedBox(width: 8),
                  _btn('Resolve', const Color(0xFF22C55E), () => _act('resolve')),
                ]),
                const SizedBox(height: 8),
                _btn('Dismiss (false positive)', AppC.faint, _dismiss, full: true),
              ],
              const SizedBox(height: 30),
            ]),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap, {bool full = false}) {
    final w = GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
          fontWeight: FontWeight.bold, color: color)),
    ));
    return full ? SizedBox(width: double.infinity, child: w) : Expanded(child: w);
  }
}
