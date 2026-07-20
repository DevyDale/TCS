// lib/screens/staff/staff_emergency_compose_screen.dart
//
// Post an emergency alert. Required audience (Staff/Students/Everyone), type,
// severity, title/message/instruction, drill toggle, type templates, and a
// deliberate slide-to-confirm. POST /api/safety/emergency/.
//
// An app alert SUPPLEMENTS official emergency channels — it never replaces the
// building alarm or warden instructions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/widgets/slide_to_confirm.dart';

const _kCoral = Color(0xFFFF5858);

class StaffEmergencyComposeScreen extends StatefulWidget {
  const StaffEmergencyComposeScreen({super.key});

  @override
  State<StaffEmergencyComposeScreen> createState() =>
      _StaffEmergencyComposeScreenState();
}

class _StaffEmergencyComposeScreenState
    extends State<StaffEmergencyComposeScreen> {
  final _api = ApiService();
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _instruction = TextEditingController();

  String _audience = '';
  String _type = 'general';
  String _severity = 'high';
  bool _drill = false;

  // (value, label, icon, default-message-template)
  static const _types = <(String, String, IconData, String, String, String)>[
    ('lockdown', 'Lockdown', Icons.lock_rounded,
        'Shelter in place', 'Remain where you are and lock the door.',
        'Stay quiet, away from windows, until an all-clear is given.'),
    ('evacuation', 'Evacuation', Icons.directions_run_rounded,
        'Evacuate now', 'Leave the building immediately.',
        'Use your nearest exit and follow warden instructions.'),
    ('weather', 'Severe weather', Icons.thunderstorm_rounded,
        'Severe weather warning', 'Severe weather is affecting campus.',
        'Stay indoors and away from windows.'),
    ('medical', 'Medical', Icons.medical_services_rounded,
        'Medical emergency', 'A medical emergency is in progress.',
        'Keep the area clear for first responders.'),
    ('security', 'Security', Icons.shield_rounded,
        'Security alert', 'A security incident is in progress.',
        'Follow staff instructions and stay calm.'),
    ('closure', 'Closure', Icons.event_busy_rounded,
        'Campus closure', 'Campus is closed.',
        'Do not come to campus until further notice.'),
    ('outage', 'Outage', Icons.power_off_rounded,
        'Utility / IT outage', 'A service outage is affecting campus.',
        'We are working to restore service.'),
    ('general', 'General', Icons.campaign_rounded, '', '', ''),
  ];

  @override
  void dispose() {
    _title.dispose(); _message.dispose(); _instruction.dispose();
    super.dispose();
  }

  void _applyTemplate(String type) {
    final t = _types.firstWhere((e) => e.$1 == type);
    setState(() {
      _type = type;
      if (_title.text.trim().isEmpty) _title.text = t.$4;
      if (_message.text.trim().isEmpty) _message.text = t.$5;
      if (_instruction.text.trim().isEmpty) _instruction.text = t.$6;
    });
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : _kCoral,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo',
          color: Colors.white))));
  }

  Future<void> _post() async {
    final title = _title.text.trim();
    final msg = _message.text.trim();
    if (_audience.isEmpty) { _snack('Choose who this is for.', error: true); return; }
    if (title.isEmpty || msg.isEmpty) {
      _snack('Title and message are required.', error: true); return;
    }
    final audLabel = _audience == 'everyone' ? 'everyone'
        : _audience == 'staff' ? 'all staff' : 'all students';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text(_drill ? 'Send DRILL alert?' : 'Send emergency alert?',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Text(
            'This ${_drill ? "DRILL " : ""}alert goes to $audLabel immediately.'
            '${_drill ? "" : "\n\nUse this only for a real situation."}',
            style: TextStyle(fontFamily: 'Momo', color: AppC.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppC.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(_drill ? 'Send drill' : 'Send now',
                  style: const TextStyle(color: _kCoral,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.post('/safety/emergency/', body: {
        'type': _type, 'severity': _severity, 'audience': _audience,
        'title': title, 'message': msg,
        'instruction': _instruction.text.trim(), 'is_drill': _drill,
      });
      HapticFeedback.heavyImpact();
      if (mounted) { _snack('Alert sent.'); Navigator.of(context).pop(true); }
    } catch (e) {
      _snack('Could not send: $e', error: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        _header(),
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Who is this for?'),
            const SizedBox(height: 8),
            Row(children: [
              for (final a in const [['staff', 'Staff'], ['students', 'Students'],
                  ['everyone', 'Everyone']])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: a[0] == 'everyone' ? 0 : 9),
                  child: GestureDetector(
                    onTap: () => setState(() => _audience = a[0]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _audience == a[0] ? _kCoral : AppC.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _audience == a[0]
                            ? _kCoral : AppC.border)),
                      child: Text(a[1], style: TextStyle(fontFamily: 'Arch',
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: _audience == a[0] ? Colors.white : AppC.sub)),
                    ),
                  ),
                )),
            ]),
            const SizedBox(height: 18),
            _label('Type'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _types)
                GestureDetector(
                  onTap: () => _applyTemplate(t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _type == t.$1 ? _kCoral.withValues(alpha: 0.15) : AppC.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _type == t.$1 ? _kCoral : AppC.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.$3, size: 15,
                          color: _type == t.$1 ? _kCoral : AppC.sub),
                      const SizedBox(width: 6),
                      Text(t.$2, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _type == t.$1 ? _kCoral : AppC.sub)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            _label('Severity'),
            const SizedBox(height: 8),
            Row(children: [
              for (final s in const [['info', 'Info', Color(0xFF3B82F6)],
                  ['high', 'High', Color(0xFFF59E0B)],
                  ['critical', 'Critical', _kCoral]])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: s[0] == 'critical' ? 0 : 9),
                  child: GestureDetector(
                    onTap: () => setState(() => _severity = s[0] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _severity == s[0] ? (s[2] as Color) : AppC.card,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: _severity == s[0]
                            ? (s[2] as Color) : AppC.border)),
                      child: Text(s[1] as String, style: TextStyle(fontFamily: 'Arch',
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: _severity == s[0] ? Colors.white : AppC.sub)),
                    ),
                  ),
                )),
            ]),
            const SizedBox(height: 18),
            _field(_title, 'Title', 'e.g. Shelter in place'),
            const SizedBox(height: 12),
            _field(_message, 'Message', 'What is happening', lines: 3),
            const SizedBox(height: 12),
            _field(_instruction, 'What to do (optional)', 'e.g. Use the north stairwell'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _drill = !_drill),
              child: Row(children: [
                Icon(_drill ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: _drill ? const Color(0xFFF59E0B) : AppC.sub, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text('This is a DRILL (clearly labelled to recipients)',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                        color: AppC.text))),
              ]),
            ),
            const SizedBox(height: 8),
            Text('An app alert supplements — it never replaces — the building '
                'alarm and official procedure.',
                style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                    color: AppC.faint, height: 1.4)),
            const SizedBox(height: 18),
            SlideToConfirm(
              label: _drill ? 'Slide to send DRILL' : 'Slide to send alert',
              color: _drill ? const Color(0xFFF59E0B) : _kCoral,
              icon: Icons.send_rounded,
              onConfirmed: _post,
            ),
            const SizedBox(height: 40),
          ],
        )),
      ]),
    );
  }

  Widget _header() => StaffHeader(
        bottomPad: 20,
        horizontal: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
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
          const SizedBox(width: 14),
          const Text('New emergency',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 22,
                  color: Colors.white)),
        ]),
      );

  Widget _label(String t) => Text(t, style: TextStyle(fontFamily: 'Arch',
      fontSize: 12, fontWeight: FontWeight.bold, color: AppC.sub));

  Widget _field(TextEditingController c, String label, String hint,
          {int lines = 1}) =>
      TextField(controller: c, maxLines: lines,
        style: TextStyle(color: AppC.text, fontFamily: 'Momo', fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: TextStyle(fontFamily: 'Momo', color: AppC.sub),
          hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 12),
          filled: true, fillColor: AppC.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
      );
}
