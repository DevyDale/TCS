// lib/screens/quiz/saved_quizzes_screen.dart
//
// Browser for all quizzes the user has previously generated.
// Tap a card → retake the quiz.
// Long-press → delete.

import 'package:flutter/material.dart';
import 'package:tcs_app/quiz_play_Screen.dart';

import '../../services/api_service.dart';

const _kShelf     = Color(0xFF2C1810);
const _kWood      = Color(0xFF5C3317);
const _kWoodLight = Color(0xFF8B5E3C);
const _kCream     = Color(0xFFFDF6EC);
const _kPaper     = Color(0xFFF5ECD7);
const _kGold      = Color(0xFFD4A017);
const _kInk       = Color(0xFF1A1209);
const _kInkLight  = Color(0xFF4A3728);

class SavedQuizzesScreen extends StatefulWidget {
  const SavedQuizzesScreen({super.key});

  @override
  State<SavedQuizzesScreen> createState() => _SavedQuizzesScreenState();
}

class _SavedQuizzesScreenState extends State<SavedQuizzesScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
        title: const Text('Delete this quiz?',
            style: TextStyle(fontFamily: 'Alfa', color: _kInk)),
        content: Text(
            '"${quiz['title']}" and all its attempts will be permanently removed.',
            style: const TextStyle(fontFamily: 'Momo', color: _kInkLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    ) ?? false;

    if (!ok) return;
    try { await _api.delete('/quiz/${quiz['id']}/'); } catch (_) {}
    setState(() => _quizzes.removeWhere((q) => q['id'] == quiz['id']));
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
            decoration: const BoxDecoration(
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
          colors: [Color(0xFF1A0E09), _kShelf, _kWood],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)),
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
                Text('My Quizzes',
                    style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 28, color: Colors.white,
                        letterSpacing: 0.5)),
                Text('AI-generated · retake anytime',
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
                child: const Center(child: Text('🧠',
                    style: TextStyle(fontSize: 24)))),
            ]),
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
          const Text('🎓', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No quizzes yet',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 18, color: _kInk)),
          const SizedBox(height: 8),
          const Text(
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
            child: const Text('Back to library',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: _kGold, backgroundColor: _kCream, onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        physics: const BouncingScrollPhysics(),
        itemCount: _quizzes.length,
        itemBuilder: (_, i) => _QuizCard(
          quiz:     _quizzes[i],
          onTap:    () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuizPlayScreen(
              quizId:    _quizzes[i]['id'] as String,
              quizTitle: _quizzes[i]['title'] as String? ?? 'Quiz',
            ),
          )).then((_) => _load()),
          onDelete: () => _delete(_quizzes[i]),
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

  const _QuizCard({
    required this.quiz,
    required this.onTap,
    required this.onDelete,
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
              child: const Center(child: Text('🧠',
                  style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
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
                      style: const TextStyle(fontFamily: 'Momo',
                          fontSize: 10, color: _kInkLight)),
                ] else
                  const Text('Not attempted yet',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 10, color: _kInkLight,
                          fontStyle: FontStyle.italic)),
                const Spacer(),
                Text(createdAt,
                    style: const TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: _kInkLight)),
              ]),
            ])),

            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: _kWood, size: 22),
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