// lib/screens/staff/emergency_detail_screen.dart
//
// Full-screen view of an emergency alert: type/severity header, message, what-
// to-do, live timeline, crisis contacts, a "Mark me safe" check-in, and (for
// the poster/admin) Add-update / Resolve. Opened from the red notification
// tile or the app-shell banner.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';

class EmergencyDetailScreen extends StatefulWidget {
  final String alertId;
  const EmergencyDetailScreen({super.key, required this.alertId});

  @override
  State<EmergencyDetailScreen> createState() => _EmergencyDetailScreenState();
}

class _EmergencyDetailScreenState extends State<EmergencyDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _a;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = (await _api.get('/safety/emergency/${widget.alertId}/')
          .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
      if (mounted) setState(() { _a = d.isEmpty ? null : d; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Color get _color {
    switch (_a?['severity']) {
      case 'critical': return const Color(0xFFDC2626);
      case 'info': return const Color(0xFF2563EB);
      default: return const Color(0xFFF59E0B);
    }
  }

  Future<void> _ack() async {
    try {
      await _api.post('/safety/emergency/${widget.alertId}/ack/');
      HapticFeedback.mediumImpact();
      await _load();
    } catch (_) {}
  }

  Future<void> _resolve() async {
    try {
      await _api.post('/safety/emergency/${widget.alertId}/resolve/');
      await _load();
    } catch (_) {}
  }

  Future<void> _addUpdate() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppC.card,
      title: Text('Add update', style: TextStyle(fontFamily: 'Alfa',
          color: AppC.text, fontSize: 17)),
      content: TextField(controller: ctrl, maxLines: 3,
          style: TextStyle(color: AppC.text),
          decoration: const InputDecoration(hintText: 'What changed?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Post', style: TextStyle(color: _color,
                fontWeight: FontWeight.bold))),
      ],
    ));
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await _api.post('/safety/emergency/${widget.alertId}/update/',
          body: {'text': ctrl.text.trim()});
      await _load();
    } catch (_) {}
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: AppC.bg,
          body: Center(child: CircularProgressIndicator(color: _color)));
    }
    final a = _a;
    if (a == null) {
      return Scaffold(backgroundColor: AppC.bg, appBar: AppBar(
          backgroundColor: AppC.bg, iconTheme: IconThemeData(color: AppC.text)),
          body: Center(child: Text('This alert is no longer available.',
              style: TextStyle(fontFamily: 'Momo', color: AppC.sub))));
    }
    final resolved = a['status'] == 'resolved';
    final drill = a['is_drill'] == true;
    final acked = a['acked'] == true;
    final canManage = a['can_manage'] == true;
    final updates = ((a['updates'] as List?) ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        // Header band
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16,
              20, 22),
          decoration: BoxDecoration(gradient: LinearGradient(
              colors: resolved
                  ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                  : [_color, _color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(resolved ? 'ALL CLEAR'
                    : '${drill ? "DRILL · " : ""}${(a['severity'] ?? '').toString().toUpperCase()}',
                    style: const TextStyle(fontFamily: 'Arch', fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1,
                        color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 16),
            Text((a['title'] ?? '').toString(),
                style: const TextStyle(fontFamily: 'Alfa', fontSize: 26,
                    color: Colors.white, height: 1.1)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((a['message'] ?? '').toString(),
                style: TextStyle(fontFamily: 'Momo', fontSize: 14, height: 1.5,
                    color: AppC.text)),
            if ((a['instruction'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _color.withValues(alpha: 0.3))),
                child: Row(children: [
                  Icon(Icons.assignment_turned_in_rounded, color: _color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHAT TO DO', style: TextStyle(fontFamily: 'Arch',
                          fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1,
                          color: _color)),
                      const SizedBox(height: 3),
                      Text((a['instruction']).toString(),
                          style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                              height: 1.4, color: AppC.text)),
                    ])),
                ]),
              ),
            ],
            // Mark me safe
            if (!resolved) ...[
              const SizedBox(height: 18),
              GestureDetector(
                onTap: acked ? null : _ack,
                child: Container(
                  width: double.infinity, height: 52, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: acked ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                        : const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF22C55E))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(acked ? Icons.check_circle_rounded : Icons.shield_rounded,
                        color: acked ? const Color(0xFF22C55E) : Colors.white, size: 19),
                    const SizedBox(width: 8),
                    Text(acked ? "You're marked safe" : 'Mark me safe',
                        style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: acked ? const Color(0xFF22C55E) : Colors.white)),
                  ]),
                ),
              ),
            ],
            // Timeline
            if (updates.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('UPDATES', style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1, color: AppC.sub)),
              const SizedBox(height: 10),
              for (final u in updates.reversed)
                Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((u['text'] ?? '').toString(),
                            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                                height: 1.4, color: AppC.text)),
                        Text('${u['author'] ?? ''}',
                            style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                                color: AppC.faint)),
                      ])),
                  ])),
            ],
            // Crisis contacts
            const SizedBox(height: 22),
            Text('IN A CRISIS', style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 1, color: AppC.sub)),
            const SizedBox(height: 8),
            _contact('Emergency', '000'),
            _contact('Lifeline', '13 11 14'),
            // Staff manage
            if (canManage && !resolved) ...[
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _addUpdate,
                    child: const Text('Add update'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _resolve,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E)),
                    child: const Text('All clear',
                        style: TextStyle(color: Colors.white)))),
              ]),
            ],
            const SizedBox(height: 30),
          ]),
        ),
      ]),
    );
  }

  Widget _contact(String name, String number) => GestureDetector(
        onTap: () => _call(number),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppC.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppC.border)),
          child: Row(children: [
            const Icon(Icons.call_rounded, color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 12),
            Text(name, style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                fontWeight: FontWeight.bold, color: AppC.text)),
            const Spacer(),
            Text(number, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: AppC.sub)),
          ]),
        ),
      );
}
