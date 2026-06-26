// lib/screens/staff/staff_protect_screen.dart
//
// PROTECT tab — the safety desk landing. Live tools as gradient cards
// (Moderation with a live flag count, Wellbeing, Suggestions) routing into
// their screens, a crisis-resources quick-call panel, and a Scam-watch tile
// (roadmap). Styled with the shared staff kit.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/staff/staff_moderation_screen.dart';
import 'package:tcs_app/screens/staff/staff_suggestions_screen.dart';
import 'package:tcs_app/screens/staff/staff_wellbeing_screen.dart';
import 'package:tcs_app/screens/staff/staff_broadcast_screen.dart';

class StaffProtectScreen extends StatefulWidget {
  const StaffProtectScreen({super.key});

  @override
  State<StaffProtectScreen> createState() => _StaffProtectScreenState();
}

class _StaffProtectScreenState extends State<StaffProtectScreen> {
  final _api = ApiService();
  int _flagsPending = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final d = (await _api.get('/moderation/staff/overview/')
          .catchError((_) => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _flagsPending = (d['flags_pending'] as int?) ?? 0);
    } catch (_) {/* badge just stays at 0 */}
  }

  void _push(BuildContext context, Widget s) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    _loadCounts(); // refresh the badge after working a queue
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: const Color(0xFFDC2626),
        onRefresh: _loadCounts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _hero(),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Column(children: [
                const SizedBox(height: 12),
                const StaffSectionLabel('Emergency',
                    subtitle: 'Alert every student at once'),
                _broadcastCard(context),
                const SizedBox(height: 22),
                const StaffSectionLabel('Safety desk',
                    subtitle: 'Keep your students safe'),
                _card(context,
                    icon: Icons.shield_rounded,
                    title: 'Moderation',
                    subtitle: 'Work the flag queue — hide, remove, dismiss.',
                    gradient: const [Color(0xFFF87171), Color(0xFFDC2626)],
                    badge: _flagsPending,
                    onTap: () => _push(context, const StaffModerationScreen())),
                const SizedBox(height: 12),
                _card(context,
                    icon: Icons.favorite_rounded,
                    title: 'Wellbeing',
                    subtitle: 'Quiet students, concern reports, Dale flags.',
                    gradient: const [Color(0xFFF472B6), Color(0xFFDB2777)],
                    onTap: () => _push(context, const StaffWellbeingScreen())),
                const SizedBox(height: 12),
                _card(context,
                    icon: Icons.lightbulb_rounded,
                    title: 'Suggestions',
                    subtitle: 'Student ideas raised to the school.',
                    gradient: const [Color(0xFF818CF8), Color(0xFF4F46E5)],
                    onTap: () => _push(context, const StaffSuggestionsScreen())),
                const SizedBox(height: 22),
                const StaffSectionLabel('When it\'s urgent',
                    subtitle: 'Who to call in a crisis'),
                _crisisCard(),
                const SizedBox(height: 22),
                const StaffSectionLabel('Scam safety'),
                _scamTile(context),
                const SizedBox(height: 40),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return StaffHeader(
      bottomPad: 28,
      horizontal: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: const Icon(Icons.verified_user_rounded,
              color: Colors.white, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Protect',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 28,
                    color: Colors.white, height: 1.05,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                        offset: Offset(0, 3))])),
            const SizedBox(height: 4),
            Text('Safety & wellbeing of your cohort',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        )),
      ]),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
                color: gradient.last.withValues(alpha: 0.32),
                blurRadius: 20, offset: const Offset(0, 11))]),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 26)),
            const SizedBox(width: 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text(title, style: const TextStyle(fontFamily: 'Alfa',
                      fontSize: 18, color: Colors.white)),
                  if (badge > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge waiting',
                          style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: gradient.last)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11.5, height: 1.35,
                    color: Colors.white.withValues(alpha: 0.92))),
              ],
            )),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 21),
          ]),
        ),
      ),
    );
  }

  Widget _broadcastCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _push(context, const StaffBroadcastScreen());
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
                color: const Color(0xFFB91C1C).withValues(alpha: 0.36),
                blurRadius: 22, offset: const Offset(0, 12))]),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.campaign_rounded,
                  color: Colors.white, size: 28)),
            const SizedBox(width: 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Emergency broadcast',
                    style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('Push an urgent alert to every student — with a '
                    'mark-yourself-safe roll-call.',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.92))),
              ],
            )),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 21),
          ]),
        ),
      ),
    );
  }

  // ── Crisis resources: tap-to-call panel ───────────────────
  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Could not start a call to $number',
            style: const TextStyle(fontFamily: 'Momo'))));
    }
  }

  Widget _crisisCard() {
    // Australia-wide support lines (publicly published, always-on).
    const lines = <(IconData, String, String, Color)>[
      (Icons.emergency_rounded, 'Emergency', '000', Color(0xFFDC2626)),
      (Icons.support_agent_rounded, 'Lifeline', '13 11 14', Color(0xFF0EA5A4)),
      (Icons.psychology_alt_rounded, 'Beyond Blue', '1300 22 4636',
          Color(0xFF6366F1)),
      (Icons.child_care_rounded, 'Kids Helpline', '1800 55 1800',
          Color(0xFFF59E0B)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: staffCard(),
        child: Column(children: [
          for (int i = 0; i < lines.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppC.border.withValues(alpha: 0.6),
                  indent: 16, endIndent: 16),
            InkWell(
              onTap: () { HapticFeedback.selectionClick(); _call(lines[i].$3); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lines[i].$4.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11)),
                    child: Icon(lines[i].$1, color: lines[i].$4, size: 19)),
                  const SizedBox(width: 13),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lines[i].$2, style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, fontSize: 13.5,
                          color: AppC.text)),
                      const SizedBox(height: 1),
                      Text(lines[i].$3, style: TextStyle(fontFamily: 'Momo',
                          fontSize: 11.5, color: AppC.sub)),
                    ],
                  )),
                  Icon(Icons.call_rounded, color: lines[i].$4, size: 19),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _scamTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _push(context, const _ScamOversightScreen());
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: staffCard(),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.radar_rounded,
                  color: Color(0xFFF59E0B), size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text('Scam watch', style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14.5,
                      color: AppC.text)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(7)),
                    child: const Text('SOON', style: TextStyle(
                        fontFamily: 'Arch', fontSize: 8,
                        fontWeight: FontWeight.bold, letterSpacing: 1,
                        color: Color(0xFFB45309))),
                  ),
                ]),
                const SizedBox(height: 3),
                Text('Spot scam waves & broadcast a warning early.',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        color: AppC.sub)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 22),
          ]),
        ),
      ),
    );
  }
}

class _ScamOversightScreen extends StatelessWidget {
  const _ScamOversightScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        StaffHeader(
          bottomPad: 24,
          horizontal: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25))),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20)),
            ),
            const SizedBox(width: 14),
            const Text('Scam watch',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 22,
                    color: Colors.white)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
          child: Column(children: [
            const Text('🛰️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Scam oversight is on the way',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
                    color: AppC.text)),
            const SizedBox(height: 10),
            Text(
                'Students can already check suspicious messages with Dale in '
                'the Scam Check tool. A live staff view of scam waves — so you '
                'can broadcast a warning early — is on the roadmap.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                    height: 1.6, color: AppC.sub)),
          ]),
        ),
      ]),
    );
  }
}
