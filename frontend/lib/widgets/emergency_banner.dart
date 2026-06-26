// lib/widgets/emergency_banner.dart
//
// Student-facing overlay for an active EmergencyBroadcast. Polls
// /moderation/broadcast/active/ and, when there's a live alert, drops a
// coloured banner at the top of the screen. If the alert requires it, the
// student taps "I'm safe" (POST /broadcast/<id>/safe/) which feeds the staff
// roll-call. Shows nothing when there's no active alert.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/services/api_service.dart';

class EmergencyBanner extends StatefulWidget {
  const EmergencyBanner({super.key});

  @override
  State<EmergencyBanner> createState() => _EmergencyBannerState();
}

class _EmergencyBannerState extends State<EmergencyBanner> {
  final _api = ApiService();
  Map<String, dynamic>? _active;
  bool _responded = false;
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
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final d = (await _api.get('/moderation/broadcast/active/')
          .catchError((_) => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      if (!mounted) return;
      final active = (d['active'] as Map?)?.cast<String, dynamic>();
      setState(() {
        // A new alert id resets the dismissed/responded state.
        if (active?['id'] != _active?['id']) {
          _dismissed = false;
        }
        _active = active;
        _responded = d['responded'] == true;
      });
    } catch (_) {/* keep whatever we had */}
  }

  Future<void> _markSafe() async {
    final id = _active?['id'];
    if (id == null) return;
    setState(() => _marking = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/moderation/broadcast/$id/safe/');
      if (mounted) setState(() => _responded = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Couldn't mark you safe — try again.",
              style: TextStyle(fontFamily: 'Momo'))));
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  (Color, Color, IconData) _style(String sev) {
    switch (sev) {
      case 'critical':
        return (const Color(0xFFDC2626), const Color(0xFF991B1B),
            Icons.emergency_rounded);
      case 'info':
        return (const Color(0xFF2563EB), const Color(0xFF1E40AF),
            Icons.info_rounded);
      default:
        return (const Color(0xFFF59E0B), const Color(0xFFB45309),
            Icons.warning_amber_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _active;
    if (a == null || _dismissed) return const SizedBox.shrink();

    final sev = (a['severity'] ?? 'warning').toString();
    final requireSafe = a['require_safe'] == true;
    final (c1, c2, icon) = _style(sev);
    final top = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.fromLTRB(14, top + 10, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: c2.withValues(alpha: 0.4),
                blurRadius: 16, offset: const Offset(0, 6))],
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  sev == 'critical' ? 'EMERGENCY'
                      : sev == 'info' ? 'NOTICE' : 'SAFETY ALERT',
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1,
                      color: Colors.white))),
              if (!requireSafe)
                GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 20)),
            ]),
            const SizedBox(height: 8),
            Text((a['message'] ?? '').toString(),
                style: const TextStyle(fontFamily: 'Momo', fontSize: 13,
                    height: 1.4, color: Colors.white)),
            if (requireSafe) ...[
              const SizedBox(height: 12),
              if (_responded)
                Row(children: const [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("You're marked safe",
                      style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ])
              else
                GestureDetector(
                  onTap: _marking ? null : _markSafe,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                    child: _marking
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c1))
                        : Text("I'm safe",
                            style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                                fontWeight: FontWeight.bold, color: c1)),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}
