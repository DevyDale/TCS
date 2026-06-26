// lib/screens/studyhub/quiz_take_screen.dart
//
// Student takes a published quiz: one card per MCQ, pick an option, submit →
// auto-graded server-side. Results show score, XP earned (first attempt only)
// and per-question explanations (spec §4 "Assign + attempt").

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class QuizTakeScreen extends StatefulWidget {
  final String quizId;
  const QuizTakeScreen({super.key, required this.quizId});

  @override
  State<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends State<QuizTakeScreen> {
  final _api = ApiService();
  bool _loading = true, _submitting = false;
  Map<String, dynamic>? _quiz;
  final Map<String, int> _answers = {};
  Map<String, dynamic>? _result;   // set after submit

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _api.getQuiz(widget.quizId) as Map;
      if (!mounted) return;
      setState(() { _quiz = d.cast<String, dynamic>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _questions =>
      ((_quiz?['questions'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>()).toList();

  Future<void> _submit() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Answer every question first.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final d = await _api.attemptQuiz(widget.quizId, _answers) as Map;
      if (!mounted) return;
      setState(() { _result = d.cast<String, dynamic>(); _submitting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      appBar: AppBar(
        backgroundColor: kStaffG1, foregroundColor: Colors.white,
        title: Text(_quiz?['title']?.toString() ?? 'Quiz',
            style: const TextStyle(fontFamily: 'Alfa', fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kStaffG1))
          : _result != null
              ? _resultsView()
              : _quizView(),
    );
  }

  Widget _quizView() {
    final qs = _questions;
    return Column(children: [
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: qs.length,
        itemBuilder: (_, i) => _qCard(i, qs[i]),
      )),
      SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: kStaffG1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Submit  (${_answers.length}/${qs.length})',
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, color: Colors.white)),
          )),
      )),
    ]);
  }

  Widget _qCard(int i, Map<String, dynamic> q) {
    final id = q['id'].toString();
    final options = (q['options'] as List? ?? []).map((e) => e.toString()).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Question ${i + 1}',
            style: TextStyle(fontFamily: 'Arch', fontSize: 11,
                fontWeight: FontWeight.bold, color: kStaffG1)),
        const SizedBox(height: 6),
        Text(q['text']?.toString() ?? '',
            style: TextStyle(fontFamily: 'Arch', fontSize: 15,
                fontWeight: FontWeight.bold, color: AppC.text, height: 1.3)),
        const SizedBox(height: 12),
        ...List.generate(options.length, (oi) {
          final selected = _answers[id] == oi;
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick();
                setState(() => _answers[id] = oi); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: selected ? kStaffG1.withValues(alpha: 0.12) : AppC.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? kStaffG1 : AppC.border,
                    width: selected ? 1.5 : 1)),
              child: Row(children: [
                Icon(selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                    size: 19, color: selected ? kStaffG1 : AppC.faint),
                const SizedBox(width: 10),
                Expanded(child: Text(options[oi],
                    style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                        color: AppC.text))),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────
  Widget _resultsView() {
    final r = _result!;
    final score = r['score'] ?? 0, total = r['total'] ?? 0;
    final pct = r['percentage'] ?? 0;
    final xp = r['xp_awarded'] ?? 0;
    final review = (r['review'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList();
    final qs = {for (final q in _questions) q['id'].toString(): q};
    final good = (pct as num) >= 60;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: good
                ? const [Color(0xFF16A34A), Color(0xFF15803D)]
                : const [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Icon(good ? Icons.emoji_events_rounded : Icons.school_rounded,
              color: Colors.white, size: 44),
          const SizedBox(height: 10),
          Text('$score / $total',
              style: const TextStyle(fontFamily: 'Alfa', fontSize: 34,
                  color: Colors.white)),
          Text('$pct%', style: TextStyle(fontFamily: 'Arch', fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9))),
          if ((xp as num) > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20)),
              child: Text('+$xp tokens earned',
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 13,
                      fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ]),
      ),
      const SizedBox(height: 18),
      Text('Review', style: TextStyle(fontFamily: 'Alfa', fontSize: 16,
          color: AppC.text)),
      const SizedBox(height: 8),
      ...review.map((rv) {
        final q = qs[rv['id'].toString()];
        final opts = (q?['options'] as List? ?? []).map((e) => e.toString()).toList();
        final ok = rv['is_correct'] == true;
        final ci = rv['correct_index'] as int? ?? 0;
        final chosen = rv['chosen'] as int? ?? -1;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                width: 1.2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 17, color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Expanded(child: Text(q?['text']?.toString() ?? '',
                  style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                      fontWeight: FontWeight.bold, color: AppC.text))),
            ]),
            const SizedBox(height: 8),
            if (chosen >= 0 && chosen < opts.length && !ok)
              Text('Your answer: ${opts[chosen]}',
                  style: const TextStyle(fontFamily: 'Momo', fontSize: 12,
                      color: Color(0xFFDC2626))),
            if (ci >= 0 && ci < opts.length)
              Text('Correct: ${opts[ci]}',
                  style: const TextStyle(fontFamily: 'Momo', fontSize: 12,
                      color: Color(0xFF16A34A))),
            if ((rv['explanation'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(rv['explanation'].toString(),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      height: 1.4, color: AppC.sub)),
            ],
          ]),
        );
      }),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 50,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(foregroundColor: kStaffG1),
          child: const Text('Done', style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold)))),
    ]);
  }
}
