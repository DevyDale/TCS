// lib/screens/staff/staff_campus_screen.dart
//
// CAMPUS tab — everything that happens on campus: events, clubs & groups, and
// the arcade. Reuses EventsScreen and ArcadeClubsScreen; the arcade is a
// full-screen experience so it's launched rather than embedded.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/staff/staff_tab_host.dart';
import 'package:tcs_app/screens/dashboard/events_screen.dart';
import 'package:tcs_app/screens/arcade/aracade_clubs.dart';
import 'package:tcs_app/screens/arcade/arcade_screen.dart';

class StaffCampusScreen extends StatelessWidget {
  const StaffCampusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StaffTabHost(
      title: 'Campus',
      emoji: '🎯',
      segments: [
        const StaffSeg('Events', Icons.event_rounded, EventsScreen()),
        const StaffSeg('Clubs', Icons.groups_rounded, ArcadeClubsScreen()),
        StaffSeg('Arcade', Icons.sports_esports_rounded, Builder(
          builder: (ctx) => StaffLaunchPanel(
            emoji: '🎮',
            title: 'Arcade',
            subtitle: 'Jump in and play with students and staff. Tournaments '
                'and class-time controls are coming to governance.',
            cta: 'Open Arcade',
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => const ArcadeScreen()));
            },
          ),
        )),
      ],
    );
  }
}
