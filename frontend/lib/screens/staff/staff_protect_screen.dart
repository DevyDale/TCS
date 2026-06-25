// lib/screens/staff/staff_protect_screen.dart
//
// PROTECT tab — the safety desk: moderation (flag/report queue + actions),
// student suggestions to the school, and scam oversight. Reuses
// StaffModerationScreen and StaffSuggestionsScreen.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_tab_host.dart';
import 'package:tcs_app/screens/staff/staff_moderation_screen.dart';
import 'package:tcs_app/screens/staff/staff_suggestions_screen.dart';
import 'package:tcs_app/screens/staff/staff_wellbeing_screen.dart';

class StaffProtectScreen extends StatelessWidget {
  const StaffProtectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffTabHost(
      title: 'Protect',
      emoji: '🛡️',
      segments: [
        StaffSeg('Moderation', Icons.shield_rounded, StaffModerationScreen()),
        StaffSeg('Wellbeing', Icons.favorite_rounded, StaffWellbeingScreen()),
        StaffSeg('Suggestions', Icons.lightbulb_rounded, StaffSuggestionsScreen()),
        StaffSeg('Scam watch', Icons.warning_rounded, _ScamOversightPanel()),
      ],
    );
  }
}

class _ScamOversightPanel extends StatelessWidget {
  const _ScamOversightPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛰️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text('Scam oversight',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
                  color: AppC.text)),
          const SizedBox(height: 8),
          Text(
              'Students can already check suspicious messages with Dale in the '
              'Scam Check tool. A live staff view of scam waves — so you can '
              'broadcast a warning early — is on the roadmap.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  height: 1.6, color: AppC.sub)),
        ]),
      ),
    );
  }
}
