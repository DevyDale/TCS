// lib/screens/staff/staff_connect_screen.dart
//
// CONNECT tab — every conversation staff have, in one landing: colleague/DM
// messages, the staff feed (digital staffroom), and the student announcement
// composer. Reuses ChatListScreen, FeedScreen and StaffAnnouncementsScreen.
// Styled with the shared staff kit.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/chat/chat_list_screen.dart';
import 'package:tcs_app/screens/feed/feed_screen.dart';
import 'package:tcs_app/screens/staff/staff_announcements_screen.dart';

class StaffConnectScreen extends StatelessWidget {
  const StaffConnectScreen({super.key});

  void _push(BuildContext context, Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  // ChatListScreen and FeedScreen are root tabs with no back button of their
  // own — pushed as routes they'd trap the user. Wrap them in a slim
  // back-bar scaffold (also reclaims the status-bar safe area).
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
              const SizedBox(height: 34),
              const StaffSectionLabel('Talk to anyone',
                  subtitle: 'Colleagues, the staffroom, your students'),
              _card(context,
                  icon: Icons.chat_bubble_rounded,
                  title: 'Messages',
                  subtitle: 'DMs and group chats with colleagues.',
                  gradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  onTap: () => _pushTab(context, const ChatListScreen())),
              const SizedBox(height: 12),
              _card(context,
                  icon: Icons.dynamic_feed_rounded,
                  title: 'Staffroom',
                  subtitle: 'Share and connect with other staff.',
                  gradient: const [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                  onTap: () => _pushTab(context, const FeedScreen())),
              const SizedBox(height: 12),
              _card(context,
                  icon: Icons.campaign_rounded,
                  title: 'Announce',
                  subtitle: 'Official posts & push to students.',
                  gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  onTap: () =>
                      _push(context, const StaffAnnouncementsScreen())),
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
          child: const Icon(Icons.forum_rounded,
              color: Colors.white, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Connect',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 28,
                    color: Colors.white, height: 1.05,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                        offset: Offset(0, 3))])),
            const SizedBox(height: 4),
            Text('Everyone you talk to, in one place',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        )),
      ]),
    );
  }

  Widget _card(
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
                color: gradient.last.withValues(alpha: 0.32),
                blurRadius: 20, offset: const Offset(0, 11))]),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 26)),
            const SizedBox(width: 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11.5, height: 1.35,
                    color: Colors.white.withValues(alpha: 0.92))),
              ],
            )),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 21),
          ]),
        ),
      ),
    );
  }
}
