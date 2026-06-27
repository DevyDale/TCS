// lib/screens/wellbeing_notice_screen.dart
//
// The student-facing transparency + consent surface for AI wellbeing support
// (PRIVACY.md §10). Explains plainly what the feature does, what is and isn't
// stored, who can see it, and lets the student turn it OFF for their own
// account. Marks the notice as seen on open. Crisis line is always shown.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';

const _kTeal = Color(0xFF0EA5A4);

class WellbeingNoticeScreen extends StatefulWidget {
  const WellbeingNoticeScreen({super.key});

  @override
  State<WellbeingNoticeScreen> createState() => _WellbeingNoticeScreenState();
}

class _WellbeingNoticeScreenState extends State<WellbeingNoticeScreen> {
  final _api = ApiService();
  bool _loading = true, _saving = false;
  bool _programmeActive = false;
  bool _optedOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _api.wellbeingConsent() as Map;
      if (!mounted) return;
      setState(() {
        _programmeActive = d['programme_active'] == true;
        _optedOut = d['opted_out'] == true;
        _loading = false;
      });
      // Mark the notice as seen (best-effort).
      _api.setWellbeingConsent(seen: true).catchError((_) => {});
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setOptOut(bool optOut) async {
    setState(() { _saving = true; _optedOut = optOut; });
    HapticFeedback.selectionClick();
    try {
      await _api.setWellbeingConsent(optOut: optOut);
    } catch (_) {
      if (mounted) setState(() => _optedOut = !optOut); // revert on failure
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _callLifeline() async {
    final uri = Uri.parse('tel:131114');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      appBar: AppBar(
        backgroundColor: AppC.bg, elevation: 0, foregroundColor: AppC.text,
        title: Text('Wellbeing & Safety',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kTeal))
          : ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 36), children: [
              _hero(),
              const SizedBox(height: 18),
              _block(Icons.favorite_rounded, 'What it does',
                  'When your College switches this on, the messages you send to '
                  'the in-app AI assistant are checked for signs you might be '
                  'struggling, so trained staff can reach out. It is a prompt for '
                  'a human to help — never a diagnosis, and never a replacement '
                  'for a real person or a crisis service.'),
              _block(Icons.lock_outline_rounded, 'What we store',
                  'We do not keep your chat transcripts for this. If something is '
                  'flagged, only a risk level, a few non-identifying theme tags '
                  '(like “academic” or “homesickness”) and a short redacted '
                  'snippet are saved, so a staff member can follow up.'),
              _block(Icons.visibility_outlined, 'Who can see it',
                  'Only designated safeguarding staff at your College. Every time '
                  'a staff member looks at or acts on a concern is recorded.'),
              const SizedBox(height: 8),
              _consentCard(),
              const SizedBox(height: 18),
              _crisisCard(),
              const SizedBox(height: 16),
              Center(child: Text('See the full Privacy Policy for details.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, color: AppC.faint))),
            ]),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kTeal, Color(0xFF0F766E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 50, height: 50, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.health_and_safety_rounded,
                color: Colors.white, size: 27)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Looking out for you',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: Colors.white)),
              const SizedBox(height: 3),
              Text(_programmeActive
                  ? 'This support is active at your College.'
                  : 'Your College hasn’t turned this on yet.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.9))),
            ],
          )),
        ]),
      );

  Widget _block(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: _kTeal, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14, color: AppC.text)),
              const SizedBox(height: 3),
              Text(body, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  height: 1.45, color: AppC.sub)),
            ],
          )),
        ]),
      );

  Widget _consentCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppC.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppC.border)),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Use AI wellbeing support',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 14, color: AppC.text)),
              const SizedBox(height: 3),
              Text(_optedOut
                  ? 'Off — your messages are not checked or stored for this.'
                  : 'On — messages may be checked so staff can support you.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: _optedOut ? AppC.faint : _kTeal)),
            ],
          )),
          const SizedBox(width: 10),
          if (_saving)
            const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal))
          else
            Switch(
              value: !_optedOut, activeThumbColor: _kTeal,
              onChanged: (v) => _setOptOut(!v)),
        ]),
      );

  Widget _crisisCard() => GestureDetector(
        onTap: _callLifeline,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.35))),
          child: Row(children: [
            const Icon(Icons.support_agent_rounded, color: Color(0xFFDC2626), size: 26),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Need help now?',
                    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 14, color: AppC.text)),
                const SizedBox(height: 2),
                Text('In an emergency call 000. Lifeline: 13 11 14 (tap to call).',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, color: AppC.sub)),
              ],
            )),
            const Icon(Icons.call_rounded, color: Color(0xFFDC2626), size: 22),
          ]),
        ),
      );
}
