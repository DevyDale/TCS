// lib/screens/studyhub/quizzes_screen.dart
//
// Quiz hub. Teachers see their own quizzes (drafts + published) with a build
// FAB, publish toggle and analytics; students see published quizzes to attempt.
// `isTeacher` switches the lens (spec §4).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';
import 'package:tcs_app/services/saved_quizzes.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/studyhub/quiz_builder_screen.dart';
import 'package:tcs_app/screens/studyhub/quiz_take_screen.dart';

class QuizzesScreen extends StatefulWidget {
  final bool isTeacher;
  const QuizzesScreen({super.key, required this.isTeacher});

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  bool _savedOnly = false;
  Set<String> _savedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    if (!widget.isTeacher) {
      SavedQuizzes.ids().then((s) { if (mounted) setState(() => _savedIds = s); });
    }
  }

  List<Map<String, dynamic>> get _visible => (_savedOnly && !widget.isTeacher)
      ? _items.where((q) => _savedIds.contains(q['id'].toString())).toList()
      : _items;

  String get _quizKey =>
      'quizzes:${widget.isTeacher ? 'teacher' : 'student'}';

  void _applyQuizzes(dynamic data) {
    if (!mounted) return;
    final list = ((data as Map)['results'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList();
    setState(() { _items = list; _loading = false; });
  }

  // Cache-first: paints the last-known list instantly (memory → disk), then
  // revalidates in the background. A spinner shows only on the first-ever load.
  void _load() {
    CacheStore.I.swr(
      _quizKey,
      fetch: () => _api.listQuizzes(mine: widget.isTeacher),
      onData: (data, _) => _applyQuizzes(data),
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  // Awaitable network refresh — pull-to-refresh and after mutations.
  Future<void> _refresh() async {
    try {
      final data = await _api.listQuizzes(mine: widget.isTeacher);
      await CacheStore.I.put(_quizKey, data);
      _applyQuizzes(data);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _build() async {
    final made = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const QuizBuilderScreen()));
    if (made == true) _refresh();
  }

  Future<void> _take(Map<String, dynamic> q) async {
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuizTakeScreen(quizId: q['id'].toString())));
    _refresh();
  }

  Future<void> _togglePublish(Map<String, dynamic> q) async {
    HapticFeedback.selectionClick();
    try { await _api.publishQuiz(q['id'].toString()); _refresh(); }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> q) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete quiz?'),
      content: Text('“${q['title']}” and its attempts will be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626)))),
      ]));
    if (ok != true) return;
    try { await _api.deleteStudyQuiz(q['id'].toString()); _refresh(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              backgroundColor: kStaffG1,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Build',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      color: Colors.white)),
              onPressed: _build)
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh, color: kStaffG1,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: StaffHeader(
              horizontal: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 38, height: 38, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20))),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Quizzes', style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 23, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(widget.isTeacher
                        ? 'Build, review & publish · see how they land'
                        : 'Practice quizzes from your teachers',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )),
                if (widget.isTeacher)
                  const Icon(Icons.quiz_rounded, color: Colors.white, size: 26)
                else
                  GestureDetector(
                    onTap: () async {
                      // Refresh saved ids each time so the filter is current.
                      final s = await SavedQuizzes.ids();
                      if (!mounted) return;
                      setState(() { _savedIds = s; _savedOnly = !_savedOnly; });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: _savedOnly ? 0.9 : 0.18),
                        borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_savedOnly ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                            color: _savedOnly ? kStaffG1 : Colors.white, size: 16),
                        const SizedBox(width: 5),
                        Text('Saved', style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, fontSize: 11.5,
                            color: _savedOnly ? kStaffG1 : Colors.white)),
                      ]),
                    ),
                  ),
              ]),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else if (_visible.isEmpty)
              SliverFillRemaining(hasScrollBody: false,
                  child: staffNoResults(widget.isTeacher
                      ? 'No quizzes yet — tap Build to make one.'
                      : _savedOnly
                          ? 'No saved quizzes yet — tap the bookmark on a quiz to save it.'
                          : 'No quizzes published yet.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => widget.isTeacher ? _teacherRow(_visible[i]) : _studentRow(_visible[i]),
                  childCount: _visible.length,
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> q) {
    return GestureDetector(
      onTap: () => _take(q),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: staffCard(),
        child: Row(children: [
          Container(width: 46, height: 46, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kStaffG1.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.quiz_rounded, color: kStaffG1, size: 23)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(q['title']?.toString() ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 14.5, color: AppC.text)),
              const SizedBox(height: 2),
              Text('${q['subject']}  ·  ${q['question_count']} questions  ·  ${q['owner']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
            ],
          )),
          if ((q['xp_reward'] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text('+${q['xp_reward']}',
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 11,
                      fontWeight: FontWeight.bold, color: Color(0xFFD97706)))),
        ]),
      ),
    );
  }

  Widget _teacherRow(Map<String, dynamic> q) {
    final published = q['is_published'] == true;
    final isAi = q['source'] == 'ai';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(q['title']?.toString() ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14.5, color: AppC.text))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (published ? const Color(0xFF16A34A) : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text(published ? 'Published' : 'Draft',
                style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: published ? const Color(0xFF16A34A) : const Color(0xFFD97706)))),
        ]),
        const SizedBox(height: 4),
        Text('${q['subject']}  ·  ${q['question_count']} questions'
            '${isAi ? "  ·  AI-drafted" : ""}',
            style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
        const Divider(height: 18),
        Row(children: [
          _action(Icons.visibility_rounded, 'Preview', () => _take(q)),
          _action(Icons.insights_rounded, 'Analytics', () => _showAnalytics(q)),
          const Spacer(),
          _action(published ? Icons.unpublished_rounded : Icons.publish_rounded,
              published ? 'Unpublish' : 'Publish', () => _togglePublish(q),
              color: published ? AppC.sub : const Color(0xFF16A34A)),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, size: 19, color: AppC.faint),
            onPressed: () => _delete(q)),
        ]),
      ]),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? kStaffG1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 11.5,
              fontWeight: FontWeight.bold, color: c)),
        ]),
      ),
    );
  }

  // ── Analytics sheet ───────────────────────────────────────────────────
  Future<void> _showAnalytics(Map<String, dynamic> q) async {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4,
        builder: (ctx, scroll) => FutureBuilder(
          future: _api.quizAnalytics(q['id'].toString()),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: kStaffG1)));
            }
            final d = (snap.data as Map).cast<String, dynamic>();
            final hardest = (d['hardest'] as List? ?? [])
                .map((e) => (e as Map).cast<String, dynamic>()).toList();
            return ListView(controller: scroll, padding: const EdgeInsets.all(18),
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppC.faint,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text(q['title']?.toString() ?? '',
                    style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: AppC.text)),
                const SizedBox(height: 14),
                Row(children: [
                  _stat('${d['attempts'] ?? 0}', 'attempts'),
                  const SizedBox(width: 10),
                  _stat('${d['average_score'] ?? 0}%', 'avg score'),
                  const SizedBox(width: 10),
                  _stat('${d['question_count'] ?? 0}', 'questions'),
                ]),
                const SizedBox(height: 18),
                if ((d['attempts'] ?? 0) == 0)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No attempts yet.',
                        style: TextStyle(fontFamily: 'Momo', color: AppC.sub))))
                else ...[
                  Text('Hardest questions',
                      style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                          fontWeight: FontWeight.bold, color: AppC.text)),
                  const SizedBox(height: 8),
                  ...hardest.map((h) => _hardRow(h)),
                ],
                const SizedBox(height: 20),
              ]);
          },
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppC.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(value, style: const TextStyle(fontFamily: 'Alfa', fontSize: 20,
                color: kStaffG1)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                color: AppC.sub)),
          ]),
        ),
      );

  Widget _hardRow(Map<String, dynamic> h) {
    final rate = h['miss_rate'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppC.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(h['text']?.toString() ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.text)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100, minHeight: 6,
              backgroundColor: AppC.border,
              valueColor: AlwaysStoppedAnimation(
                  rate >= 50 ? const Color(0xFFDC2626) : const Color(0xFFF59E0B))))),
          const SizedBox(width: 8),
          Text('$rate% missed', style: TextStyle(fontFamily: 'Arch', fontSize: 10.5,
              fontWeight: FontWeight.bold, color: AppC.sub)),
        ]),
      ]),
    );
  }
}
