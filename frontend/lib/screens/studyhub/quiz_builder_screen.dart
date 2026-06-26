// lib/screens/studyhub/quiz_builder_screen.dart
//
// Teacher quiz builder (spec §4). Two ways in: write questions by hand, or let
// Dale draft an MCQ set from a topic. AI output lands as an EDITABLE DRAFT — the
// teacher is the accuracy gate, nothing publishes until they review and save.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class _QDraft {
  final textC = TextEditingController();
  final opts = List.generate(4, (_) => TextEditingController());
  final explC = TextEditingController();
  int correct = 0;
  _QDraft();
  void dispose() {
    textC.dispose(); explC.dispose();
    for (final c in opts) { c.dispose(); }
  }
  Map<String, dynamic> toJson(int order) => {
        'text': textC.text.trim(),
        'options': opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
        'correct_index': correct,
        'explanation': explC.text.trim(),
        'order': order,
      };
}

class QuizBuilderScreen extends StatefulWidget {
  const QuizBuilderScreen({super.key});

  @override
  State<QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends State<QuizBuilderScreen> {
  final _api = ApiService();
  final _titleC = TextEditingController();
  final _subjectC = TextEditingController();
  final List<_QDraft> _qs = [];
  bool _saving = false, _generating = false;
  String _source = 'manual';

  @override
  void initState() {
    super.initState();
    _qs.add(_QDraft());
  }

  @override
  void dispose() {
    _titleC.dispose(); _subjectC.dispose();
    for (final q in _qs) { q.dispose(); }
    super.dispose();
  }

  void _addQuestion() => setState(() => _qs.add(_QDraft()));
  void _removeQuestion(int i) {
    if (_qs.length == 1) return;
    setState(() { _qs.removeAt(i).dispose(); });
  }

  Future<void> _save({required bool publish}) async {
    final title = _titleC.text.trim();
    final subject = _subjectC.text.trim();
    if (title.isEmpty || subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and subject are required.')));
      return;
    }
    final questions = <Map<String, dynamic>>[];
    for (var i = 0; i < _qs.length; i++) {
      final j = _qs[i].toJson(i);
      if ((j['text'] as String).isEmpty || (j['options'] as List).length < 2) continue;
      questions.add(j);
    }
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one question with 2+ options.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _api.saveQuiz(
          title: title, subject: subject, questions: questions, source: _source) as Map;
      if (publish) {
        await _api.publishQuiz(saved['id'].toString());
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(publish ? 'Quiz published to students.'
              : 'Saved as a draft.')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  // ── Dale generate ─────────────────────────────────────────────────────
  void _showGenerateSheet() {
    final topicC = TextEditingController();
    int count = 5;
    String difficulty = 'medium';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> go() async {
          if (topicC.text.trim().isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Give Dale a topic.')));
            return;
          }
          Navigator.pop(ctx);
          await _generate(topicC.text.trim(), count, difficulty);
        }
        return Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppC.faint,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: kStaffG1, size: 20),
              const SizedBox(width: 8),
              Text('Generate with Dale',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: AppC.text)),
            ]),
            const SizedBox(height: 6),
            Text('Dale drafts an MCQ set you can edit before publishing.',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, color: AppC.sub)),
            const SizedBox(height: 14),
            TextField(controller: topicC,
              style: TextStyle(fontFamily: 'Momo', color: AppC.text),
              decoration: InputDecoration(
                hintText: 'Topic (e.g. photosynthesis, the French Revolution)',
                filled: true, fillColor: AppC.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Row(children: [
              Text('Questions', style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                  fontWeight: FontWeight.bold, color: AppC.sub)),
              const Spacer(),
              ...[3, 5, 8, 10].map((n) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                    label: Text('$n'), selected: count == n,
                    selectedColor: kStaffG1.withValues(alpha: 0.18),
                    onSelected: (_) => setSheet(() => count = n)))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text('Difficulty', style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                  fontWeight: FontWeight.bold, color: AppC.sub)),
              const Spacer(),
              ...['easy', 'medium', 'hard'].map((d) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                    label: Text(d), selected: difficulty == d,
                    selectedColor: kStaffG1.withValues(alpha: 0.18),
                    onSelected: (_) => setSheet(() => difficulty = d)))),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: go,
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kStaffG1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                label: const Text('Draft it',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, color: Colors.white)))),
          ]),
        );
      }),
    );
  }

  Future<void> _generate(String topic, int count, String difficulty) async {
    setState(() => _generating = true);
    try {
      final d = await _api.generateStudyQuiz(
          topic: topic, subject: _subjectC.text.trim(),
          count: count, difficulty: difficulty) as Map;
      final drafts = (d['questions'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (drafts.isEmpty) throw 'Dale returned no questions.';
      // Replace the working set with editable drafts.
      for (final q in _qs) { q.dispose(); }
      _qs.clear();
      for (final dq in drafts) {
        final qd = _QDraft();
        qd.textC.text = dq['text']?.toString() ?? '';
        final opts = (dq['options'] as List? ?? []).map((e) => e.toString()).toList();
        for (var i = 0; i < qd.opts.length; i++) {
          qd.opts[i].text = i < opts.length ? opts[i] : '';
        }
        qd.correct = (dq['correct_index'] as int? ?? 0).clamp(0, 3);
        qd.explC.text = dq['explanation']?.toString() ?? '';
        _qs.add(qd);
      }
      if (_subjectC.text.trim().isEmpty && (d['subject'] ?? '').toString().isNotEmpty) {
        _subjectC.text = d['subject'].toString();
      }
      if (_titleC.text.trim().isEmpty) _titleC.text = topic;
      _source = 'ai';
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Draft ready — review every answer before publishing.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      appBar: AppBar(
        backgroundColor: kStaffG1, foregroundColor: Colors.white,
        title: const Text('Build a quiz',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Generate with Dale',
            onPressed: _generating ? null : _showGenerateSheet,
            icon: const Icon(Icons.auto_awesome_rounded)),
        ],
      ),
      body: _generating
          ? _generatingView()
          : ListView(padding: const EdgeInsets.all(14), children: [
              if (_source == 'ai') _draftBanner(),
              _field(_titleC, 'Quiz title', Icons.title_rounded),
              const SizedBox(height: 10),
              _field(_subjectC, 'Subject (e.g. Year 12 Biology)', Icons.school_rounded),
              const SizedBox(height: 16),
              for (var i = 0; i < _qs.length; i++) _qEditor(i),
              OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                    foregroundColor: kStaffG1,
                    minimumSize: const Size.fromHeight(48)),
                label: const Text('Add question')),
              const SizedBox(height: 80),
            ]),
      bottomNavigationBar: _generating ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _saving ? null : () => _save(publish: false),
              style: OutlinedButton.styleFrom(
                  foregroundColor: kStaffG1,
                  minimumSize: const Size.fromHeight(50)),
              child: const Text('Save draft', style: TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold)))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: _saving ? null : () => _save(publish: true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kStaffG1,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publish', style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, color: Colors.white)))),
          ]),
        ),
      ),
    );
  }

  Widget _draftBanner() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
              'AI draft — check every question and correct answer before you publish. '
              'Dale can be confidently wrong.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                  height: 1.35, color: AppC.text))),
        ]),
      );

  Widget _generatingView() => Center(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: kStaffG1),
          const SizedBox(height: 18),
          Text('Dale is drafting your quiz…',
              style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                  fontWeight: FontWeight.bold, color: AppC.text)),
          const SizedBox(height: 4),
          Text('You’ll review it before anything publishes.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11.5, color: AppC.sub)),
        ]));

  Widget _qEditor(int i) {
    final q = _qs[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Question ${i + 1}', style: TextStyle(fontFamily: 'Arch',
              fontSize: 12, fontWeight: FontWeight.bold, color: kStaffG1)),
          const Spacer(),
          if (_qs.length > 1)
            GestureDetector(
              onTap: () => _removeQuestion(i),
              child: Icon(Icons.delete_outline_rounded,
                  size: 19, color: AppC.faint)),
        ]),
        const SizedBox(height: 8),
        TextField(controller: q.textC, maxLines: null,
          style: TextStyle(fontFamily: 'Arch', fontSize: 14, color: AppC.text),
          decoration: InputDecoration(
            hintText: 'Question text',
            filled: true, fillColor: AppC.bg, isDense: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        const SizedBox(height: 10),
        Text('Tap the circle to mark the correct answer',
            style: TextStyle(fontFamily: 'Momo', fontSize: 10.5, color: AppC.faint)),
        const SizedBox(height: 6),
        ...List.generate(q.opts.length, (oi) {
          final correct = q.correct == oi;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => q.correct = oi),
                child: Icon(correct
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                    color: correct ? const Color(0xFF16A34A) : AppC.faint, size: 22)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: q.opts[oi],
                style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.text),
                decoration: InputDecoration(
                  hintText: 'Option ${String.fromCharCode(65 + oi)}',
                  filled: true, fillColor: AppC.bg, isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none)))),
            ]),
          );
        }),
        const SizedBox(height: 4),
        TextField(controller: q.explC,
          style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.text),
          decoration: InputDecoration(
            hintText: 'Explanation (optional, shown after submit)',
            filled: true, fillColor: AppC.bg, isDense: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) => TextField(
        controller: c,
        style: TextStyle(fontFamily: 'Momo', color: AppC.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppC.faint, size: 20),
          filled: true, fillColor: AppC.card,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}
