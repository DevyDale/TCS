// lib/screens/staff/child_safety_screen.dart
//
// Safeguarding leads' case queue — the child-safety lane of moderation. Cases
// arrive here when any staff member escalates a report (evidence preserved,
// content hidden). Leads review the preserved snapshot, add notes, record a
// report-to-authorities step, suspend the account, and close with an outcome.
// Every step is on an append-only audit trail. Server gates to leads (403).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kRed = Color(0xFFDC2626);

class ChildSafetyScreen extends StatefulWidget {
  const ChildSafetyScreen({super.key});

  @override
  State<ChildSafetyScreen> createState() => _ChildSafetyScreenState();
}

class _ChildSafetyScreenState extends State<ChildSafetyScreen> {
  final _api = ApiService();
  bool _loading = true, _forbidden = false;
  String _filter = 'open_active';
  List<Map<String, dynamic>> _cases = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.childSafetyCases(status: _filter) as Map;
      final list = (d['results'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _cases = list; _loading = false; _forbidden = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _forbidden = e.toString().contains('403') ||
            e.toString().toLowerCase().contains('safeguarding');
      });
    }
  }

  ({Color color, String label}) _sev(String s) => switch (s) {
        'critical' => (color: _kRed, label: 'Critical'),
        'urgent' => (color: const Color(0xFFEA580C), label: 'Urgent'),
        _ => (color: const Color(0xFFF59E0B), label: 'Review'),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: _kRed, onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: _kRed)))
            else if (_forbidden)
              SliverFillRemaining(hasScrollBody: false, child: _forbiddenView())
            else ...[
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(children: [
                  _chip('Active', 'open_active'),
                  const SizedBox(width: 8),
                  _chip('Reported', 'reported'),
                  const SizedBox(width: 8),
                  _chip('Closed', 'closed'),
                  const SizedBox(width: 8),
                  _chip('All', 'all'),
                ]),
              )),
              if (_cases.isEmpty)
                SliverFillRemaining(hasScrollBody: false,
                    child: staffNoResults('No cases in this view.'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 40),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _caseRow(_cases[i]),
                    childCount: _cases.length,
                  )),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() => StaffHeader(
        horizontal: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 38, height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Child Safety',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 23, color: Colors.white)),
              const SizedBox(height: 3),
              Text('Safeguarding case queue · leads only',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85))),
            ],
          )),
          const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
        ]),
      );

  Widget _forbiddenView() => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_rounded, color: _kRed, size: 44),
          const SizedBox(height: 14),
          Text('Safeguarding leads only',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: AppC.text)),
          const SizedBox(height: 8),
          Text('This queue is restricted to designated safeguarding leads. '
              'Ask an admin to grant access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5, color: AppC.sub)),
        ]),
      );

  Widget _chip(String label, String value) {
    final on = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? _kRed : AppC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? _kRed : AppC.border)),
        child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
            fontWeight: FontWeight.bold, color: on ? Colors.white : AppC.sub)),
      ),
    );
  }

  Widget _caseRow(Map<String, dynamic> c) {
    final sev = _sev((c['severity'] ?? 'urgent').toString());
    final status = (c['status'] ?? '').toString();
    return GestureDetector(
      onTap: () => _openCase(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: staffCard(border: sev.color.withValues(alpha: 0.45)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sev.color,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(sev.label, style: const TextStyle(fontFamily: 'Arch',
                  fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(width: 8),
            Text(_statusLabel(status),
                style: TextStyle(fontFamily: 'Arch', fontSize: 10.5,
                    fontWeight: FontWeight.bold, color: AppC.sub)),
            const Spacer(),
            Text(_ago(c['created_at']?.toString() ?? ''),
                style: TextStyle(fontFamily: 'Momo', fontSize: 10.5, color: AppC.faint)),
          ]),
          const SizedBox(height: 8),
          Text(c['reason']?.toString().isNotEmpty == true
              ? c['reason'].toString() : 'Child-safety concern',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14, color: AppC.text)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.person_rounded, size: 13, color: AppC.faint),
            const SizedBox(width: 4),
            Text('Subject: ${c['subject']}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
            const SizedBox(width: 12),
            Icon(Icons.flag_rounded, size: 12, color: AppC.faint),
            const SizedBox(width: 4),
            Text('by ${c['raised_by']}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.faint)),
          ]),
        ]),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'preserved' => 'Evidence preserved',
        'reported' => 'Reported to authorities',
        'closed' => 'Closed',
        _ => 'Open',
      };

  String _ago(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }

  void _openCase(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _CaseSheet(api: _api, caseId: c['id'].toString()),
    ).then((_) => _load());
  }
}

// ── Case detail + actions ───────────────────────────────────────────────
class _CaseSheet extends StatefulWidget {
  final ApiService api;
  final String caseId;
  const _CaseSheet({required this.api, required this.caseId});

  @override
  State<_CaseSheet> createState() => _CaseSheetState();
}

class _CaseSheetState extends State<_CaseSheet> {
  bool _loading = true, _busy = false;
  Map<String, dynamic>? _case;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.childSafetyCase(widget.caseId) as Map;
      if (!mounted) return;
      setState(() { _case = d.cast<String, dynamic>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(String action, {String? note}) async {
    setState(() => _busy = true);
    try {
      final d = await widget.api.childSafetyAction(widget.caseId, action, note: note) as Map;
      if (!mounted) return;
      setState(() { _case = d.cast<String, dynamic>(); _busy = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')));
      }
    }
  }

  Future<String?> _prompt(String title, String hint, {bool required = false}) async {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppC.card,
      title: Text(title, style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: AppC.text)),
      content: TextField(controller: c, autofocus: true, maxLines: 3,
        style: TextStyle(fontFamily: 'Momo', color: AppC.text),
        decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () {
          if (required && c.text.trim().isEmpty) return;
          Navigator.pop(ctx, c.text.trim());
        }, child: const Text('Save')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (ctx, scroll) {
        if (_loading) {
          return const Center(child: Padding(padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _kRed)));
        }
        final c = _case;
        if (c == null) {
          return Center(child: Padding(padding: const EdgeInsets.all(40),
              child: Text('Could not load case.',
                  style: TextStyle(fontFamily: 'Momo', color: AppC.sub))));
        }
        final p = (c['preserved'] as Map?)?.cast<String, dynamic>() ?? {};
        final trail = (c['trail'] as List? ?? [])
            .map((e) => (e as Map).cast<String, dynamic>()).toList();
        final status = (c['status'] ?? '').toString();
        final closed = status == 'closed';
        return ListView(controller: scroll, padding: const EdgeInsets.all(18),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppC.faint,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.shield_rounded, color: _kRed, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Child-safety case',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text))),
            ]),
            const SizedBox(height: 4),
            Text('${c['severity']?.toString().toUpperCase()} · ${c['status']}',
                style: TextStyle(fontFamily: 'Arch', fontSize: 11.5,
                    fontWeight: FontWeight.bold, color: _kRed)),
            const SizedBox(height: 16),

            // Preserved evidence (read-only snapshot)
            _section('Preserved evidence'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppC.bg, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppC.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _kv('Type', p['content_type']?.toString() ?? '—'),
                _kv('Reason', p['reason_label']?.toString() ?? c['reason']?.toString() ?? '—'),
                _kv('Author', p['author_name']?.toString() ?? '—'),
                _kv('Reported by', p['reporter_name']?.toString() ?? '—'),
                _kv('Captured', _fmt(p['captured_at']?.toString())),
                const SizedBox(height: 8),
                Text('Content snapshot', style: TextStyle(fontFamily: 'Arch',
                    fontSize: 11, fontWeight: FontWeight.bold, color: AppC.faint)),
                const SizedBox(height: 4),
                Text(p['preview']?.toString() ?? '(no preview)',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                        height: 1.4, color: AppC.text)),
                if ((p['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reporter note: ${p['description']}',
                      style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                          fontStyle: FontStyle.italic, color: AppC.sub)),
                ],
              ]),
            ),

            if ((c['notes'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _section('Case notes'),
              Container(width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppC.bg,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c['notes'].toString().trim(),
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12, height: 1.4,
                        color: AppC.text))),
            ],

            if (closed && (c['outcome'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              _section('Outcome'),
              Container(width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c['outcome'].toString(),
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.text))),
            ],

            const SizedBox(height: 16),
            _section('Audit trail'),
            ...trail.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 6, color: _kRed)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    '${t['actor']} · ${t['action'].toString().replaceAll('child_safety.', '')}'
                    '${(t['summary'] ?? '').toString().isNotEmpty ? " — ${t['summary']}" : ""}',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub))),
                Text(_fmt(t['at']?.toString()),
                    style: TextStyle(fontFamily: 'Momo', fontSize: 9.5, color: AppC.faint)),
              ]),
            )),

            const SizedBox(height: 20),
            // Actions
            if (!closed) ...[
              if (_busy)
                const Center(child: CircularProgressIndicator(color: _kRed))
              else ...[
                _btn('Add note', Icons.note_add_rounded, kStaffG1, () async {
                  final note = await _prompt('Add a case note', 'What happened / next step',
                      required: true);
                  if (note != null && note.isNotEmpty) _action('add_note', note: note);
                }),
                const SizedBox(height: 8),
                if (status != 'reported')
                  _btn('Record: reported to authorities', Icons.gavel_rounded,
                      const Color(0xFFEA580C), () async {
                    final note = await _prompt('Report to authorities',
                        'Reference / who was contacted (optional)');
                    _action('report_authorities', note: note ?? '');
                  }),
                if (status != 'reported') const SizedBox(height: 8),
                if ((c['subject_id'] ?? '').toString().isNotEmpty)
                  _btn('Suspend the account', Icons.lock_rounded, _kRed,
                      () => _action('suspend_subject')),
                if ((c['subject_id'] ?? '').toString().isNotEmpty) const SizedBox(height: 8),
                _btn('Close case (with outcome)', Icons.check_circle_rounded,
                    const Color(0xFF16A34A), () async {
                  final note = await _prompt('Close case',
                      'Outcome — required', required: true);
                  if (note != null && note.isNotEmpty) _action('close', note: note);
                }),
              ],
            ] else
              _btn('Reopen case', Icons.refresh_rounded, kStaffG1,
                  () => _action('reopen')),
            const SizedBox(height: 24),
          ]);
      },
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(fontFamily: 'Alfa', fontSize: 14, color: AppC.text)),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(k, style: TextStyle(fontFamily: 'Arch',
              fontSize: 11, fontWeight: FontWeight.bold, color: AppC.faint))),
          Expanded(child: Text(v, style: TextStyle(fontFamily: 'Momo',
              fontSize: 12, color: AppC.text))),
        ]),
      );

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton.icon(
          onPressed: () { HapticFeedback.selectionClick(); onTap(); },
          icon: Icon(icon, size: 18, color: Colors.white),
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          label: Text(label, style: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, color: Colors.white))),
      );

  String _fmt(String? iso) {
    if (iso == null) return '—';
    final t = DateTime.tryParse(iso);
    if (t == null) return '—';
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.day}/${l.month} ${two(l.hour)}:${two(l.minute)}';
  }
}
