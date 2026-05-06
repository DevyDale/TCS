// lib/screens/arcade/snake_game.dart
//
// Classic Snake with 10-level progression, story intro, countdown,
// score popups, and grid-based wall obstacles.
//
// Reads level params:
//   gridSize  - NxN play area
//   speedMs   - tick interval
//   walls     - count of random walls
//   food      - simultaneous food on board

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/arcade/game_polish.dart';

import 'game_engine.dart';
import 'level_system.dart';
import 'levels/snake_levels.dart';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});
  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  bool   _showStory   = true;
  int    _level       = 1;
  bool   _showCountdown = false;
  bool   _started     = false;
  bool   _paused      = false;
  bool   _dead        = false;

  late int _grid;
  late int _speedMs;
  late int _foodTarget;
  late LevelConfig _cfg;

  // Snake body — list of (x, y) positions, head is first
  List<Point<int>> _snake = [];
  Point<int> _dir   = const Point(1, 0);     // right
  Point<int> _queuedDir = const Point(1, 0); // buffered to prevent self-bites
  List<Point<int>> _food  = [];
  List<Point<int>> _walls = [];
  int    _score   = 0;
  int    _combo   = 0;

  Timer? _tickTimer;
  final _rand = Random();
  final _pops = ScorePopTracker();

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _openLevelSelect() async {
    final picked = await Navigator.push<int>(context, MaterialPageRoute(
      builder: (_) => const LevelSelectScreen(
        gameSlug:   'snake',
        gameName:   'Snake',
        gameEmoji:  '🐍',
        gradient:   [Color(0xFF11998E), Color(0xFF38EF7D)],
        levels:     kSnakeLevels,
      ),
    ));
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _beginCountdown();
  }

  void _beginCountdown() {
    _cfg        = kSnakeLevels[_level - 1];
    _grid       = _cfg.params['gridSize'] as int;
    _speedMs    = _cfg.params['speedMs']  as int;
    _foodTarget = _cfg.params['food']     as int;
    setState(() {
      _showCountdown = true;
      _started       = false;
    });
  }

  void _startGame() {
    final c = _grid ~/ 2;
    _snake = [Point(c, c), Point(c - 1, c), Point(c - 2, c)];
    _dir       = const Point(1, 0);
    _queuedDir = const Point(1, 0);
    _food      = [];
    _walls     = [];
    _score     = 0;
    _combo     = 0;
    _dead      = false;
    _paused    = false;
    _pops.clear();

    // Generate walls
    final wallCount = _cfg.params['walls'] as int;
    for (int i = 0; i < wallCount; i++) {
      _placeWall();
    }
    // Initial food
    while (_food.length < _foodTarget) {
      _placeFood();
    }
    setState(() {
      _showCountdown = false;
      _started       = true;
    });
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(Duration(milliseconds: _speedMs), (_) => _tick());
  }

  void _placeFood() {
    for (int t = 0; t < 80; t++) {
      final p = Point(_rand.nextInt(_grid), _rand.nextInt(_grid));
      if (_isOccupied(p)) continue;
      _food.add(p);
      return;
    }
  }

  void _placeWall() {
    for (int t = 0; t < 80; t++) {
      final p = Point(_rand.nextInt(_grid), _rand.nextInt(_grid));
      // Keep clear of starting area
      if ((p.x - _grid ~/ 2).abs() < 4 && (p.y - _grid ~/ 2).abs() < 2) continue;
      if (_isOccupied(p)) continue;
      _walls.add(p);
      return;
    }
  }

  bool _isOccupied(Point<int> p) {
    if (_snake.contains(p)) return true;
    if (_food.contains(p))  return true;
    if (_walls.contains(p)) return true;
    return false;
  }

  // ── Tick ──────────────────────────────────────────────────

  void _tick() {
    if (_paused || _dead) return;

    // Apply queued direction now (avoids buffering issues if user spams)
    _dir = _queuedDir;

    final head = _snake.first;
    final next = Point(head.x + _dir.x, head.y + _dir.y);

    // Wall hit (boundary)
    if (next.x < 0 || next.x >= _grid || next.y < 0 || next.y >= _grid) {
      _die();
      return;
    }
    // Wall hit (interior)
    if (_walls.contains(next)) { _die(); return; }
    // Self collision
    if (_snake.contains(next))  { _die(); return; }

    // Eat?
    final ateIdx = _food.indexOf(next);
    final ate = ateIdx != -1;

    setState(() {
      _snake.insert(0, next);
      if (ate) {
        _food.removeAt(ateIdx);
        _combo += 1;
        final base   = 10 + (_level * 2);
        final bonus  = _combo > 2 ? (_combo - 2) * 5 : 0;
        final earned = base + bonus;
        _score += earned;
        HapticFeedback.lightImpact();
        // Floating "+N" near current head
        _pops.add(amount: earned, position: _gridToScreen(next));
        while (_food.length < _foodTarget) {
          _placeFood();
        }
      } else {
        _snake.removeLast();   // didn't grow
        if (_combo > 0 && _snake.length > 4) {
          // Slow combo decay (combo only fires from eating, this just drops it)
          // We keep _combo intact between eats, only reset on collisions.
        }
      }
    });
  }

  Offset _gridToScreen(Point<int> p) {
    final size = MediaQuery.of(context).size;
    final boardSize = size.width - 32;
    final cell = boardSize / _grid;
    // Approx — game body owns the actual position
    return Offset(p.x * cell + cell / 2, 250 + p.y * cell + cell / 2);
  }

  void _die() {
    _tickTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _dead = true);
    Future.delayed(const Duration(milliseconds: 700), _finish);
  }

  void _finish() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => LevelCompleteScreen(
        gameSlug: 'snake',
        gameName: 'Snake',
        config:   _cfg,
        score:    _score,
        outcome:  _score >= _cfg.targetScore ? 'win' : 'lose',
      ),
    )).then((replay) {
      if (!mounted) return;
      if (replay == 'replay') _beginCountdown();
      else                   _openLevelSelect();
    });
  }

  void _setDirection(int dx, int dy) {
    if (_dead || !_started) return;
    // Don't let the user reverse into themselves
    if (dx == -_dir.x && dy == -_dir.y) return;
    _queuedDir = Point(dx, dy);
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('snake')) {
      return GameStoryScreen(
        gameSlug: 'snake',
        onPlay: () { setState(() => _showStory = false); _openLevelSelect(); });
    }
    if (!_showCountdown && !_started) {
      // Cold-start: show landing → level select
      return Scaffold(
        backgroundColor: kDarkBg,
        body: SafeArea(child: _buildLanding()),
      );
    }
    if (_showCountdown) {
      return Scaffold(
        backgroundColor: kDarkBg,
        body: CountdownIntro(
          onComplete: _startGame,
          gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
        ),
      );
    }
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Stack(children: [
        _buildGame(),
        if (_paused) PauseOverlay(
          gameName: 'Snake',
          onResume: () => setState(() => _paused = false),
          onQuit:   () => Navigator.pop(context),
        ),
        // Score popups
        ValueListenableBuilder<List<ScorePop>>(
          valueListenable: _pops,
          builder: (_, list, __) => Stack(children: [
            for (final p in list)
              Positioned(
                left: p.position.dx - 30,
                top:  p.position.dy - 30,
                child: ScorePopup(
                  amount: p.amount,
                  color:  const Color(0xFF38EF7D),
                  onDone: () => _pops.remove(p.id),
                ),
              ),
          ]),
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
              color: kDarkCard2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white60, size: 20),
          ),
        ),
      ),
      const Spacer(),
      const Text('🐍', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF11998E), Color(0xFF38EF7D)]).createShader(b),
        blendMode: BlendMode.srcIn,
        child: const Text('Snake',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 40, color: Colors.white)),
      ),
      const SizedBox(height: 10),
      Text('Eat data nodes · Avoid walls\n10 levels of mounting chaos',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13,
              color: Colors.white.withOpacity(0.5), height: 1.6)),
      MiniLeaderboard(gameSlug: 'snake', gameName: 'Snake'),
      const Spacer(),
      GestureDetector(
        onTap: _openLevelSelect,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: const Color(0xFF11998E).withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: const Center(
            child: Text('Choose Level 🎮',
                style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 20, color: Colors.white)),
          ),
        ),
      ),
    ]),
  );

  Widget _buildGame() {
    final size  = MediaQuery.of(context).size;
    final board = (size.width - 32).clamp(0, 480).toDouble();
    final cell  = board / _grid;

    return Column(children: [
      // HUD
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _paused = true),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: kDarkCard2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.pause_rounded,
                  color: Colors.white60, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Text('Lv.$_level',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 14, color: Color(0xFF38EF7D))),
          const Spacer(),
          ComboMeter(combo: _combo),
          const Spacer(),
          Text('$_score',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 18, color: kNeonOrange)),
        ])),
      const SizedBox(height: 10),

      // Board
      Center(child: GestureDetector(
        onVerticalDragUpdate: (d) {
          if (d.delta.dy.abs() > 6) {
            _setDirection(0, d.delta.dy > 0 ? 1 : -1);
          }
        },
        onHorizontalDragUpdate: (d) {
          if (d.delta.dx.abs() > 6) {
            _setDirection(d.delta.dx > 0 ? 1 : -1, 0);
          }
        },
        child: Container(
          width: board, height: board,
          decoration: BoxDecoration(
            color: const Color(0xFF0A1424),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: CustomPaint(
            painter: _SnakePainter(
              grid:  _grid,
              cell:  cell,
              snake: _snake,
              food:  _food,
              walls: _walls,
              dead:  _dead,
            ),
          ),
        ),
      )),
      const SizedBox(height: 10),
      Text('Swipe to change direction',
          style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: Colors.white.withOpacity(0.4))),
      const Spacer(),

      // D-pad fallback for users who prefer buttons
      Padding(padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
        child: Column(children: [
          _dpadBtn(Icons.keyboard_arrow_up_rounded,    () => _setDirection(0, -1)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _dpadBtn(Icons.keyboard_arrow_left_rounded,  () => _setDirection(-1, 0)),
            const SizedBox(width: 50),
            _dpadBtn(Icons.keyboard_arrow_right_rounded, () => _setDirection(1, 0)),
          ]),
          _dpadBtn(Icons.keyboard_arrow_down_rounded,  () => _setDirection(0, 1)),
        ])),
    ]);
  }

  Widget _dpadBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: 50, height: 50, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: kDarkCard2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Icon(icon, color: Colors.white70, size: 26),
    ),
  );
}

class _SnakePainter extends CustomPainter {
  final int  grid;
  final double cell;
  final List<Point<int>> snake;
  final List<Point<int>> food;
  final List<Point<int>> walls;
  final bool dead;

  _SnakePainter({
    required this.grid,
    required this.cell,
    required this.snake,
    required this.food,
    required this.walls,
    required this.dead,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 0.5;
    for (int i = 0; i <= grid; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), gridPaint);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), gridPaint);
    }

    // Walls
    final wallPaint = Paint()..color = Colors.blueGrey.shade700;
    for (final w in walls) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w.x * cell + 1, w.y * cell + 1, cell - 2, cell - 2),
          const Radius.circular(3)),
        wallPaint,
      );
    }

    // Food (apples)
    for (final f in food) {
      canvas.drawCircle(
        Offset(f.x * cell + cell / 2, f.y * cell + cell / 2),
        cell * 0.34,
        Paint()..color = const Color(0xFFFF5858),
      );
      canvas.drawCircle(
        Offset(f.x * cell + cell * 0.42, f.y * cell + cell * 0.4),
        cell * 0.10,
        Paint()..color = Colors.white.withOpacity(0.5),
      );
    }

    // Snake
    for (int i = 0; i < snake.length; i++) {
      final p     = snake[i];
      final fade  = (1.0 - (i / max(snake.length, 1) * 0.4)).clamp(0.6, 1.0);
      final color = (dead ? Colors.red.shade400 : const Color(0xFF38EF7D))
          .withOpacity(fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x * cell + 1, p.y * cell + 1, cell - 2, cell - 2),
          Radius.circular(i == 0 ? 6 : 3)),
        Paint()..color = color,
      );
      // Eyes on head
      if (i == 0) {
        final eyePaint = Paint()..color = Colors.black87;
        canvas.drawCircle(
            Offset(p.x * cell + cell * 0.32, p.y * cell + cell * 0.35),
            cell * 0.06, eyePaint);
        canvas.drawCircle(
            Offset(p.x * cell + cell * 0.68, p.y * cell + cell * 0.35),
            cell * 0.06, eyePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) => true;
}
