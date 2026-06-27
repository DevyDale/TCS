// lib/screens/staff/staff_study_hub_screen.dart
//
// The teacher's Study-Hub console (spec §5, phases 1-3 shipped): an office-hours
// toggle, the Resource library (upload/verify) and the Q&A board (answer once
// for the cohort). Quizzes / sessions / insights are flagged as the next wave.
// Reached from the staff Connect tab in place of the peer-only student hub.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/studyhub/resource_library_screen.dart';
import 'package:tcs_app/screens/studyhub/qa_board_screen.dart';
import 'package:tcs_app/screens/studyhub/quizzes_screen.dart';
import 'package:tcs_app/screens/studyhub/sessions_screen.dart';
import 'package:tcs_app/screens/studyhub/study_insights_screen.dart';
import 'package:tcs_app/screens/studyhub/subject_hubs_screen.dart';

class StaffStudyHubScreen extends StatefulWidget {
  const StaffStudyHubScreen({super.key});

  @override
  State<StaffStudyHubScreen> createState() => _StaffStudyHubScreenState();
}

class _StaffStudyHubScreenState extends State<StaffStudyHubScreen> {
  final _api = ApiService();
  bool _open = false;
  String _subjects = '';
  bool _loadingAv = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final d = await _api.myAvailability() as Map;
      if (!mounted) return;
      setState(() {
        _open = d['is_open'] == true;
        _subjects = (d['subjects'] as List? ?? []).join(', ');
        _loadingAv = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAv = false);
    }
  }

  Future<void> _toggleOpen(bool v) async {
    setState(() => _open = v);
    HapticFeedback.selectionClick();
    try {
      await _api.setAvailability(subjects: _subjects, isOpen: v);
    } catch (_) {
      if (mounted) setState(() => _open = !v);
    }
  }

  void _editSubjects() {
    final c = TextEditingController(text: _subjects);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppC.card,
      title: const Text('My subjects'),
      content: TextField(
        controller: c, autofocus: true,
        style: TextStyle(fontFamily: 'Momo', color: AppC.text),
        decoration: const InputDecoration(
            hintText: 'e.g. Year 12 Chemistry, Year 11 Biology')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            setState(() => _subjects = c.text.trim());
            try { await _api.setAvailability(subjects: _subjects, isOpen: _open); }
            catch (_) {}
          },
          child: const Text('Save')),
      ],
    ));
  }

  void _push(Widget s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => s));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          StaffHeader(
            horizontal: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40, height: 40, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 10),
              Container(
                width: 50, height: 50, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Study Hub',
                      style: TextStyle(fontFamily: 'Alfa', fontSize: 26,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Text('Your teaching console',
                      style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85))),
                ],
              )),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Column(children: [
              _officeHours(),
              const SizedBox(height: 18),
              // ── Everyday teaching actions first ──
              const StaffSectionLabel('Teach',
                  subtitle: 'Your day-to-day with students'),
              _tile(
                icon: Icons.forum_rounded,
                title: 'Q&A Board',
                subtitle: 'Answer once — the whole cohort sees it',
                grad: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                onTap: () => _push(const QaBoardScreen(isTeacher: true))),
              const SizedBox(height: 12),
              _tile(
                icon: Icons.quiz_rounded,
                title: 'Quizzes',
                subtitle: 'Build or generate-with-Dale · review · publish · analytics',
                grad: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                onTap: () => _push(const QuizzesScreen(isTeacher: true))),
              const SizedBox(height: 12),
              _tile(
                icon: Icons.menu_book_rounded,
                title: 'Resource Library',
                subtitle: 'Upload notes, papers & guides · verify trusted ones',
                grad: const [Color(0xFF5B53E8), Color(0xFF8E54E9)],
                onTap: () => _push(const ResourceLibraryScreen(isTeacher: true))),
              const SizedBox(height: 12),
              _tile(
                icon: Icons.event_available_rounded,
                title: 'Study Sessions',
                subtitle: 'Schedule revision · students RSVP · remind attendees',
                grad: const [Color(0xFF0EA5A4), Color(0xFF0F766E)],
                onTap: () => _push(const SessionsScreen(isTeacher: true))),
              const SizedBox(height: 18),
              // ── Overview / read-the-room tools below ──
              const StaffSectionLabel('Overview',
                  subtitle: 'See the whole subject & where demand is'),
              _tile(
                icon: Icons.dashboard_rounded,
                title: 'Subject Hubs',
                subtitle: 'Everything for a subject — resources, Q&A, quizzes, sessions',
                grad: const [Color(0xFF334155), Color(0xFF1E293B)],
                onTap: () => _push(const SubjectHubsScreen(isTeacher: true))),
              const SizedBox(height: 12),
              _tile(
                icon: Icons.insights_rounded,
                title: 'Demand Insights',
                subtitle: 'Top subjects · coverage gaps · hardest questions',
                grad: const [Color(0xFF0891B2), Color(0xFF0E7490)],
                onTap: () => _push(const StudyInsightsScreen())),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _officeHours() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: staffCard(
            border: _open ? const Color(0xFF16A34A).withValues(alpha: 0.5) : null),
        child: Column(children: [
          Row(children: [
            Container(
              width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (_open ? const Color(0xFF16A34A) : kStaffG1)
                    .withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.support_agent_rounded,
                  color: _open ? const Color(0xFF16A34A) : kStaffG1, size: 24)),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Office hours',
                    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 15, color: AppC.text)),
                const SizedBox(height: 2),
                Text(_open
                    ? 'Open — students can see you’re available'
                    : 'Closed — flip on when you’re free to help',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        color: _open ? const Color(0xFF16A34A) : AppC.sub)),
              ],
            )),
            if (_loadingAv)
              const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kStaffG1))
            else
              Switch(
                value: _open, activeThumbColor: const Color(0xFF16A34A),
                onChanged: _toggleOpen),
          ]),
          const Divider(height: 22),
          GestureDetector(
            onTap: _editSubjects,
            child: Row(children: [
              Icon(Icons.school_rounded, size: 16, color: AppC.faint),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  _subjects.isEmpty ? 'Tap to add the subjects you teach' : _subjects,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                      color: _subjects.isEmpty ? AppC.faint : AppC.text))),
              Icon(Icons.edit_rounded, size: 15, color: AppC.faint),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tile({
    required IconData icon, required String title, required String subtitle,
    required List<Color> grad, required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: grad.last.withValues(alpha: 0.32),
                blurRadius: 18, offset: const Offset(0, 10))]),
          child: Row(children: [
            Container(
              width: 50, height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.white, size: 25)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 17, color: Colors.white)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                    height: 1.3, color: Colors.white.withValues(alpha: 0.92))),
              ],
            )),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ]),
        ),
      ),
    );
  }

}
