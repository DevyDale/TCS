// lib/widgets/emergency_banner.dart
//
// App-shell overlay for an active EmergencyAlert (incl. evacuation). Polls
// /safety/emergency/active/ (audience-filtered server-side, so a user only
// sees alerts meant for them), shows a coloured banner, lets them mark safe,
// and opens the full-screen detail on tap. Shows nothing when nothing's active.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/emergency_detail_screen.dart';

class EmergencyBanner extends StatefulWidget {
  const EmergencyBanner({super.key});

  @override
  State<EmergencyBanner> createState() => _EmergencyBannerState();
}

class _EmergencyBannerState extends State<EmergencyBanner> {
  final _api = ApiService();
  Map<String, dynamic>? _alert;
  bool _dismissed = false;
  bool _marking = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _check();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() { _poll?.cancel(); super.dispose(); }

  int _rank(Map<String, dynamic> a) {
    switch (a['severity']) { case 'critical': return 3; case 'high': return 2; default: return 1; }
  }

  Future<void> _check() async {
    try {
      final d = (await _api.get('/safety/emergency/active/')
          .catchError((_) => <String, dynamic>{}) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final list = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
      list.sort((a, b) => _rank(b).compareTo(_rank(a)));
      final top = list.isNotEmpty ? list.first : null;
      setState(() {
        if (top?['id'] != _alert?['id']) _dismissed = false; // new alert resets
        _alert = top;
      });
    } catch (_) {/* keep prior */}
  }

  Future<void> _markSafe() async {
    final id = _alert?['id'];
    if (id == null) return;
    setState(() => _marking = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/safety/emergency/$id/ack/');
      await _check();
    } catch (_) {}
    finally { if (mounted) setState(() => _marking = false); }
  }

  (Color, Color, IconData) _style(String sev) {
    switch (sev) {
      case 'critical': return (const Color(0xFFDC2626), const Color(0xFF991B1B),
          Icons.error_rounded);
      case 'info': return (const Color(0xFF2563EB), const Color(0xFF1E40AF),
          Icons.info_rounded);
      default: return (const Color(0xFFF59E0B), const Color(0xFFB45309),
          Icons.warning_amber_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _alert;
    if (a == null || _dismissed) return const SizedBox.shrink();
    final sev = (a['severity'] ?? 'high').toString();
    final drill = a['is_drill'] == true;
    final acked = a['acked'] == true;
    final (c1, c2, icon) = _style(sev);
    final top = MediaQuery.of(context).padding.top;

    return Positioned(top: 0, left: 0, right: 0, child: Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EmergencyDetailScreen(alertId: a['id'].toString()))),
        child: Container(
          padding: EdgeInsets.fromLTRB(14, top + 10, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2]),
            boxShadow: [BoxShadow(color: c2.withValues(alpha: 0.4),
                blurRadius: 16, offset: const Offset(0, 6))],
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  '${drill ? "DRILL — " : ""}${(a['title'] ?? '').toString()}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 13.5,
                      fontWeight: FontWeight.bold, color: Colors.white))),
              if (sev != 'critical')
                GestureDetector(onTap: () => setState(() => _dismissed = true),
                    child: const Icon(Icons.close_rounded, color: Colors.white70,
                        size: 20)),
            ]),
            const SizedBox(height: 6),
            Text((a['message'] ?? '').toString(), maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    height: 1.35, color: Colors.white)),
            const SizedBox(height: 10),
            Row(children: [
              if (acked)
                Row(children: const [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text("You're safe", style: TextStyle(fontFamily: 'Arch',
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ])
              else
                GestureDetector(
                  onTap: _marking ? null : _markSafe,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(10)),
                    child: _marking
                        ? SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c1))
                        : Text("I'm safe", style: TextStyle(fontFamily: 'Arch',
                            fontSize: 12, fontWeight: FontWeight.bold, color: c1)),
                  ),
                ),
              const Spacer(),
              const Text('Tap for details ›', style: TextStyle(fontFamily: 'Momo',
                  fontSize: 10.5, color: Colors.white70)),
            ]),
          ]),
        ),
      ),
    ));
  }
}
