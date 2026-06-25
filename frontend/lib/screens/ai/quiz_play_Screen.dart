// lib/screens/quiz/quiz_play_screen.dart
//
// Interactive quiz player. Receives either a full preloaded quiz JSON
// (handed in by the generator) or just a quizId — in which case it
// fetches /quiz/<id>/play/. Handles MCQ, true/false, and short-answer.

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/ai/quiz_results_Screen.dart';

import '../../../../services/api_service.dart';

const _kShelf     = Color(0xFF2C1810);
const _kWood      = Color(0xFF5C3317);
const _kWoodLight = Color(0xFF8B5E3C);
const _kCream     = Color(0xFFFDF6EC);
const _kPaper     = Color(0xFFF5ECD7);
const _kGold      = Color(0xFFD4A017);
const _kInk       = Color(0xFF1A1209);
const _kInkLight  = Color(0xFF4A3728);

class QuizPlayScreen extends StatefulWidget {
  final String  quizId;
  final String  quizTitle;
  final Map<String, dynamic>? preloaded;

  const QuizPlayScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    this.preloaded,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  final _api = ApiService();
  final _shortCtrl = TextEditingController();

  Map<String, dynamic>?  _quiz;
  List<dynamic>          _questions = const [];
  final Map<String, dynamic> _answers = {};

  int     _index    = 0;
  bool    _loading  = true;
  bool    _submitting = false;

  late final Stopwatch _stopwatch;
  Timer? _ticker;
  String _elapsed = '00:00';

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final sec = _stopwatch.elapsed.inSeconds;
      final mm = (sec ~/ 60).toString().padLeft(2, '0');
      final ss = (sec % 60).toString().padLeft(2, '0');
      if (mounted) setState(() => _elapsed = '$mm:$ss');
    });

    if (widget.preloaded != null) {
      _hydrate(widget.preloaded!);
    } else {
      _fetch();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    _shortCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> data) {
    setState(() {
      _quiz      = data;
      _questions = (data['questions'] as List?) ?? const [];
      _loading   = false;
    });
  }

  Future<void> _fetch() async {
    try {
      final data = await _api.get('/quiz/${widget.quizId}/play/');
      _hydrate(data as Map<String, dynamic>);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ─── Navigation ─────────────────────────────────────────
  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _shortCtrl.text = (_answers[_currentQ['id']] as String?) ?? '';
      });
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _shortCtrl.text = (_answers[_currentQ['id']] as String?) ?? '';
      });
    }
  }

  Map<String, dynamic> get _currentQ =>
      _questions[_index] as Map<String, dynamic>;

  bool get _hasAnswered =>
      _answers.containsKey(_currentQ['id']) &&
      _answers[_currentQ['id']] != null &&
      _answers[_currentQ['id']].toString().isNotEmpty;

  Future<void> _submit() async {
    final unanswered = _questions.where((q) {
      final id = (q as Map<String, dynamic>)['id'];
      return !_answers.containsKey(id) ||
          _answers[id] == null ||
          _answers[id].toString().isEmpty;
    }).length;

    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kCream,
          title: const T('Submit anyway?',
              style: TextStyle(fontFamily: 'Alfa', color: _kInk)),
          content: Text('You have $unanswered unanswered questions.',
              style: const TextStyle(fontFamily: 'Momo', color: _kInkLight)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const T('Keep going')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kGold),
              onPressed: () => Navigator.pop(ctx, true),
              child: const T('Submit',
                  style: TextStyle(color: Colors.white))),
          ],
        ),
      ) ?? false;
      if (!ok) return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    _stopwatch.stop();

    try {
      final result = await _api.post(
        '/quiz/${widget.quizId}/submit/',
        body: {
          'answers':           _answers,
          'duration_seconds':  _stopwatch.elapsed.inSeconds,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => QuizResultsScreen(
          quizTitle: widget.quizTitle,
          result:    result as Map<String, dynamic>,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _stopwatch.start();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Submit failed: ${e.toString()}')));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading)        return _scaffold(_centered(_loadingBlock()));
    if (_questions.isEmpty) return _scaffold(_centered(_emptyBlock()));
    if (_submitting)     return _scaffold(_centered(_submittingBlock()));

    final progress = (_index + 1) / _questions.length;
    final q = _currentQ;

    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(progress),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _questionTypeBadge(q['type'] as String? ?? 'mcq'),
                const SizedBox(height: 14),
                Text('Question ${_index + 1} of ${_questions.length}',
                    style: const TextStyle(fontFamily: 'Momo',
                        fontSize: 11, color: _kInkLight)),
                const SizedBox(height: 8),
                Text(q['question'] as String? ?? '',
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 18, color: _kInk, height: 1.4)),
                const SizedBox(height: 24),
                _answerWidget(q),
              ]),
            ),
          ),
          _buildFooter(),
        ]),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────
  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kShelf, _kWood],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: _confirmExit,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12))),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white70, size: 18))),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.quizTitle,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 14, color: Colors.white))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.12))),
            child: Row(children: [
              const Icon(Icons.timer_outlined,
                  size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(_elapsed,
                  style: const TextStyle(fontFamily: 'Momo',
                      fontSize: 11, color: Colors.white70)),
            ])),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress, minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(_kGold)),
        ),
      ]),
    );
  }

  Widget _questionTypeBadge(String type) {
    final config = {
      'mcq':        ('🅰️', 'Multiple choice', const Color(0xFF1E88E5)),
      'true_false': ('✅', 'True or false',    const Color(0xFF43A047)),
      'short':      ('✍️', 'Short answer',    const Color(0xFF8E24AA)),
    };
    final (emoji, label, color) = config[type] ?? config['mcq']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontFamily: 'Arch',
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ─── Answer widgets ─────────────────────────────────────
  Widget _answerWidget(Map<String, dynamic> q) {
    final type = q['type'] as String? ?? 'mcq';
    if (type == 'mcq')        return _mcqWidget(q);
    if (type == 'true_false') return _tfWidget(q);
    return _shortWidget(q);
  }

  Widget _mcqWidget(Map<String, dynamic> q) {
    final options = (q['options'] as List?) ?? const [];
    final qid = q['id'] as String;
    final selected = _answers[qid] as String?;
    return Column(children: List.generate(options.length, (i) {
      final letter = String.fromCharCode(65 + i);   // A,B,C,D
      final isSel = selected == letter;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _answers[qid] = letter);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSel ? _kGold.withOpacity(0.15) : _kPaper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSel
                  ? _kGold : _kWoodLight.withOpacity(0.3),
                  width: isSel ? 1.5 : 1)),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isSel ? _kGold : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kWoodLight.withOpacity(0.3))),
                child: Center(child: Text(letter,
                    style: TextStyle(fontFamily: 'Alfa',
                        color: isSel ? Colors.white : _kInk,
                        fontSize: 14)))),
              const SizedBox(width: 12),
              Expanded(child: Text(options[i].toString(),
                  style: const TextStyle(fontFamily: 'Momo',
                      fontSize: 13, color: _kInk, height: 1.4))),
              if (isSel)
                const Icon(Icons.check_circle_rounded,
                    color: _kGold, size: 20),
            ]),
          ),
        ),
      );
    }));
  }

  Widget _tfWidget(Map<String, dynamic> q) {
    final qid = q['id'] as String;
    final selected = _answers[qid] as bool?;
    Widget chip(bool value, String label, IconData icon, Color color) {
      final isSel = selected == value;
      return Expanded(child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _answers[qid] = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 22),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isSel ? color : _kPaper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSel
                ? color : _kWoodLight.withOpacity(0.3),
                width: isSel ? 1.5 : 1)),
          child: Column(children: [
            Icon(icon, size: 36,
                color: isSel ? Colors.white : color),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(fontFamily: 'Alfa',
                    fontSize: 16,
                    color: isSel ? Colors.white : _kInk)),
          ]),
        ),
      ));
    }
    return Row(children: [
      chip(true,  'True',  Icons.check_circle_rounded,
           const Color(0xFF43A047)),
      chip(false, 'False', Icons.cancel_rounded,
           const Color(0xFFE53935)),
    ]);
  }

  Widget _shortWidget(Map<String, dynamic> q) {
    final qid = q['id'] as String;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const T('Your answer',
          style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 11, color: _kInkLight)),
      const SizedBox(height: 8),
      TextField(
        controller: _shortCtrl,
        maxLines: 3,
        style: const TextStyle(fontFamily: 'Momo',
            fontSize: 13, color: _kInk, height: 1.5),
        decoration: InputDecoration(
          hintText: TranslationService.I.tr('Type your answer here…'),
          hintStyle: const TextStyle(fontFamily: 'Momo', color: _kInkLight),
          filled: true, fillColor: _kPaper,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _kWoodLight.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kGold, width: 1.5)),
        ),
        onChanged: (v) => _answers[qid] = v.trim(),
      ),
    ]);
  }

  // ─── Footer (prev/next/submit) ──────────────────────────
  Widget _buildFooter() {
    final isLast = _index == _questions.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _kCream,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, -3))]),
      child: SafeArea(top: false,
        child: Row(children: [
          if (_index > 0)
            Expanded(child: OutlinedButton(
              onPressed: _prev,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kWood,
                side: BorderSide(color: _kWoodLight.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(Icons.arrow_back_rounded, size: 16),
                SizedBox(width: 6),
                T('Previous',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ]))),
          if (_index > 0) const SizedBox(width: 10),
          Expanded(flex: _index > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: _hasAnswered ? (isLast ? _submit : _next) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? const Color(0xFF43A047) : _kGold,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kWoodLight.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: _hasAnswered ? 4 : 0,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(isLast ? 'Submit' : 'Next',
                    style: const TextStyle(fontFamily: 'Alfa',
                        fontSize: 14, letterSpacing: 0.3)),
                const SizedBox(width: 6),
                Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 16),
              ]))),
        ]),
      ),
    );
  }

  // ─── Confirm exit ───────────────────────────────────────
  Future<void> _confirmExit() async {
    if (_answers.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        title: const T('Leave the quiz?',
            style: TextStyle(fontFamily: 'Alfa', color: _kInk)),
        content: const T(
            'Your progress will be lost. The quiz itself is saved and you can retake it anytime.',
            style: TextStyle(fontFamily: 'Momo', color: _kInkLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const T('Stay')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const T('Leave')),
        ],
      ),
    ) ?? false;
    if (ok && mounted) Navigator.pop(context);
  }

  // ─── Static helpers ─────────────────────────────────────
  Widget _scaffold(Widget body) =>
      Scaffold(backgroundColor: _kCream, body: SafeArea(child: body));

  Widget _centered(Widget child) =>
      Center(child: Padding(padding: const EdgeInsets.all(32), child: child));

  Widget _loadingBlock() => const Column(mainAxisSize: MainAxisSize.min, children: [
    CircularProgressIndicator(color: _kGold),
    SizedBox(height: 20),
    T('Loading your quiz…',
        style: TextStyle(fontFamily: 'Momo', color: _kInkLight, fontSize: 13)),
  ]);

  Widget _emptyBlock() => Column(mainAxisSize: MainAxisSize.min, children: [
    const T('🤷', style: TextStyle(fontSize: 60)),
    const SizedBox(height: 20),
    const T('No questions in this quiz',
        style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
    const SizedBox(height: 16),
    TextButton(onPressed: () => Navigator.pop(context),
        child: const T('Back')),
  ]);

  Widget _submittingBlock() => const Column(mainAxisSize: MainAxisSize.min, children: [
    CircularProgressIndicator(color: _kGold),
    SizedBox(height: 20),
    T('Grading…',
        style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
  ]);
}