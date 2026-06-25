// lib/screens/staff/staff_dale_screen.dart
//
// DALE tab — a proper landing for the AI in its two staff roles:
//   • Ask Dale  — staff's own assistant (AiAssistantScreen)
//   • Train Dale — upload course material so Dale tutors students from it
//                  (StaffKnowledgeScreen)
// Styled with the shared staff kit (StaffHeader / staffCard).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';

// The Dale animation — the robot Lottie used across the app. Falls back to an
// icon if the file isn't found.
const _kDaleLottie = 'assets/images/robot.json';

class StaffDaleScreen extends StatelessWidget {
  const StaffDaleScreen({super.key});

  void _push(BuildContext context, Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  Widget _daleVisual({required double size, required Color fallback}) {
    return Lottie.asset(
      _kDaleLottie,
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.auto_awesome_rounded, color: fallback, size: size * 0.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          _header(),
          Transform.translate(
            offset: const Offset(0, -26),
            child: Column(children: [
              // ── spacing just before the Ask Dale container ──
              const SizedBox(height: 10),
              _featureCard(
                context,
                visual: _daleVisual(size: 40, fallback: Colors.white),
                title: 'Ask Dale',
                subtitle: 'Draft a notice, summarise a policy, plan a lesson '
                    'or just ask a question.',
                gradient: const [Color(0xFF8E54E9), Color(0xFF5B53E8)],
                cta: 'Start chatting',
                onTap: () => _push(context, const AiAssistantScreen()),
              ),
              const SizedBox(height: 14),
              _featureCard(
                context,
                visual: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 30),
                title: 'Train Dale',
                subtitle: 'Upload your notes and PDFs so Dale tutors students '
                    'from your real course material.',
                gradient: const [Color(0xFF2DD4BF), Color(0xFF0EA5A4)],
                cta: 'Upload material',
                onTap: () => _push(context, const StaffKnowledgeScreen()),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 26,
      horizontal: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: _daleVisual(size: 44, fallback: Colors.white)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dale',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 28,
                    color: Colors.white, height: 1.05,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                        offset: Offset(0, 3))])),
            const SizedBox(height: 4),
            Text('Your AI tutor & assistant',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        )),
      ]),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required Widget visual,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required String cta,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
                color: gradient.last.withValues(alpha: 0.32),
                blurRadius: 22, offset: const Offset(0, 12))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 56, height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(18)),
                  child: visual),
                const Spacer(),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18)),
              ]),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(fontFamily: 'Alfa', fontSize: 21,
                      color: Colors.white)),
              const SizedBox(height: 7),
              Text(subtitle,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.92))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(cta,
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: Colors.white)),
                  const SizedBox(width: 5),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 13, color: Colors.white),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
