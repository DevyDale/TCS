// lib/screens/staff/staff_needs_attention_screen.dart
//
// The "Needs attention" queue, moved off Home. Reached from the
// notifications button in the staff Home header. Lists things that need a
// response (escalations, flags, wellbeing) and routes each into its module.
// Data: GET /api/moderation/staff/needs-attention/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_moderation_screen.dart';
import 'package:tcs_app/screens/staff/staff_wellbeing_screen.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

class StaffNeedsAttentionScreen extends StatefulWidget {
  const StaffNeedsAttentionScreen({super.key});

  @override
  State<StaffNeedsAttentionScreen> createState() =>
      _StaffNeedsAttentionScreenState();
}

class _StaffNeedsAttentionScreenState extends State<StaffNeedsAttentionScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _needs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = (await _api.get('/moderation/staff/needs-attention/')
          .catchError((_) => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _needs = ((n['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  void _openTarget(String target) {
    if (target == 'moderation') {
      _push(const StaffModerationScreen());
    } else if (target == 'wellbeing') {
      _push(const StaffWellbeingScreen());
    }
  }

  ({IconData icon, Color color}) _needStyle(String type) {
    switch (type) {
      case 'escalation':
        return (icon: Icons.priority_high_rounded, color: const Color(0xFFE11D48));
      case 'flag':
        return (icon: Icons.flag_rounded, color: const Color(0xFFF59E0B));
      case 'wellbeing':
        return (icon: Icons.favorite_rounded, color: const Color(0xFF0EA5A4));
      default:
        return (icon: Icons.notifications_rounded, color: _kIndigo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: _kDeep,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            const SizedBox(height: 18),
            _body(),
            const SizedBox(height: 40),
          ],
        ),
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
        ]),
        const SizedBox(height: 16),
        const Text('Needs attention',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 26,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.bolt_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text('Things that need a response from you',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppC.border)),
          child: const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kDeep))),
        ),
      );
    }
    if (_needs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppC.border)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(
                "You're all caught up — nothing needs you right now.",
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: AppC.sub))),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: _needs.map((it) {
        final st = _needStyle((it['type'] ?? '').toString());
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _openTarget((it['target'] ?? '').toString());
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: staffCard(border: st.color.withValues(alpha: 0.30)),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: st.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(st.icon, color: st.color, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((it['title'] ?? '').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, fontSize: 13.5,
                            color: AppC.text)),
                    const SizedBox(height: 2),
                    Text((it['subtitle'] ?? '').toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: AppC.sub)),
                  ],
                )),
                Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 20),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }
}
