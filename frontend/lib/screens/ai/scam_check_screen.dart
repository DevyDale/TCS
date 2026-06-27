// lib/screens/ai/scam_check_screen.dart
//
// "Is this a scam?" — paste a suspicious call/text/email/job offer and Dale
// returns a cautious, structured verdict + the safe next action. Multilingual.
// Backed by POST /api/ai/scam-check/. Dale is a FIRST check, not the final
// authority — the UI always routes the student to official channels.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/widgets/ai_spinner.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/translation_service.dart';

const _kTeal   = Color(0xFF0EA5A4);
const _kBlue   = Color(0xFF2563EB);
const _kRed    = Color(0xFFE11D48);
const _kAmber  = Color(0xFFF59E0B);
const _kGreen  = Color(0xFF16A34A);

class ScamCheckScreen extends StatefulWidget {
  /// Optionally prefill the box (e.g. when launched from a chat message).
  final String? initialText;
  const ScamCheckScreen({super.key, this.initialText});

  @override
  State<ScamCheckScreen> createState() => _ScamCheckScreenState();
}

class _ScamCheckScreenState extends State<ScamCheckScreen> {
  final _api = ApiService();
  late final TextEditingController _ctrl;
  bool _loading = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
    if ((widget.initialText ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _result = null; });
    try {
      final data = await _api.post('/ai/scam-check/', body: {
        'content': text,
        'language': TranslationService.I.lang,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() { _result = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = {
          'verdict': 'suspicious',
          'headline': "I couldn't check this right now — treat it as suspicious "
              "and verify it independently.",
          'flags': [],
          'what_to_do': [
            "Don't pay anyone or share personal or bank details.",
            'Verify through official channels or your student office.',
          ],
          'anchor': 'When in doubt, stop and verify through official channels.',
          'report': const [],
        };
      });
    }
  }

  // Upload a screenshot of a suspicious message/email/call and let Dale read it.
  Future<void> _pickImage() async {
    if (_loading) return;
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      await _checkImage(base64Encode(bytes));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not read that image — try another.')));
      }
    }
  }

  Future<void> _checkImage(String b64) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _result = null; });
    try {
      final data = await _api.post('/ai/scam-check/', body: {
        'image': b64,
        'language': TranslationService.I.lang,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() { _result = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = {
          'verdict': 'suspicious',
          'headline': "I couldn't read that screenshot right now — treat it as "
              "suspicious and verify it independently.",
          'flags': const [],
          'what_to_do': const [
            "Don't pay anyone or share personal or bank details.",
            "Verify through official channels or your student office.",
          ],
          'anchor': 'When in doubt, stop and verify through official channels.',
          'report': const [],
        };
      });
    }
  }

  void _reset() {
    setState(() { _result = null; _ctrl.clear(); });
  }

  // ── Verdict styling ──────────────────────────────────────
  ({Color color, String emoji, String label}) _verdictStyle(String v) {
    switch (v) {
      case 'likely_scam':
        return (color: _kRed, emoji: '🚨', label: 'Likely a scam');
      case 'probably_safe':
        return (color: _kGreen, emoji: '✅', label: 'Probably safe — but verify');
      case 'suspicious':
      default:
        return (color: _kAmber, emoji: '⚠️', label: 'Suspicious — be careful');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _buildInput(),
              const SizedBox(height: 14),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    const AiSpinner(color: _kTeal),
                    const SizedBox(height: 14),
                    T('Dale is checking this carefully…',
                        style: TextStyle(fontFamily: 'Momo',
                            fontSize: 12.5, color: AppC.sub)),
                  ]),
                )
              else if (_result != null)
                _buildResult(_result!)
              else
                _buildIntro(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 8, right: 16, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kTeal, _kBlue],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop()),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 21)),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          T('Scam Check',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 19, color: Colors.white)),
          T('Paste a suspicious message — I’ll check it',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11.5, color: Colors.white70)),
        ])),
      ]),
    );
  }

  Widget _buildInput() {
    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppC.border)),
        child: TextField(
          controller: _ctrl,
          maxLines: 6, minLines: 4,
          style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: AppC.text),
          cursorColor: _kTeal,
          decoration: InputDecoration(
            hintText: 'Paste a suspicious call, text, email or job offer here…',
            hintStyle: TextStyle(
                fontFamily: 'Momo', fontSize: 13, color: AppC.faint),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16)),
        ),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: _check,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kTeal, _kBlue]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _kTeal.withOpacity(0.30),
                blurRadius: 12, offset: const Offset(0, 5))]),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Icon(Icons.search_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            T('Check it', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      // Upload a screenshot — Dale reads the text in the image.
      GestureDetector(
        onTap: _loading ? null : _pickImage,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kTeal.withOpacity(0.4))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.image_outlined, color: _kTeal, size: 19),
            const SizedBox(width: 8),
            T('Upload a screenshot', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 14, color: _kTeal)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildIntro() {
    const tips = [
      ('🏛️', 'Fake authorities', 'ATO, immigration or police threatening visa cancellation, fines or arrest.'),
      ('💳', 'Odd payment demands', 'Gift cards, vouchers, crypto or wire transfer — real bodies never use these.'),
      ('⏰', 'Pressure & urgency', '“Act now or else.” Scams manufacture panic so you don’t verify.'),
      ('🎁', 'Too good to be true', 'Fake jobs, scholarships, refunds or prizes with links to click.'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        T('What I look for',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 15, color: AppC.text)),
        const SizedBox(height: 12),
        ...tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.$1, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$2, style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: AppC.text)),
              const SizedBox(height: 2),
              Text(t.$3, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11.5, height: 1.4, color: AppC.sub)),
            ])),
          ]),
        )),
        const SizedBox(height: 4),
        Text("Dale is a first check, not the final word — always verify "
            "through official channels.",
            style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                fontStyle: FontStyle.italic, color: AppC.faint)),
      ]),
    );
  }

  Widget _buildResult(Map<String, dynamic> r) {
    final v = (r['verdict'] as String? ?? 'suspicious');
    final st = _verdictStyle(v);
    final flags = (r['flags'] as List?)?.cast<String>() ?? const [];
    final steps = (r['what_to_do'] as List?)?.cast<String>() ?? const [];
    final explanation = (r['explanation'] as String? ?? '').trim();
    final anchor = (r['anchor'] as String? ?? '').trim();
    final report = (r['report'] as List?)?.cast<Map>() ?? const [];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Verdict banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: st.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: st.color.withOpacity(0.45), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(st.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(st.label, style: TextStyle(fontFamily: 'Alfa',
                fontSize: 17, color: st.color)),
          ]),
          const SizedBox(height: 8),
          Text(r['headline'] as String? ?? '',
              style: TextStyle(fontFamily: 'Momo', fontSize: 13.5,
                  height: 1.5, color: AppC.text)),
        ]),
      ),
      if (flags.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('⚑  Warning signs I spotted'),
        const SizedBox(height: 8),
        ...flags.map((f) => _bullet(f, st.color, Icons.flag_rounded)),
      ],
      if (steps.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('✓  What to do now'),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((e) => _numbered(e.key + 1, e.value)),
      ],
      if (explanation.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppC.border)),
          child: Text(explanation, style: TextStyle(fontFamily: 'Momo',
              fontSize: 12.5, height: 1.55, color: AppC.sub)),
        ),
      ],
      if (anchor.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBlue.withOpacity(0.25))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.verified_user_rounded, color: _kBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(anchor, style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, height: 1.5, fontWeight: FontWeight.w600,
                color: AppC.text))),
          ]),
        ),
      ],
      if (report.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('☎  Report it / get help'),
        const SizedBox(height: 8),
        ...report.map((m) => _reportRow(
            m['label']?.toString() ?? '', m['value']?.toString() ?? '')),
      ],
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _reset,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppC.border)),
          child: Center(child: T('Check another message',
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13.5,
                  color: AppC.text))),
        ),
      ),
    ]);
  }

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(fontFamily: 'Alfa', fontSize: 14, color: AppC.text));

  Widget _bullet(String text, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'Momo',
              fontSize: 12.5, height: 1.45, color: AppC.text))),
        ]),
      );

  Widget _numbered(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
                color: _kTeal, shape: BoxShape.circle),
            child: Center(child: Text('$n', style: const TextStyle(
                fontFamily: 'Arch', fontSize: 11, color: Colors.white,
                fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontFamily: 'Momo',
              fontSize: 12.5, height: 1.45, color: AppC.text))),
        ]),
      );

  Widget _reportRow(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppC.border)),
        child: Row(children: [
          const Icon(Icons.open_in_new_rounded, size: 15, color: _kTeal),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12.5, color: AppC.text)),
            Text(value, style: const TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: _kTeal)),
          ])),
        ]),
      );
}
