// lib/screens/arcade/tic_tac_toe_game.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key});
  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame>
    with SingleTickerProviderStateMixin {
  static const X = 'X', O = 'O', EMPTY = '';
  List<String> _board = List.filled(9, EMPTY);
  bool _playerTurn = true;
  String? _winner;
  bool _draw = false;
  bool _aiThinking = false;
  int _playerWins = 0, _aiWins = 0, _draws = 0;
  int _totalScore = 0;
  String _difficulty = 'Medium';
  bool _started = false;

  late final AnimationController _winCtrl;
  late final Animation<double> _winScale;

  @override
  void initState() {
    super.initState();
    _winCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _winScale = CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() { 
    _winCtrl.dispose(); 
    super.dispose(); 
  }

  // ── Minimax AI ─────────────────────────────────────────────
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

  int _minimax(List<String> b, bool isMax, int depth) {
    final r = _checkWinner(b);
    if (r == O) return 10 - depth;
    if (r == X) return depth - 10;
    if (r == 'draw') return 0;
    if (_difficulty == 'Easy' && depth > 1) return 0;
    if (_difficulty == 'Medium' && depth > 3) return 0;

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

    int best = -999, move = -1;
    final b = List<String>.from(_board);
    for (var i = 0; i < 9; i++) {
      if (b[i] != EMPTY) continue;
      b[i] = O;
      final v = _minimax(b, false, 0);
      b[i] = EMPTY;
      if (v > best) { best = v; move = i; }
    }
    if (move != -1) _board[move] = O;

    final w = _checkWinner(_board);
    setState(() {
      _aiThinking = false;
      if (w == O) { 
        _winner = O; 
        _aiWins++; 
        _winCtrl.forward(from: 0); 
      } else if (w == 'draw') { 
        _draw = true; 
        _draws++; 
        _winCtrl.forward(from: 0); 
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
      final pts = _difficulty == 'Easy' ? 20 : _difficulty == 'Medium' ? 35 : 50;
      setState(() { _winner = X; _playerWins++; _totalScore += pts; });
      _winCtrl.forward(from: 0);
    } else if (w == 'draw') {
      setState(() { _draw = true; _draws++; _totalScore += 10; });
      _winCtrl.forward(from: 0);
    } else {
      _aiMove();
    }
  }

  void _reset() { 
    setState(() { 
      _board = List.filled(9, EMPTY); 
      _winner = null;
      _draw = false; 
      _playerTurn = true; 
      _aiThinking = false; 
    }); 
  }

  void _finish() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => GameOverScreen(result: GameResult(
        gameSlug: 'tic-tac-toe', 
        gameName: 'Tic Tac Toe',
        score: _totalScore,
        outcome: _playerWins > _aiWins ? 'win' : _playerWins < _aiWins ? 'lose' : 'draw',
      ))));
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _buildLanding()));
    return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _buildGame()));
  }

  Widget _buildLanding() => Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: () => Navigator.pop(context),
      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: kDarkCard2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white60, size: 20)))),
    const Spacer(),
    const Text('⭕', style: TextStyle(fontSize: 80)),
    const SizedBox(height: 16),
    ShaderMask(shaderCallback: (b) => LinearGradient(
        colors: [kNeonOrange, kNeonRed]).createShader(b), blendMode: BlendMode.srcIn,
      child: const Text('Tic Tac Toe', style: TextStyle(fontFamily: 'Alfa', fontSize: 38,
          color: Colors.white))),
    const SizedBox(height: 16),
    Text('Select Difficulty', style: TextStyle(fontFamily: 'Momo', fontSize: 12,
        color: Colors.white.withOpacity(0.4))),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.center, children:
        ['Easy','Medium','Hard'].map<Widget>((d) => GestureDetector(
      onTap: () => setState(() => _difficulty = d),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: _difficulty == d ? const LinearGradient(
              colors: [kNeonOrange, kNeonRed]) : null,
          color: _difficulty == d ? null : kDarkCard2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _difficulty == d
              ? Colors.transparent : Colors.white.withOpacity(0.08))),
        child: Text(d, style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
            fontSize: 13, color: _difficulty == d ? Colors.white : Colors.white60))),
    )).toList()),
    const SizedBox(height: 16),
    MiniLeaderboard(gameSlug: 'tic-tac-toe', gameName: 'Tic Tac Toe'),
    const Spacer(),
    GestureDetector(onTap: () => setState(() => _started = true),
      child: Container(width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: kNeonOrange.withOpacity(0.4),
              blurRadius: 20, offset: const Offset(0, 6))]),
        child: const Center(child: Text('Play ▶', style: TextStyle(
            fontFamily: 'Alfa', fontSize: 20, color: Colors.white))))),
  ]));

  Widget _buildGame() {
    final winLine = _wins();
    final status = _winner == X ? '🎉 You Win!' : _winner == O
        ? '🤖 AI Wins!' : _draw ? '🤝 Draw!' : _aiThinking ? '🤖 AI thinking...' : '🎮 Your Turn (X)';
    final statusColor = _winner == X ? Colors.green.shade400 : _winner == O ? kNeonRed
        : _draw ? kNeonOrange : Colors.white70;

    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(children: [
        GestureDetector(onTap: _finish, child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.07))),
          child: const Icon(Icons.flag_rounded, color: Colors.white60, size: 18))),
        const Spacer(),
        Text('$_totalScore pts', style: const TextStyle(fontFamily: 'Alfa',
            fontSize: 16, color: kNeonOrange)),
      ]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _scoreBox('You', '$_playerWins', Colors.green.shade400),
        const SizedBox(width: 16),
        _scoreBox('Draw', '$_draws', kNeonOrange),
        const SizedBox(width: 16),
        _scoreBox('AI', '$_aiWins', kNeonRed),
      ]),
      const SizedBox(height: 16),
      AnimatedSwitcher(duration: const Duration(milliseconds: 300),
        child: Text(status, key: ValueKey(status),
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 16, color: statusColor))),
      const SizedBox(height: 20),
      Expanded(child: Center(child: AspectRatio(aspectRatio: 1,
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
                  onTap: () => _tap(i),
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
                        ? ShaderMask(shaderCallback: (b) => LinearGradient(
                              colors: [kNeonBlue, kNeonPurple]).createShader(b),
                            blendMode: BlendMode.srcIn,
                            child: const Text('X', style: TextStyle(fontFamily: 'Alfa',
                                fontSize: 42, color: Colors.white)))
                        : isO ? ShaderMask(shaderCallback: (b) => LinearGradient(
                              colors: [kNeonOrange, kNeonRed]).createShader(b),
                            blendMode: BlendMode.srcIn,
                            child: const Text('O', style: TextStyle(fontFamily: 'Alfa',
                                fontSize: 42, color: Colors.white)))
                        : null),
                  ),
                );
              },
            )))))),
      const SizedBox(height: 20),
      if (_winner != null || _draw)
        Row(children: [
          Expanded(child: GestureDetector(onTap: _reset,
            child: Container(height: 50, decoration: BoxDecoration(color: kDarkCard2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.07))),
              child: const Center(child: Text('Play Again', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)))))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(onTap: _finish,
            child: Container(height: 50, decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kNeonOrange, kNeonRed]),
                borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('Save Score', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)))))),
        ]),
    ]));
  }

  Widget _scoreBox(String label, String val, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Text(val, style: TextStyle(fontFamily: 'Alfa', fontSize: 22, color: color)),
      Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 10, color: color.withOpacity(0.7))),
    ]));
}