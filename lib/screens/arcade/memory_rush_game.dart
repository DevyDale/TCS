// lib/screens/arcade/memory_match_game.dart
//
// Card-pair matching game with 10 levels. Each level adds cards and
// shrinks the time the cards stay flipped to memorise.
//
// Reads level params:
//   cols, rows  - grid layout (cols × rows must be even, total = pairs × 2)
//   flipBack    - ms before mismatched cards flip back

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/arcade/game_polish.dart';

import 'game_engine.dart';
import 'level_system.dart';
import 'levels/memory_match_levels.dart';

const _kCardEmojis = [
  '🎮','🎲','🎯','🎨','🎭','🎺','🎸','🥁','🎷','🎤',
  '🚀','🛸','🛰️','🪐','⭐','🌟','✨','💫','🌙','🌞',
  '🍕','🍔','🍣','🍜','🍩','🍪','🥨','🌮','🥗','🍱',
  '🐱','🐶','🦊','🐼','🐧','🦉','🐢','🦋','🐝','🦄',
  '⚽','🏀','🎾','🏐','⛳','🏓','🥋','🥊','🎿','🛹',
];

class _Card {
  final String emoji;
  bool flipped = false;
  bool matched = false;
  _Card(this.emoji);
}

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame>
    with SingleTickerProviderStateMixin {
  bool _showStory     = true;
  bool _showCountdown = false;
  int  _level         = 1;
  bool _started       = false;
  bool _paused        = false;

  late LevelConfig _cfg;
  late int _cols, _rows;
  late int _flipBack;

  List<_Card> _cards = [];
  int? _firstIdx;
  bool _busy = false;
  int _flips = 0;
  int _matches = 0;
  int _streak = 0;
  int _score = 0;
  int _elapsed = 0;
  Timer? _swTimer;

  @override
  void dispose() {
    _swTimer?.cancel();
    super.dispose();
  }

  void _openLevelSelect() async {
    final picked = await Navigator.push<int>(context, MaterialPageRoute(
      builder: (_) => const LevelSelectScreen(
        gameSlug:  'memory-match',
        gameName:  'Memory Match',
        gameEmoji: '🃏',
        gradient:  [kNeonBlue, kNeonOrange],
        levels:    kMemoryMatchLevels,
      ),
    ));
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _beginCountdown();
  }

  void _beginCountdown() {
    _cfg      = kMemoryMatchLevels[_level - 1];
    _cols     = _cfg.params['cols']     as int;
    _rows     = _cfg.params['rows']     as int;
    _flipBack = _cfg.params['flipBack'] as int;
    setState(() {
      _showCountdown = true;
      _started       = false;
    });
  }

  void _startGame() {
    final pairs = (_cols * _rows) ~/ 2;
    final pool  = List<String>.from(_kCardEmojis)..shuffle();
    final picks = pool.take(pairs).toList();
    final deck  = <_Card>[];
    for (final e in picks) {
      deck.add(_Card(e));
      deck.add(_Card(e));
    }
    deck.shuffle();
    setState(() {
      _cards     = deck;
      _firstIdx  = null;
      _busy      = false;
      _flips     = 0;
      _matches   = 0;
      _streak    = 0;
      _score     = 0;
      _elapsed   = 0;
      _showCountdown = false;
      _started   = true;
    });
    _swTimer?.cancel();
    _swTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() => _elapsed += 1);
    });
  }

  void _flip(int i) {
    if (_busy || _paused) return;
    final c = _cards[i];
    if (c.flipped || c.matched) return;
    HapticFeedback.lightImpact();
    setState(() {
      c.flipped = true;
      _flips += 1;
    });
    if (_firstIdx == null) {
      _firstIdx = i;
      return;
    }
    // Second card — check
    final firstIdx = _firstIdx!;
    _firstIdx = null;

    if (_cards[firstIdx].emoji == c.emoji) {
      // Match!
      _streak += 1;
      final base  = 80 + (_level * 5);
      final bonus = _streak > 1 ? (_streak - 1) * 30 : 0;
      final earned = base + bonus;
      setState(() {
        _cards[firstIdx].matched = true;
        c.matched               = true;
        _matches += 1;
        _score += earned;
      });
      HapticFeedback.mediumImpact();
      if (_matches == _cards.length ~/ 2) _finishWin();
    } else {
      // No match — flip both back after delay
      _streak = 0;
      _busy   = true;
      Future.delayed(Duration(milliseconds: _flipBack), () {
        if (!mounted) return;
        setState(() {
          _cards[firstIdx].flipped = false;
          c.flipped                = false;
          _busy                    = false;
        });
      });
    }
  }

  void _finishWin() {
    _swTimer?.cancel();
    HapticFeedback.heavyImpact();
    // Time bonus
    final total       = _cards.length ~/ 2;
    final perfectFlips = total * 2;
    final flipBonus   = max(0, (perfectFlips - _flips + total) * 5);
    final timeBonus   = max(0, 60 - _elapsed) * 8;
    final finalScore  = _score + flipBonus + timeBonus;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => LevelCompleteScreen(
          gameSlug: 'memory-match',
          gameName: 'Memory Match',
          config:   _cfg,
          score:    finalScore,
          outcome:  finalScore >= _cfg.targetScore ? 'win' : 'complete',
        ),
      )).then((replay) {
        if (!mounted) return;
        if (replay == 'replay') _beginCountdown();
        else                   _openLevelSelect();
      });
    });
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('memory-match')) {
      return GameStoryScreen(
        gameSlug: 'memory-match',
        onPlay: () { setState(() => _showStory = false); _openLevelSelect(); });
    }
    if (_showCountdown) {
      return Scaffold(
        backgroundColor: kDarkBg,
        body: CountdownIntro(
          onComplete: _startGame,
          gradient: const [kNeonBlue, kNeonOrange],
        ),
      );
    }
    if (!_started) {
      return Scaffold(
        backgroundColor: kDarkBg,
        body: SafeArea(child: _buildLanding()),
      );
    }
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Stack(children: [
        _buildGame(),
        if (_paused) PauseOverlay(
          gameName: 'Memory Match',
          onResume: () => setState(() => _paused = false),
          onQuit:   () => Navigator.pop(context),
        ),
      ])),
    );
  }

  Widget _buildLanding() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Align(alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: kDarkCard2, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white60, size: 20)))),
      const Spacer(),
      const Text('🃏', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (b) =>
            const LinearGradient(colors: [kNeonBlue, kNeonOrange]).createShader(b),
        blendMode: BlendMode.srcIn,
        child: const Text('Memory Match',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 36, color: Colors.white)),
      ),
      const SizedBox(height: 10),
      Text('Flip pairs · Build streaks\nFewer flips = bigger score',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13,
              color: Colors.white.withOpacity(0.5), height: 1.6)),
      MiniLeaderboard(gameSlug: 'memory-match', gameName: 'Memory Match'),
      const Spacer(),
      GestureDetector(
        onTap: _openLevelSelect,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kNeonBlue, kNeonOrange]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: kNeonBlue.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: const Center(child: Text('Choose Level 🎮',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white))),
        ),
      ),
    ]),
  );

  Widget _buildGame() {
    return Column(children: [
      // HUD
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _paused = true),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: kDarkCard2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: const Icon(Icons.pause_rounded,
                  color: Colors.white60, size: 18))),
          const SizedBox(width: 10),
          Text('Lv.$_level',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 14, color: kNeonOrange)),
          const Spacer(),
          ComboMeter(combo: _streak),
          const Spacer(),
          Text('${_elapsed}s · $_flips flips',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: Colors.white.withOpacity(0.5))),
          const SizedBox(width: 10),
          Text('$_score',
              style: const TextStyle(fontFamily: 'Alfa', fontSize: 18,
                  color: kNeonBlue)),
        ])),
      const SizedBox(height: 14),

      // Grid
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _cols,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: _cards.length,
          itemBuilder: (_, i) => _CardTile(
            card: _cards[i],
            onTap: () => _flip(i),
          ),
        ),
      )),
      const SizedBox(height: 8),
      Text('Pairs found: $_matches / ${_cards.length ~/ 2}',
          style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: Colors.white.withOpacity(0.4))),
      const SizedBox(height: 16),
    ]);
  }
}

class _CardTile extends StatelessWidget {
  final _Card card;
  final VoidCallback onTap;
  const _CardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final showFace = card.flipped || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: card.matched ? Colors.green.shade900.withOpacity(0.4)
                              : showFace ? Colors.white : kDarkCard2,
          gradient: showFace
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF1E1E38), Color(0xFF2C2C50)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: card.matched ? Colors.green.shade500
                  : showFace    ? kNeonBlue.withOpacity(0.4)
                                : Colors.white.withOpacity(0.06),
            width: 1.5,
          ),
        ),
        child: Center(child: showFace
            ? Text(card.emoji, style: const TextStyle(fontSize: 28))
            : const Icon(Icons.question_mark_rounded,
                color: Colors.white24, size: 20)),
      ),
    );
  }
}
