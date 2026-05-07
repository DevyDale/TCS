// lib/widgets/ai_assistant_fab.dart
//
// Two widgets:
// 1. AiAssistantFab    — floating pulsing button, drop onto any Scaffold
// 2. AiAssistantCard   — pinned card for the feed screen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

// ─────────────────────────────────────────────────────────────
// FLOATING ACTION BUTTON
// Drop this into any Scaffold's floatingActionButton parameter.
// It floats, pulses, and opens the AI chat screen.
// ─────────────────────────────────────────────────────────────

class AiAssistantFab extends StatefulWidget {
  const AiAssistantFab({super.key});

  @override
  State<AiAssistantFab> createState() => _AiAssistantFabState();
}

class _AiAssistantFabState extends State<AiAssistantFab>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _pressCtrl;
  late final AnimationController _rotateCtrl;

  late final Animation<double> _floatAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120),
        lowerBound: 0.88, upperBound: 1.0, value: 1.0);

    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    _floatAnim  = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _pulseAnim  = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _scaleAnim  = CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut);
    _rotateAnim = Tween<double>(begin: 0, end: 1.0)
        .animate(CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _floatCtrl.dispose(); _pulseCtrl.dispose();
    _pressCtrl.dispose(); _rotateCtrl.dispose();
    super.dispose();
  }

  void _openAssistant() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const AiAssistantScreen(),
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 420),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnim, _pulseAnim, _scaleAnim]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: GestureDetector(
            onTapDown:   (_) => _pressCtrl.reverse(),
            onTapUp:     (_) { _pressCtrl.forward(); _openAssistant(); },
            onTapCancel: ()  => _pressCtrl.forward(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Container(
                  width:  64 + 16 * _pulseAnim.value,
                  height: 64 + 16 * _pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kG2.withOpacity(0.15 * (1 - _pulseAnim.value)),
                  ),
                ),

                // Rotating gradient border
                AnimatedBuilder(
                  animation: _rotateAnim,
                  builder: (_, child) => Transform.rotate(
                    angle: _rotateAnim.value * 6.28,
                    child: child,
                  ),
                  child: Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [_kG1, _kG2, _kG3, _kG4, _kG1],
                      ),
                    ),
                  ),
                ),

                // Main button body
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF1a1a2e), Color(0xFF0D0D1A)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 24)),
                  ),
                ),

                // Online dot
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0D0D1A), width: 2),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF1D9E75).withOpacity(0.6),
                        blurRadius: 6,
                      )],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FEED CARD
// A rich entry point card for the top of the home feed.
// Usage: drop into your feed ListView as the first item.
// ─────────────────────────────────────────────────────────────

class AiAssistantCard extends StatefulWidget {
  const AiAssistantCard({super.key});

  @override
  State<AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends State<AiAssistantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _shimmerCtrl.dispose(); super.dispose(); }

  void _open() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const AiAssistantScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 420),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (_, child) => Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141428),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(
                _kG2.withOpacity(0.25),
                _kG1.withOpacity(0.4),
                _shimmerAnim.value,
              )!,
              width: 1.5,
            ),
            boxShadow: [BoxShadow(
              color: _kG2.withOpacity(0.1 + 0.05 * _shimmerAnim.value),
              blurRadius: 20, offset: const Offset(0, 6),
            )],
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + title + online badge
              Row(
                children: [
                  // AI icon
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_kG1, _kG2],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(
                        color: _kG2.withOpacity(0.35), blurRadius: 12,
                      )],
                    ),
                    child: const Center(
                        child: Text('🤖', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TCS AI Assistant',
                            style: TextStyle(
                              fontFamily: 'Alfa', fontSize: 15, color: Colors.white,
                            )),
                        const SizedBox(height: 3),
                        Row(children: [
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1D9E75), shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('Online · Always free',
                              style: TextStyle(
                                fontFamily: 'Momo', fontSize: 11,
                                color: Colors.white.withOpacity(0.4),
                              )),
                        ]),
                      ],
                    ),
                  ),

                  // Arrow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kG2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        color: _kG2, size: 14),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                'Ask me anything — study tips, campus events, course help, arcade guides and more.',
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 12,
                  color: Colors.white.withOpacity(0.55), height: 1.5,
                ),
              ),

              const SizedBox(height: 14),

              // Quick chip row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickChip('📖 Study help', _kG1),
                    const SizedBox(width: 8),
                    _QuickChip('🏫 Campus info', _kG2),
                    const SizedBox(width: 8),
                    _QuickChip('🎉 Events', _kG3),
                    const SizedBox(width: 8),
                    _QuickChip('🕹 Arcade tips', _kG4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _QuickChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label,
        style: TextStyle(
          fontFamily: 'Momo', fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        )),
  );
}
