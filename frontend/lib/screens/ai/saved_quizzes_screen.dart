// lib/screens/quiz/saved_quizzes_screen.dart
//
// Browser for all quizzes the user has previously generated.
// Tap a card → retake the quiz.
// Long-press → delete.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/screens/ai/quiz_play_Screen.dart';
import 'package:tcs_app/widgets/ai_spinner.dart';
import 'package:tcs_app/widgets/quiz_share_picker.dart';

import '../../../../services/api_service.dart';

// Quiz palette now blends with the app theme (was a brown bookshelf).
const _kIndigo    = Color(0xFF3F51B5);
const _kDeep      = Color(0xFF512DA8);
Color get _kShelf     => AppC.bg;
Color get _kWood      => AppC.sub;
Color get _kWoodLight => AppC.border;
Color get _kCream     => AppC.card;
Color get _kPaper     => AppC.card2;
const _kGold      = Color(0xFFD4A017);
Color get _kInk => AppC.text;
Color get _kInkLight  => AppC.sub;

class SavedQuizzesScreen extends StatefulWidget {
  const SavedQuizzesScreen({super.key});

  @override
  State<SavedQuizzesScreen> createState() => _SavedQuizzesScreenState();
}

class _SavedQuizzesScreenState extends State<SavedQuizzesScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Quizzes matching the search box (title / subject / difficulty).
  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _quizzes;
    return _quizzes.where((x) {
      final t = (x['title'] as String? ?? '').toLowerCase();
      final s = (x['subject'] as String? ?? '').toLowerCase();
      final d = (x['difficulty'] as String? ?? '').toLowerCase();
      return t.contains(q) || s.contains(q) || d.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/quiz/') as List;
      setState(() {
        _quizzes = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> quiz) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        title: T('Delete this quiz?',
            style: TextStyle(fontFamily: 'Alfa', color: _kInk)),
        content: Text(
            '"${quiz['title']}" and all its attempts will be permanently removed.',
            style: TextStyle(fontFamily: 'Momo', color: _kInkLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const T('Cancel')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const T('Delete')),
        ],
      ),
    ) ?? false;

    if (!ok) return;
    try { await _api.delete('/quiz/${quiz['id']}/'); } catch (_) {}
    setState(() => _quizzes.removeWhere((q) => q['id'] == quiz['id']));
  }

  void _share(Map<String, dynamic> quiz) {
    showQuizSharePicker(
      context,
      quizId: quiz['id'] as String,
      title: quiz['title'] as String? ?? 'Quiz',
      count: (quiz['question_count'] as num?)?.toInt()
          ?? (quiz['num_questions'] as num?)?.toInt() ?? 0,
      difficulty: quiz['difficulty'] as String? ?? '',
    );
  }

  // ── Redo a quiz in another format ──────────────────────────
  String _bumpDifficulty(String d, {required bool up}) {
    const order = ['easy', 'medium', 'hard'];
    var i = order.indexOf(d == 'mixed' ? 'medium' : d);
    if (i < 0) i = 1;
    i = (i + (up ? 1 : -1)).clamp(0, order.length - 1);
    return order[i];
  }

  Future<void> _redo(Map<String, dynamic> quiz) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppC.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(children: [
              T('Redo this quiz',
                  style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 17, color: AppC.text)),
            ]),
          ),
          _redoOption(Icons.replay_rounded, 'Same questions',
              'Retake the exact same quiz', _kIndigo, 'same'),
          _redoOption(Icons.trending_up_rounded, 'Make it harder',
              'New questions, tougher', const Color(0xFFE53935), 'harder'),
          _redoOption(Icons.trending_down_rounded, 'Make it simpler',
              'New questions, easier', const Color(0xFF43A047), 'simpler'),
          _redoOption(Icons.add_circle_outline_rounded, 'More questions',
              'New questions, +5 longer', _kGold, 'more'),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (choice == null || !mounted) return;

    final quizId = quiz['id'] as String;
    final title  = quiz['title'] as String? ?? 'Quiz';

    if (choice == 'same') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizPlayScreen(quizId: quizId, quizTitle: title),
      )).then((_) => _load());
      return;
    }

    final materialId = quiz['material_id'] as String?;
    if (materialId == null || materialId.isEmpty) {
      _snack('The original material was deleted — can\'t regenerate this one.');
      return;
    }

    final difficulty = quiz['difficulty'] as String? ?? 'medium';
    final count = (quiz['num_questions'] as num?)?.toInt()
        ?? (quiz['question_count'] as num?)?.toInt() ?? 10;
    final types = (quiz['question_types'] as List?)?.cast<String>()
        ?? const ['mcq', 'true_false', 'short'];

    var newDiff = difficulty;
    var newNum  = count;
    switch (choice) {
      case 'harder':  newDiff = _bumpDifficulty(difficulty, up: true);  break;
      case 'simpler': newDiff = _bumpDifficulty(difficulty, up: false); break;
      case 'more':    newNum  = (count + 5).clamp(3, 25);               break;
    }

    // Regenerating overlay (the AI call takes a few seconds).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppC.card,
            borderRadius: BorderRadius.circular(20)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            T('🧠', style: TextStyle(fontSize: 40)),
            SizedBox(height: 16),
            AiSpinner(color: _kIndigo),
          ]),
        ),
      ),
    );

    try {
      final newQuiz = await _api.post('/quiz/generate/', body: {
        'material_id':    materialId,
        'subject':        quiz['subject'] ?? '',
        'num_questions':  newNum,
        'difficulty':     newDiff,
        'question_types': types,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss overlay
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          quizId:    newQuiz['id'] as String,
          quizTitle: newQuiz['title'] as String? ?? title,
          preloaded: newQuiz,
        ),
      )).then((_) => _load());
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss overlay
      _snack('Couldn\'t regenerate the quiz. Please try again.');
    }
  }

  Widget _redoOption(IconData icon, String title, String sub, Color color,
      String value) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14, color: AppC.text)),
              const SizedBox(height: 1),
              Text(sub, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11.5, color: AppC.sub)),
            ])),
          Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 20),
        ]),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kIndigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kShelf,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kGold))
                : _quizzes.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kIndigo, _kDeep],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12))),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white70, size: 20))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGold.withOpacity(0.4))),
                child: Text('${_quizzes.length} quizzes',
                    style: const TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: _kGold,
                        fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                T('My Quizzes',
                    style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 28, color: Colors.white,
                        letterSpacing: 0.5)),
                T('AI-generated · retake anytime',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: Colors.white54)),
              ]),
              const Spacer(),
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGold.withOpacity(0.3))),
                child: const Center(child: T('🧠',
                    style: TextStyle(fontSize: 24)))),
            ]),
            const SizedBox(height: 14),
            // Search through saved quizzes.
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18))),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(
                    fontFamily: 'Momo', fontSize: 14, color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search your quizzes…',
                  hintStyle: const TextStyle(
                      fontFamily: 'Momo', fontSize: 13, color: Colors.white60),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          }),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const T('🎓', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          T('No quizzes yet',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 18, color: _kInk)),
          const SizedBox(height: 8),
          Text(
              'Head back to your library and tap\n"Quiz me" on any PDF or DOCX.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 13, color: _kInkLight, height: 1.5)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context),
            child: const T('Back to library',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    return RefreshIndicator(
      color: _kGold, backgroundColor: _kCream, onRefresh: _load,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              children: [
                const SizedBox(height: 80),
                Center(child: Column(children: [
                  Icon(Icons.search_off_rounded, size: 48, color: _kInkLight),
                  const SizedBox(height: 12),
                  Text('No quizzes match "$_query"',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 13, color: _kInkLight)),
                ])),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (_, i) => _QuizCard(
                quiz:     items[i],
                onTap:    () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => QuizPlayScreen(
                    quizId:    items[i]['id'] as String,
                    quizTitle: items[i]['title'] as String? ?? 'Quiz',
                  ),
                )).then((_) => _load()),
                onDelete: () => _delete(items[i]),
                onRedo: () => _redo(items[i]),
                onShare: () => _share(items[i]),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _QuizCard extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRedo;
  final VoidCallback onShare;

  const _QuizCard({
    required this.quiz,
    required this.onTap,
    required this.onDelete,
    required this.onRedo,
    required this.onShare,
  });

  Color _difficultyColor(String d) {
    switch (d) {
      case 'easy':   return const Color(0xFF43A047);
      case 'medium': return _kGold;
      case 'hard':   return const Color(0xFFE53935);
      case 'mixed':  return const Color(0xFF8E24AA);
      default:       return _kWood;
    }
  }

  Color _scoreColor(double pct) {
    if (pct >= 80) return const Color(0xFF43A047);
    if (pct >= 60) return _kGold;
    if (pct >= 40) return const Color(0xFFFB8C00);
    return const Color(0xFFE53935);
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7)   return '${dt.day}/${dt.month}/${dt.year % 100}';
    if (diff.inDays > 0)   return '${diff.inDays}d ago';
    if (diff.inHours > 0)  return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final title       = quiz['title']    as String? ?? 'Untitled quiz';
    final subject     = quiz['subject']  as String? ?? '';
    final difficulty  = quiz['difficulty'] as String? ?? 'medium';
    final qcount      = (quiz['question_count'] as num?)?.toInt() ?? 0;
    final attempts    = (quiz['attempt_count']  as num?)?.toInt() ?? 0;
    final lastScore   = quiz['last_score'] as Map<String, dynamic>?;
    final createdAt   = _formatDate(quiz['created_at'] as String? ?? '');
    final difColor    = _difficultyColor(difficulty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onDelete,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kPaper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kWoodLight.withOpacity(0.3)),
            boxShadow: [BoxShadow(
              color: _kWood.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Quiz icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [difColor, difColor.withOpacity(0.7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12)),
              child: const Center(child: T('🧠',
                  style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13, color: _kInk, height: 1.3)),
              const SizedBox(height: 6),

              Wrap(spacing: 5, runSpacing: 5, children: [
                if (subject.isNotEmpty) _pill('📘', subject, _kWood),
                _pill('📊', difficulty[0].toUpperCase() + difficulty.substring(1),
                      difColor),
                _pill('❓', '$qcount Qs', _kInkLight),
              ]),
              const SizedBox(height: 8),

              Row(children: [
                if (lastScore != null) ...[
                  Icon(Icons.emoji_events_rounded, size: 11,
                      color: _scoreColor((lastScore['percentage'] as num?)?.toDouble() ?? 0)),
                  const SizedBox(width: 3),
                  Text(
                    '${(lastScore['percentage'] as num?)?.toStringAsFixed(0) ?? 0}% '
                        '(${lastScore['score']}/${lastScore['total']})',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10,
                        color: _scoreColor((lastScore['percentage'] as num?)?.toDouble() ?? 0),
                        fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('· $attempts attempts',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 10, color: _kInkLight)),
                ] else
                  T('Not attempted yet',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 10, color: _kInkLight,
                          fontStyle: FontStyle.italic)),
                const Spacer(),
                Text(createdAt,
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: _kInkLight)),
              ]),
            ])),

            const SizedBox(width: 6),
            Column(mainAxisSize: MainAxisSize.min, children: [
              // Share this quiz to a chat / study group.
              GestureDetector(
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kIndigo.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.ios_share_rounded,
                      color: _kIndigo, size: 17)),
              ),
              const SizedBox(height: 6),
              // Redo this quiz in another format.
              GestureDetector(
                onTap: onRedo,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kIndigo.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.refresh_rounded,
                      color: _kIndigo, size: 17)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 9)),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 9, color: color,
                  fontWeight: FontWeight.bold))),
      ]),
    );
  }
}