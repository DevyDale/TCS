// lib/screens/staff/staff_connect_screen.dart
//
// CONNECT tab — every conversation staff have, in one roof: colleague/DM
// messages, the staff feed (digital staffroom), and the student announcement
// composer. Reuses ChatListScreen, FeedScreen and StaffAnnouncementsScreen.

import 'package:flutter/material.dart';
import 'package:tcs_app/screens/staff/staff_tab_host.dart';
import 'package:tcs_app/screens/chat/chat_list_screen.dart';
import 'package:tcs_app/screens/feed/feed_screen.dart';
import 'package:tcs_app/screens/staff/staff_announcements_screen.dart';

class StaffConnectScreen extends StatelessWidget {
  const StaffConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaffTabHost(
      title: 'Connect',
      emoji: '💬',
      segments: [
        StaffSeg('Messages', Icons.chat_bubble_rounded, ChatListScreen()),
        StaffSeg('Staffroom', Icons.dynamic_feed_rounded, FeedScreen()),
        StaffSeg('Announce', Icons.campaign_rounded, StaffAnnouncementsScreen()),
      ],
    );
  }
}
