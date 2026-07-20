// lib/screens/staff/staff_campus_screen.dart
//
// CAMPUS tab — what happens on campus: events and the arcade. Laid out as a
// landing (wide Events hero + Arcade launch tile) to match Connect/Protect.
// Reuses EventsScreen and ArcadeScreen (arcade is full-screen, so launched).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/dashboard/events_screen.dart';
import 'package:tcs_app/screens/arcade/arcade_screen.dart';

class StaffCampusScreen extends StatelessWidget {
  const StaffCampusScreen({super.key});

  void _push(BuildContext context, Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  // EventsScreen is a root tab with no back button — wrap it so it's escapable.
  void _pushTab(BuildContext context, Widget child) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: AppC.bg,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppC.text),
                onPressed: () => Navigator.of(ctx).maybePop(),
              ),
            ),
            Expanded(child: child),
          ]),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          _hero(),
          Transform.translate(
            offset: const Offset(0, -26),
            child: Column(children: [
              const SizedBox(height: 30),
              StaffSectionLabel('On campus',
                  subtitle: 'Run events and join the fun'),

              _featureWide(context,
                  icon: Icons.event_available_rounded,
                  title: 'Events',
                  subtitle: 'Create, edit and manage campus events.',
                  gradient: const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                  onTap: () => _pushTab(context, const EventsScreen())),
              const SizedBox(height: 12),

              _featureWide(context,
                  icon: Icons.sports_esports_rounded,
                  title: 'Arcade',
                  subtitle: 'Jump in and play with students and staff. '
                      'Tournaments and class-time controls are coming soon.',
                  gradient: const [Color(0xFF22D3EE), Color(0xFF2563EB)],
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _push(context, const ArcadeScreen());
                  }),

              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return StaffHeader(
      bottomPad: 28,
      horizontal: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
          child: const Icon(Icons.celebration_rounded,
              color: Colors.white, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Campus',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 28,
                    color: Colors.white, height: 1.05,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                        offset: Offset(0, 3))])),
            const SizedBox(height: 4),
            Text('Events & play across the cohort',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        )),
      ]),
    );
  }

  Widget _featureWide(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
                color: gradient.last.withValues(alpha: 0.34),
                blurRadius: 22, offset: const Offset(0, 12))]),
          child: Row(children: [
            Container(
              width: 58, height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: Colors.white, size: 30)),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 21, color: Colors.white)),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, height: 1.4,
                    color: Colors.white.withValues(alpha: 0.92))),
              ],
            )),
            const SizedBox(width: 8),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18)),
          ]),
        ),
      ),
    );
  }
}
