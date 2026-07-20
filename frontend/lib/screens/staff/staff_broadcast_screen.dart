// lib/screens/staff/staff_broadcast_screen.dart
//
// Emergency broadcast — elevated staff push a high-priority safety alert to
// every student (lockdown, weather, urgent safety). Optionally require a
// "mark yourself safe" reply, giving a live roll-call.
//   POST /moderation/staff/broadcast/            create + push
//   GET  /moderation/staff/broadcasts/           history
//   GET  /moderation/staff/broadcast/<id>/responses/   roll-call

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class StaffBroadcastScreen extends StatefulWidget {
  const StaffBroadcastScreen({super.key});

  @override
  State<StaffBroadcastScreen> createState() => _StaffBroadcastScreenState();
}

class _StaffBroadcastScreenState extends State<StaffBroadcastScreen> {
  final _api = ApiService();
  final _msgCtrl = TextEditingController();
  String _severity = 'warning';
  bool _requireSafe = false;
  bool _sending = false;
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  static const _sev = <(String, String, IconData, Color)>[
    ('info', 'Info', Icons.info_rounded, Color(0xFF3B82F6)),
    ('warning', 'Warning', Icons.warning_amber_rounded, Color(0xFFF59E0B)),
    ('critical', 'Critical', Icons.emergency_rounded, Color(0xFFDC2626)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Color get _sevColor =>
      _sev.firstWhere((s) => s.$1 == _severity).$4;

  Future<void> _load() async {
    try {
      final d = (await _api.get('/moderation/staff/broadcasts/')
          .catchError((_) => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _history = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : _sevColor,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo',
          color: Colors.white)),
    ));
  }

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) { _snack('Write a message first.', error: true); return; }

    final label = _sev.firstWhere((s) => s.$1 == _severity).$2;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Send $label alert to all students?',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Text(
            'This pushes a notification to every student immediately'
            '${_requireSafe ? ' and asks them to mark themselves safe' : ''}.',
            style: TextStyle(fontFamily: 'Momo', color: AppC.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: AppC.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Send now',
                  style: TextStyle(color: _sevColor,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _sending = true);
    HapticFeedback.heavyImpact();
    try {
      await _api.post('/moderation/staff/broadcast/', body: {
        'message': msg,
        'severity': _severity,
        'require_safe': _requireSafe,
      });
      _msgCtrl.clear();
      setState(() => _requireSafe = false);
      _snack('Alert sent to all students ✓');
      await _load();
    } catch (e) {
      _snack('Could not send: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          _header(),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Column(children: [
              const SizedBox(height: 10),
              _composer(),
              const SizedBox(height: 22),
              StaffSectionLabel('Recent alerts',
                  subtitle: 'Tap to see who replied safe'),
              if (_loading)
                const Padding(padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(
                        color: Color(0xFFDC2626))))
              else if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: staffCard(),
                    child: Text('No alerts sent yet.',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                            color: AppC.sub)),
                  ),
                )
              else
                for (final b in _history) _historyTile(b),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 22,
      horizontal: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20)),
          ),
          const Spacer(),
          const Icon(Icons.campaign_rounded, color: Colors.white70, size: 22),
        ]),
        const SizedBox(height: 14),
        const Text('Emergency broadcast',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 6),
        Text('A high-priority alert to every student',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.85))),
      ]),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: staffCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Severity selector
          Row(children: [
            for (final s in _sev) ...[
              Expanded(child: GestureDetector(
                onTap: () { HapticFeedback.selectionClick();
                    setState(() => _severity = s.$1); },
                child: Container(
                  margin: EdgeInsets.only(right: s.$1 == 'critical' ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _severity == s.$1 ? s.$4 : AppC.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _severity == s.$1 ? s.$4 : AppC.border)),
                  child: Column(children: [
                    Icon(s.$3, size: 18,
                        color: _severity == s.$1 ? Colors.white
                            : AppC.sub),
                    const SizedBox(height: 3),
                    Text(s.$2, style: TextStyle(fontFamily: 'Arch',
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: _severity == s.$1 ? Colors.white
                            : AppC.sub)),
                  ]),
                ),
              )),
            ],
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _msgCtrl,
            maxLines: 4, minLines: 3, maxLength: 2000,
            style: TextStyle(fontFamily: 'Momo', fontSize: 13.5,
                color: AppC.text, height: 1.4),
            decoration: InputDecoration(
              hintText: 'What do students need to know right now?',
              hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  color: AppC.sub.withValues(alpha: 0.7)),
              filled: true, fillColor: AppC.bg,
              counterStyle: TextStyle(fontFamily: 'Momo', fontSize: 10,
                  color: AppC.faint),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _requireSafe = !_requireSafe),
            child: Row(children: [
              Icon(_requireSafe
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: _requireSafe ? _sevColor : AppC.sub, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Ask students to mark themselves safe',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                      color: AppC.text))),
            ]),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _sending ? _sevColor.withValues(alpha: 0.6) : _sevColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _sevColor.withValues(alpha: 0.35),
                    blurRadius: 16, offset: const Offset(0, 8))]),
              child: _sending
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Send to all students',
                          style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> b) {
    final sev = (b['severity'] ?? 'warning').toString();
    final s = _sev.firstWhere((e) => e.$1 == sev, orElse: () => _sev[1]);
    final requireSafe = b['require_safe'] == true;
    final safeCount = (b['safe_count'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: requireSafe ? () => _rollCall(b) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: staffCard(border: s.$4.withValues(alpha: 0.30)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: s.$4.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(s.$3, color: s.$4, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text((b['message'] ?? '').toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                        height: 1.35, color: AppC.text)),
                const SizedBox(height: 4),
                Text([
                  s.$2,
                  if (requireSafe) '$safeCount marked safe',
                  if (b['is_active'] == true) 'active',
                ].join('  ·  '),
                    style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                        fontWeight: FontWeight.bold, color: s.$4)),
              ],
            )),
            if (requireSafe)
              Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 20),
          ]),
        ),
      ),
    );
  }

  // Roll-call: who has marked safe vs who hasn't.
  void _rollCall(Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4,
        builder: (ctx, scroll) => FutureBuilder(
          future: _api.get('/moderation/staff/broadcast/${b['id']}/responses/')
              .catchError((_) => <String, dynamic>{}),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: Padding(padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFFDC2626))));
            }
            final m = (snap.data as Map?) ?? const {};
            final safe = ((m['safe'] as List?) ?? const [])
                .cast<Map<String, dynamic>>();
            final pending = ((m['pending'] as List?) ?? const [])
                .cast<Map<String, dynamic>>();
            return Column(children: [
              const SizedBox(height: 10),
              Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: AppC.border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(children: [
                  _tally('${safe.length}', 'safe', const Color(0xFF22C55E)),
                  const SizedBox(width: 12),
                  _tally('${pending.length}', 'no reply',
                      const Color(0xFFF59E0B)),
                ]),
              ),
              Divider(height: 1, color: AppC.divider),
              Expanded(child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                children: [
                  if (safe.isNotEmpty) ...[
                    _rollHeader('Marked safe', const Color(0xFF22C55E)),
                    for (final p in safe)
                      _rollRow(p['name']?.toString() ?? 'Student', true),
                    const SizedBox(height: 14),
                  ],
                  if (pending.isNotEmpty) ...[
                    _rollHeader('No reply yet', const Color(0xFFF59E0B)),
                    for (final p in pending)
                      _rollRow(p['name']?.toString() ?? 'Student', false),
                  ],
                ],
              )),
            ]);
          },
        ),
      ),
    );
  }

  Widget _tally(String n, String label, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.25))),
          child: Column(children: [
            Text(n, style: TextStyle(fontFamily: 'Alfa', fontSize: 22, color: c)),
            Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                color: AppC.sub)),
          ]),
        ),
      );

  Widget _rollHeader(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(width: 4, height: 14,
              decoration: BoxDecoration(color: c,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t.toUpperCase(), style: TextStyle(fontFamily: 'Arch',
              fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5,
              color: AppC.text)),
        ]),
      );

  Widget _rollRow(String name, bool safe) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(safe ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 16, color: safe ? const Color(0xFF22C55E)
                  : const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Text(name, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
              color: AppC.text)),
        ]),
      );
}
