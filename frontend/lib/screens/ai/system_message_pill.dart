// lib/screens/chat/system_message_pill.dart
//
// Centered pill that renders system-style chat notices like
//   "🤖 Dale joined the chat"
//   "Alice joined the bubble"
//   "Dale left the chat"
//
// These are messages where is_system == true (regardless of is_ai).
// They never have a sender bubble; they sit centered between message
// rows so the eye reads them as ambient state changes, not chat.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

class SystemMessagePill extends StatelessWidget {
  final String text;
  const SystemMessagePill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 11.5,
                  color: AppC.sub,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}