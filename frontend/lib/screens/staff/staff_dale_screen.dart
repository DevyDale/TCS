// lib/screens/staff/staff_dale_screen.dart
//
// DALE — the staff AI landing page. A hero header with the Dale animation, a
// short intro, and two gradient cards leading into the existing screens:
//   • Ask Dale  → AiAssistantScreen   (staff's own AI assistant)
//   • Train Dale → StaffKnowledgeScreen (upload course material for RAG)
// (A) restyle-the-shell redesign — the inner screens are unchanged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';

const _kDaleLottie = 'assets/images/robot.json';

class StaffDaleScreen extends StatelessWidget {
  const StaffDaleScreen({super.key});

  void _push(BuildContext c, Widget s) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => s));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          _header(context),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Column(children: [
              const StaffSectionLabel('What do you need?'),
              _actionCard(
                context,
                icon: Icons.auto_awesome_rounded,
                title: 'Ask Dale',
                subtitle: 'Draft a notice, summarise a policy, plan a lesson, '
                    'or get a quick answer — your own AI assistant.',
                gradient: const [Color(0xFF6DD5FA), Color(0xFF8E54E9)],
                onTap: () => _push(context, const AiAssistantScreen()),
              ),
              const SizedBox(height: 14),
              _actionCard(
                context,
                icon: Icons.school_rounded,
                title: 'Train Dale',
                subtitle: 'Upload course PDFs & notes so Dale tutors students '
                    'from your real material, and cites it.',
                gradient: const [Color(0xFF2DD4BF), Color(0xFF0EA5A4)],
                onTap: () => _push(context, const StaffKnowledgeScreen()),
              ),
              const SizedBox(height: 16),
              _tip(),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Hero header with the Dale animation ───────────────────
  Widget _header(BuildContext context) {
    return StaffHeader(
      bottomPad: 24,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22))),
            child: const Text('AI CO-PILOT',
                style: TextStyle(fontFamily: 'Arch', fontSize: 8.5,
                    fontWeight: FontWeight.bold, letterSpacing: 1.2,
                    color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.30),
                  width: 1.5)),
            child: Center(
              child: Lottie.asset(_kDaleLottie,
                  width: 52, height: 52, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded, color: Colors.white, size: 38)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Dale AI',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 28,
                      color: Colors.white, height: 1.0,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                          offset: Offset(0, 3))])),
              const SizedBox(height: 6),
              Text('Your AI co-pilot — ask anything, and train it on your '
                  'own course material.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.88))),
            ],
          )),
        ]),
      ]),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
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
                blurRadius: 20, offset: const Offset(0, 10))]),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(17)),
              child: Icon(icon, color: Colors.white, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 19, color: Colors.white)),
                const Spacer(),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16)),
              ]),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, height: 1.4,
                  color: Colors.white.withValues(alpha: 0.92))),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _tip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: staffCard(),
        child: Row(children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: T(
            'The more you upload in Train Dale, the better Dale tutors your '
            'students — it answers from your notes, not just the internet.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, height: 1.45,
                color: AppC.sub))),
        ]),
      ),
    );
  }
}
