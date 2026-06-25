// lib/screens/quiz/quiz_generator_screen.dart
//
// Wizard for creating an AI-generated quiz from a saved material.
//
// Three steps in one scrollable form:
//   1. Pick the material  (only PDFs and DOCXs are quiz-compatible)
//   2. Subject            (auto-filled from material; user can override)
//   3. Quiz settings      (count, difficulty, question types)
//
// Tap "Generate quiz" → backend extracts text from the file, calls OpenAI,
// returns a quiz, then we push the play screen.

import 'package:flutter/material.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/ai/quiz_play_Screen.dart';

import '../../../../services/api_service.dart';

// Library palette (matches saved materials screen)
const _kShelf     = Color(0xFF2C1810);
const _kWood      = Color(0xFF5C3317);
const _kWoodLight = Color(0xFF8B5E3C);
const _kCream     = Color(0xFFFDF6EC);
const _kPaper     = Color(0xFFF5ECD7);
const _kGold      = Color(0xFFD4A017);
const _kInk       = Color(0xFF1A1209);
const _kInkLight  = Color(0xFF4A3728);

class QuizGeneratorScreen extends StatefulWidget {
  /// Full saved-materials list, so we can offer a picker.
  final List<Map<String, dynamic>> materials;

  /// If launched from a single material's "Quiz me" button, pre-select it.
  final Map<String, dynamic>? initialMaterial;

  const QuizGeneratorScreen({
    super.key,
    required this.materials,
    this.initialMaterial,
  });

  @override
  State<QuizGeneratorScreen> createState() => _QuizGeneratorScreenState();
}

class _QuizGeneratorScreenState extends State<QuizGeneratorScreen> {
  final _api          = ApiService();
  final _subjectCtrl  = TextEditingController();

  Map<String, dynamic>? _selected;
  int      _count       = 10;
  String   _difficulty  = 'medium';
  final Set<String> _types = {'mcq', 'true_false', 'short'};

  bool   _generating = false;
  String _statusLine = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialMaterial != null && _isQuizable(widget.initialMaterial!)) {
      _selected = widget.initialMaterial;
      _subjectCtrl.text = (widget.initialMaterial!['subject'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────
  bool _isQuizable(Map<String, dynamic> m) {
    final ft = (m['file_type'] as String? ?? '').toLowerCase();
    final fn = (m['file_name'] as String? ?? '').toLowerCase();
    return ft.contains('pdf') || ft.contains('doc') || ft.contains('word')
        || fn.endsWith('.pdf') || fn.endsWith('.docx');
  }

  List<Map<String, dynamic>> get _quizable =>
      widget.materials.where(_isQuizable).toList();

  Future<void> _generate() async {
    if (_selected == null) return;
    if (_types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: T('Pick at least one question type.')));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _generating = true;
      _statusLine = 'Reading your material…';
    });

    // Tiny progress narrative — purely cosmetic, since the actual work
    // happens server-side in one round trip.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _generating) {
        setState(() => _statusLine = 'Asking the AI to write questions…');
      }
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _generating) {
        setState(() => _statusLine = 'Almost there…');
      }
    });

    try {
      final quiz = await _api.post('/quiz/generate/', body: {
        'material_id':    _selected!['id'],
        'subject':        _subjectCtrl.text.trim(),
        'num_questions':  _count,
        'difficulty':     _difficulty,
        'question_types': _types.toList(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => QuizPlayScreen(
                quizId: quiz['id'] as String,
                quizTitle: quiz['title'] as String? ?? 'Quiz',
                preloaded: quiz as Map<String, dynamic>,
              )));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _statusLine = '';
      });
      // Try to extract a friendly error message
      String msg = 'Couldn\'t generate the quiz. Please try again.';
      final s = e.toString();
      final match = RegExp(r'"error":\s*"([^"]+)"').firstMatch(s);
      if (match != null) msg = match.group(1) ?? msg;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_generating) return _buildLoading();

    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _stepLabel('1', 'Choose your material'),
                const SizedBox(height: 12),
                _buildMaterialPicker(),
                const SizedBox(height: 28),

                _stepLabel('2', 'Subject'),
                const SizedBox(height: 8),
                T(
                    'Helps the AI focus on the right vocabulary. Auto-filled when we know the source group.',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 11, color: _kInkLight)),
                const SizedBox(height: 10),
                _buildSubjectField(),
                const SizedBox(height: 28),

                _stepLabel('3', 'Quiz settings'),
                const SizedBox(height: 12),
                _buildSettingsCard(),
              ],
            ),
          ),
          _buildFooter(),
        ]),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kShelf, _kWood],
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.withOpacity(0.12))),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white70, size: 20))),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          T('AI Quiz Generator',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 20, color: Colors.white)),
          T('Turn any saved material into an interactive quiz',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11, color: Colors.white60)),
        ])),
        const T('🧠', style: TextStyle(fontSize: 26)),
      ]),
    );
  }

  Widget _stepLabel(String n, String label) => Row(children: [
    Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kGold, Color(0xFFB8870E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(n,
          style: const TextStyle(fontFamily: 'Alfa',
              color: Colors.white, fontSize: 14)))),
    const SizedBox(width: 10),
    Text(label,
        style: const TextStyle(fontFamily: 'Alfa',
            fontSize: 16, color: _kInk)),
  ]);

  // ─── 1. Material picker ─────────────────────────────────
  Widget _buildMaterialPicker() {
    if (_quizable.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kPaper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kWoodLight.withOpacity(0.3))),
        child: Column(children: [
          const T('📭', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const T('No quiz-compatible materials',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 14, color: _kInk)),
          const SizedBox(height: 4),
          T('Save a PDF or DOCX in your library first.',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11, color: _kInkLight)),
        ]),
      );
    }

    if (_selected != null) {
      return _selectedMaterialCard();
    }

    return Column(children: _quizable.map((m) {
      final type = ((m['file_type'] as String?) ?? '').toLowerCase().contains('pdf')
          ? 'PDF' : 'DOC';
      final color = type == 'PDF'
          ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selected = m;
            _subjectCtrl.text = (m['subject'] as String?) ?? '';
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPaper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kWoodLight.withOpacity(0.3))),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    type == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                    color: color, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m['title'] as String? ?? 'Untitled',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 13, color: _kInk)),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((m['subject'] as String?)?.isNotEmpty ?? false) m['subject'],
                    if ((m['source_group_name'] as String?)?.isNotEmpty ?? false)
                      m['source_group_name'],
                  ].whereType<String>().join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Momo',
                      fontSize: 10, color: _kInkLight)),
              ])),
              const Icon(Icons.chevron_right_rounded,
                  color: _kWood, size: 20),
            ]),
          ),
        ),
      );
    }).toList());
  }

  Widget _selectedMaterialCard() {
    final m = _selected!;
    final type = ((m['file_type'] as String?) ?? '').toLowerCase().contains('pdf')
        ? 'PDF' : 'DOC';
    final color = type == 'PDF'
        ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.12), _kPaper],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(
              type == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
              color: Colors.white, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['title'] as String? ?? 'Untitled',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 14, color: _kInk)),
          const SizedBox(height: 2),
          Text(m['file_name'] as String? ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Momo',
                  fontSize: 10, color: _kInkLight)),
        ])),
        IconButton(
            tooltip: TranslationService.I.tr('Change'),
            onPressed: () => setState(() => _selected = null),
            icon: const Icon(Icons.swap_horiz_rounded, color: _kWood)),
      ]),
    );
  }

  // ─── 2. Subject ─────────────────────────────────────────
  Widget _buildSubjectField() {
    return TextField(
      controller: _subjectCtrl,
      style: const TextStyle(fontFamily: 'Momo',
          fontSize: 14, color: _kInk),
      decoration: InputDecoration(
        hintText: TranslationService.I.tr('e.g. Mathematics, Biology, Programming…'),
        hintStyle: const TextStyle(fontFamily: 'Momo',
            color: _kInkLight, fontSize: 13),
        filled: true, fillColor: _kPaper,
        prefixIcon: const Icon(Icons.subject_rounded, color: _kWood),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kWoodLight.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGold, width: 1.5)),
      ),
    );
  }

  // ─── 3. Settings ────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kWoodLight.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Number of questions
        const T('Number of questions',
            style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12, color: _kInk)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _kGold,
                inactiveTrackColor: _kWoodLight.withOpacity(0.2),
                thumbColor: _kGold,
                overlayColor: _kGold.withOpacity(0.15),
                valueIndicatorColor: _kWood,
              ),
              child: Slider(
                value: _count.toDouble(),
                min: 3, max: 25,
                divisions: 22,
                label: '$_count',
                onChanged: (v) => setState(() => _count = v.round()),
              ))),
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: _kGold,
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$_count',
                style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 14, color: Colors.white)))),
        ]),

        const SizedBox(height: 18),
        const T('Difficulty',
            style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12, color: _kInk)),
        const SizedBox(height: 8),
        Row(children: [
          for (final d in ['easy', 'medium', 'hard', 'mixed'])
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _difficultyChip(d),
            )),
        ]),

        const SizedBox(height: 18),
        const T('Question types',
            style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12, color: _kInk)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _typeChip('mcq',         'Multiple choice', '🅰️'),
          _typeChip('true_false',  'True / False',    '✅'),
          _typeChip('short',       'Short answer',    '✍️'),
        ]),
      ]),
    );
  }

  Widget _difficultyChip(String d) {
    final selected = _difficulty == d;
    return GestureDetector(
      onTap: () => setState(() => _difficulty = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _kGold : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected
              ? _kGold : _kWoodLight.withOpacity(0.3))),
        child: Center(child: Text(d[0].toUpperCase() + d.substring(1),
            style: TextStyle(fontFamily: 'Arch',
                fontSize: 11, fontWeight: FontWeight.bold,
                color: selected ? Colors.white : _kInk))),
      ),
    );
  }

  Widget _typeChip(String key, String label, String emoji) {
    final selected = _types.contains(key);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _types.remove(key);
        } else {
          _types.add(key);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kGold.withOpacity(0.18) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected
              ? _kGold : _kWoodLight.withOpacity(0.3),
              width: selected ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontFamily: 'Arch',
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: selected ? _kWood : _kInk)),
          if (selected) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded, size: 13, color: _kGold),
          ],
        ]),
      ),
    );
  }

  // ─── Footer (Generate button) ───────────────────────────
  Widget _buildFooter() {
    final canGenerate = _selected != null && _types.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _kCream,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
            blurRadius: 10, offset: const Offset(0, -3))]),
      child: SafeArea(top: false,
        child: ElevatedButton(
          onPressed: canGenerate ? _generate : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGold,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kWoodLight.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: canGenerate ? 4 : 0,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome_rounded, size: 18),
            const SizedBox(width: 8),
            Text(canGenerate ? 'Generate quiz' : 'Pick a material to continue',
                style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 15, letterSpacing: 0.3)),
          ]),
        ),
      ),
    );
  }

  // ─── Loading screen ─────────────────────────────────────
  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: _kCream,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const T('🧠', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 28),
              const SizedBox(
                width: 36, height: 36,
                child: CircularProgressIndicator(
                    color: _kGold, strokeWidth: 3)),
              const SizedBox(height: 28),
              const T('Generating your quiz',
                  style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 22, color: _kInk)),
              const SizedBox(height: 10),
              SizedBox(
                width: 260,
                child: Text(_statusLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Momo',
                        fontSize: 13, color: _kInkLight, height: 1.5))),
            ]),
          ),
        ),
      ),
    );
  }
}