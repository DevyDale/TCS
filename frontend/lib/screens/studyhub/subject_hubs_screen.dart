// lib/screens/studyhub/subject_hubs_screen.dart
//
// Subject hubs (spec §3D): a directory of subjects, each opening a single
// bundled space — that subject's resources, open questions, quizzes and
// upcoming sessions in one place. Re-uses the existing surfaces filtered by
// subject; `isTeacher` carries through so teacher affordances stay available.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/studyhub/resource_library_screen.dart';
import 'package:tcs_app/screens/studyhub/qa_board_screen.dart';
import 'package:tcs_app/screens/studyhub/quizzes_screen.dart';
import 'package:tcs_app/screens/studyhub/sessions_screen.dart';
import 'package:tcs_app/screens/studyhub/quiz_take_screen.dart';

class SubjectHubsScreen extends StatefulWidget {
  final bool isTeacher;
  const SubjectHubsScreen({super.key, required this.isTeacher});

  @override
  State<SubjectHubsScreen> createState() => _SubjectHubsScreenState();
}

class _SubjectHubsScreenState extends State<SubjectHubsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.studySubjects() as Map;
      final list = (d['results'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _subjects = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        onRefresh: _load, color: kStaffG1,
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
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Subject Hubs', style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 22, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text('Everything for a subject in one place',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )),
                const Icon(Icons.dashboard_rounded, color: Colors.white, size: 26),
              ]),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else if (_subjects.isEmpty)
              SliverFillRemaining(hasScrollBody: false,
                  child: staffNoResults('No subjects yet — add resources or a quiz.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _subjectCard(_subjects[i]),
                  childCount: _subjects.length,
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _subjectCard(Map<String, dynamic> s) {
    final subject = s['subject']?.toString() ?? '';
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => SubjectHubScreen(
                subject: subject, isTeacher: widget.isTeacher)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: staffCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kStaffG1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.local_library_rounded, color: kStaffG1, size: 23)),
            const SizedBox(width: 12),
            Expanded(child: Text(subject,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: AppC.text))),
            const Icon(Icons.chevron_right_rounded, color: kStaffG1),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(Icons.menu_book_rounded, '${s['resources'] ?? 0}', 'resources'),
            _pill(Icons.forum_rounded, '${s['open_questions'] ?? 0}', 'open Qs'),
            _pill(Icons.quiz_rounded, '${s['quizzes'] ?? 0}', 'quizzes'),
            _pill(Icons.event_available_rounded, '${s['sessions'] ?? 0}', 'sessions'),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(IconData icon, String n, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppC.bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: kStaffG1),
          const SizedBox(width: 5),
          Text('$n $label', style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: AppC.sub)),
        ]),
      );
}

// ── A single subject's bundled space ────────────────────────────────────
class SubjectHubScreen extends StatefulWidget {
  final String subject;
  final bool isTeacher;
  const SubjectHubScreen({super.key, required this.subject, required this.isTeacher});

  @override
  State<SubjectHubScreen> createState() => _SubjectHubScreenState();
}

class _SubjectHubScreenState extends State<SubjectHubScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _resources = [], _questions = [], _quizzes = [], _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = widget.subject;
    try {
      final results = await Future.wait([
        _api.studyResources(subject: s).catchError((_) => {'results': []}),
        _api.studyQuestions(subject: s, status: 'open').catchError((_) => {'results': []}),
        _api.listQuizzes(subject: s).catchError((_) => {'results': []}),
        _api.studySessions(when: 'upcoming', subject: s).catchError((_) => {'results': []}),
      ]);
      List<Map<String, dynamic>> ex(dynamic d) => ((d as Map)['results'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() {
        _resources = ex(results[0]);
        _questions = ex(results[1]);
        _quizzes   = ex(results[2]);
        _sessions  = ex(results[3]);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => s)).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        onRefresh: _load, color: kStaffG1,
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
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Alfa', fontSize: 21,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text('Subject hub',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )),
                const Icon(Icons.local_library_rounded, color: Colors.white, size: 26),
              ]),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  _section('Resources', Icons.menu_book_rounded, _resources.length,
                      () => _open(ResourceLibraryScreen(isTeacher: widget.isTeacher))),
                  if (_resources.isEmpty) _emptyLine('No resources yet.')
                  else ..._resources.take(4).map(_resourceRow),
                  const SizedBox(height: 18),

                  _section('Open questions', Icons.forum_rounded, _questions.length,
                      () => _open(QaBoardScreen(isTeacher: widget.isTeacher))),
                  if (_questions.isEmpty) _emptyLine('No open questions.')
                  else ..._questions.take(4).map(_questionRow),
                  const SizedBox(height: 18),

                  _section('Quizzes', Icons.quiz_rounded, _quizzes.length,
                      () => _open(QuizzesScreen(isTeacher: widget.isTeacher))),
                  if (_quizzes.isEmpty) _emptyLine('No quizzes published.')
                  else ..._quizzes.take(4).map(_quizRow),
                  const SizedBox(height: 18),

                  _section('Upcoming sessions', Icons.event_available_rounded,
                      _sessions.length,
                      () => _open(SessionsScreen(isTeacher: widget.isTeacher))),
                  if (_sessions.isEmpty) _emptyLine('No sessions scheduled.')
                  else ..._sessions.take(4).map(_sessionRow),
                ])),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, int count, VoidCallback seeAll) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: kStaffG1),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontFamily: 'Alfa', fontSize: 15, color: AppC.text)),
          const SizedBox(width: 6),
          if (count > 0)
            Text('$count', style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                fontWeight: FontWeight.bold, color: AppC.faint)),
          const Spacer(),
          TextButton(onPressed: seeAll,
              style: TextButton.styleFrom(
                  foregroundColor: kStaffG1, visualDensity: VisualDensity.compact),
              child: const Text('See all', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget _emptyLine(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 4),
        child: Text(t, style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.faint)),
      );

  Widget _tile({required IconData icon, required String title, String? sub,
          Widget? trailing, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: staffCard(),
          child: Row(children: [
            Icon(icon, size: 20, color: kStaffG1),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 13, color: AppC.text)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
                ],
              ],
            )),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget _resourceRow(Map<String, dynamic> r) => _tile(
        icon: (r['kind'] == 'link') ? Icons.link_rounded : Icons.description_rounded,
        title: r['title']?.toString() ?? '',
        sub: '${r['kind']} · ${r['owner']}',
        trailing: Icon((r['kind'] == 'link')
            ? Icons.open_in_new_rounded : Icons.download_rounded,
            color: kStaffG1, size: 20),
        onTap: () async {
          final url = (r['url'] ?? '').toString();
          if (url.isEmpty) return;
          try { await _api.downloadStudyResource(r['id'].toString()); } catch (_) {}
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      );

  Widget _questionRow(Map<String, dynamic> q) => _tile(
        icon: Icons.help_outline_rounded,
        title: q['title']?.toString() ?? '',
        sub: '${q['answer_count'] ?? 0} answers · ${q['asker']}',
        trailing: const Icon(Icons.chevron_right_rounded, color: kStaffG1, size: 20),
        onTap: () => _open(QaBoardScreen(isTeacher: widget.isTeacher)),
      );

  Widget _quizRow(Map<String, dynamic> q) => _tile(
        icon: Icons.quiz_rounded,
        title: q['title']?.toString() ?? '',
        sub: '${q['question_count'] ?? 0} questions',
        trailing: const Icon(Icons.play_circle_outline_rounded, color: kStaffG1, size: 22),
        onTap: () => _open(QuizTakeScreen(quizId: q['id'].toString())),
      );

  Widget _sessionRow(Map<String, dynamic> s) {
    final when = DateTime.tryParse(s['when']?.toString() ?? '')?.toLocal();
    final rsvped = s['is_rsvped'] == true;
    return _tile(
      icon: Icons.event_rounded,
      title: s['title']?.toString() ?? '',
      sub: when == null ? null
          : '${when.day}/${when.month} ${when.hour.toString().padLeft(2, '0')}:'
            '${when.minute.toString().padLeft(2, '0')} · ${s['rsvp_count'] ?? 0} going',
      trailing: widget.isTeacher ? null : GestureDetector(
        onTap: () async {
          HapticFeedback.selectionClick();
          try {
            final d = await _api.rsvpSession(s['id'].toString()) as Map;
            setState(() {
              s['is_rsvped'] = d['is_rsvped'];
              s['rsvp_count'] = d['rsvp_count'];
            });
          } catch (_) {}
        },
        child: Icon(rsvped ? Icons.check_circle_rounded
            : Icons.add_circle_outline_rounded,
            color: rsvped ? const Color(0xFF16A34A) : kStaffG1, size: 24),
      ),
    );
  }
}
