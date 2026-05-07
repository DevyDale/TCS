// lib/screens/arcade/battle_bots_game.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

enum _BotState { idle, selected, dead }
enum _Turn { player, enemy }

class _Bot {
  int x, y, hp, maxHp, atk, range;
  _BotState state;
  bool isPlayer;
  String emoji;
  Color color;

  _Bot({
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.atk,
    required this.range,
    required this.isPlayer,
    required this.emoji,
    required this.color,
    this.state = _BotState.idle, // ← default, so it's always initialised
  });
}

class BattleBotsGame extends StatefulWidget {
  const BattleBotsGame({super.key});
  @override State<BattleBotsGame> createState() => _BattleBotsGameState();
}

class _BattleBotsGameState extends State<BattleBotsGame> {
  static const _levels = [
    {'name': 'Circuit Beginner', 'grid': 5, 'enemyBots': 2, 'enemyHp': 3, 'enemyAtk': 1},
    {'name': 'Steel Arena',      'grid': 6, 'enemyBots': 3, 'enemyHp': 4, 'enemyAtk': 2},
    {'name': 'Omega Protocol',   'grid': 7, 'enemyBots': 4, 'enemyHp': 5, 'enemyAtk': 2},
  ];

  int _level = 0;
  bool _started = false;
  List<_Bot> _bots = [];
  _Turn _turn = _Turn.player;
  _Bot? _selected;
  List<String> _log = [];
  int _score = 0;
  String _statusMsg = 'Select a bot to move';
  bool _showStory = true;
  bool _paused = false;
  bool _gameOver = false;
  final _rng = Random();

  Future<void> _handleQuit() async {
    setState(() => _paused = true);
    final quit = await showQuitDialog(context);
    if (!mounted) return;
    if (quit) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => GameOverScreen(result: GameResult(
              gameSlug: 'battle-bots', gameName: 'Battle Bots',
              score: _score, outcome: 'complete'))));
    } else {
      setState(() => _paused = false);
    }
  }

  @override void initState() { super.initState(); }

  Map get _cfg  => _levels[_level];
  int get _grid => _cfg['grid'] as int;

  void _start() {
    final g = _grid;
    final playerBots = [
      _Bot(x: 0, y: g - 1, hp: 5, maxHp: 5, atk: 2, range: 1, isPlayer: true, emoji: '🤖', color: kNeonBlue),
      _Bot(x: 1, y: g - 1, hp: 4, maxHp: 4, atk: 1, range: 2, isPlayer: true, emoji: '🦾', color: kNeonPurple),
      _Bot(x: 2, y: g - 1, hp: 3, maxHp: 3, atk: 3, range: 1, isPlayer: true, emoji: '⚡', color: kNeonOrange),
    ];
    final enemyBots = List.generate(
      _cfg['enemyBots'] as int,
      (i) => _Bot(
        x: i + 1, y: 0,
        hp:     _cfg['enemyHp']  as int,
        maxHp:  _cfg['enemyHp']  as int,
        atk:    _cfg['enemyAtk'] as int,
        range: 1, isPlayer: false, emoji: '👾', color: kNeonRed,
      ),
    );
    setState(() {
      _bots = [...playerBots, ...enemyBots];
      _started = true;
      _turn = _Turn.player;
      _selected = null;
      _log = [];
      _score = 0;
      _statusMsg = 'Your turn! Select a bot.';
      _gameOver = false;
    });
  }

  List<_Bot> get _playerBots =>
      _bots.where((b) => b.isPlayer && b.state != _BotState.dead).toList();
  List<_Bot> get _enemyBots  =>
      _bots.where((b) => !b.isPlayer && b.state != _BotState.dead).toList();

  // Returns a sentinel _Bot (hp==0, x==-1) when nothing is found.
  // Using a sentinel avoids nullable gymnastics and matches the original logic.
  _Bot _sentinel({bool isPlayer = true}) => _Bot(
    x: -1, y: -1, hp: 0, maxHp: 1, atk: 0, range: 0,
    isPlayer: isPlayer, emoji: '', color: Colors.transparent,
  );

  void _tapCell(int x, int y) {
    if (_gameOver || _turn != _Turn.player) return;

    // Check if tapped a friendly bot
    final bot = _bots.firstWhere(
      (b) => b.x == x && b.y == y && b.isPlayer && b.state != _BotState.dead,
      orElse: _sentinel,
    );
    if (bot.x == x && bot.y == y && bot.hp > 0) {
      setState(() {
        for (final b in _bots) { if (b.isPlayer) b.state = _BotState.idle; }
        _selected = bot;
        bot.state = _BotState.selected;
        _statusMsg = '${bot.emoji} selected — tap to move or attack';
      });
      return;
    }

    if (_selected == null) return;

    // Check if tapped an enemy in range
    final enemy = _bots.firstWhere(
      (b) => b.x == x && b.y == y && !b.isPlayer && b.state != _BotState.dead,
      orElse: () => _sentinel(isPlayer: false),
    );
    if (enemy.x == x && enemy.y == y && enemy.hp > 0) {
      final dist = ((_selected!.x - x).abs() + (_selected!.y - y).abs());
      if (dist <= _selected!.range) {
        _attack(_selected!, enemy);
      } else {
        setState(() => _statusMsg = 'Too far to attack! (range ${_selected!.range})');
      }
      return;
    }

    // Move
    final blocked = _bots.any((b) => b.x == x && b.y == y && b.state != _BotState.dead);
    if (!blocked && ((_selected!.x - x).abs() + (_selected!.y - y).abs()) == 1) {
      setState(() {
        _selected!.x = x;
        _selected!.y = y;
        _selected!.state = _BotState.idle;
        _selected = null;
        _statusMsg = 'Moved! Select next bot or end turn.';
      });
    }
  }

  void _attack(_Bot attacker, _Bot defender) {
    HapticFeedback.heavyImpact();
    final dmg = attacker.atk + _rng.nextInt(2);
    setState(() {
      defender.hp = (defender.hp - dmg).clamp(0, defender.maxHp);
      if (defender.hp == 0) {
        defender.state = _BotState.dead;
        _score += 50 + _level * 20;
      }
      _log.insert(0, '${attacker.emoji} → ${defender.emoji}: -$dmg HP');
      if (_log.length > 5) _log.removeLast();
      attacker.state = _BotState.idle;
      _selected = null;
      _statusMsg = 'Attacked! -$dmg damage.';
      _checkWin();
    });
  }

  void _endTurn() {
    if (_turn != _Turn.player || _gameOver) return;
    setState(() {
      _turn = _Turn.enemy;
      for (final b in _bots) { b.state = _BotState.idle; }
      _selected = null;
    });
    _enemyTurn();
  }

  void _enemyTurn() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _paused) return;
    for (final enemy in _enemyBots) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final targets = _playerBots;
      if (targets.isEmpty) break;
      targets.sort((a, b) =>
          (a.x - enemy.x).abs() + (a.y - enemy.y).abs() -
          ((b.x - enemy.x).abs() + (b.y - enemy.y).abs()));
      final target = targets.first;
      final dist = (enemy.x - target.x).abs() + (enemy.y - target.y).abs();
      if (dist <= enemy.range) {
        final dmg = enemy.atk + _rng.nextInt(2);
        setState(() {
          target.hp = (target.hp - dmg).clamp(0, target.maxHp);
          if (target.hp == 0) target.state = _BotState.dead;
          _log.insert(0, '${enemy.emoji} → ${target.emoji}: -$dmg HP');
          if (_log.length > 5) _log.removeLast();
        });
        _checkWin();
        if (_gameOver) return;
      } else {
        final dx = (target.x - enemy.x).sign;
        final dy = (target.y - enemy.y).sign;
        setState(() {
          if (dx != 0 && !_bots.any((b) => b.x == enemy.x + dx && b.y == enemy.y && b.state != _BotState.dead)) {
            enemy.x += dx;
          } else if (dy != 0 && !_bots.any((b) => b.x == enemy.x && b.y == enemy.y + dy && b.state != _BotState.dead)) {
            enemy.y += dy;
          }
        });
      }
    }
    if (!mounted) return;
    setState(() { _turn = _Turn.player; _statusMsg = 'Your turn! Select a bot.'; });
  }

  void _checkWin() {
    if (_enemyBots.isEmpty) {
      _score += 200 + _level * 100;
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => GameOverScreen(result: GameResult(
              gameSlug: 'battle-bots', gameName: 'Battle Bots',
              score: _score, outcome: 'win', extra: {'level': _level + 1}))));
      _gameOver = true;
    } else if (_playerBots.isEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => GameOverScreen(result: GameResult(
              gameSlug: 'battle-bots', gameName: 'Battle Bots',
              score: _score, outcome: 'lose', extra: {'level': _level + 1}))));
      _gameOver = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('battle-bots')) {
      return GameStoryScreen(
          gameSlug: 'battle-bots',
          onPlay: () => setState(() => _showStory = false));
    }
    if (!_started) {
      return Scaffold(backgroundColor: kDarkBg,
          body: SafeArea(child: _landing()));
    }
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Stack(children: [
        _game(context),
        if (_paused) PauseOverlay(
            gameName: 'Battle Bots',
            onResume: () => setState(() => _paused = false),
            onQuit: _handleQuit),
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
      const Text('🤖', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 16),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(colors: [kNeonBlue, kNeonPurple]).createShader(b),
        blendMode: BlendMode.srcIn,
        child: const Text('Battle Bots',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 38, color: Colors.white))),
      const SizedBox(height: 10),
      Text('Turn-based strategy · Select & move bots\nAttack enemies in range',
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
                gradient: sel ? const LinearGradient(colors: [kNeonBlue, kNeonPurple]) : null,
                color: sel ? null : kDarkCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? Colors.transparent : Colors.white.withOpacity(0.08))),
              child: Text('Lv.${i + 1}',
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13, color: sel ? Colors.white : Colors.white60))));
        })),
      const SizedBox(height: 8),
      Text(_levels[_level]['name'] as String,
          style: const TextStyle(fontFamily: 'Momo', fontSize: 13, color: kNeonBlue)),
      MiniLeaderboard(gameSlug: 'battle-bots', gameName: 'Battle Bots'),
      const Spacer(),
      GestureDetector(
        onTap: _start,
        child: Container(width: double.infinity, height: 56,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kNeonBlue, kNeonPurple]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: kNeonBlue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))]),
          child: const Center(child: Text('Deploy Bots! ⚡',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white))))),
    ]));

  // ── Game ──────────────────────────────────────────────────

  Widget _game(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final gridPx   = (size.width - 32).clamp(0, 440).toDouble();
    final cellSize = gridPx / _grid;
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text('Lv.${_level + 1}', style: const TextStyle(fontFamily: 'Alfa', fontSize: 13, color: kNeonBlue)),
          const SizedBox(width: 8),
          Expanded(child: Text(_statusMsg,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 11, color: Colors.white60),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('$_score pts', style: const TextStyle(fontFamily: 'Alfa', fontSize: 13, color: kNeonOrange)),
        ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: (_turn == _Turn.player ? kNeonBlue : kNeonRed).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Text(_turn == _Turn.player ? '⚔️ Your Turn' : '🤖 Enemy Turn',
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 11,
                  color: _turn == _Turn.player ? kNeonBlue : kNeonRed)))),
      Center(child: Container(width: gridPx, height: gridPx,
        decoration: BoxDecoration(color: const Color(0xFF0D1F35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _grid),
          itemCount: _grid * _grid,
          itemBuilder: (_, idx) {
            final x = idx % _grid;
            final y = idx ~/ _grid;
            final bot = _bots.firstWhere(
              (b) => b.x == x && b.y == y && b.state != _BotState.dead,
              orElse: _sentinel,
            );
            final hasBot  = bot.x == x && bot.y == y && bot.hp > 0;
            final hasSel  = _selected != null;
            final inRange = hasSel &&
                ((_selected!.x - x).abs() + (_selected!.y - y).abs()) <= _selected!.range;
            final isMove  = hasSel &&
                ((_selected!.x - x).abs() + (_selected!.y - y).abs()) == 1 &&
                !_bots.any((b) => b.x == x && b.y == y && b.state != _BotState.dead);
            return GestureDetector(
              onTap: () => _tapCell(x, y),
              child: Container(
                decoration: BoxDecoration(
                  color: isMove ? kNeonBlue.withOpacity(0.12)
                      : (inRange && hasBot && !bot.isPlayer) ? kNeonRed.withOpacity(0.12)
                      : (x + y) % 2 == 0 ? Colors.white.withOpacity(0.02) : Colors.transparent,
                  border: Border.all(color: Colors.white.withOpacity(0.04))),
                child: hasBot ? Stack(children: [
                  if (bot.state == _BotState.selected) Container(
                    decoration: BoxDecoration(color: kNeonBlue.withOpacity(0.25),
                        border: Border.all(color: kNeonBlue, width: 2))),
                  Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(bot.emoji, style: TextStyle(fontSize: cellSize * 0.45)),
                    Container(width: cellSize * 0.7, height: 3,
                      decoration: BoxDecoration(color: Colors.black26,
                          borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        widthFactor: bot.hp / bot.maxHp,
                        alignment: Alignment.centerLeft,
                        child: Container(decoration: BoxDecoration(
                            color: bot.hp > bot.maxHp / 2 ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(2))))),
                  ])),
                ]) : const SizedBox.shrink()));
          }))),
      if (_log.isNotEmpty) Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kDarkCard, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: _log.take(3).map((l) => Text(l,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 10, color: Colors.white54))).toList())),
      Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Row(children: [
          ..._playerBots.map((b) => Padding(padding: const EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(b.emoji, style: const TextStyle(fontSize: 16)),
              Text(' ${b.hp}/${b.maxHp}',
                  style: const TextStyle(fontFamily: 'Momo', fontSize: 10, color: Colors.white54)),
            ]))),
          const Spacer(),
          ..._enemyBots.map((b) => Padding(padding: const EdgeInsets.only(left: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(b.emoji, style: const TextStyle(fontSize: 16)),
              Text(' ${b.hp}/${b.maxHp}',
                  style: const TextStyle(fontFamily: 'Momo', fontSize: 10, color: Colors.white54)),
            ]))),
        ])),
      const Spacer(),
      if (_turn == _Turn.player)
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GestureDetector(
            onTap: _endTurn,
            child: Container(width: double.infinity, height: 44,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('End Turn →',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      color: Colors.white, fontSize: 14)))))),
    ]);
  }
}