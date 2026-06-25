// lib/screens/quiz/quiz_results_screen.dart
//
// Shows the result of a submitted quiz attempt:
//   • Big percentage hero (color-tiered)
//   • Score + time taken
//   • Per-question review with user vs correct + explanation
//   • Retake / Back to library actions

import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/screens/ai/quiz_play_Screen.dart';


const _kShelf     = Color(0xFF2C1810);
const _kWood      = Color(0xFF5C3317);
const _kWoodLight = Color(0xFF8B5E3C);
const _kCream     = Color(0xFFFDF6EC);
const _kPaper     = Color(0xFFF5ECD7);
const _kGold      = Color(0xFFD4A017);
const _kInk       = Color(0xFF1A1209);
const _kInkLight  = Color(0xFF4A3728);
const _kGreen     = Color(0xFF43A047);
const _kRed       = Color(0xFFE53935);

class QuizResultsScreen extends StatefulWidget {
  final String quizTitle;

  /// Result payload returned by POST /quiz/<id>/submit/. Shape:
  ///   {
  ///     id, quiz, score, total, percentage, duration_seconds, completed_at,
  ///     breakdown:  [{id, user_answer, correct_answer, is_correct, explanation}],
  ///     questions:  [ ...full questions including correct_answer ]
  ///   }
  final Map<String, dynamic> result;

  const QuizResultsScreen({
    super.key,
    required this.quizTitle,
    required this.result,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final Set<int> _expanded = {};

  // ─── Score tiering ─────────────────────────────────────
  ({Color color, String emoji, String tier}) _scoreTier(double pct) {
    if (pct >= 90) return (color: _kGreen, emoji: '🏆', tier: 'Outstanding');
    if (pct >= 75) return (color: const Color(0xFF7CB342), emoji: '🎉', tier: 'Great work');
    if (pct >= 60) return (color: _kGold, emoji: '👍', tier: 'Solid');
    if (pct >= 40) return (color: const Color(0xFFFB8C00), emoji: '📚', tier: 'Keep studying');
    return (color: _kRed, emoji: '💪', tier: 'Try again');
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  String _quizId() => widget.result['quiz']?.toString() ?? '';

  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final score      = (r['score']      as num?)?.toInt()    ?? 0;
    final total      = (r['total']      as num?)?.toInt()    ?? 0;
    final percentage = (r['percentage'] as num?)?.toDouble() ?? 0.0;
    final duration   = (r['duration_seconds'] as num?)?.toInt() ?? 0;
    final breakdown  = (r['breakdown']  as List?) ?? const [];
    final questions  = (r['questions']  as List?) ?? const [];

    final tier = _scoreTier(percentage);

    return Scaffold(
      backgroundColor: _kCream,
      body: CustomScrollView(
        slivers: [
          // ─── Hero ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tier.color.withOpacity(0.95), tier.color.withOpacity(0.7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.popUntil(context,
                            (route) => route.isFirst || route.settings.name == 'saved_materials'),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: Colors.white.withOpacity(0.3))),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20))),
                      const Spacer(),
                      Text(tier.tier,
                          style: const TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: Colors.white, letterSpacing: 0.5)),
                    ]),
                    const SizedBox(height: 12),
                    Center(child: Text(tier.emoji,
                        style: const TextStyle(fontSize: 64))),
                    const SizedBox(height: 6),
                    Center(child: Text('${percentage.toStringAsFixed(percentage % 1 == 0 ? 0 : 1)}%',
                        style: const TextStyle(fontFamily: 'Alfa',
                            fontSize: 60, color: Colors.white,
                            letterSpacing: 0.5, height: 1))),
                    const SizedBox(height: 8),
                    Center(child: Text('$score out of $total correct',
                        style: const TextStyle(fontFamily: 'Momo',
                            fontSize: 14, color: Colors.white))),
                    const SizedBox(height: 14),

                    // Stat strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.25))),
                      child: Row(children: [
                        _statTile('⏱', _formatDuration(duration), 'Time'),
                        Container(width: 1, height: 30,
                            color: Colors.white.withOpacity(0.2)),
                        _statTile('✅', '$score', 'Correct'),
                        Container(width: 1, height: 30,
                            color: Colors.white.withOpacity(0.2)),
                        _statTile('❌', '${total - score}', 'Wrong'),
                      ]),
                    ),

                    const SizedBox(height: 12),
                    Center(child: Text(widget.quizTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Arch',
                            fontSize: 12, color: Colors.white70))),
                  ]),
                ),
              ),
            ),
          ),

          // ─── Review header ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Row(children: [
                Container(width: 4, height: 18,
                    decoration: BoxDecoration(color: _kGold,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const T('Review',
                    style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 18, color: _kInk)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kWood.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('${breakdown.length}',
                      style: const TextStyle(fontFamily: 'Momo',
                          fontSize: 11, color: _kWood,
                          fontWeight: FontWeight.bold))),
                const Spacer(),
                T('Tap to expand',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: _kInkLight)),
              ]),
            ),
          ),

          // ─── Per-question cards ───────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final b = breakdown[i] as Map<String, dynamic>;
              final q = i < questions.length
                  ? questions[i] as Map<String, dynamic>
                  : <String, dynamic>{};
              return _ReviewCard(
                index:    i + 1,
                question: q,
                answerInfo: b,
                expanded: _expanded.contains(i),
                onToggle: () => setState(() {
                  if (_expanded.contains(i)) {
                    _expanded.remove(i);
                  } else {
                    _expanded.add(i);
                  }
                }),
              );
            }, childCount: breakdown.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ─── Bottom action bar ──────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.popUntil(context,
                    (route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kWood,
                  side: BorderSide(color: _kWoodLight.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                child: const T('Back to library',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 13)),
              )),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _quizId().isEmpty ? null : () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => QuizPlayScreen(
                      quizId:    _quizId(),
                      quizTitle: widget.quizTitle,
                    ),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.refresh_rounded, size: 16),
                  SizedBox(width: 6),
                  T('Retake',
                      style: TextStyle(fontFamily: 'Alfa',
                          fontSize: 14, letterSpacing: 0.3)),
                ]))),
          ]),
        ),
      ),
    );
  }

  Widget _statTile(String emoji, String value, String label) {
    return Expanded(child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(fontFamily: 'Alfa',
              fontSize: 16, color: Colors.white)),
      Text(label,
          style: const TextStyle(fontFamily: 'Momo',
              fontSize: 10, color: Colors.white70)),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────
// Per-question review card
// ─────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> question;
  final Map<String, dynamic> answerInfo;
  final bool expanded;
  final VoidCallback onToggle;

  const _ReviewCard({
    required this.index,
    required this.question,
    required this.answerInfo,
    required this.expanded,
    required this.onToggle,
  });

  String _formatAnswer(dynamic value, String type, List<dynamic> options) {
    if (value == null || (value is String && value.isEmpty)) return '— blank —';
    if (type == 'true_false') {
      if (value is bool) return value ? 'True' : 'False';
      return value.toString();
    }
    if (type == 'mcq' && value is String && options.isNotEmpty) {
      // Map "A".."D" to the option text for readability
      const map = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
      final idx = map[value.toUpperCase()];
      if (idx != null && idx < options.length) {
        return '$value. ${options[idx]}';
      }
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final type        = question['type'] as String? ?? 'mcq';
    final options     = (question['options'] as List?) ?? const [];
    final qText       = question['question'] as String? ?? '';
    final isCorrect   = answerInfo['is_correct'] as bool? ?? false;
    final explanation = answerInfo['explanation'] as String? ?? '';

    final userText    = _formatAnswer(answerInfo['user_answer'],    type, options);
    final correctText = _formatAnswer(answerInfo['correct_answer'], type, options);

    final color = isCorrect ? _kGreen : _kRed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Container(
          decoration: BoxDecoration(
            color: _kPaper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4), width: 1.2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: color,
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Icon(
                      isCorrect ? Icons.check_rounded : Icons.close_rounded,
                      color: Colors.white, size: 18))),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Question $index',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 10, color: _kInkLight)),
                  const SizedBox(height: 2),
                  Text(qText,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 13, color: _kInk, height: 1.4)),
                ])),
                const SizedBox(width: 6),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: expanded ? 0.5 : 0,
                  child: Icon(Icons.expand_more_rounded,
                      color: _kInkLight, size: 22)),
              ]),
            ),

            // Expanded body
            if (expanded) Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Divider(color: _kWoodLight, height: 1),
                const SizedBox(height: 12),
                _answerRow('Your answer', userText,
                    color: isCorrect ? _kGreen : _kRed,
                    icon:  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded),
                if (!isCorrect) ...[
                  const SizedBox(height: 10),
                  _answerRow('Correct answer', correctText,
                      color: _kGreen,
                      icon:  Icons.check_circle_rounded),
                ],
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kGold.withOpacity(0.3))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const T('💡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(explanation,
                          style: const TextStyle(fontFamily: 'Momo',
                              fontSize: 11, color: _kInk, height: 1.5))),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _answerRow(String label, String value,
      {required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 10, color: color)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: _kInk, height: 1.4)),
        ])),
      ]),
    );
  }
}