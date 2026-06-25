// lib/widgets/ai_spinner.dart
//
// Playful "thinking" indicator for AI replies: three pulsing dots plus a
// cycling gerund status word (à la Claude Code's spinner verbs). Drop-in
// replacement for the old static _TypingDots — makes the wait feel alive.
//
// Usage:  AiSpinner(color: theme.gradient.last)

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// The fun word bank. Gerunds keep the "…ing" rhythm; a few are TCS / study
/// flavored so Dale feels at home. The spinner picks one at random and never
/// repeats the same word twice in a row.
const List<String> kSpinnerWords = [
  'Thinking', 'Pondering', 'Noodling', 'Brewing', 'Cooking', 'Crafting',
  'Conjuring', 'Musing', 'Percolating', 'Marinating', 'Ruminating',
  'Tinkering', 'Puzzling', 'Plotting', 'Dreaming', 'Imagining',
  'Synthesizing', 'Vibing', 'Cogitating', 'Deliberating', 'Mulling',
  'Brainstorming', 'Sketching', 'Weaving', 'Calculating', 'Wondering',
  'Reflecting', 'Composing', 'Riffing', 'Doodling', 'Daydreaming',
  'Untangling', 'Decoding', 'Scheming', 'Connecting dots', 'Studying up',
  'Consulting notes', 'Sharpening pencils', 'Channeling Dale', 'Flipping pages',
  'Crunching', 'Brewing ideas', 'Spelunking', 'Galaxy-braining', 'Vibing hard',
];

class AiSpinner extends StatefulWidget {
  /// Accent colour for the dots; the word renders a touch softer.
  final Color color;

  /// Optional override for the word font (defaults to the app's 'Momo').
  final String fontFamily;

  const AiSpinner({super.key, required this.color, this.fontFamily = 'Momo'});

  @override
  State<AiSpinner> createState() => _AiSpinnerState();
}

class _AiSpinnerState extends State<AiSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;
  Timer? _cycle;
  final _rng = Random();
  late String _word;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _word = kSpinnerWords[_rng.nextInt(kSpinnerWords.length)];
    _cycle = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted) return;
      setState(() {
        String w;
        do {
          w = kSpinnerWords[_rng.nextInt(kSpinnerWords.length)];
        } while (w == _word);
        _word = w;
      });
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _dots,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i / 3;
              final t = (_dots.value - delay).clamp(0.0, 1.0);
              final op = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.35, 1.0);
              // Dots also bob up a hair for extra life.
              final lift = (t < 0.5 ? t * 2 : (1 - t) * 2) * 2.0;
              return Container(
                width: 7,
                height: 7,
                margin: EdgeInsets.only(right: 4, bottom: lift),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(op),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            '$_word…',
            key: ValueKey<String>(_word),
            style: TextStyle(
              color: widget.color.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: widget.fontFamily,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
