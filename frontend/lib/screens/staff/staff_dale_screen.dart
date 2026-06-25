// lib/screens/staff/staff_dale_screen.dart
//
// DALE tab — the AI in the two roles staff care about: Ask Dale (their own
// assistant) and Train Dale (upload course material so Dale tutors students
// from it). Reuses AiAssistantScreen and StaffKnowledgeScreen.

import 'package:flutter/material.dart';
import 'package:tcs_app/screens/staff/staff_tab_host.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';

class StaffDaleScreen extends StatelessWidget {
  const StaffDaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffTabHost(
      title: 'Dale',
      emoji: '🤖',
      segments: [
        StaffSeg('Ask Dale', Icons.auto_awesome_rounded, AiAssistantScreen()),
        StaffSeg('Train Dale', Icons.school_rounded, StaffKnowledgeScreen()),
      ],
    );
  }
}
