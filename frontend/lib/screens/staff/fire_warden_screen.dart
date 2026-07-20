// lib/screens/staff/fire_warden_screen.dart
//
// Fire-warden console. Verified wardens (is_fire_warden) can trigger an
// evacuation (type=evacuation) via slide-to-confirm with a zone + drill/real
// toggle; everyone else sees the page but the Execute control is disabled.
// Shows active-evacuation status, all-clear, a safe-check-in roster and a
// history of evacuations.
//
// SUPPLEMENT to the building alarm and official procedure — never a replacement.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/widgets/slide_to_confirm.dart';

const _kCoral = Color(0xFFFF5858);
const _kAmber = Color(0xFFF7971E);

class FireWardenScreen extends StatefulWidget {
  const FireWardenScreen({super.key});

  @override
  State<FireWardenScreen> createState() => _FireWardenScreenState();
}

class _FireWardenScreenState extends State<FireWardenScreen> {
  final _api = ApiService();
  final _zone = TextEditingController(text: 'Main building');
  final _instruction = TextEditingController();
  bool _drill = true; // default to drill — safer
  bool _isWarden = false;
  String _wardenName = '';
  bool _loading = true;
  Map<String, dynamic>? _active; // active evacuation, if any
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _zone.dispose(); _instruction.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final me = (await _api.getMyProfile().catchError((_) => <String, dynamic>{})
          as Map).cast<String, dynamic>();
      final active = (await _api.get('/safety/emergency/active/')
          .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
      final hist = (await _api.get('/safety/emergency/history/')
          .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final actives = ((active['results'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .where((a) => a['type'] == 'evacuation').toList();
      setState(() {
        _isWarden = me['is_fire_warden'] == true;
        _wardenName = (me['display_name'] ?? me['name'] ?? 'Warden').toString();
        _active = actives.isNotEmpty ? actives.first : null;
        _history = ((hist['results'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .where((a) => a['type'] == 'evacuation').toList();
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
      backgroundColor: error ? const Color(0xFFB3261E) : _kCoral,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo',
          color: Colors.white))));
  }

  Future<void> _execute() async {
    final zone = _zone.text.trim();
    if (zone.isEmpty) { _snack('Enter the zone/building.', error: true); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text(_drill ? 'Start DRILL evacuation?' : 'Start evacuation?',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Text(
            'This alerts everyone in "$zone" to evacuate '
            '${_drill ? "(DRILL)" : "immediately"}.',
            style: TextStyle(fontFamily: 'Momo', color: AppC.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppC.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(_drill ? 'Start drill' : 'Evacuate',
                  style: const TextStyle(color: _kCoral,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.post('/safety/emergency/', body: {
        'type': 'evacuation', 'severity': 'critical', 'audience': 'everyone',
        'title': _drill ? 'DRILL — Evacuate $zone' : 'Evacuate $zone',
        'message': 'Evacuate $zone now.',
        'instruction': _instruction.text.trim().isEmpty
            ? 'Use your nearest exit and follow warden instructions.'
            : _instruction.text.trim(),
        'zone': zone, 'is_drill': _drill,
      });
      HapticFeedback.heavyImpact();
      _snack(_drill ? 'Drill evacuation started.' : 'Evacuation started.');
      await _load();
    } catch (e) {
      _snack('Could not start: $e', error: true);
      rethrow;
    }
  }

  Future<void> _allClear() async {
    final id = _active?['id'];
    if (id == null) return;
    try {
      await _api.post('/safety/emergency/$id/resolve/');
      _snack('All clear sent.');
      await _load();
    } catch (_) {
      _snack('Could not send all-clear.', error: true);
    }
  }

  void _openRoster() {
    final id = _active?['id'];
    if (id == null) return;
    showModalBottomSheet(
      context: context, backgroundColor: AppC.card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
        builder: (ctx, scroll) => FutureBuilder(
          future: _api.get('/safety/emergency/$id/roster/')
              .catchError((_) => <String, dynamic>{}),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: Padding(padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _kCoral)));
            }
            final m = (snap.data as Map?) ?? const {};
            final safe = ((m['safe'] as List?) ?? []).cast<Map<String, dynamic>>();
            final pending = ((m['pending'] as List?) ?? []).cast<Map<String, dynamic>>();
            return ListView(controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30), children: [
                Center(child: Container(width: 38, height: 4,
                    decoration: BoxDecoration(color: AppC.border,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Safe check-in', style: TextStyle(fontFamily: 'Alfa',
                    fontSize: 17, color: AppC.text)),
                const SizedBox(height: 4),
                Text('${safe.length} safe · ${pending.length} not yet checked in',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
                const SizedBox(height: 14),
                for (final p in safe) _rosterRow(p['name']?.toString() ?? '', true),
                for (final p in pending) _rosterRow(p['name']?.toString() ?? '', false),
              ]);
          },
        ),
      ),
    );
  }

  Widget _rosterRow(String name, bool safe) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(safe ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 16, color: safe ? const Color(0xFF22C55E) : _kAmber),
          const SizedBox(width: 10),
          Text(name, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
              color: AppC.text)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kCoral))
          : ListView(padding: EdgeInsets.zero, children: [
              _header(),
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusPanel(),
                    const SizedBox(height: 18),
                    if (_active != null) ...[
                      _activeControls(),
                      const SizedBox(height: 18),
                    ] else
                      _executePanel(),
                    const SizedBox(height: 8),
                    StaffSectionLabel('Evacuation history'),
                    if (_history.isEmpty)
                      Padding(padding: const EdgeInsets.all(16),
                        child: Text('No evacuations recorded yet.',
                            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                                color: AppC.sub)))
                    else
                      for (final h in _history) _historyRow(h),
                  ]),
              ),
            ]),
    );
  }

  Widget _header() => StaffHeader(
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
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.white70, size: 22),
          ]),
          const SizedBox(height: 14),
          const Text('Fire Warden',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 24, color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                      offset: Offset(0, 3))])),
          const SizedBox(height: 6),
          Row(children: [
            Icon(_isWarden ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(_isWarden
                ? '$_wardenName · verified warden'
                : 'Not a verified warden — contact an admin',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9))),
          ]),
        ]),
      );

  Widget _statusPanel() {
    final active = _active != null;
    final color = active ? _kCoral : const Color(0xFF22C55E);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(children: [
        Icon(active ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(active
                ? '${_active!['is_drill'] == true ? "DRILL · " : ""}EVACUATION ACTIVE'
                : 'No active evacuation',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: color)),
            if (active) ...[
              const SizedBox(height: 3),
              Text('${_active!['zone'] ?? ''} · started by ${_active!['posted_by'] ?? ''}',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.sub)),
            ],
          ])),
      ]),
    );
  }

  Widget _activeControls() {
    return Column(children: [
      GestureDetector(
        onTap: _openRoster,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: staffCard(),
          child: Row(children: [
            const Icon(Icons.fact_check_rounded, color: Color(0xFF22C55E), size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text('Safe check-in roster · ${_active!['ack_count'] ?? 0} safe',
                style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                    fontWeight: FontWeight.bold, color: AppC.text))),
            Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 20),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      SlideToConfirm(
        label: 'Slide for ALL CLEAR',
        color: const Color(0xFF22C55E),
        icon: Icons.check_rounded,
        onConfirmed: _allClear,
      ),
    ]);
  }

  Widget _executePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Execute evacuation', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 16, color: AppC.text)),
        const SizedBox(height: 12),
        TextField(controller: _zone, enabled: _isWarden,
          style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
          decoration: InputDecoration(labelText: 'Zone / building',
            labelStyle: TextStyle(fontFamily: 'Momo', color: AppC.sub),
            filled: true, fillColor: AppC.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none))),
        const SizedBox(height: 10),
        TextField(controller: _instruction, enabled: _isWarden,
          style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
          decoration: InputDecoration(labelText: 'Instruction (optional)',
            hintText: 'e.g. Use the north stairwell',
            labelStyle: TextStyle(fontFamily: 'Momo', color: AppC.sub),
            hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 12),
            filled: true, fillColor: AppC.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        Row(children: [
          for (final d in const [[true, 'Drill'], [false, 'Real']])
            Expanded(child: Padding(
              padding: EdgeInsets.only(right: d[0] == true ? 9 : 0),
              child: GestureDetector(
                onTap: _isWarden ? () => setState(() => _drill = d[0] as bool) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _drill == d[0]
                        ? (d[0] == true ? _kAmber : _kCoral) : AppC.bg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _drill == d[0]
                        ? (d[0] == true ? _kAmber : _kCoral) : AppC.border)),
                  child: Text(d[1] as String, style: TextStyle(fontFamily: 'Arch',
                      fontSize: 12.5, fontWeight: FontWeight.bold,
                      color: _drill == d[0] ? Colors.white : AppC.sub)),
                ),
              ),
            )),
        ]),
        const SizedBox(height: 14),
        if (!_isWarden)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAmber.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: _kAmber, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Only a verified fire warden can execute this. '
                  'Ask an admin to assign you.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.text, height: 1.35))),
            ]),
          )
        else
          SlideToConfirm(
            label: _drill ? 'Slide to start DRILL' : 'Slide to EVACUATE',
            color: _drill ? _kAmber : _kCoral,
            icon: Icons.directions_run_rounded,
            onConfirmed: _execute,
          ),
        const SizedBox(height: 10),
        Text('A push is best-effort. Students still follow the building alarm '
            'and warden instructions.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                color: AppC.faint, height: 1.4)),
      ]),
    );
  }

  Widget _historyRow(Map<String, dynamic> h) {
    final drill = h['is_drill'] == true;
    final resolved = h['status'] == 'resolved';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: staffCard(),
      child: Row(children: [
        Container(
          width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (drill ? _kAmber : _kCoral).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.directions_run_rounded,
              color: drill ? _kAmber : _kCoral, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${h['zone'] ?? 'Evacuation'}${drill ? '  ·  DRILL' : ''}',
                style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                    fontWeight: FontWeight.bold, color: AppC.text)),
            const SizedBox(height: 2),
            Text('by ${h['posted_by'] ?? ''}  ·  ${h['ack_count'] ?? 0} checked in',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
          ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (resolved ? const Color(0xFF22C55E) : _kCoral)
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7)),
          child: Text(resolved ? 'Ended' : 'Active',
              style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: resolved ? const Color(0xFF16A34A) : _kCoral)),
        ),
      ]),
    );
  }
}
