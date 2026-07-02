// lib/screens/staff/staff_student_questions_screen.dart
//
// "What students ask Dale" — a staff-facing window into the kinds of things
// students bring to the assistant, grouped by category with tap-to-reveal
// example answers.
//
// PRIVACY: this is a CURATED gallery of representative examples — NOT a feed of
// real student messages. Students ask Dale wellbeing/personal/sensitive things,
// and surfacing raw questions (even to staff) is a safety risk for minors, so
// nothing here is real student data. If real aggregate "trending" data is ever
// added, it must be anonymised, category-level only, and run through a
// wellbeing/PII moderation filter first.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class _QA {
  final String category;
  final IconData icon;
  final Color color;
  final String question;
  final String answer;
  const _QA(this.category, this.icon, this.color, this.question, this.answer);
}

const _cats = <String, (IconData, Color)>{
  'Study & concepts': (Icons.menu_book_rounded, Color(0xFF60A5FA)),
  'Exams & prep':     (Icons.event_note_rounded, Color(0xFFF59E0B)),
  'Campus & events':  (Icons.campaign_rounded,   Color(0xFF34D399)),
  'Clubs & activities': (Icons.groups_rounded,   Color(0xFFEC4899)),
  'Using the app':    (Icons.phone_iphone_rounded, Color(0xFF8E54E9)),
  'Student life':     (Icons.favorite_rounded,   Color(0xFFFF6B6B)),
};

const _questions = <_QA>[
  // Study & concepts
  _QA('Study & concepts', Icons.menu_book_rounded, Color(0xFF60A5FA),
      'Can you explain photosynthesis in simple terms?',
      'Sure! Plants take in sunlight, water and carbon dioxide, and turn them '
      'into glucose (their food) and oxygen. Think of the leaf as a tiny solar '
      'kitchen — light is the energy, and the "recipe" happens in the '
      'chloroplasts. Want the word equation too?'),
  _QA('Study & concepts', Icons.menu_book_rounded, Color(0xFF60A5FA),
      "What's the difference between mitosis and meiosis?",
      'Mitosis makes two identical cells for growth and repair. Meiosis makes '
      'four cells with half the DNA, for reproduction. Quick memory hook: '
      'MI-Tosis = MI-nding the body; MEI-osis = MakE gametes.'),
  _QA('Study & concepts', Icons.menu_book_rounded, Color(0xFF60A5FA),
      'How do I solve a quadratic equation?',
      'Try factoring first; if it won\'t factor neatly, use the quadratic '
      'formula x = (-b ± √(b²-4ac)) / 2a. Tell me the equation and I\'ll walk '
      'through it step by step.'),

  // Exams & prep
  _QA('Exams & prep', Icons.event_note_rounded, Color(0xFFF59E0B),
      'Can you make me a study plan for this week?',
      'Absolutely. Tell me your subjects, your exam dates, and how many hours '
      'a day you can study, and I\'ll build a day-by-day plan with focused '
      'blocks and breaks.'),
  _QA('Exams & prep', Icons.event_note_rounded, Color(0xFFF59E0B),
      'How should I revise so it actually sticks?',
      'Active recall + spaced repetition beats re-reading. Quiz yourself, use '
      'the Arcade quiz battles, and revisit topics after 1 day, 3 days, then a '
      'week. Short focused sessions win over long cramming.'),
  _QA('Exams & prep', Icons.event_note_rounded, Color(0xFFF59E0B),
      'Any tips for staying focused while studying?',
      'Try 25-minute focus sprints with 5-minute breaks, phone on the other '
      'side of the room, and one clear goal per sprint. Water and a tidy desk '
      'help more than people expect.'),

  // Campus & events
  _QA('Campus & events', Icons.campaign_rounded, Color(0xFF34D399),
      "What's happening on campus this week?",
      'Check the Events tab for the latest — I can point you to what\'s coming '
      'up and help you RSVP so it\'s saved to your calendar.'),
  _QA('Campus & events', Icons.campaign_rounded, Color(0xFF34D399),
      'When is the next club fair?',
      'Club fairs and sign-ups show up under Events and in Announcements. Turn '
      'on notifications and you\'ll get a heads-up before it starts.'),

  // Clubs & activities
  _QA('Clubs & activities', Icons.groups_rounded, Color(0xFFEC4899),
      'What clubs can I join at TCS?',
      'Head to the club posts in your feed to see active groups, or ask a '
      'teacher. If you want to start one, I can help you draft a pitch.'),
  _QA('Clubs & activities', Icons.groups_rounded, Color(0xFFEC4899),
      'How do I start a study group?',
      'Create a Chat Bubble, invite classmates, and pin your materials. I can '
      'even join the group chat to help answer questions while you study.'),

  // Using the app
  _QA('Using the app', Icons.phone_iphone_rounded, Color(0xFF8E54E9),
      'How do I find a study buddy?',
      'Open the Study Hub and tap Buddies — you\'ll be matched by subject. '
      'Once paired you get a private study chat with materials sharing.'),
  _QA('Using the app', Icons.phone_iphone_rounded, Color(0xFF8E54E9),
      'How do I RSVP to an event?',
      'Open the event from the Events tab and tap RSVP — it saves your spot '
      'and you\'ll get reminders before it starts.'),
  _QA('Using the app', Icons.phone_iphone_rounded, Color(0xFF8E54E9),
      'How does the leaderboard and XP work?',
      'You earn XP from quizzes, streaks and activity. The Arcade leaderboard '
      'ranks players — keep a daily streak going for the biggest boost.'),

  // Student life
  _QA('Student life', Icons.favorite_rounded, Color(0xFFFF6B6B),
      'How do I manage my time better?',
      'Start with a simple weekly plan: fixed classes first, then study blocks, '
      'then free time. Protect sleep — a rested brain learns faster. I can help '
      'you build a routine that fits your week.'),
  _QA('Student life', Icons.favorite_rounded, Color(0xFFFF6B6B),
      'Any tips for making friends at a new school?',
      'Join a club or study group around something you enjoy — shared '
      'activities make conversation easy. Small hellos add up. You belong here.'),
];

class StaffStudentQuestionsScreen extends StatefulWidget {
  const StaffStudentQuestionsScreen({super.key});

  @override
  State<StaffStudentQuestionsScreen> createState() =>
      _StaffStudentQuestionsScreenState();
}

class _StaffStudentQuestionsScreenState
    extends State<StaffStudentQuestionsScreen> {
  String _filter = 'All';
  final Set<int> _open = {};

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ..._cats.keys];
    final items = _filter == 'All'
        ? _questions
        : _questions.where((q) => q.category == _filter).toList();

    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(
        children: [
          _header(),
          _chips(cats),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(items[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 18,
      horizontal: const EdgeInsets.only(left: 6, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Expanded(
                child: Text(
                  'What students ask Dale',
                  style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 19, color: Colors.white),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 2, right: 6),
            child: Text(
              'Representative examples of how students use the assistant — '
              'grouped by topic. Tap a question to see how Dale replies.',
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 12,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(List<String> cats) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cats[i];
          final sel = c == _filter;
          return GestureDetector(
            onTap: () => setState(() {
              _filter = c;
              _open.clear();
            }),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: sel ? kStaffGrad : null,
                color: sel ? null : AppC.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? Colors.transparent : AppC.border),
              ),
              child: Text(
                c,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AppC.sub,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(_QA q, int i) {
    final open = _open.contains(i);
    return GestureDetector(
      onTap: () => setState(() {
        open ? _open.remove(i) : _open.add(i);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: staffCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: q.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(q.icon, color: q.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    q.question,
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      height: 1.3,
                      color: AppC.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppC.faint, size: 22),
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppC.card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppC.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.answer,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppC.sub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
