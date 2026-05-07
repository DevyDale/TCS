// lib/screens/arcade/number_guesser_game.dart
//
// Higher/Lower number guessing game. 10 levels expand the range and
// adjust the guess budget.
//
// Reads level params:
//   min, max  - range of secret number
//   guesses   - max attempts allowed

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_engine.dart';
import 'level_system.dart';
import 'levels/number_guesser_levels.dart';

class NumberGuesserGame extends StatefulWidget {
  const NumberGuesserGame({super.key});
  @override
  State<NumberGuesserGame> createState() => _NumberGuesserGameState();
}

class _NumberGuesserGameState extends State<NumberGuesserGame> {
  bool _showStory = true;
  int  _level     = 1;
  bool _started   = false;
  bool _won       = false;
  bool _lost      = false;

  late LevelConfig _cfg;
  late int _min, _max, _maxGuesses;
  int _secret = 0;
  int _guessesUsed = 0;
  int _currentGuess = 0;
  String _hint = '';
  List<_GuessEntry> _history = [];
  final _rand = Random();

  void _openLevelSelect() async {
    final picked = await Navigator.push<int>(context, MaterialPageRoute(
      builder: (_) => const LevelSelectScreen(
        gameSlug:  'number-guesser',
        gameName:  'Number Guesser',
        gameEmoji: '🔢',
        gradient:  [kNeonOrange, kNeonRed],
        levels:    kNumberGuesserLevels,
      ),
    ));
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _startRound();
  }

  void _startRound() {
    _cfg        = kNumberGuesserLevels[_level - 1];
    _min        = _cfg.params['min']     as int;
    _max        = _cfg.params['max']     as int;
    _maxGuesses = _cfg.params['guesses'] as int;
    _secret     = _min + _rand.nextInt(_max - _min + 1);
    setState(() {
      _started      = true;
      _won          = false;
      _lost         = false;
      _guessesUsed  = 0;
      _currentGuess = (_min + _max) ~/ 2;
      _hint         = 'Pick a number between $_min and $_max';
      _history      = [];
    });
  }

  void _submit() {
    if (_won || _lost) return;
    HapticFeedback.lightImpact();
    final g = _currentGuess;
    String hint;
    bool match = g == _secret;
    if (match) {
      hint = '🎯 You got it!';
      HapticFeedback.heavyImpact();
    } else if (g < _secret) {
      hint = '⬆️  Higher than $g';
    } else {
      hint = '⬇️  Lower than $g';
    }
    setState(() {
      _guessesUsed += 1;
      _hint         = hint;
      _history.add(_GuessEntry(value: g, match: match,
          tooHigh: !match && g > _secret));
      if (match) {
        _won = true;
        Future.delayed(const Duration(milliseconds: 700), _finish);
      } else if (_guessesUsed >= _maxGuesses) {
        _lost = true;
        _hint = 'The number was $_secret';
        Future.delayed(const Duration(milliseconds: 1200), _finish);
      }
    });
  }

  void _finish() {
    if (!mounted) return;
    final remaining   = _maxGuesses - _guessesUsed;
    final base        = _won ? 100 + (_level * 30) : 0;
    final bonus       = _won ? remaining * 50 + (_level * 10) : 0;
    final score       = base + bonus;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => LevelCompleteScreen(
        gameSlug: 'number-guesser',
        gameName: 'Number Guesser',
        config:   _cfg,
        score:    score,
        outcome:  _won ? 'win' : 'lose',
      ),
    )).then((replay) {
      if (!mounted) return;
      if (replay == 'replay') _startRound();
      else                   _openLevelSelect();
    });
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('number-guesser')) {
      return GameStoryScreen(
        gameSlug: 'number-guesser',
        onPlay: () { setState(() => _showStory = false); _openLevelSelect(); });
    }
    if (!_started) {
      return Scaffold(
        backgroundColor: kDarkBg,
        body: SafeArea(child: _buildLanding()),
      );
    }
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: _buildGame()),
    );
  }

  Widget _buildLanding() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Align(alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: kDarkCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white60, size: 20)))),
      const Spacer(),
      const Text('🔢', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (b) =>
            const LinearGradient(colors: [kNeonOrange, kNeonRed]).createShader(b),
        blendMode: BlendMode.srcIn,
        child: const Text('Number Guesser',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 32, color: Colors.white)),
      ),
      const SizedBox(height: 10),
      Text('Crack the secret code\nFewer guesses = bigger score',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13,
              color: Colors.white.withOpacity(0.5), height: 1.6)),
      MiniLeaderboard(gameSlug: 'number-guesser', gameName: 'Number Guesser'),
      const Spacer(),
      GestureDetector(
        onTap: _openLevelSelect,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: kNeonOrange.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: const Center(child: Text('Choose Level 🎮',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white))),
        ),
      ),
    ]),
  );

  Widget _buildGame() {
    final remaining = _maxGuesses - _guessesUsed;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: kDarkCard2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white60, size: 18))),
          const SizedBox(width: 10),
          Text('Lv.$_level',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 14, color: kNeonOrange)),
          const Spacer(),
          Text('Range $_min – $_max',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: Colors.white.withOpacity(0.5))),
        ]),
        const SizedBox(height: 24),

        // Guesses remaining badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (remaining <= 2 ? kNeonRed : kNeonBlue).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (remaining <= 2 ? kNeonRed : kNeonBlue).withOpacity(0.3)),
          ),
          child: Text('🎯 $remaining guesses remaining',
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: remaining <= 2 ? kNeonRed : kNeonBlue)),
        ),
        const SizedBox(height: 28),

        // Big number display
        Container(
          width: 200, height: 100,
          decoration: BoxDecoration(
            color: kDarkCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kNeonOrange.withOpacity(0.4), width: 2),
          ),
          child: Center(
            child: Text('$_currentGuess',
                style: const TextStyle(fontFamily: 'Alfa', fontSize: 48,
                    color: kNeonOrange)),
          ),
        ),
        const SizedBox(height: 16),

        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: kNeonOrange,
            inactiveTrackColor: Colors.white12,
            thumbColor: kNeonOrange,
            overlayColor: kNeonOrange.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            min: _min.toDouble(), max: _max.toDouble(),
            value: _currentGuess.toDouble().clamp(_min.toDouble(), _max.toDouble()),
            onChanged: (_won || _lost)
                ? null
                : (v) => setState(() => _currentGuess = v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$_min', style: TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: Colors.white.withOpacity(0.4))),
            Text('$_max', style: TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: Colors.white.withOpacity(0.4))),
          ],
        ),
        const SizedBox(height: 24),

        // Hint
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(_hint),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kDarkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_hint,
                style: const TextStyle(fontFamily: 'Momo',
                    fontSize: 14, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 18),

        // Submit
        if (!_won && !_lost)
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Guess ⚡',
                    style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 18, color: Colors.white)),
              ),
            ),
          ),

        // History
        const SizedBox(height: 16),
        Expanded(
          child: ListView(reverse: true, children: [
            for (final h in _history.reversed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: h.match ? Colors.green.shade900.withOpacity(0.3) : kDarkCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: h.match
                        ? Colors.green.shade400
                        : Colors.white.withOpacity(0.06)),
                ),
                child: Row(children: [
                  Icon(
                    h.match
                        ? Icons.check_circle_rounded
                        : h.tooHigh
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                    color: h.match ? Colors.green : Colors.white60,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text('${h.value}',
                      style: const TextStyle(fontFamily: 'Alfa',
                          fontSize: 14, color: Colors.white)),
                  const Spacer(),
                  Text(
                    h.match
                        ? 'Correct!'
                        : h.tooHigh ? 'Too high' : 'Too low',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                        color: h.match ? Colors.green :
                               Colors.white.withOpacity(0.5)),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _GuessEntry {
  final int  value;
  final bool match;
  final bool tooHigh;
  _GuessEntry({required this.value, required this.match, required this.tooHigh});
}
