// lib/widgets/dale_loader.dart
//
// A playful loading state: the Dale robot Lottie in the centre with a word that
// keeps changing (beaming, booping, bouncing…). When [done] flips true it
// swaps to a green tick. Used while the Train-Dale page / training is working.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';

const _kViolet = Color(0xFF8E54E9);

const _kGerunds = <String>[
  'Beaming', 'Booping', 'Bouncing', 'Brewing', 'Bubbling', 'Chasing',
  'Churning', 'Coalescing', 'Conjuring', 'Cooking', 'Crafting', 'Crunching',
  'Cuddling', 'Dancing', 'Dazzling', 'Discovering', 'Doodling', 'Dreaming',
  'Drifting', 'Enchanting', 'Exploring', 'Finding', 'Floating', 'Fluttering',
  'Foraging', 'Forging', 'Frolicking', 'Gathering', 'Giggling', 'Gliding',
  'Greeting', 'Growing', 'Hatching', 'Herding', 'Honking', 'Hopping',
  'Hugging', 'Humming', 'Imagining', 'Inventing', 'Jingling', 'Juggling',
  'Jumping', 'Kindling', 'Knitting', 'Launching', 'Leaping', 'Mapping',
  'Marinating', 'Meandering', 'Mixing', 'Moseying', 'Munching', 'Napping',
  'Nibbling', 'Noodling', 'Orbiting', 'Painting', 'Percolating', 'Petting',
  'Plotting', 'Pondering', 'Popping', 'Prancing', 'Purring', 'Puzzling',
  'Questing', 'Riding', 'Roaming', 'Rolling', 'Sautéing', 'Scribbling',
  'Seeking', 'Shimmying', 'Singing', 'Skipping', 'Sleeping', 'Snacking',
  'Sniffing', 'Snuggling', 'Soaring', 'Sparking', 'Spinning', 'Splashing',
  'Sprouting', 'Squishing', 'Stargazing', 'Stirring', 'Strolling', 'Swimming',
  'Swinging', 'Tickling', 'Tinkering', 'Toasting', 'Tumbling', 'Twirling',
  'Waddling', 'Wandering', 'Watching', 'Weaving',
];

class DaleLoader extends StatefulWidget {
  final bool done;
  final String? doneLabel;
  const DaleLoader({super.key, this.done = false, this.doneLabel});

  @override
  State<DaleLoader> createState() => _DaleLoaderState();
}

class _DaleLoaderState extends State<DaleLoader> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!widget.done) _start();
  }

  void _start() {
    _t = Timer.periodic(const Duration(milliseconds: 480), (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _kGerunds.length);
    });
  }

  @override
  void didUpdateWidget(covariant DaleLoader old) {
    super.didUpdateWidget(old);
    if (widget.done && _t != null) { _t!.cancel(); _t = null; }
    if (!widget.done && _t == null) _start();
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (c, a) => ScaleTransition(
              scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: a, child: c)),
          child: widget.done
              ? Container(
                  key: const ValueKey('tick'),
                  width: 120, height: 120, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                        width: 2)),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFF22C55E), size: 64))
              : SizedBox(
                  key: const ValueKey('dale'),
                  width: 130, height: 130,
                  child: Lottie.asset('assets/images/robot.json',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.smart_toy_rounded, color: _kViolet, size: 80))),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            widget.done
                ? (widget.doneLabel ?? 'All set!')
                : '${_kGerunds[_i]}…',
            key: ValueKey(widget.done ? 'done' : _kGerunds[_i]),
            style: TextStyle(fontFamily: 'Alfa', fontSize: 17,
                color: widget.done ? const Color(0xFF22C55E) : AppC.text),
          ),
        ),
      ]),
    );
  }
}
