// lib/screens/staff/scam_watch_screen.dart
//
// Staff Scam Watch — triage student scam reports and publish campus alerts.
//   GET  /scam/staff/reports/ ?status=
//   POST /scam/staff/reports/<id>/action/  {status}
//   POST /scam/staff/alerts/  {title, body, scam_type}   (fans out to students)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kCoral = Color(0xFFFF5858);
const _kAmber = Color(0xFFF7971E);

const _scamTypes = <String, String>{
  'visa_fee': 'Visa / fee', 'tuition': 'Tuition', 'accommodation': 'Housing',
  'job': 'Fake job', 'tax_deportation': 'Tax / deport', 'romance_crypto': 'Romance / crypto',
  'phishing': 'Phishing', 'scholarship': 'Scholarship', 'other': 'Other',
};

class ScamWatchScreen extends StatefulWidget {
  const ScamWatchScreen({super.key});

  @override
  State<ScamWatchScreen> createState() => _ScamWatchScreenState();
}

class _ScamWatchScreenState extends State<ScamWatchScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _filter = '';
  final Set<String> _busy = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final q = _filter.isEmpty ? '' : '?status=$_filter';
      final d = (await _api.get('/scam/staff/reports/$q')
          .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _reports = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : _kCoral,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo', color: Colors.white))));
  }

  Future<void> _action(Map<String, dynamic> r, String status) async {
    final id = (r['id'] ?? '').toString();
    setState(() => _busy.add(id));
    HapticFeedback.selectionClick();
    try {
      await _api.post('/scam/staff/reports/$id/action/', body: {'status': status});
      await _load();
    } catch (_) { _snack('Could not update.', error: true); }
    finally { if (mounted) setState(() => _busy.remove(id)); }
  }

  Future<void> _publish() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String type = 'other';
    final ok = await showModalBottomSheet<bool>(
      context: context, backgroundColor: AppC.card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        InputDecoration dec(String h) => InputDecoration(hintText: h,
            hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 13),
            filled: true, fillColor: AppC.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none));
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38, height: 4, decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: _kCoral, size: 20),
              const SizedBox(width: 10),
              Text('Publish campus alert', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 17, color: AppC.text)),
            ]),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, style: TextStyle(color: AppC.text),
                decoration: dec('Title — e.g. Fake visa-fee texts going around')),
            const SizedBox(height: 10),
            TextField(controller: bodyCtrl, maxLines: 3, style: TextStyle(color: AppC.text),
                decoration: dec('What students should watch for & do')),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('Type',
                style: TextStyle(fontFamily: 'Arch', fontSize: 11,
                    fontWeight: FontWeight.bold, color: AppC.sub))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _scamTypes.entries)
                GestureDetector(
                  onTap: () => setSheet(() => type = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: type == e.key ? _kCoral : AppC.bg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: type == e.key ? _kCoral : AppC.border)),
                    child: Text(e.value, style: TextStyle(fontFamily: 'Arch',
                        fontSize: 11.5, fontWeight: FontWeight.bold,
                        color: type == e.key ? Colors.white : AppC.sub)),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: () => Navigator.pop(sheetCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: _kCoral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Publish to all students',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      color: Colors.white)),
            )),
          ]),
        );
      }),
    );
    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
      _snack('Title and body are required.', error: true); return;
    }
    try {
      await _api.post('/scam/staff/alerts/', body: {
        'title': titleCtrl.text.trim(), 'body': bodyCtrl.text.trim(),
        'scam_type': type,
      });
      _snack('Alert published to students ✓');
    } catch (_) { _snack('Could not publish.', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    const filters = [['', 'All'], ['new', 'New'], ['reviewing', 'Reviewing'],
        ['confirmed', 'Confirmed'], ['dismissed', 'Dismissed']];
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kCoral, onPressed: _publish,
        icon: const Icon(Icons.campaign_rounded, color: Colors.white),
        label: const Text('Publish alert', style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: _kCoral, onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()), padding: EdgeInsets.zero, children: [
          _header(),
          const SizedBox(height: 14),
          SizedBox(height: 36, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = _filter == filters[i][0];
              return GestureDetector(
                onTap: () { setState(() => _filter = filters[i][0]); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? _kCoral : AppC.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? _kCoral : AppC.border)),
                  child: Text(filters[i][1], style: TextStyle(fontFamily: 'Arch',
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: sel ? Colors.white : AppC.sub)),
                ),
              );
            },
          )),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator(color: _kCoral)))
          else if (_reports.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 40), child: Center(
              child: Column(children: [
                Icon(Icons.verified_user_rounded, size: 48, color: AppC.faint),
                const SizedBox(height: 10),
                Text('No reports here.', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 13, color: AppC.sub)),
              ])))
          else
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              child: Column(children: [
                for (final r in _reports) ...[_reportCard(r), const SizedBox(height: 10)],
              ])),
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
            const Icon(Icons.radar_rounded, color: Colors.white70, size: 22),
          ]),
          const SizedBox(height: 14),
          const Text('Scam watch', style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
              color: Colors.white, shadows: [Shadow(color: Colors.black26,
                  blurRadius: 8, offset: Offset(0, 3))])),
          const SizedBox(height: 6),
          Text('Triage student reports & warn the campus',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
      );

  Widget _reportCard(Map<String, dynamic> r) {
    final id = (r['id'] ?? '').toString();
    final status = (r['status'] ?? 'new').toString();
    final victim = r['was_victim'] == true;
    final busy = _busy.contains(id);
    final typeLabel = _scamTypes[r['scam_type']] ?? 'Other';
    final statusColor = status == 'confirmed' ? _kCoral
        : status == 'dismissed' ? AppC.faint
        : status == 'reviewing' ? _kAmber : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: staffCard(border: victim ? _kCoral.withValues(alpha: 0.4) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: _kAmber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7)),
            child: Text(typeLabel, style: const TextStyle(fontFamily: 'Arch',
                fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)))),
          const SizedBox(width: 6),
          if (victim)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _kCoral.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7)),
              child: const Text('VICTIM', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 8, fontWeight: FontWeight.bold, color: _kCoral))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7)),
            child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Arch',
                fontSize: 8, fontWeight: FontWeight.bold, color: statusColor))),
        ]),
        const SizedBox(height: 8),
        Text((r['content'] ?? '').toString(), maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5, height: 1.4,
                color: AppC.text)),
        if ((r['contact'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Contact: ${r['contact']}', style: TextStyle(fontFamily: 'Momo',
              fontSize: 11, color: AppC.sub)),
        ],
        const SizedBox(height: 6),
        Text('by ${r['student'] ?? 'Student'}', style: TextStyle(fontFamily: 'Momo',
            fontSize: 10.5, color: AppC.faint)),
        const SizedBox(height: 10),
        if (busy)
          const Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)))
        else
          Row(children: [
            _actBtn('Reviewing', _kAmber, () => _action(r, 'reviewing')),
            const SizedBox(width: 8),
            _actBtn('Confirm', _kCoral, () => _action(r, 'confirmed')),
            const SizedBox(width: 8),
            _actBtn('Dismiss', AppC.faint, () => _action(r, 'dismissed')),
          ]),
      ]),
    );
  }

  Widget _actBtn(String label, Color color, VoidCallback onTap) => Expanded(
        child: GestureDetector(onTap: onTap, child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4))),
          child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 11.5,
              fontWeight: FontWeight.bold, color: color)),
        )),
      );
}
