// lib/screens/staff/suggestions_review_screen.dart
//
// "Voice of Campus" — staff review of student suggestions to the school.
//   GET   /feedback/school/             (list, enriched)
//   PATCH /feedback/staff/<id>/         status / priority / note / flag
//   POST  /feedback/staff/<id>/reply/   notify the student

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kViolet = Color(0xFF8E54E9);

const _statuses = <List<String>>[
  ['new', 'New'], ['under_review', 'Reviewing'], ['planned', 'Planned'],
  ['done', 'Done'], ['wont_do', "Won't do"],
];

Color _statusColor(String s) {
  switch (s) {
    case 'planned': return const Color(0xFF2563EB);
    case 'done': return const Color(0xFF059669);
    case 'wont_do': return AppC.faint;
    case 'under_review': return const Color(0xFFF59E0B);
    default: return _kViolet;
  }
}

String _statusLabel(String s) =>
    _statuses.firstWhere((e) => e[0] == s, orElse: () => [s, s])[1];

class SuggestionsReviewScreen extends StatefulWidget {
  const SuggestionsReviewScreen({super.key});

  @override
  State<SuggestionsReviewScreen> createState() => _SuggestionsReviewScreenState();
}

class _SuggestionsReviewScreenState extends State<SuggestionsReviewScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await _api.get('/feedback/school/').catchError((_) => []);
      if (!mounted) return;
      setState(() {
        _items = (d as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _filter.isEmpty
        ? _items
        : _items.where((s) => s['status'] == _filter).toList();
    list.sort((a, b) => ((b['priority'] as int?) ?? 0)
        .compareTo((a['priority'] as int?) ?? 0));
    return list;
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : _kViolet,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo', color: Colors.white))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: _kViolet, onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()), padding: EdgeInsets.zero, children: [
          _header(),
          const SizedBox(height: 14),
          SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              _chip('', 'All'),
              for (final s in _statuses) _chip(s[0], s[1]),
            ])),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator(color: _kViolet)))
          else if (_filtered.isEmpty)
            staffNoResults('No suggestions here.')
          else
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(children: [
                for (final s in _filtered) ...[_card(s), const SizedBox(height: 10)],
              ])),
        ]),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final sel = _filter == value;
    return Padding(padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: sel ? _kViolet : AppC.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? _kViolet : AppC.border)),
          child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
              fontWeight: FontWeight.bold, color: sel ? Colors.white : AppC.sub)),
        ),
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
            const Icon(Icons.lightbulb_rounded, color: Colors.white70, size: 22),
          ]),
          const SizedBox(height: 14),
          const Text('Voice of Campus', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 24, color: Colors.white, shadows: [Shadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))])),
          const SizedBox(height: 6),
          Text('Student suggestions to the school',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
      );

  Widget _card(Map<String, dynamic> s) {
    final status = (s['status'] ?? 'new').toString();
    final flagged = s['is_flagged'] == true;
    final priority = (s['priority'] as int?) ?? 0;
    return GestureDetector(
      onTap: () => _openDetail(s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: staffCard(border: flagged ? const Color(0xFFFF5858).withValues(alpha: 0.4) : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text((s['title'] ?? '').toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14, color: AppC.text))),
            if (flagged) const Icon(Icons.flag_rounded, size: 14, color: Color(0xFFFF5858)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7)),
              child: Text(_statusLabel(status).toUpperCase(), style: TextStyle(
                  fontFamily: 'Arch', fontSize: 8, fontWeight: FontWeight.bold,
                  color: _statusColor(status)))),
          ]),
          const SizedBox(height: 6),
          Text((s['message'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, height: 1.35, color: AppC.sub)),
          const SizedBox(height: 8),
          Row(children: [
            Text('by ${s['student_name'] ?? 'Student'}', style: TextStyle(
                fontFamily: 'Momo', fontSize: 10.5, color: AppC.faint)),
            const Spacer(),
            if (priority > 0) ...[
              const Icon(Icons.priority_high_rounded, size: 13, color: Color(0xFFF59E0B)),
              Text('$priority', style: const TextStyle(fontFamily: 'Arch', fontSize: 10.5,
                  fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
            ],
          ]),
        ]),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> s) {
    String status = (s['status'] ?? 'new').toString();
    double priority = ((s['priority'] as int?) ?? 0).toDouble();
    bool flagged = s['is_flagged'] == true;
    final noteCtrl = TextEditingController(text: (s['admin_note'] ?? '').toString());
    final replyCtrl = TextEditingController();

    showModalBottomSheet(context: context, backgroundColor: AppC.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        Future<void> save() async {
          try {
            await _api.patch('/feedback/staff/${s['id']}/', body: {
              'status': status, 'priority': priority.round(),
              'admin_note': noteCtrl.text.trim(), 'is_flagged': flagged,
            });
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            _snack('Saved ✓'); await _load();
          } catch (_) { _snack('Could not save.', error: true); }
        }
        Future<void> reply() async {
          final m = replyCtrl.text.trim();
          if (m.isEmpty) return;
          try {
            await _api.post('/feedback/staff/${s['id']}/reply/', body: {'message': m});
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            _snack('Reply sent to student ✓'); await _load();
          } catch (_) { _snack('Could not send reply.', error: true); }
        }
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 14,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(
                  color: AppC.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text((s['title'] ?? '').toString(), style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 18, color: AppC.text)),
              const SizedBox(height: 4),
              Text('by ${s['student_name'] ?? 'Student'}', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11, color: AppC.faint)),
              const SizedBox(height: 12),
              Text((s['message'] ?? '').toString(), style: TextStyle(fontFamily: 'Momo',
                  fontSize: 13, height: 1.5, color: AppC.text)),
              const SizedBox(height: 18),
              Text('STATUS', style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1, color: AppC.sub)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final st in _statuses)
                  GestureDetector(onTap: () => setSheet(() => status = st[0]),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: status == st[0]
                          ? _statusColor(st[0]) : AppC.bg,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: status == st[0] ? _statusColor(st[0]) : AppC.border)),
                      child: Text(st[1], style: TextStyle(fontFamily: 'Arch', fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: status == st[0] ? Colors.white : AppC.sub)))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Text('PRIORITY', style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                    fontWeight: FontWeight.bold, letterSpacing: 1, color: AppC.sub)),
                const Spacer(),
                Text('${priority.round()}', style: TextStyle(fontFamily: 'Alfa',
                    fontSize: 14, color: _kViolet)),
              ]),
              Slider(value: priority, min: 0, max: 100, activeColor: _kViolet,
                  onChanged: (v) => setSheet(() => priority = v)),
              GestureDetector(onTap: () => setSheet(() => flagged = !flagged),
                child: Row(children: [
                  Icon(flagged ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: flagged ? const Color(0xFFFF5858) : AppC.sub, size: 22),
                  const SizedBox(width: 8),
                  Text('Flag to Protect (safeguarding concern)', style: TextStyle(
                      fontFamily: 'Momo', fontSize: 12.5, color: AppC.text)),
                ])),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, maxLines: 2,
                style: TextStyle(color: AppC.text, fontFamily: 'Momo', fontSize: 13),
                decoration: InputDecoration(hintText: 'Internal note (staff only)',
                    hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 12),
                    filled: true, fillColor: AppC.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: save, style: ElevatedButton.styleFrom(backgroundColor: _kViolet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: const Text('Save', style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, color: Colors.white)))),
              const SizedBox(height: 16),
              Divider(color: AppC.divider),
              const SizedBox(height: 8),
              Text('REPLY TO STUDENT', style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1, color: AppC.sub)),
              const SizedBox(height: 8),
              TextField(controller: replyCtrl, maxLines: 2,
                style: TextStyle(color: AppC.text, fontFamily: 'Momo', fontSize: 13),
                decoration: InputDecoration(hintText: 'Send a reply (notifies them)',
                    hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 12),
                    filled: true, fillColor: AppC.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, height: 46, child: OutlinedButton(
                onPressed: reply, child: const Text('Send reply'))),
              const SizedBox(height: 10),
            ],
          )),
        );
      }),
    );
  }
}
