// lib/screens/studyhub/qa_board_screen.dart
//
// Shared Study-Hub surface (spec §3C): students post academic questions tagged
// by subject; teachers and peers answer; upvote; mark-resolved; teacher answers
// carry a badge so the cohort sees the authoritative reply. `isTeacher` lets a
// teacher's answer be badged and gives them resolve/accept rights on any thread.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class QaBoardScreen extends StatefulWidget {
  final bool isTeacher;
  const QaBoardScreen({super.key, required this.isTeacher});

  @override
  State<QaBoardScreen> createState() => _QaBoardScreenState();
}

class _QaBoardScreenState extends State<QaBoardScreen> {
  final _api = ApiService();
  bool _loading = true;
  String _filter = 'open';   // open | resolved | all
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.studyQuestions(
          status: _filter == 'all' ? null : _filter) as Map;
      final list = (d['results'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kStaffG1,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ask',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.white)),
        onPressed: _showAskSheet),
      body: RefreshIndicator(
        onRefresh: _load, color: kStaffG1,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: StaffHeader(
              horizontal: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _back(),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Q&A Board',
                        style: TextStyle(fontFamily: 'Alfa', fontSize: 23,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(widget.isTeacher
                        ? 'Answer once — the whole cohort sees it'
                        : 'Ask a question, get help from teachers & peers',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )),
                const Icon(Icons.forum_rounded, color: Colors.white, size: 26),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(children: [
                _chip('Open', 'open'),
                const SizedBox(width: 8),
                _chip('Resolved', 'resolved'),
                const SizedBox(width: 8),
                _chip('All', 'all'),
              ]),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else if (_items.isEmpty)
              SliverFillRemaining(hasScrollBody: false,
                  child: staffNoResults('No questions here yet.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _row(_items[i]),
                  childCount: _items.length,
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _back() => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      );

  Widget _chip(String label, String value) {
    final on = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? kStaffG1 : AppC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? kStaffG1 : AppC.border)),
        child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
            fontWeight: FontWeight.bold,
            color: on ? Colors.white : AppC.sub)),
      ),
    );
  }

  Widget _row(Map<String, dynamic> q) {
    final resolved = q['status'] == 'resolved';
    return GestureDetector(
      onTap: () => _openThread(q),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: staffCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kStaffG1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Text(q['subject']?.toString() ?? '',
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 10,
                      fontWeight: FontWeight.bold, color: kStaffG1))),
            const Spacer(),
            if (resolved)
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                SizedBox(width: 3),
                Text('Resolved', style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                    fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ]),
          ]),
          const SizedBox(height: 8),
          Text(q['title']?.toString() ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14.5, color: AppC.text)),
          if ((q['body'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(q['body'].toString(),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.person_rounded, size: 13, color: AppC.faint),
            const SizedBox(width: 3),
            Text(q['asker']?.toString() ?? '',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.faint)),
            const SizedBox(width: 14),
            Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppC.faint),
            const SizedBox(width: 3),
            Text('${q['answer_count'] ?? 0}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.faint)),
            const SizedBox(width: 14),
            Icon(Icons.arrow_upward_rounded, size: 13, color: AppC.faint),
            const SizedBox(width: 3),
            Text('${q['upvotes'] ?? 0}',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.faint)),
          ]),
        ]),
      ),
    );
  }

  void _openThread(Map<String, dynamic> q) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ThreadScreen(
          api: _api, questionId: q['id'].toString(), isTeacher: widget.isTeacher),
    )).then((_) => _load());
  }

  // ── Ask sheet ─────────────────────────────────────────────────────────
  void _showAskSheet() {
    final titleC = TextEditingController();
    final subjC  = TextEditingController();
    final bodyC  = TextEditingController();
    bool busy = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> submit() async {
          if (titleC.text.trim().isEmpty || subjC.text.trim().isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Question and subject are required.')));
            return;
          }
          setSheet(() => busy = true);
          try {
            await _api.askStudyQuestion(
                title: titleC.text.trim(), subject: subjC.text.trim(),
                body: bodyC.text.trim());
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            setSheet(() => busy = false);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Could not post: $e')));
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppC.faint,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text('Ask a question',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
            const SizedBox(height: 14),
            _field(titleC, 'Your question', Icons.help_outline_rounded),
            const SizedBox(height: 10),
            _field(subjC, 'Subject (e.g. Year 12 Maths)', Icons.school_rounded),
            const SizedBox(height: 10),
            _field(bodyC, 'Add detail (optional)', Icons.notes_rounded, lines: 3),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: busy ? null : submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: kStaffG1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Post question',
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, color: Colors.white)),
              )),
          ]),
        );
      }),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
          {int lines = 1}) =>
      TextField(
        controller: c, maxLines: lines,
        style: TextStyle(fontFamily: 'Momo', color: AppC.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppC.faint, size: 20),
          filled: true, fillColor: AppC.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}

// ── Thread (question + answers) ─────────────────────────────────────────
class _ThreadScreen extends StatefulWidget {
  final ApiService api;
  final String questionId;
  final bool isTeacher;
  const _ThreadScreen({
    required this.api, required this.questionId, required this.isTeacher});

  @override
  State<_ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<_ThreadScreen> {
  final _answerC = TextEditingController();
  bool _loading = true, _posting = false;
  Map<String, dynamic>? _q;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.studyQuestion(widget.questionId) as Map;
      if (!mounted) return;
      setState(() { _q = d.cast<String, dynamic>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final body = _answerC.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      await widget.api.answerStudyQuestion(widget.questionId, body);
      _answerC.clear();
      if (mounted) FocusScope.of(context).unfocus();
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _resolve() async {
    try { await widget.api.resolveStudyQuestion(widget.questionId); await _load(); }
    catch (_) {}
  }

  Future<void> _accept(String answerId) async {
    HapticFeedback.selectionClick();
    try { await widget.api.acceptStudyAnswer(answerId); await _load(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final resolved = q?['status'] == 'resolved';
    final answers = (q?['answers'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList();
    final canResolve = widget.isTeacher; // asker rights handled server-side too
    return Scaffold(
      backgroundColor: AppC.bg,
      appBar: AppBar(
        backgroundColor: kStaffG1, foregroundColor: Colors.white,
        title: const Text('Question',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18)),
        actions: [
          if (q != null && canResolve)
            TextButton(
              onPressed: _resolve,
              child: Text(resolved ? 'Reopen' : 'Resolve',
                  style: const TextStyle(color: Colors.white,
                      fontFamily: 'Arch', fontWeight: FontWeight.bold))),
        ],
      ),
      body: _loading || q == null
          ? const Center(child: CircularProgressIndicator(color: kStaffG1))
          : Column(children: [
              Expanded(child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: staffCard(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kStaffG1.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text(q['subject']?.toString() ?? '',
                              style: const TextStyle(fontFamily: 'Arch', fontSize: 10,
                                  fontWeight: FontWeight.bold, color: kStaffG1))),
                        const SizedBox(height: 10),
                        Text(q['title']?.toString() ?? '',
                            style: TextStyle(fontFamily: 'Arch',
                                fontWeight: FontWeight.bold, fontSize: 16,
                                color: AppC.text)),
                        if ((q['body'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(q['body'].toString(),
                              style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                                  height: 1.4, color: AppC.sub)),
                        ],
                        const SizedBox(height: 8),
                        Text('Asked by ${q['asker']}',
                            style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                                color: AppC.faint)),
                      ]),
                  ),
                  const SizedBox(height: 16),
                  Text('${answers.length} ${answers.length == 1 ? "answer" : "answers"}',
                      style: TextStyle(fontFamily: 'Alfa', fontSize: 14,
                          color: AppC.text)),
                  const SizedBox(height: 8),
                  ...answers.map((a) => _answerCard(a)),
                  const SizedBox(height: 80),
                ],
              )),
              _composer(),
            ]),
    );
  }

  Widget _answerCard(Map<String, dynamic> a) {
    final isTeacher = a['is_teacher'] == true;
    final accepted = a['is_accepted'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: accepted ? const Color(0xFF16A34A)
                : (isTeacher ? kStaffG1.withValues(alpha: 0.5) : AppC.border),
            width: accepted ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isTeacher ? Icons.school_rounded : Icons.person_rounded,
              size: 15, color: isTeacher ? kStaffG1 : AppC.faint),
          const SizedBox(width: 5),
          Text(a['author']?.toString() ?? '',
              style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                  fontWeight: FontWeight.bold, color: AppC.text)),
          if (isTeacher) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kStaffG1.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6)),
              child: const Text('Teacher', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 9, fontWeight: FontWeight.bold, color: kStaffG1))),
          ],
          const Spacer(),
          if (accepted)
            const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 17),
        ]),
        const SizedBox(height: 8),
        Text(a['body']?.toString() ?? '',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13, height: 1.4,
                color: AppC.text)),
        if (widget.isTeacher && !accepted) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _accept(a['id'].toString()),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF16A34A)),
              label: const Text('Accept', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 12, fontWeight: FontWeight.bold)))),
        ],
      ]),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppC.card,
          border: Border(top: BorderSide(color: AppC.border))),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _answerC, minLines: 1, maxLines: 4,
            style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.text),
            decoration: InputDecoration(
              hintText: widget.isTeacher
                  ? 'Answer as a teacher…' : 'Write an answer…',
              filled: true, fillColor: AppC.bg, isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none)),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _posting ? null : _post,
            child: Container(
              width: 44, height: 44, alignment: Alignment.center,
              decoration: const BoxDecoration(color: kStaffG1, shape: BoxShape.circle),
              child: _posting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
          ),
        ]),
      ),
    );
  }
}
