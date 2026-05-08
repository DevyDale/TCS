// lib/widgets/arcade/game_polish.dart
//
// Drop-in polish widgets for any in-game screen:
//   • CountdownIntro    — 3-2-1-GO! before play starts
//   • ScorePopup        — "+100" floating numbers
//   • ComboMeter        — multiplier on consecutive successful actions
//   • PowerUpBadge      — UI for active timed power-ups

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_engine.dart';

// ════════════════════════════════════════════════════════════
// CountdownIntro — 3, 2, 1, GO!
// ════════════════════════════════════════════════════════════
//
//   CountdownIntro(
//     onComplete: () => setState(() => _gameStarted = true),
//   )
//
// Each number bounces in with elastic scale + fades out. "GO!" is
// green and shouts the final beat.

class CountdownIntro extends StatefulWidget {
  final VoidCallback onComplete;
  final List<Color> gradient;
  const CountdownIntro({
    super.key,
    required this.onComplete,
    this.gradient = const [kNeonBlue, kNeonPurple],
  });

  @override
  State<CountdownIntro> createState() => _CountdownIntroState();
}

class _CountdownIntroState extends State<CountdownIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _step = 3;     // 3, 2, 1, 0=GO

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _tick();
  }

  Future<void> _tick() async {
    while (_step >= 0) {
      _ctrl.reset();
      _ctrl.forward();
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (_step == 0) {
        widget.onComplete();
        return;
      }
      setState(() => _step -= 1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGo = _step == 0;
    final label = isGo ? 'GO!' : '$_step';
    return Container(
      color: kDarkBg.withOpacity(0.95),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final scale = 0.4 + (Curves.elasticOut.transform(_ctrl.value) * 0.8);
            final opacity = (_ctrl.value < 0.7)
                ? 1.0
                : (1.0 - ((_ctrl.value - 0.7) / 0.3));
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                          colors: isGo
                              ? [Colors.green.shade300, Colors.green.shade600]
                              : widget.gradient)
                      .createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Alfa',
                      fontSize: 120,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ScorePopup — floating "+100" number
// ════════════════════════════════════════════════════════════
//
// Manage a list of pops in your game state. Each pop is an entry; the
// widget fades + drifts upward and self-removes when its animation ends.
//
//   Stack(children: [
//     YourGameContent(),
//     for (final pop in _scorePops)
//       Positioned(
//         left: pop.position.dx,
//         top:  pop.position.dy,
//         child: ScorePopup(
//           amount: pop.amount,
//           onDone: () => setState(() => _scorePops.remove(pop)),
//         ),
//       ),
//   ])

class ScorePopup extends StatefulWidget {
  final int amount;
  final VoidCallback? onDone;
  final Color color;
  final Duration duration;
  final double riseDistance;

  const ScorePopup({
    super.key,
    required this.amount,
    this.onDone,
    this.color = kNeonOrange,
    this.duration = const Duration(milliseconds: 900),
    this.riseDistance = 60,
  });

  @override
  State<ScorePopup> createState() => _ScorePopupState();
}

class _ScorePopupState extends State<ScorePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final dy = -widget.riseDistance * t;
        final opacity = t < 0.7 ? 1.0 : (1.0 - ((t - 0.7) / 0.3));
        final scale = t < 0.2
            ? Curves.elasticOut.transform(t / 0.2) * 0.6 + 0.4
            : 1.0;
        return IgnorePointer(
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Text(
                  widget.amount > 0
                      ? '+${widget.amount}'
                      : '${widget.amount}',
                  style: TextStyle(
                    fontFamily: 'Alfa',
                    fontSize: 22,
                    color: widget.color,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper struct for tracking active score pops in game state.
class ScorePop {
  final int     id;
  final int     amount;
  final Offset  position;
  ScorePop({required this.id, required this.amount, required this.position});
}

// ════════════════════════════════════════════════════════════
// ComboMeter — consecutive-action multiplier
// ════════════════════════════════════════════════════════════
//
// Pass in the current combo count. Renders a fire emoji + "x3 COMBO"
// pill that grows + shimmers as the multiplier climbs.
//
//   ComboMeter(combo: _combo)   // 0 = hidden

class ComboMeter extends StatelessWidget {
  final int combo;
  const ComboMeter({super.key, required this.combo});

  @override
  Widget build(BuildContext context) {
    if (combo < 2) return const SizedBox.shrink();

    // Color escalates with combo size
    Color color;
    String emoji;
    if (combo >= 10) { color = kNeonRed;    emoji = '🔥'; }
    else if (combo >= 5)  { color = kNeonOrange; emoji = '🔥'; }
    else                  { color = kNeonPurple; emoji = '⚡'; }

    final scale = 1.0 + ((combo.clamp(0, 12) / 12) * 0.25);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.elasticOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.30),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('x$combo COMBO',
              style: TextStyle(
                fontFamily: 'Alfa', fontSize: 13,
                color: color,
              )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PowerUpBadge — chip showing active timed buff
// ════════════════════════════════════════════════════════════
//
// Show a small pill with an emoji + countdown bar for each active
// power-up. The bar drains as time passes.
//
//   Wrap(spacing: 6, children: [
//     PowerUpBadge(emoji: '⚡', label: '2x SPEED', secondsLeft: 4.2, totalSeconds: 8),
//     PowerUpBadge(emoji: '🛡️', label: 'SHIELD', secondsLeft: 1.5, totalSeconds: 5),
//   ])

class PowerUpBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final double secondsLeft;
  final double totalSeconds;
  final Color color;

  const PowerUpBadge({
    super.key,
    required this.emoji,
    required this.label,
    required this.secondsLeft,
    required this.totalSeconds,
    this.color = kNeonBlue,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalSeconds == 0
        ? 0.0
        : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
          const SizedBox(height: 4),
          // Drain bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              width: 60,
              height: 3,
              color: Colors.white.withOpacity(0.10),
              child: FractionallySizedBox(
                widthFactor: pct,
                alignment: Alignment.centerLeft,
                child: Container(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Tracker — small helper to manage a stream of score pops
// ════════════════════════════════════════════════════════════
//
// Centralised so games don't have to manage IDs themselves.
//
//   final _pops = ScorePopTracker();
//   ...
//   _pops.add(amount: 100, position: tapPosition);
//   ...
//   ValueListenableBuilder(
//     valueListenable: _pops,
//     builder: (_, list, __) => Stack(children: [
//       for (final p in list) Positioned(
//         left: p.position.dx,
//         top:  p.position.dy,
//         child: ScorePopup(amount: p.amount, onDone: () => _pops.remove(p.id)),
//       ),
//     ]),
//   )

class ScorePopTracker extends ValueNotifier<List<ScorePop>> {
  ScorePopTracker() : super([]);
  int _nextId = 0;

  void add({required int amount, required Offset position}) {
    final pop = ScorePop(id: _nextId++, amount: amount, position: position);
    value = [...value, pop];
  }

  void remove(int id) {
    value = value.where((p) => p.id != id).toList();
  }

  void clear() => value = const [];
}
