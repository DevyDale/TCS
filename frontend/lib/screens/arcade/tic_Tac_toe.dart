// lib/screens/arcade/tic_Tac_toe.dart
//
// Tic Tac Toe — two modes in one widget:
//
//  1. SINGLE-PLAYER (mp == null): the existing 10-level vs-AI game
//     (level select, depth-scaled minimax, LevelCompleteScreen). Unchanged.
//
//  2. VERSUS (mp != null): a live shared-board 1v1 over the arcade match
//     WebSocket. Both phones open the same GameSession and share one board.
//     • participants[0] (the challenger) is X and moves first; [1] is O.
//     • Each move broadcasts the full board + whose turn is next via
//       broadcastState; the other phone applies it, so no one can move out
//       of turn and the two boards never diverge.
//     • When the board resolves, each side submits a result (win 100 /
//       lose 0 / draw 50); the server's settle_match awards the pot.
//     • Quitting forfeits the match to the opponent.
import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';
import 'level_system.dart';
import 'levels/tic_tac_toe_levels.dart';
import '../../services/match_ws_service.dart';

class TicTacToeGame extends StatefulWidget {
  // Versus mode is active when [mp] is non-null.
  final MultiplayerSession? mp;
  final bool iAmX;       // true if this device is participants[0] (challenger)
  final String myId;     // this device's user_id (to read presence)

  const TicTacToeGame({super.key, this.mp, this.iAmX = true, this.myId = ''});

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame>
    with SingleTickerProviderStateMixin {
  static const X = 'X', O = 'O', EMPTY = '';
  List<String> _board = List.filled(9, EMPTY);

  // ── Single-player state ──
  bool _playerTurn = true;
  String? _winner;
  bool _draw = false;
  bool _aiThinking = false;
  bool _ending = false;
  int _level = 1; // 1-based; indexes kTicTacToeLevels[_level - 1]
  bool _started = false;
  final _rng = Random();

  // ── Versus state ──
  MatchWsService? _ws;
  StreamSubscription<MatchEvent>? _wsSub;
  bool _oppConnected = false;
  String _turn = X;          // whose turn it is (X always starts)
  bool _versusDone = false;
  bool _resultSent = false;
  bool _settled = false;
  String _settledText = '';
  bool _settledWin = false;

  late final AnimationController _winCtrl;
  late final Animation<double> _winScale;

  bool get _versus => widget.mp != null;
  String get _mySym => widget.iAmX ? X : O;
  String get _oppSym => widget.iAmX ? O : X;
  LevelConfig get _cfg => kTicTacToeLevels[_level - 1];

  @override
  void initState() {
    super.initState();
    _winCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _winScale = CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut);
    if (_versus) _connectVersus();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.dispose();
    _winCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  Shared helpers
  // ════════════════════════════════════════════════════════════
  String? _checkWinner(List<String> b) {
    const lines = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (final l in lines) {
      if (b[l[0]] != EMPTY && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) return b[l[0]];
    }
    if (!b.contains(EMPTY)) return 'draw';
    return null;
  }

  List<int> _wins() {
    const lines = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (final l in lines) {
      if (_board[l[0]] != EMPTY && _board[l[0]] == _board[l[1]] && _board[l[1]] == _board[l[2]]) {
        return l;
      }
    }
    return [];
  }

  // Shared board grid used by both modes.
  Widget _boardWidget(void Function(int) onCell) {
    final winLine = _wins();
    return AspectRatio(aspectRatio: 1,
      child: Container(decoration: BoxDecoration(color: kDarkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Padding(padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: 9,
            itemBuilder: (_, i) {
              final val = _board[i];
              final isWin = winLine.contains(i);
              final isX = val == X;
              final isO = val == O;
              return GestureDetector(
                onTap: () => onCell(i),
                child: AnimatedContainer(duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: isWin
                        ? (isX ? Colors.green.shade900 : Colors.red.shade900)
                        : kDarkCard2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isWin
                        ? (isX ? Colors.green.shade400 : kNeonRed)
                        : Colors.white.withOpacity(0.07), width: isWin ? 2 : 1)),
                  child: Center(child: isX
                      ? ShaderMask(shaderCallback: (b) => const LinearGradient(
                            colors: [kNeonBlue, kNeonPurple]).createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: const T('X', style: TextStyle(fontFamily: 'Alfa',
                              fontSize: 42, color: Colors.white)))
                      : isO ? ShaderMask(shaderCallback: (b) => const LinearGradient(
                            colors: [kNeonOrange, kNeonRed]).createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: const T('O', style: TextStyle(fontFamily: 'Alfa',
                              fontSize: 42, color: Colors.white)))
                      : null),
                ),
              );
            },
          ))));
  }

  @override
  Widget build(BuildContext context) {
    if (_versus) {
      return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _buildVersus()));
    }
    if (!_started) return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _buildLanding()));
    return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _buildGame()));
  }

  // ════════════════════════════════════════════════════════════
  //  VERSUS MODE
  // ════════════════════════════════════════════════════════════
  Future<void> _connectVersus() async {
    _ws = MatchWsService();
    _wsSub = _ws!.stream.listen(_onWsEvent);
    await _ws!.connect(widget.mp!.sessionId);
  }

  void _onWsEvent(MatchEvent e) {
    if (!mounted) return;
    switch (e.type) {
      case 'presence':
        final uid    = e.raw['user_id']?.toString() ?? '';
        final isPlayer = e.raw['is_player'] == true;
        final joined = e.raw['joined'] == true;
        if (isPlayer && uid.isNotEmpty && uid != widget.myId && joined) {
          setState(() => _oppConnected = true);
        }
        break;

      case 'state':
        final p = e.payload;
        if (p == null) break;
        final board = (p['board'] as List?)?.map((x) => x.toString()).toList();
        if (board == null || board.length != 9) break;
        final done   = p['done'] == true;
        final winner = p['winner']?.toString();
        setState(() {
          _board = board;
          _turn = (p['turn']?.toString() ?? _oppSym);
          _oppConnected = true;
          if (done) _versusDone = true;
        });
        if (done && winner != null) {
          _winCtrl.forward(from: 0);
          _submitVersusResult(winner);
        }
        break;

      case 'result':
        // Opponent reported their score — informational only.
        break;

      case 'forfeit':
        if (!mounted) return;
        setState(() => _versusDone = true);
        break;

      case 'settled':
        final winnerId = e.raw['winner']?.toString();
        final draw     = e.raw['draw'] == true;
        final pot      = e.raw['pot'] ?? (widget.mp!.wager * 2);
        setState(() {
          _settled = true;
          _versusDone = true;
          if (draw || winnerId == null) {
            _settledText = 'Draw — your wager is refunded.';
            _settledWin  = false;
          } else if (winnerId == widget.myId) {
            _settledText = 'You win the pot! 🪙 $pot';
            _settledWin  = true;
          } else {
            _settledText = 'You lost the match.';
            _settledWin  = false;
          }
        });
        // Auto-return after a few seconds if the player doesn't tap.
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _settled) Navigator.of(context).maybePop();
        });
        break;

      case 'error':
        final msg = e.raw['message']?.toString() ?? 'Match error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kNeonRed));
        break;
    }
  }

  void _versusTap(int i) {
    if (_versusDone || !_oppConnected) return;
    if (_turn != _mySym) return;          // not my turn
    if (_board[i] != EMPTY) return;
    HapticFeedback.lightImpact();

    final newBoard = List<String>.from(_board);
    newBoard[i] = _mySym;
    final w = _checkWinner(newBoard);
    bool done = false;
    String? winner;
    String nextTurn = _oppSym;
    if (w == _mySym) { done = true; winner = _mySym; nextTurn = _mySym; }
    else if (w == 'draw') { done = true; winner = 'draw'; }

    setState(() {
      _board = newBoard;
      _turn = nextTurn;
      if (done) _versusDone = true;
    });

    _ws?.broadcastState({
      'board': newBoard,
      'turn': nextTurn,
      'done': done,
      'winner': winner,
    });

    if (done) {
      HapticFeedback.heavyImpact();
      _winCtrl.forward(from: 0);
      _submitVersusResult(winner!);
    }
  }

  // Submit my result exactly once. `winner` is 'X' / 'O' / 'draw'.
  void _submitVersusResult(String winner) {
    if (_resultSent) return;
    _resultSent = true;
    final myScore = winner == 'draw' ? 50 : (winner == _mySym ? 100 : 0);
    _ws?.submitResult(myScore);
  }

  Future<void> _confirmForfeit() async {
    if (_settled) { Navigator.of(context).maybePop(); return; }
    final quit = await showQuitDialog(context, isMultiplayer: true);
    if (!mounted) return;
    if (quit) {
      _ws?.forfeit();
      Navigator.of(context).maybePop();
    }
  }

  Widget _buildVersus() {
    final opp = widget.mp!.opponentTag.isEmpty ? 'Opponent' : widget.mp!.opponentTag;
    final myTurn = _turn == _mySym;
    final status = !_oppConnected
        ? 'Waiting for $opp to join…'
        : _versusDone
            ? (_settled ? '' : 'Settling…')
            : (myTurn ? '🎮 Your turn ($_mySym)' : "⏳ $opp's turn");
    final statusColor = !_oppConnected
        ? Colors.white54
        : (myTurn && !_versusDone) ? Colors.green.shade400 : Colors.white70;

    return Stack(children: [
      Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Row(children: [
          GestureDetector(onTap: _confirmForfeit, child: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.07))),
            child: const Icon(Icons.flag_rounded, color: Colors.white60, size: 18))),
          const Spacer(),
          ShaderMask(shaderCallback: (b) => const LinearGradient(
              colors: [kNeonOrange, kNeonRed]).createShader(b), blendMode: BlendMode.srcIn,
            child: Text('VS  $opp', style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 16, color: Colors.white))),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(10)),
            child: Text('🪙 ${widget.mp!.wager * 2}', style: const TextStyle(
                fontFamily: 'Momo', fontSize: 12, color: Color(0xFFFFD700)))),
        ]),
        const SizedBox(height: 6),
        Text('You are $_mySym', style: TextStyle(fontFamily: 'Momo', fontSize: 12,
            color: Colors.white.withOpacity(0.4))),
        const SizedBox(height: 18),
        AnimatedSwitcher(duration: const Duration(milliseconds: 300),
          child: Text(status, key: ValueKey(status),
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 18, color: statusColor))),
        const SizedBox(height: 18),
        Expanded(child: Center(child: _boardWidget(_versusTap))),
        const SizedBox(height: 20),
      ])),
      if (!_oppConnected && !_settled)
        Container(color: Colors.black.withOpacity(0.55),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: kNeonOrange),
            const SizedBox(height: 16),
            Text('Waiting for $opp…', style: const TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ]))),
      if (_settled)
        Container(color: Colors.black.withOpacity(0.8),
          child: Center(child: Container(margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: kDarkCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: (_settledWin ? Colors.green.shade400 : kNeonRed)
                    .withOpacity(0.4))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_settledWin ? '🏆' : '🤝', style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(_settledText, textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Alfa', fontSize: 20, color: Colors.white)),
              const SizedBox(height: 20),
              GestureDetector(onTap: () => Navigator.of(context).maybePop(),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
                      borderRadius: BorderRadius.circular(14)),
                  child: const T('Back to Arcade', style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)))),
            ])))),
    ]);
  }

  // ════════════════════════════════════════════════════════════
  //  SINGLE-PLAYER MODE (vs AI, 10 levels) — unchanged behaviour
  // ════════════════════════════════════════════════════════════
  int _minimax(List<String> b, bool isMax, int depth) {
    final r = _checkWinner(b);
    if (r == O) return 10 - depth;
    if (r == X) return depth - 10;
    if (r == 'draw') return 0;
    if (depth > (_cfg.params['aiDepth'] as int)) return 0;

    var best = isMax ? -999 : 999;
    for (var i = 0; i < 9; i++) {
      if (b[i] != EMPTY) continue;
      b[i] = isMax ? O : X;
      final v = _minimax(b, !isMax, depth + 1);
      b[i] = EMPTY;
      best = isMax ? (v > best ? v : best) : (v < best ? v : best);
    }
    return best;
  }

  void _aiMove() async {
    setState(() => _aiThinking = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final empties = [for (var i = 0; i < 9; i++) if (_board[i] == EMPTY) i];
    int move = -1;
    final randomness = (_cfg.params['aiRandomness'] as num).toDouble();
    if (empties.isNotEmpty && _rng.nextDouble() < randomness) {
      move = empties[_rng.nextInt(empties.length)];
    } else {
      int best = -999;
      final b = List<String>.from(_board);
      for (var i = 0; i < 9; i++) {
        if (b[i] != EMPTY) continue;
        b[i] = O;
        final v = _minimax(b, false, 0);
        b[i] = EMPTY;
        if (v > best) { best = v; move = i; }
      }
    }
    if (move != -1) _board[move] = O;

    final w = _checkWinner(_board);
    setState(() {
      _aiThinking = false;
      if (w == O) {
        _winner = O;
        _winCtrl.forward(from: 0);
        _endLevel(0, 'lose');
      } else if (w == 'draw') {
        _draw = true;
        _winCtrl.forward(from: 0);
        _endLevel(_drawScore(), 'win');
      } else {
        _playerTurn = true;
      }
    });
  }

  void _tap(int i) {
    if (_board[i] != EMPTY || _winner != null || _draw || !_playerTurn || _aiThinking) return;
    HapticFeedback.lightImpact();
    setState(() { _board[i] = X; _playerTurn = false; });
    final w = _checkWinner(_board);
    if (w == X) {
      HapticFeedback.heavyImpact();
      setState(() => _winner = X);
      _winCtrl.forward(from: 0);
      _endLevel(_cfg.targetScore, 'win');
    } else if (w == 'draw') {
      setState(() => _draw = true);
      _winCtrl.forward(from: 0);
      _endLevel(_drawScore(), 'win');
    } else {
      _aiMove();
    }
  }

  int _drawScore() => (_cfg.targetScore * 0.75).ceil();

  void _endLevel(int score, String outcome) {
    if (_ending) return;
    _ending = true;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => LevelCompleteScreen(
          gameSlug: 'tic-tac-toe', gameName: 'Tic Tac Toe',
          config: _cfg, score: score, outcome: outcome)));
    });
  }

  Future<void> _openLevelSelect() async {
    final picked = await Navigator.push<int>(context, MaterialPageRoute(
      builder: (_) => const LevelSelectScreen(
        gameSlug: 'tic-tac-toe',
        gameName: 'Tic Tac Toe',
        gameEmoji: '⭕',
        gradient: [kNeonOrange, kNeonRed],
        levels: kTicTacToeLevels,
      ),
    ));
    if (picked == null || !mounted) return;
    setState(() {
      _level = picked;
      _started = true;
      _ending = false;
      _board = List.filled(9, EMPTY);
      _winner = null;
      _draw = false;
      _playerTurn = true;
      _aiThinking = false;
    });
  }

  Widget _buildLanding() => Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: () => Navigator.pop(context),
      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: kDarkCard2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white60, size: 20)))),
    const Spacer(),
    const T('⭕', style: TextStyle(fontSize: 80)),
    const SizedBox(height: 16),
    ShaderMask(shaderCallback: (b) => const LinearGradient(
        colors: [kNeonOrange, kNeonRed]).createShader(b), blendMode: BlendMode.srcIn,
      child: const T('Tic Tac Toe', style: TextStyle(fontFamily: 'Alfa', fontSize: 38,
          color: Colors.white))),
    const SizedBox(height: 10),
    T('Beat the bot — it gets smarter every level.\nLv.10 plays perfectly: a draw is a win.',
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Momo', fontSize: 13,
          color: Colors.white.withOpacity(0.5), height: 1.6)),
    const SizedBox(height: 24),
    MiniLeaderboard(gameSlug: 'tic-tac-toe', gameName: 'Tic Tac Toe'),
    const Spacer(),
    GestureDetector(onTap: _openLevelSelect,
      child: Container(width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: kNeonOrange.withOpacity(0.4),
              blurRadius: 20, offset: const Offset(0, 6))]),
        child: const Center(child: T('Choose Level ▶', style: TextStyle(
            fontFamily: 'Alfa', fontSize: 20, color: Colors.white))))),
  ]));

  Widget _buildGame() {
    final status = _winner == X ? '🎉 You Win!' : _winner == O
        ? '🤖 AI Wins!' : _draw ? '🤝 Draw!' : _aiThinking ? '🤖 AI thinking...' : '🎮 Your Turn (X)';
    final statusColor = _winner == X ? Colors.green.shade400 : _winner == O ? kNeonRed
        : _draw ? kNeonOrange : Colors.white70;

    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.07))),
          child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18))),
        const Spacer(),
        Text('Lv.$_level · ${_cfg.title}', style: const TextStyle(fontFamily: 'Alfa',
            fontSize: 14, color: kNeonOrange)),
      ]),
      const SizedBox(height: 24),
      AnimatedSwitcher(duration: const Duration(milliseconds: 300),
        child: Text(status, key: ValueKey(status),
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 18, color: statusColor))),
      const SizedBox(height: 24),
      Expanded(child: Center(child: _boardWidget(_tap))),
      const SizedBox(height: 20),
    ]));
  }
}
