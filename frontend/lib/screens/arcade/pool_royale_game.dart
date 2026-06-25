// lib/screens/arcade/pool_royale_game.dart
import 'dart:math';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

class _Ball {
  double x, y, r;
  double vx;       // ← initialised with default
  double vy;       // ← initialised with default
  Color color;
  bool pocketed;   // ← initialised with default
  int id;

  _Ball({
    required this.x,
    required this.y,
    required this.r,
    required this.color,
    required this.id,
    this.vx = 0.0,
    this.vy = 0.0,
    this.pocketed = false,
  });
}

class PoolRoyaleGame extends StatefulWidget {
  const PoolRoyaleGame({super.key});
  @override State<PoolRoyaleGame> createState() => _PoolRoyaleGameState();
}

class _PoolRoyaleGameState extends State<PoolRoyaleGame>
    with SingleTickerProviderStateMixin {
  static const _levels = [
    {'name': 'Beginner Table', 'balls': 4,  'pocketBonus': 50},
    {'name': 'Amateur Cup',    'balls': 7,  'pocketBonus': 75},
    {'name': 'Pro Circuit',    'balls': 10, 'pocketBonus': 100},
  ];

  int _level = 0;
  bool _showStory = true;
  bool _paused    = false;
  bool _started   = false;
  List<_Ball> _balls = [];
  int _score = 0, _shots = 0;
  bool _aiming = false, _shooting = false;
  Offset _aimStart = Offset.zero, _aimEnd = Offset.zero;
  late AnimationController _physCtrl;
  double _tableW = 300, _tableH = 180;
  final _ballR = 10.0;
  late List<Offset> _pockets;

  void _togglePause() {
    HapticFeedback.lightImpact();
    setState(() => _paused = !_paused);
  }

  Future<void> _handleQuit() async {
    setState(() => _paused = true);
    final quit = await showQuitDialog(context);
    if (!mounted) return;
    if (quit) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => GameOverScreen(result: GameResult(
              gameSlug: 'pool-royale', gameName: 'Pool Royale',
              score: _score, outcome: 'complete'))));
    } else {
      setState(() => _paused = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _physCtrl = AnimationController(
        vsync: this, duration: const Duration(hours: 1))
      ..addListener(_physStep)
      ..repeat();
  }

  @override void dispose() { _physCtrl.dispose(); super.dispose(); }

  void _initTable(double w, double h) {
    _tableW = w; _tableH = h;
    _pockets = [
      Offset(0, 0),     Offset(w / 2, 0),   Offset(w, 0),
      Offset(0, h),     Offset(w / 2, h),   Offset(w, h),
    ];
  }

  void _start() {
    final w = _tableW; final h = _tableH;
    final cueBall = _Ball(x: w * 0.25, y: h / 2, r: _ballR, color: Colors.white, id: 0);
    final colors = [
      Colors.yellow, Colors.red, Colors.blue, Colors.orange,
      Colors.purple, Colors.green, Colors.red.shade900,
      Colors.teal, Colors.pink, Colors.amber,
    ];
    final bCount   = _levels[_level]['balls'] as int;
    final ballsList = <_Ball>[cueBall];
    final startX   = w * 0.65;
    final startY   = h / 2;
    int ballId = 1; int row = 0;
    while (ballId <= bCount) {
      for (int c = 0; c <= row && ballId <= bCount; c++, ballId++) {
        ballsList.add(_Ball(
          x: startX + row * _ballR * 2,
          y: startY - row * _ballR + c * _ballR * 2,
          r: _ballR,
          color: colors[(ballId - 1) % colors.length],
          id: ballId,
        ));
      }
      row++;
    }
    setState(() {
      _balls    = ballsList;
      _started  = true;
      _score    = 0;
      _shots    = 0;
      _aiming   = false;
      _shooting = false;
    });
  }

  void _physStep() {
    if (!_shooting || _paused) return;
    bool moving = false;
    setState(() {
      for (final b in _balls) {
        if (b.pocketed) continue;
        b.x  += b.vx; b.y += b.vy;
        b.vx *= 0.985; b.vy *= 0.985;
        if (b.vx.abs() < 0.01 && b.vy.abs() < 0.01) { b.vx = 0; b.vy = 0; }
        else moving = true;

        if (b.x - b.r < 0)       { b.x = b.r;          b.vx =  b.vx.abs(); }
        if (b.x + b.r > _tableW) { b.x = _tableW - b.r; b.vx = -b.vx.abs(); }
        if (b.y - b.r < 0)       { b.y = b.r;          b.vy =  b.vy.abs(); }
        if (b.y + b.r > _tableH) { b.y = _tableH - b.r; b.vy = -b.vy.abs(); }

        for (final p in _pockets) {
          if ((b.x - p.dx).abs() < _ballR * 1.5 && (b.y - p.dy).abs() < _ballR * 1.5) {
            b.pocketed = true; b.vx = 0; b.vy = 0;
            if (b.id > 0) _score += _levels[_level]['pocketBonus'] as int;
            HapticFeedback.mediumImpact();
            break;
          }
        }
      }

      for (int i = 0; i < _balls.length; i++) {
        for (int j = i + 1; j < _balls.length; j++) {
          final a = _balls[i]; final b = _balls[j];
          if (a.pocketed || b.pocketed) continue;
          final dx = b.x - a.x; final dy = b.y - a.y;
          final d  = sqrt(dx * dx + dy * dy);
          if (d < a.r + b.r && d > 0) {
            final nx = dx / d; final ny = dy / d;
            final overlap = (a.r + b.r - d) / 2;
            a.x -= nx * overlap; a.y -= ny * overlap;
            b.x += nx * overlap; b.y += ny * overlap;
            final dvx = a.vx - b.vx; final dvy = a.vy - b.vy;
            final dot = dvx * nx + dvy * ny;
            a.vx -= dot * nx; a.vy -= dot * ny;
            b.vx += dot * nx; b.vy += dot * ny;
          }
        }
      }

      if (!moving) _shooting = false;
      final remaining = _balls.where((b) => b.id > 0 && !b.pocketed).length;
      if (remaining == 0) _finish();
    });
  }

  void _shoot() {
    final cue = _balls.first;
    if (_shooting || cue.pocketed) return;
    final dx    = _aimStart.dx - _aimEnd.dx;
    final dy    = _aimStart.dy - _aimEnd.dy;
    final power = sqrt(dx * dx + dy * dy).clamp(0, 120) / 120 * 18;
    final angle = atan2(dy, dx);
    cue.vx = cos(angle) * power;
    cue.vy = sin(angle) * power;
    HapticFeedback.heavyImpact();
    setState(() { _shooting = true; _aiming = false; _shots++; });
  }

  void _finish() {
    _physCtrl.stop();
    final bonus = max(0, 30 - _shots) * 10;
    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => GameOverScreen(result: GameResult(
            gameSlug: 'pool-royale', gameName: 'Pool Royale',
            score: _score + bonus, outcome: 'win',
            extra: {'level': _level + 1, 'shots': _shots}))));
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('pool-royale')) {
      return GameStoryScreen(
          gameSlug: 'pool-royale',
          onPlay: () => setState(() => _showStory = false));
    }
    if (!_started) {
      return Scaffold(backgroundColor: kDarkBg,
          body: SafeArea(child: _landing()));
    }
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Stack(children: [
        Column(children: [
          GameHUD(
            score:   '$_score pts',
            level:   'Pool Royale · Lv.${_level + 1}',
            paused:  _paused,
            onPause: _togglePause,
            onQuit:  _handleQuit,
            extra: Text(
              '🎱 ${_balls.where((b) => b.id > 0 && !b.pocketed).length} left  ·  $_shots shots',
              style: const TextStyle(fontFamily: 'Momo', fontSize: 11, color: Colors.white60)),
          ),
          Expanded(child: _gameBody(context)),
        ]),
        if (_paused) PauseOverlay(
          gameName:  'Pool Royale',
          onResume:  () => setState(() => _paused = false),
          onQuit:    _handleQuit,
        ),
      ])),
    );
  }

  // ── Landing ───────────────────────────────────────────────

  Widget _landing() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      Align(alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: kDarkCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white60, size: 20)))),
      const Spacer(),
      const T('🎱', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(colors: [kNeonPurple, kNeonBlue]).createShader(b),
        blendMode: BlendMode.srcIn,
        child: const T('Pool Royale',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 38, color: Colors.white))),
      const SizedBox(height: 10),
      T('Drag from cue ball to aim\nPocket all colored balls!',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Momo', fontSize: 13,
            color: Colors.white.withOpacity(0.5), height: 1.6)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final sel = i == _level;
          return GestureDetector(
            onTap: () => setState(() => _level = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(colors: [kNeonPurple, kNeonBlue]) : null,
                color: sel ? null : kDarkCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? Colors.transparent : Colors.white.withOpacity(0.08))),
              child: Text('Lv.${i + 1}',
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13, color: sel ? Colors.white : Colors.white60))));
        })),
      const SizedBox(height: 8),
      Text(_levels[_level]['name'] as String,
          style: const TextStyle(fontFamily: 'Momo', fontSize: 13, color: kNeonPurple)),
      MiniLeaderboard(gameSlug: 'pool-royale', gameName: 'Pool Royale'),
      const Spacer(),
      GestureDetector(
        onTap: _start,
        child: Container(width: double.infinity, height: 56,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kNeonPurple, kNeonBlue]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: kNeonPurple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))]),
          child: const Center(child: T('Break! 🎱',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white))))),
    ]));

  // ── Game body ─────────────────────────────────────────────

  Widget _gameBody(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final tableW = size.width - 32.0;
    final tableH = tableW * 0.55;
    if (_tableW != tableW) _initTable(tableW, tableH);
    final cue = _balls.first;
    return Column(children: [
      const SizedBox(height: 8),
      GestureDetector(
        onPanStart: (d) {
          if (_shooting || _paused) return;
          final tp = d.localPosition;
          if ((tp.dx - cue.x).abs() < 30 && (tp.dy - cue.y).abs() < 30) {
            setState(() {
              _aiming    = true;
              _aimStart  = Offset(cue.x, cue.y);
              _aimEnd    = tp;
            });
          }
        },
        onPanUpdate: (d) {
          if (!_aiming || _paused) return;
          setState(() => _aimEnd = d.localPosition);
        },
        onPanEnd: (_) { if (_aiming && !_paused) _shoot(); },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: tableW, height: tableH,
          decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B6914), width: 8)),
          child: CustomPaint(
            painter: _PoolPainter(
                balls:    _balls,
                pockets:  _pockets,
                aimStart: _aiming ? _aimStart : null,
                aimEnd:   _aiming ? _aimEnd   : null,
                tableW:   tableW,
                tableH:   tableH),
            child: const SizedBox.expand()))),
      const SizedBox(height: 10),
      Container(
        margin:  const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kDarkCard, borderRadius: BorderRadius.circular(10)),
        child: Text(
          _paused      ? '⏸ Game paused'
          : _shooting  ? '⏳ Ball rolling...'
          : _aiming    ? 'Release to shoot!'
          : cue.pocketed ? '😱 Cue ball pocketed!'
          : 'Drag from white ball to aim',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Momo', fontSize: 12, color: Colors.white60))),
      if (cue.pocketed && !_shooting && !_paused)
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                cue.x       = _tableW * 0.25;
                cue.y       = _tableH / 2;
                cue.vx      = 0;
                cue.vy      = 0;
                cue.pocketed = false;
                _score      = max(0, _score - 30);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: kNeonOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kNeonOrange.withOpacity(0.3))),
              child: const Center(child: T('↩ Place cue ball (-30 pts)',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 13, color: kNeonOrange)))))),
      const Spacer(),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Pool painter
// ─────────────────────────────────────────────────────────────

class _PoolPainter extends CustomPainter {
  final List<_Ball> balls;
  final List<Offset> pockets;
  final Offset? aimStart, aimEnd;
  final double tableW, tableH;
  const _PoolPainter({
    required this.balls, required this.pockets,
    this.aimStart, this.aimEnd,
    required this.tableW, required this.tableH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pockets) {
      canvas.drawCircle(p, 12, Paint()..color = Colors.black87);
      canvas.drawCircle(p, 10, Paint()..color = const Color(0xFF111111));
    }

    if (aimStart != null && aimEnd != null) {
      final dx = aimStart!.dx - aimEnd!.dx;
      final dy = aimStart!.dy - aimEnd!.dy;
      final d  = sqrt(dx * dx + dy * dy);
      if (d > 5) {
        final nx = dx / d; final ny = dy / d;
        final paint = Paint()
          ..color      = Colors.white.withOpacity(0.4)
          ..strokeWidth = 1.5
          ..style      = PaintingStyle.stroke;
        for (int i = 0; i < 5; i++) {
          final s = aimStart! + Offset(nx * i * 20, ny * i * 20);
          final e = aimStart! + Offset(nx * (i * 20 + 10), ny * (i * 20 + 10));
          canvas.drawLine(s, e, paint);
        }
        final double power = (d / 120).clamp(0.0, 1.0);
        canvas.drawArc(
          Rect.fromCenter(center: aimStart!, width: 60 * power, height: 60 * power),
          -pi / 2, pi * 2 * power, false,
          Paint()..color = kNeonOrange.withOpacity(0.5)..strokeWidth = 2..style = PaintingStyle.stroke);
      }
    }

    for (final b in balls) {
      if (b.pocketed) continue;
      canvas.drawCircle(Offset(b.x + 2, b.y + 2), b.r, Paint()..color = Colors.black26);
      canvas.drawCircle(
        Offset(b.x, b.y), b.r,
        Paint()..color = b.color..shader = RadialGradient(
          colors: [b.color.withOpacity(0.6), b.color],
          stops: const [0.0, 1.0],
          center: const Alignment(-0.3, -0.3),
        ).createShader(Rect.fromCircle(center: Offset(b.x, b.y), radius: b.r)));
      canvas.drawCircle(
          Offset(b.x - b.r * 0.3, b.y - b.r * 0.3), b.r * 0.25,
          Paint()..color = Colors.white.withOpacity(0.7));
      if (b.id > 0) {
        final tp = TextPainter(
          text: TextSpan(text: '${b.id}',
              style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(b.x - tp.width / 2, b.y - tp.height / 2));
      }
    }
  }

  @override bool shouldRepaint(_PoolPainter o) => true;
}