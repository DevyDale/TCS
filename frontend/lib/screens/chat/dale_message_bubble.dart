// lib/screens/chat/dale_message_bubble.dart
//
// Renders a single non-system message authored by Dale (is_ai == true,
// is_system == false). Visually distinct from user bubbles:
//   • 36×36 gradient avatar (sky → purple) with robot icon
//   • "Dale ✨" name label above the bubble
//   • White bubble with a thin 1px gradient border so it pops
//   • Always left-aligned (Dale isn't "you")
//
// Dale only sends text — image/audio/sticker rendering is not needed
// here. If we ever extend Dale to send media, fall through to a
// regular media renderer.

import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

// Sage palette — matches the chat room (chat_room_screen.dart) so Dale's
// bubble blends with the conversation instead of using the AI-Hub purple.
const _kG1   = Color(0xFFA9BC95); // sage
const _kG2   = Color(0xFF6E8159); // sage dark
const _kInk  = Color(0xFF2E3A24);

class DaleMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  /// True when the message above this one was also from Dale.
  /// We hide the avatar + name on consecutive Dale messages to
  /// avoid visual repetition.
  final bool collapseHeader;

  const DaleMessageBubble({
    super.key,
    required this.message,
    this.collapseHeader = false,
  });

  String _fmt(String iso) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final text = (message['text'] as String?)
              ?? (message['display_text'] as String?)
              ?? '';
    final time = _fmt((message['created_at'] as String?) ?? '');
    final maxW = MediaQuery.of(context).size.width * 0.74;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Avatar (or spacer when collapsed) ─────────
          if (collapseHeader)
            const SizedBox(width: 44)
          else ...[
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_kG1, _kG2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _kG2.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: Lottie.asset(
                  'assets/images/robot.json',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // ── Bubble column ─────────────────────────────
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!collapseHeader)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [_kG1, _kG2],
                          ).createShader(rect),
                          child: const T(
                            'Dale',
                            style: TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kG1, _kG2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(collapseHeader ? 20 : 4),
                        topRight: const Radius.circular(20),
                        bottomLeft: const Radius.circular(20),
                        bottomRight: const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(collapseHeader ? 18 : 3),
                          topRight: const Radius.circular(18),
                          bottomLeft: const Radius.circular(18),
                          bottomRight: const Radius.circular(18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            style: const TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 14.5,
                              color: _kInk,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 10.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
