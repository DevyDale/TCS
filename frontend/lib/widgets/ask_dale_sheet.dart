// lib/screens/chat/ask_dale_sheet.dart
//
// Modal bottom sheet that opens when the user taps the Dale button
// AND Dale is already active in the room.
//
// Two affordances:
//   1. A text field + "Ask" button — sends a specific question to
//      /chat/rooms/<id>/ai/summon/ with the user's text. The reply is
//      handled by the parent via onAsk(message).
//   2. "Catch me up" quick action — same endpoint with no message,
//      Dale just summarises / responds to recent context.
//   3. "Remove Dale from chat" — destructive, confirms first.
//
// The sheet doesn't talk to the API itself; it calls onAsk and
// onRemove and lets the parent handle the network call + optimistic
// UI. That keeps this file purely visual.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

// Sage palette — matches the chat room (chat_room_screen.dart) so the
// Ask-Dale sheet blends with the conversation instead of AI-Hub purple.
const _kG1   = Color(0xFFA9BC95); // sage
const _kG2   = Color(0xFF6E8159); // sage dark
const _kInk  = Color(0xFF2E3A24);
Color get _kSlate => AppC.sub;
const _kRed  = Color(0xFFFF4F6E);

/// Public entry — call this. Returns immediately; the parent's
/// onAsk / onRemove callbacks fire as the user taps.
Future<void> showAskDaleSheet(
  BuildContext context, {
  required Future<void> Function(String message) onAsk,
  required Future<void> Function() onRemove,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AskDaleSheet(onAsk: onAsk, onRemove: onRemove),
    ),
  );
}

class _AskDaleSheet extends StatefulWidget {
  final Future<void> Function(String) onAsk;
  final Future<void> Function() onRemove;
  const _AskDaleSheet({
    required this.onAsk,
    required this.onRemove,
  });

  @override
  State<_AskDaleSheet> createState() => _AskDaleSheetState();
}

class _AskDaleSheetState extends State<_AskDaleSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _ask({String? override}) async {
    final msg = (override ?? _ctrl.text).trim();
    setState(() => _busy = true);
    try {
      await widget.onAsk(msg);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const T('Remove Dale from this chat?',
            style: TextStyle(
                fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
        content: T(
          "Dale will stop participating. You can add him back any time.",
          style: TextStyle(
              fontFamily: 'Momo', fontSize: 13, color: _kSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: T('Cancel',
                style: TextStyle(color: _kSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const T('Remove',
                style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    ) ?? false;
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await widget.onRemove();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppC.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header row
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_kG1, _kG2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipOval(
                    child: Lottie.asset(
                      'assets/images/robot.json',
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Icon(
                          Icons.smart_toy_rounded,
                          color: AppC.card,
                          size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('Dale is here',
                        style: TextStyle(
                            fontFamily: 'Alfa',
                            fontSize: 16,
                            color: _kInk)),
                    SizedBox(height: 1),
                    T('Ask anything based on the chat',
                        style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 12,
                            color: _kSlate)),
                  ],
                )),
              ]),
              const SizedBox(height: 16),

              // Text field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kG1.withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  enableSuggestions: true,
                  maxLines: 3, minLines: 1,
                  cursorColor: _kG2,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ask(),
                  style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 14, color: _kInk),
                  decoration: InputDecoration(
                    hintText: TranslationService.I.tr('Ask Dale a question…'),
                    hintStyle: TextStyle(
                        fontFamily: 'Momo',
                        color: AppC.faint,
                        fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Primary actions row
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _busy ? null : () => _ask(override: ''),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppC.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppC.border),
                      ),
                      child: const Center(
                        child: T('Catch me up',
                            style: TextStyle(
                                fontFamily: 'Arch',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _kInk)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _busy ? null : () => _ask(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kG1, _kG2],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: _kG2.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Center(
                        child: _busy
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : T('Ask Dale',
                                style: TextStyle(
                                    fontFamily: 'Arch',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppC.text)),
                      ),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 14),
              Divider(color: AppC.border, height: 1),
              const SizedBox(height: 6),

              // Remove option
              TextButton.icon(
                onPressed: _busy ? null : _confirmRemove,
                icon: const Icon(Icons.exit_to_app_rounded,
                    color: _kRed, size: 18),
                label: const T('Remove Dale from chat',
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: _kRed,
                    )),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
