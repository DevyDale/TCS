// lib/screens/staff/staff_connect_screen.dart
//
// CONNECT tab — every conversation staff have, in one landing, laid out by
// hierarchy rather than a flat list: a wide Messages feature tile, a 2-up grid
// (Feed / Announce), and a compact Community row (Study groups / Clubs).
// Reuses ChatListScreen, StaffFeedScreen, StaffAnnouncementsScreen,
// GroupsStudyHubScreen and ArcadeClubsScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/chat/chat_list_screen.dart';
import 'package:tcs_app/screens/staff/staff_feed_screen.dart';
import 'package:tcs_app/screens/staff/staff_announcements_screen.dart';
import 'package:tcs_app/screens/groups/groups_study_hub_screen.dart';
import 'package:tcs_app/screens/arcade/aracade_clubs.dart';

class StaffConnectScreen extends StatelessWidget {
  const StaffConnectScreen({super.key});

  void _push(BuildContext context, Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  // ChatListScreen / GroupsStudyHubScreen are root tabs with no back button —
  // pushed as routes they'd trap the user. Wrap in a slim back-bar scaffold.
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
              const StaffSectionLabel('Talk to anyone',
                  subtitle: 'Colleagues, the staffroom, your students'),

              // Hero feature: Messages (the most-used).
              _featureWide(context,
                  icon: Icons.chat_bubble_rounded,
                  title: 'Messages',
                  subtitle: 'DMs and group chats with your colleagues.',
                  gradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  onTap: () => _pushTab(context, const ChatListScreen())),
              const SizedBox(height: 12),

              // 2-up grid: Feed + Announce.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: _gridTile(context,
                      icon: Icons.dynamic_feed_rounded,
                      title: 'Feed',
                      subtitle: 'What students post',
                      gradient: const [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                      onTap: () => _push(context, const StaffFeedScreen()))),
                  const SizedBox(width: 12),
                  Expanded(child: _gridTile(context,
                      icon: Icons.campaign_rounded,
                      title: 'Announce',
                      subtitle: 'Post & push',
                      gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                      onTap: () =>
                          _push(context, const StaffAnnouncementsScreen()))),
                ]),
              ),

              const SizedBox(height: 24),
              const StaffSectionLabel('Community',
                  subtitle: 'Where students gather'),

              // Compact community rows.
              _communityRow(context,
                  icon: Icons.groups_rounded,
                  title: 'Study groups',
                  subtitle: 'Student study groups across the cohort',
                  color: const Color(0xFF059669),
                  onTap: () => _pushTab(context, const GroupsStudyHubScreen())),
              const SizedBox(height: 10),
              _communityRow(context,
                  icon: Icons.local_activity_rounded,
                  title: 'Clubs',
                  subtitle: 'Clubs and societies on campus',
                  color: const Color(0xFFEA580C),
                  onTap: () => _push(context, const ArcadeClubsScreen())),

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

  // Wide hero feature tile.
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
                    fontSize: 12, height: 1.35,
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

  // Square-ish grid tile (taller, vertical layout).
  Widget _gridTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        height: 138,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
              color: gradient.last.withValues(alpha: 0.32),
              blurRadius: 18, offset: const Offset(0, 10))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46, height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 24)),
            const Spacer(),
            Text(title, style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 17, color: Colors.white)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }

  // Compact, low-emphasis card-coloured row.
  Widget _communityRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: staffCard(),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 14.5,
                    color: AppC.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11.5, color: AppC.sub)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 22),
          ]),
        ),
      ),
    );
  }
}
