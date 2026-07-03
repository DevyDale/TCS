// lib/screens/staff/staff_termination_screen.dart
//
// Staff-only Student Termination (Phase 1: the security core).
//   • Terminate tab: mandatory reason category + note + TYPED student-ID
//     confirmation before the action fires. Permanent bar is admin/lead only
//     (enforced server-side; a 403 is surfaced clearly). A safety/child-safety
//     reason is hard-routed to a safeguarding lead — never actioned here.
//   • History tab: the append-only termination log, filterable by reason.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/services/api_service.dart';

const _kDanger = Color(0xFFE11D48);

const _reasons = <(String, String)>[
  ('conduct',            'Serious misconduct'),
  ('harassment',         'Harassment / bullying'),
  ('academic_integrity', 'Academic dishonesty'),
  ('repeat_violations',  'Repeated violations'),
  ('safety',             'Safety / child-safety'),
  ('other',              'Other'),
];

String _reasonLabel(String key) =>
    _reasons.firstWhere((r) => r.$1 == key, orElse: () => (key, key)).$2;

class StaffTerminationScreen extends StatefulWidget {
  const StaffTerminationScreen({super.key});
  @override
  State<StaffTerminationScreen> createState() => _StaffTerminationScreenState();
}

class _StaffTerminationScreenState extends State<StaffTerminationScreen> {
  final _api = ApiService();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _header(),
        _tabs(),
        Expanded(
          child: _tab == 0
              ? _TerminateForm(api: _api, onDone: () => setState(() => _tab = 1))
              : _HistoryTab(api: _api),
        ),
      ]),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 14,
      horizontal: const EdgeInsets.only(left: 6, right: 16),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const Text('⛔', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Student Termination',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 19,
                  color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _tabs() {
    Widget seg(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: sel ? kStaffGrad : null,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Arch', fontSize: 13, fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : AppC.sub)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppC.card2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppC.border)),
      child: Row(children: [seg(0, 'Terminate'), seg(1, 'History')]),
    );
  }
}

// ── Terminate form ─────────────────────────────────────────────────────
class _TerminateForm extends StatefulWidget {
  final ApiService api;
  final VoidCallback onDone;
  const _TerminateForm({required this.api, required this.onDone});
  @override
  State<_TerminateForm> createState() => _TerminateFormState();
}

class _TerminateFormState extends State<_TerminateForm> {
  final _id = TextEditingController();
  final _note = TextEditingController();
  final _confirm = TextEditingController();
  String _reason = 'conduct';
  bool _permanent = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _id.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _id.dispose(); _note.dispose(); _confirm.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      _id.text.trim().isNotEmpty && _confirm.text.trim() == _id.text.trim();
  bool get _canSubmit =>
      _confirmed && _note.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    final isSafety = _reason == 'safety';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isSafety ? 'Route to safeguarding?' : 'Terminate student?',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
        content: Text(
          isSafety
              ? 'This has a safety / child-safety reason, so it will be routed '
                'to a safeguarding lead — not actioned as a normal termination.'
              : 'This bans ${_id.text.trim()}, ends all their sessions and hides '
                'their content. ${_permanent ? "A permanent bar keeps them from "
                "ever signing in again." : ""} This is recorded and can only be '
                'lifted by a lead.',
          style: TextStyle(fontFamily: 'Momo', fontSize: 13, height: 1.5,
              color: AppC.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppC.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(isSafety ? 'Route' : 'Terminate',
                  style: const TextStyle(color: _kDanger,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final res = await widget.api.terminateStudent(
        studentId: _id.text.trim(),
        reason: _reason,
        note: _note.text.trim(),
        confirmId: _confirm.text.trim(),
        permanent: _permanent,
      );
      if (!mounted) return;
      final routed = (res is Map) && res['routed'] == true;
      _snack(routed
          ? 'Routed to a safeguarding lead.'
          : 'Student terminated and barred.', ok: true);
      _id.clear(); _note.clear(); _confirm.clear();
      if (!routed) widget.onDone();
    } catch (e) {
      if (mounted) _snack(_clean(e), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clean(Object e) {
    final s = e.toString();
    return s.replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
  }

  void _snack(String m, {required bool ok}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? const Color(0xFF0EA5A4) : _kDanger,
          content: Text(m, style: const TextStyle(fontFamily: 'Momo',
              color: Colors.white)),
        ));

  @override
  Widget build(BuildContext context) {
    final isSafety = _reason == 'safety';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kDanger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kDanger.withValues(alpha: 0.30))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: _kDanger, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Termination bans the account, ends every session, hides their '
              'content and records a sealed, roster-level bar. It is not casual '
              'moderation.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, height: 1.4,
                  color: AppC.sub))),
          ]),
        ),
        const SizedBox(height: 18),

        _label('Student ID'),
        _field(_id, 'e.g. TCS2024001', TextInputType.text),
        const SizedBox(height: 16),

        _label('Reason category'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: staffCard(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _reason,
              isExpanded: true,
              dropdownColor: AppC.card,
              style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: AppC.text),
              items: [
                for (final r in _reasons)
                  DropdownMenuItem(value: r.$1, child: Text(r.$2)),
              ],
              onChanged: (v) => setState(() => _reason = v ?? 'conduct'),
            ),
          ),
        ),
        if (isSafety) ...[
          const SizedBox(height: 8),
          Text('Safety reasons are hard-routed to a safeguarding lead — they '
              'are never actioned as a normal termination here.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: const Color(0xFF0EA5A4), height: 1.4)),
        ],
        const SizedBox(height: 16),

        _label('Reason note (required)'),
        _field(_note, 'What happened — for the sealed record', TextInputType.multiline,
            maxLines: 4),
        const SizedBox(height: 16),

        if (!isSafety)
          Container(
            decoration: staffCard(),
            child: SwitchListTile(
              value: _permanent,
              activeThumbColor: _kDanger,
              onChanged: (v) => setState(() => _permanent = v),
              title: Text('Permanent bar',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 13.5, color: AppC.text)),
              subtitle: Text('Restricted to admins / safeguarding leads.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.sub)),
            ),
          ),
        const SizedBox(height: 16),

        _label('Type the student ID to confirm'),
        _field(_confirm, 'Retype the exact student ID', TextInputType.text,
            border: _confirm.text.isEmpty
                ? null
                : (_confirmed ? const Color(0xFF0EA5A4) : _kDanger)),
        const SizedBox(height: 22),

        GestureDetector(
          onTap: _canSubmit ? _submit : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _canSubmit ? 1 : 0.5,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSafety ? const Color(0xFF0EA5A4) : _kDanger,
                borderRadius: BorderRadius.circular(15),
              ),
              child: _busy
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : Text(isSafety ? 'Route to safeguarding' : 'Terminate student',
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, fontSize: 15,
                          color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t, style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 12.5, color: AppC.text)),
      );

  Widget _field(TextEditingController c, String hint, TextInputType kb,
      {int maxLines = 1, Color? border}) {
    return Container(
      decoration: BoxDecoration(
        color: AppC.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border ?? AppC.border,
            width: border != null ? 1.6 : 1)),
      child: TextField(
        controller: c,
        keyboardType: kb,
        maxLines: maxLines,
        style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: AppC.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.faint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}

// ── History tab ────────────────────────────────────────────────────────
class _HistoryTab extends StatefulWidget {
  final ApiService api;
  const _HistoryTab({required this.api});
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.api.terminationLog(
          reason: _filter.isEmpty ? null : _filter) as Map;
      if (!mounted) return;
      setState(() {
        _rows = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          itemCount: _reasons.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final key = i == 0 ? '' : _reasons[i - 1].$1;
            final label = i == 0 ? 'All' : _reasons[i - 1].$2;
            final sel = _filter == key;
            return GestureDetector(
              onTap: () { setState(() => _filter = key); _load(); },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: sel ? kStaffGrad : null,
                  color: sel ? null : AppC.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: sel ? Colors.transparent : AppC.border)),
                child: Text(label, style: TextStyle(fontFamily: 'Arch',
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppC.sub)),
              ),
            );
          },
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kStaffG2))
            : _rows.isEmpty
                ? Center(child: Text('No terminations recorded.',
                    style: TextStyle(fontFamily: 'Momo', color: AppC.sub)))
                : RefreshIndicator(
                    color: kStaffG2,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _row(_rows[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> r) {
    final active = r['is_active'] == true;
    final permanent = r['is_permanent'] == true;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            '${r['full_name'] ?? ''}  ·  ${r['student_id'] ?? ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 13.5, color: AppC.text))),
          _pill(active ? 'ACTIVE' : 'LIFTED',
              active ? _kDanger : AppC.faint),
        ]),
        const SizedBox(height: 4),
        Text(_reasonLabel((r['reason'] ?? '').toString())
            + (permanent ? '  ·  permanent' : ''),
            style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 0.4, color: kStaffG2)),
        if ((r['note'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(r['note'].toString(),
              style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, height: 1.35,
                  color: AppC.sub)),
        ],
        const SizedBox(height: 6),
        Text('by ${r['terminated_by'] ?? 'Staff'} · ${_ago(r['created_at'])}',
            style: TextStyle(fontFamily: 'Momo', fontSize: 10, color: AppC.faint)),
      ]),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7)),
        child: Text(t, style: TextStyle(fontFamily: 'Arch', fontSize: 8.5,
            fontWeight: FontWeight.bold, letterSpacing: 0.5, color: c)),
      );

  String _ago(dynamic iso) {
    final dt = DateTime.tryParse((iso ?? '').toString())?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}
