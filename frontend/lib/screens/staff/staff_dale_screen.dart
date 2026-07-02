// lib/screens/staff/staff_dale_screen.dart
//
// DALE tab — an AI-assistant landing for staff.
//   • Hero with the Dale robot animation.
//   • Tap-to-chat prompt bar + suggestion chips → Ask Dale (AiAssistantScreen).
//   • Train Dale card → upload course material (StaffKnowledgeScreen).
//   • Roadmap tools shown as "Soon".
// Styled with the shared staff kit (StaffHeader / staffCard / section label).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';

const _kDaleLottie = 'assets/images/robot.json';

class StaffDaleScreen extends StatelessWidget {
  const StaffDaleScreen({super.key});

  void _push(BuildContext context, Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  void _askDale(BuildContext context,
      {String? initialInput, bool openAttachment = false}) {
    HapticFeedback.selectionClick();
    _push(
        context,
        AiAssistantScreen(
          initialInput: initialInput,
          openAttachment: openAttachment,
        ));
  }

  Widget _dale({required double size, required Color fallback}) {
    return Lottie.asset(
      _kDaleLottie,
      width: size,
      height: size,
      fit: BoxFit.contain,
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
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.zero,
        children: [
          _hero(context),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Column(
              children: [
                const SizedBox(height: 14),
                _promptBar(context),
                const SizedBox(height: 14),
                _suggestions(context),
                const SizedBox(height: 26),
                const StaffSectionLabel(
                  'Tools',
                  subtitle: 'What Dale can do for your cohort',
                ),
                _trainCard(context),
                const SizedBox(height: 12),
                _soonRow(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────
  Widget _hero(BuildContext context) {
    return StaffHeader(
      bottomPad: 30,
      horizontal: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (Navigator.of(context).canPop())
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Container(
            width: 104,
            height: 104,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _dale(size: 78, fallback: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'Hi, I\'m Dale',
            style: TextStyle(
              fontFamily: 'Alfa',
              fontSize: 26,
              color: Colors.white,
              height: 1.05,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your AI tutor & assistant',
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tap-to-chat prompt bar ────────────────────────────────
  Widget _promptBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _askDale(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
          decoration: staffCard(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Ask Dale anything…',
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 13.5,
                    color: AppC.sub,
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: kStaffGrad,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: kStaffG2.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Suggestion chips ──────────────────────────────────────
  Widget _suggestions(BuildContext context) {
    // (icon, label, starter prompt, open file picker on entry)
    const chips = <(IconData, String, String, bool)>[
      (
        Icons.campaign_rounded,
        'Draft an announcement',
        'Draft a clear, friendly announcement for students about: ',
        false
      ),
      (
        Icons.summarize_rounded,
        'Summarise a policy',
        'Summarise this policy for students in simple, plain-language points:\n\n',
        false
      ),
      (
        Icons.menu_book_rounded,
        'Plan a lesson',
        'Help me plan a lesson. Subject and topic: ',
        false
      ),
      (
        Icons.translate_rounded,
        'Translate a notice',
        'Translate this notice into English. First tell me the original '
            'language, then give a clear translation:\n\n',
        false
      ),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final c = chips[i];
          return GestureDetector(
            onTap: () => _askDale(context,
                initialInput: c.$3, openAttachment: c.$4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: staffCard(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.$1, size: 15, color: kStaffG2),
                  const SizedBox(width: 7),
                  Text(
                    c.$2,
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppC.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Train Dale card ───────────────────────────────────────
  Widget _trainCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _push(context, const StaffKnowledgeScreen());
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2DD4BF), Color(0xFF0EA5A4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0EA5A4).withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Train Dale',
                      style: TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 19,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Upload notes & PDFs so Dale tutors students from your '
                      'real course material.',
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Roadmap (Soon) ────────────────────────────────────────
  Widget _soonRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _soonTile(
            context,
            Icons.query_stats_rounded,
            'What students ask',
            const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 12),
          _soonTile(
            context,
            Icons.quiz_rounded,
            'Quiz curation',
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _soonTile(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: kStaffG1,
                duration: const Duration(seconds: 2),
                content: Text(
                  '$title — coming soon',
                  style: const TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                ),
              ),
            );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: staffCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppC.faint.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SOON',
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppC.sub,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppC.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
