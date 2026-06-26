// lib/screens/studyhub/study_insights_screen.dart
//
// Demand Insights (spec §5) — a teacher-only, AGGREGATE read on where students
// need help: top subjects by open questions, coverage gaps (asked-about but no
// resources), the unanswered backlog, and the hardest published quiz questions.
// Never names an individual — every figure is a count by subject.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class StudyInsightsScreen extends StatefulWidget {
  const StudyInsightsScreen({super.key});

  @override
  State<StudyInsightsScreen> createState() => _StudyInsightsScreenState();
}

class _StudyInsightsScreenState extends State<StudyInsightsScreen> {
  final _api = ApiService();
  bool _loading = true, _forbidden = false;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.studyInsights() as Map;
      if (!mounted) return;
      setState(() { _data = d.cast<String, dynamic>(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _forbidden = e.toString().contains('403') ||
            e.toString().toLowerCase().contains('teachers only');
      });
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
            SliverToBoxAdapter(child: _header()),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else if (_forbidden)
              SliverFillRemaining(hasScrollBody: false,
                  child: staffNoResults('Teachers only.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                sliver: SliverList(delegate: SliverChildListDelegate(_body())),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() => StaffHeader(
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
              const Text('Demand Insights', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 21, color: Colors.white)),
              const SizedBox(height: 3),
              Text('Where your cohort needs help · aggregate only',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85))),
            ],
          )),
          const Icon(Icons.insights_rounded, color: Colors.white, size: 26),
        ]),
      );

  List<Widget> _body() {
    final d = _data!;
    final totals = (d['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final top = (d['top_subjects'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList();
    final gaps = (d['coverage_gaps'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList();
    final hardest = (d['hardest_questions'] as List? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList();

    final maxQ = top.isEmpty ? 1 : top
        .map((r) => (r['questions'] as int? ?? 0))
        .fold<int>(1, (a, b) => b > a ? b : a);

    return [
      // Totals strip
      Row(children: [
        _stat('${totals['open_questions'] ?? 0}', 'open Qs', const Color(0xFFEA580C)),
        const SizedBox(width: 10),
        _stat('${totals['unanswered'] ?? 0}', 'unanswered', const Color(0xFFDC2626)),
        const SizedBox(width: 10),
        _stat('${totals['resources'] ?? 0}', 'resources', kStaffG1),
      ]),
      const SizedBox(height: 22),

      _label('Top subjects by demand'),
      if (top.isEmpty) _empty('No questions asked yet.')
      else ...top.map((r) => _subjectRow(r, maxQ)),

      if (gaps.isNotEmpty) ...[
        const SizedBox(height: 22),
        _label('Coverage gaps'),
        Text('Students are asking here, but there’s no curated material yet.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
        const SizedBox(height: 8),
        ...gaps.map((g) => _gapRow(g)),
      ],

      if (hardest.isNotEmpty) ...[
        const SizedBox(height: 22),
        _label('Hardest quiz questions'),
        Text('Most-missed across your published quizzes — likely misconceptions.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
        const SizedBox(height: 8),
        ...hardest.map((h) => _hardRow(h)),
      ],
    ];
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: staffCard(),
          child: Column(children: [
            Text(value, style: TextStyle(fontFamily: 'Alfa', fontSize: 24, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 10.5, color: AppC.sub)),
          ]),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(fontFamily: 'Alfa', fontSize: 15, color: AppC.text)),
      );

  Widget _empty(String t) => Container(
        padding: const EdgeInsets.all(16), decoration: staffCard(),
        child: Text(t, style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
      );

  Widget _subjectRow(Map<String, dynamic> r, int maxQ) {
    final q = r['questions'] as int? ?? 0;
    final open = r['open_questions'] as int? ?? 0;
    final res = r['resources'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r['subject']?.toString() ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 13.5, color: AppC.text))),
          if (open > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text('$open open', style: const TextStyle(fontFamily: 'Arch',
                  fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)))),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: q / maxQ, minHeight: 6,
            backgroundColor: AppC.border,
            valueColor: const AlwaysStoppedAnimation(kStaffG1))),
        const SizedBox(height: 6),
        Text('$q question${q == 1 ? "" : "s"}  ·  $res resource${res == 1 ? "" : "s"}',
            style: TextStyle(fontFamily: 'Momo', fontSize: 10.5, color: AppC.faint)),
      ]),
    );
  }

  Widget _gapRow(Map<String, dynamic> g) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: staffCard(border: const Color(0xFFEA580C).withValues(alpha: 0.4)),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(g['subject']?.toString() ?? '',
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 13.5, color: AppC.text))),
          Text('${g['questions']} asked · 0 resources',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
        ]),
      );

  Widget _hardRow(Map<String, dynamic> h) {
    final rate = h['miss_rate'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: kStaffG1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7)),
            child: Text(h['subject']?.toString() ?? '',
                style: const TextStyle(fontFamily: 'Arch', fontSize: 9.5,
                    fontWeight: FontWeight.bold, color: kStaffG1))),
          const Spacer(),
          Text('$rate% missed', style: TextStyle(fontFamily: 'Arch', fontSize: 11,
              fontWeight: FontWeight.bold,
              color: rate >= 50 ? const Color(0xFFDC2626) : const Color(0xFFF59E0B))),
        ]),
        const SizedBox(height: 6),
        Text(h['text']?.toString() ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Momo', fontSize: 12, height: 1.35, color: AppC.text)),
      ]),
    );
  }
}
