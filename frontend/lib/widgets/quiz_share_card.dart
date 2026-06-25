// lib/widgets/quiz_share_card.dart
//
// Renders a shared quiz (parsed from a chat message / group post marker) as a
// tappable card. Tapping opens the quiz to attempt; on submit it lands in the
// user's quiz history like any other attempt.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/quiz_share.dart';
import 'package:tcs_app/screens/ai/quiz_play_Screen.dart';

const _kBlue   = Color(0xFF6DD5FA);
const _kPurple = Color(0xFF8E54E9);

class QuizShareCard extends StatelessWidget {
  final QuizShare quiz;

  /// When true the card sits inside the sender's own (colored) bubble, so it
  /// uses a translucent-white treatment for contrast.
  final bool onAccent;

  /// Who shared the quiz — shown on the card so multi-person bubbles always
  /// say who it came from. Null/empty hides the label.
  final String? sharedBy;

  const QuizShareCard({
    super.key,
    required this.quiz,
    this.onAccent = false,
    this.sharedBy,
  });

  @override
  Widget build(BuildContext context) {
    final diff = quiz.difficulty.isEmpty
        ? ''
        : quiz.difficulty[0].toUpperCase() + quiz.difficulty.substring(1);
    final meta = [
      if (quiz.count > 0) '${quiz.count} questions',
      if (diff.isNotEmpty) diff,
    ].join('  ·  ');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizPlayScreen(quizId: quiz.id, quizTitle: quiz.title),
      )),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onAccent ? Colors.white.withOpacity(0.16) : AppC.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: onAccent
                  ? Colors.white.withOpacity(0.30)
                  : _kPurple.withOpacity(0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sharedBy != null && sharedBy!.trim().isNotEmpty) ...[
              Row(children: [
                Icon(Icons.person_rounded, size: 12,
                    color: onAccent ? Colors.white70 : AppC.sub),
                const SizedBox(width: 4),
                Flexible(child: Text('${sharedBy!.trim()} shared a quiz',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                        color: onAccent ? Colors.white70 : AppC.sub))),
              ]),
              const SizedBox(height: 8),
            ],
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kBlue, _kPurple],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(11)),
                child: const Center(
                    child: T('🧠', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('QUIZ',
                      style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                          fontWeight: FontWeight.bold, letterSpacing: 1,
                          color: onAccent
                              ? Colors.white70 : _kPurple)),
                  const SizedBox(height: 1),
                  Text(quiz.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, fontSize: 13,
                          height: 1.2,
                          color: onAccent ? Colors.white : AppC.text)),
                ],
              )),
            ]),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(meta,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                      color: onAccent ? Colors.white70 : AppC.sub)),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                gradient: onAccent
                    ? null
                    : const LinearGradient(colors: [_kBlue, _kPurple]),
                color: onAccent ? Colors.white : null,
                borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text('Take quiz  →',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 12.5,
                        color: onAccent ? _kPurple : Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
