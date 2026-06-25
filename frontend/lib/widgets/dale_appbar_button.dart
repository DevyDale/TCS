// lib/screens/chat/dale_app_bar_button.dart
//
// The "+ Dale" button that lives in the chat room app bar.
// Visual: 40×40 gradient circle (sky → purple) with a small robot icon.
// When Dale is active in the room, a green pulse dot sits in the corner.
//
// Behaviour is intentionally minimal — this widget just draws and
// reports taps. Logic (enable / summon / remove) lives in the parent.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kOnline = Color(0xFF10B981);

class DaleAppBarButton extends StatefulWidget {
  /// True when Dale is enabled in this room. Drives the pulse dot.
  final bool active;

  /// Tap = enable Dale (if inactive) OR open Ask Dale sheet (if active).
  final VoidCallback onTap;

  /// Long-press shortcut for "remove Dale" — only meaningful when active.
  final VoidCallback? onLongPress;

  /// Set true while a network call is in flight (replaces the icon
  /// with a tiny spinner so the user knows something's happening).
  final bool busy;

  const DaleAppBarButton({
    super.key,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.busy = false,
  });

  @override
  State<DaleAppBarButton> createState() => _DaleAppBarButtonState();
}

class _DaleAppBarButtonState extends State<DaleAppBarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.busy ? null : widget.onTap,
      onLongPress: widget.busy ? null : widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main body ──────────────────────────────────
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kG1, _kG2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kG2.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2,
                      ),
                    )
                  : SizedBox(
                      width: 28, height: 28,
                      child: Lottie.asset(
                        'assets/images/robot.json',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.smart_toy_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
            ),
          ),

          // ── Pulse dot (only when active) ───────────────
          if (widget.active)
            Positioned(
              right: -1, bottom: -1,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final t = _pulse.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ripple
                      Container(
                        width: 16 + 6 * t,
                        height: 16 + 6 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kOnline.withOpacity(0.25 * (1 - t)),
                        ),
                      ),
                      // Solid dot
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _kOnline,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}