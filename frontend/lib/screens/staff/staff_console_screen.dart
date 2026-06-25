// lib/screens/staff/staff_console_screen.dart
//
// Staff Console — command-center home for staff. The Announcements pillar is
// now wired to the live module; the rest open placeholders until built.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/staff/staff_announcements_screen.dart';
import 'package:tcs_app/screens/staff/staff_moderation_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';
import 'package:tcs_app/screens/staff/staff_suggestions_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
Color get _bg => AppC.bg;
Color get _card => AppC.card;
Color get _card2 => AppC.card2;

class StaffConsoleScreen extends StatelessWidget {
  final String fullName;
  final String preferredName;
  final String role;

  const StaffConsoleScreen({
    super.key,
    required this.fullName,
    this.preferredName = '',
    this.role = 'Staff',
  });

  String get _firstName {
    final n = (preferredName.trim().isNotEmpty ? preferredName : fullName).trim();
    return n.isEmpty ? 'Staff' : n.split(' ').first;
  }

  void _open(BuildContext context, _Pillar p) {
    HapticFeedback.mediumImpact();
    Widget destination;
    switch (p.title) {
      case 'Announcements':
        destination = const StaffAnnouncementsScreen();
        break;
      case 'Moderation':
        destination = const StaffModerationScreen();
        break;
      case 'Dale AI':
        destination = const StaffKnowledgeScreen();
        break;
      case 'Suggestions':
        destination = const StaffSuggestionsScreen();
        break;
      default:
        destination = _StaffSection(pillar: p);
    }
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, a, __) => destination,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 320),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _statStrip()),
            SliverToBoxAdapter(child: _sectionLabel('Controls')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 14,
                  crossAxisSpacing: 14, childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PillarCard(
                    pillar: _pillars[i],
                    onTap: () => _open(context, _pillars[i]),
                  ),
                  childCount: _pillars.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
    child: Row(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kG2, _kG1]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _kG2.withOpacity(.4), blurRadius: 18)],
        ),
        child: Center(child: Text(
          _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'S',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 24, color: AppC.text),
        )),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        T('Staff Console',
            style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                color: AppC.text.withOpacity(.45), letterSpacing: 2)),
        const SizedBox(height: 2),
        Text('Hi, $_firstName',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: AppC.text)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kG2.withOpacity(.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kG2.withOpacity(.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_rounded, size: 14, color: _kG1),
          const SizedBox(width: 5),
          Text(role.isEmpty ? 'Staff' : role,
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 12, color: AppC.text)),
        ]),
      ),
    ]),
  );

  Widget _statStrip() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Row(children: const [
      _StatTile(label: 'Flags pending', value: '—', accent: _kG4, icon: Icons.flag_rounded),
      SizedBox(width: 12),
      _StatTile(label: 'Active today', value: '—', accent: _kG1, icon: Icons.bolt_rounded),
      SizedBox(width: 12),
      _StatTile(label: 'Upcoming', value: '—', accent: _kG3, icon: Icons.event_rounded),
    ]),
  );

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
    child: Row(children: [
      Container(width: 4, height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kG2, _kG3],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(t, style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: AppC.text)),
    ]),
  );
}

class _Pillar {
  final String title, subtitle;
  final IconData icon;
  final List<Color> gradient;
  const _Pillar(this.title, this.subtitle, this.icon, this.gradient);
}

const _pillars = [
  _Pillar('Moderation', 'Flags, hide & remove, suspend',
      Icons.shield_rounded, [_kG4, Color(0xFFB23A48)]),
  _Pillar('Announcements', 'Official posts & push',
      Icons.campaign_rounded, [_kG2, Color(0xFF5B2EC4)]),
  _Pillar('Events & Clubs', 'Create, edit, approve',
      Icons.event_available_rounded, [_kG3, Color(0xFFD96E0F)]),
  _Pillar('Oversight', 'Roster & engagement',
      Icons.insights_rounded, [_kG1, Color(0xFF2575FC)]),
  _Pillar('Dale AI', 'Train the tutor on your notes',
      Icons.psychology_rounded, [Color(0xFF43E97B), Color(0xFF38B2AC)]),
  _Pillar('Suggestions', 'Student ideas to the school',
      Icons.lightbulb_rounded, [Color(0xFF4F46E5), Color(0xFF8E54E9)]),
];

class _PillarCard extends StatelessWidget {
  final _Pillar pillar;
  final VoidCallback onTap;
  const _PillarCard({required this.pillar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_card2, _card],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pillar.gradient.first.withOpacity(.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pillar.gradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(pillar.icon, color: Colors.white, size: 24),
          ),
          const Spacer(),
          Text(pillar.title,
              style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: AppC.text)),
          const SizedBox(height: 4),
          Text(pillar.subtitle,
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: AppC.text.withOpacity(.5), height: 1.3)),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color accent;
  final IconData icon;
  const _StatTile({required this.label, required this.value,
      required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(.18)),
      ),
      child: Column(children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Momo', fontSize: 9,
                color: AppC.text.withOpacity(.45))),
      ]),
    ));
  }
}

class _StaffSection extends StatelessWidget {
  final _Pillar pillar;
  const _StaffSection({required this.pillar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        title: Text(pillar.title,
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: pillar.gradient),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(pillar.icon, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 18),
        Text(pillar.title,
            style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: AppC.text)),
        const SizedBox(height: 8),
        T('This module is being wired up.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                color: AppC.text.withOpacity(.5))),
      ])),
    );
  }
}
