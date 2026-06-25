// lib/screens/arcade/texas_poker_game.dart
import 'dart:math';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

// ─── Card model ───────────────────────────────────────────────
class _Card {
  final int value; // 2-14 (14=Ace)
  final String suit; // ♠♥♦♣
  const _Card(this.value, this.suit);
  String get label {
    if (value == 14) return 'A';
    if (value == 13) return 'K';
    if (value == 12) return 'Q';
    if (value == 11) return 'J';
    return '$value';
  }
  Color get color => (suit == '♥' || suit == '♦') ? Colors.red.shade700 : Colors.grey.shade900;
  bool get isRed  => suit == '♥' || suit == '♦';
}

// ─── Deck ─────────────────────────────────────────────────────
List<_Card> _buildDeck() {
  final suits = ['♠','♥','♦','♣'];
  final deck  = <_Card>[];
  for (final s in suits) for (int v = 2; v <= 14; v++) {
    deck.add(_Card(v,s));
  }
  deck.shuffle(Random());
  return deck;
}

// ─── Hand evaluator ───────────────────────────────────────────
class _HandEval {
  final int rank;   // higher = better
  final String name;
  const _HandEval(this.rank, this.name);
}

_HandEval _evaluate(List<_Card> cards) {
  // Best 5 from up to 7 cards
  if (cards.length < 2) return const _HandEval(0, 'High Card');
  final vals = cards.map((c) => c.value).toList()..sort((a,b) => b-a);
  final suits = cards.map((c) => c.suit).toList();
  final valCount = <int,int>{};
  for (final v in vals) {
    valCount[v] = (valCount[v] ?? 0) + 1;
  }
  final suitCount = <String,int>{};
  for (final s in suits) {
    suitCount[s] = (suitCount[s] ?? 0) + 1;
  }

  final isFlush  = suitCount.values.any((c) => c >= 5);
  final pairs    = valCount.values.where((c) => c == 2).length;
  final threeKind= valCount.values.any((c) => c == 3);
  final fourKind = valCount.values.any((c) => c == 4);
  // Straight check
  bool isStraight = false;
  final uniq = valCount.keys.toList()..sort((a,b)=>b-a);
  for (int i = 0; i <= uniq.length - 5; i++) {
    if (uniq[i] - uniq[i+4] == 4) { isStraight = true; break; }
  }
  // Ace-low straight
  if (!isStraight && uniq.contains(14) && uniq.contains(2) &&
      uniq.contains(3) && uniq.contains(4) && uniq.contains(5)) {
    isStraight = true;
  }

  if (isFlush && isStraight) return const _HandEval(8, 'Straight Flush');
  if (fourKind)              return const _HandEval(7, 'Four of a Kind');
  if (threeKind && pairs>0)  return const _HandEval(6, 'Full House');
  if (isFlush)               return const _HandEval(5, 'Flush');
  if (isStraight)            return const _HandEval(4, 'Straight');
  if (threeKind)             return const _HandEval(3, 'Three of a Kind');
  if (pairs >= 2)            return const _HandEval(2, 'Two Pair');
  if (pairs == 1)            return const _HandEval(1, 'One Pair');
  return const _HandEval(0, 'High Card');
}

// ─── Poker game ───────────────────────────────────────────────
class TexasPokerGame extends StatefulWidget {
  const TexasPokerGame({super.key});
  @override State<TexasPokerGame> createState() => _TexasPokerGameState();
}

class _TexasPokerGameState extends State<TexasPokerGame>
    with SingleTickerProviderStateMixin {
  static const _levels = [
    {'name':'Campus Cafe',   'cpus':1,'startChips':500,'bigBlind':20, 'aiAgg':0.3},
    {'name':'Student Lounge','cpus':2,'startChips':800,'bigBlind':50, 'aiAgg':0.5},
    {'name':'Finals Night',  'cpus':3,'startChips':1000,'bigBlind':100,'aiAgg':0.7},
  ];

  int _level = 0;
  bool _started = false, _showStory = true, _paused = false;
  List<_Card> _deck = [];
  List<_Card> _playerHand = [], _community = [];
  List<List<_Card>> _cpuHands = [];
  List<int> _cpuChips = [];
  List<bool> _cpuFolded = [];
  int _playerChips = 0, _pot = 0, _currentBet = 0;
  int _round = 0; // 0=preflop 1=flop 2=turn 3=river 4=showdown
  String _phase = '';
  bool _playerFolded = false;
  String _message = '';
  bool _playerActed = false;
  int _totalGames = 0, _wins = 0;
  late AnimationController _cardCtrl;
  late Animation<double> _cardAnim;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400))..forward();
    _cardAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
  }
  @override void dispose() { _cardCtrl.dispose(); super.dispose(); }

  Map get _cfg => _levels[_level];
  int get _cpuCount => _cfg['cpus'] as int;
  int get _bigBlind => _cfg['bigBlind'] as int;

  void _start() {
    setState(() {
      _started = true;
      _playerChips = _cfg['startChips'] as int;
      _cpuChips    = List.generate(_cpuCount, (_) => _cfg['startChips'] as int);
      _cpuFolded   = List.generate(_cpuCount, (_) => false);
      _totalGames  = 0; _wins = 0; _message = '';
    });
    _dealHand();
  }

  void _dealHand() {
    if (_playerChips <= 0) { _finishGame(); return; }
    _deck = _buildDeck();
    final blind = _bigBlind;
    setState(() {
      _playerHand   = [_deck.removeLast(), _deck.removeLast()];
      _cpuHands     = List.generate(_cpuCount, (_) =>
          [_deck.removeLast(), _deck.removeLast()]);
      _community    = [];
      _cpuFolded    = List.generate(_cpuCount, (_) => false);
      _playerFolded = false;
      _pot          = blind * 3; // blinds collected
      _currentBet   = blind;
      _round        = 0; _phase = 'Pre-Flop';
      _message      = 'Your move. Blind: \$$blind';
      _playerActed  = false;
      _totalGames++;
    });
    _cardCtrl.reset(); _cardCtrl.forward();
  }

  void _playerAction(String action, {int raiseAmt = 0}) {
    if (_playerActed || _paused) return;
    HapticFeedback.lightImpact();
    setState(() {
      switch (action) {
        case 'fold':
          _playerFolded = true;
          _message = 'You folded. CPUs win the pot.';
          _cpuChips[0] += _pot;
          break;
        case 'call':
          final pay = min(_currentBet, _playerChips);
          _playerChips -= pay; _pot += pay;
          _message = 'Called \$$pay';
          break;
        case 'raise':
          final total = _currentBet + raiseAmt;
          final pay = min(total, _playerChips);
          _playerChips -= pay; _pot += pay;
          _currentBet = total;
          _message = 'Raised to \$$_currentBet';
          break;
        case 'check':
          _message = 'Check.';
          break;
      }
      _playerActed = true;
    });
    if (_playerFolded) {
      Future.delayed(const Duration(milliseconds: 1500), _dealHand);
    } else {
      Future.delayed(const Duration(milliseconds: 700), _cpuActions);
    }
  }

  void _cpuActions() {
    if (!mounted) return;
    setState(() {
      final agg = _cfg['aiAgg'] as double;
      for (int i = 0; i < _cpuCount; i++) {
        if (_cpuFolded[i]) continue;
        final r = _rng.nextDouble();
        if (r < 0.2 && _round > 0) { _cpuFolded[i] = true; }
        else if (r < 0.5 + agg) {
          // Call
          final pay = min(_currentBet, _cpuChips[i]);
          _cpuChips[i] -= pay; _pot += pay;
        } else {
          // Raise
          final raise = _bigBlind * (1 + _rng.nextInt(3));
          final pay = min(_currentBet + raise, _cpuChips[i]);
          _cpuChips[i] -= pay; _pot += pay;
          _currentBet += raise;
        }
      }
    });
    Future.delayed(const Duration(milliseconds: 500), _advanceRound);
  }

  void _advanceRound() {
    if (!mounted) return;
    setState(() {
      _round++;
      _playerActed = false;
      if (_round == 1) {
        _community = [_deck.removeLast(),_deck.removeLast(),_deck.removeLast()];
        _phase = 'Flop';
        _message = 'The flop is revealed!';
      } else if (_round == 2) {
        _community.add(_deck.removeLast());
        _phase = 'Turn';
        _message = 'The turn card!';
      } else if (_round == 3) {
        _community.add(_deck.removeLast());
        _phase = 'River';
        _message = 'The river card!';
      } else {
        _showdown();
        return;
      }
      _cardCtrl.reset(); _cardCtrl.forward();
    });
  }

  void _showdown() {
    setState(() => _phase = 'Showdown');
    // Evaluate hands
    final playerBest = _evaluate([..._playerHand, ..._community]);
    int bestCpuRank  = -1;
    int winnerCpu    = -1;
    for (int i = 0; i < _cpuCount; i++) {
      if (_cpuFolded[i]) continue;
      final eval = _evaluate([..._cpuHands[i], ..._community]);
      if (eval.rank > bestCpuRank) { bestCpuRank = eval.rank; winnerCpu = i; }
    }

    bool playerWins = !_playerFolded &&
        (winnerCpu == -1 || playerBest.rank > bestCpuRank ||
         (playerBest.rank == bestCpuRank));

    setState(() {
      if (playerWins) {
        _playerChips += _pot;
        _wins++;
        _message = '🏆 You win with ${playerBest.name}! +\$$_pot';
      } else {
        if (winnerCpu >= 0) _cpuChips[winnerCpu] += _pot;
        _message = '😔 CPU wins${winnerCpu >= 0 ? " with ${_evaluate([..._cpuHands[winnerCpu],..._community]).name}" : ""}!';
      }
      _pot = 0;
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (_playerChips >= (_cfg['startChips'] as int) * 2) {
        _finishGame(won: true);
      } else if (_playerChips <= 0) _finishGame();
      else if (_totalGames >= 5) _finishGame(won: _wins >= 3);
      else _dealHand();
    });
  }

  void _finishGame({bool won = false}) {
    final score = _playerChips + _wins * 50;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => GameOverScreen(result: GameResult(
        gameSlug: 'texas-poker', gameName: "Texas Hold'em",
        score: score, outcome: won ? 'win' : 'lose',
        extra: {'level': _level+1, 'wins': _wins, 'chips': _playerChips}))));
  }

  Future<void> _handleQuit() async {
    setState(() => _paused = true);
    final quit = await showQuitDialog(context);
    if (!mounted) return;
    if (quit) {
      _finishGame(won: _wins > _totalGames ~/ 2);
    } else {
      setState(() => _paused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('texas-poker')) {
      return GameStoryScreen(gameSlug: 'texas-poker',
        onPlay: () => setState(() => _showStory = false));
    }
    if (!_started) {
      return Scaffold(backgroundColor: kDarkBg,
        body: SafeArea(child: _landing()));
    }
    return Scaffold(backgroundColor: const Color(0xFF1B5E20),
        body: SafeArea(child: _game()));
  }

  Widget _landing() => Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Align(alignment: Alignment.centerLeft,
      child: GestureDetector(onTap: () => Navigator.pop(context),
        child: Container(width:40,height:40,
          decoration:BoxDecoration(color:kDarkCard2,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:Colors.white.withOpacity(0.08))),
          child:const Icon(Icons.arrow_back_rounded,color:Colors.white60,size:20)))),
    const Spacer(),
    const T('🃏', style: TextStyle(fontSize: 80)),
    const SizedBox(height: 16),
    ShaderMask(shaderCallback:(b)=>const LinearGradient(
        colors:[Color(0xFF66BB6A),Color(0xFFFFD700)]).createShader(b),
      blendMode:BlendMode.srcIn,
      child:const Text("Texas Hold'em",
        style:TextStyle(fontFamily:'Alfa',fontSize:30,color:Colors.white))),
    const SizedBox(height: 10),
    T('Fold · Call · Raise\nBest hand wins the pot',
      textAlign:TextAlign.center,
      style:TextStyle(fontFamily:'Momo',fontSize:13,
        color:Colors.white.withOpacity(0.5),height:1.6)),
    const SizedBox(height: 20),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(3,(i){
      final sel=i==_level;
      return GestureDetector(onTap:()=>setState(()=>_level=i),
        child:AnimatedContainer(duration:const Duration(milliseconds:200),
          margin:const EdgeInsets.symmetric(horizontal:6),
          padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
          decoration:BoxDecoration(
            gradient:sel?const LinearGradient(colors:[Color(0xFF388E3C),Color(0xFF1B5E20)]):null,
            color:sel?null:kDarkCard2,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:sel?Colors.transparent:Colors.white.withOpacity(0.08))),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text('Lv.${i+1}',style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
              fontSize:12,color:sel?Colors.white:Colors.white60)),
            Text('${_levels[i]['cpus']} CPU',style:TextStyle(fontFamily:'Momo',
              fontSize:10,color:sel?Colors.white60:Colors.white30)),
          ])));
    })),
    const SizedBox(height:8),
    Text((_levels[_level]['name'] as String),
      style:const TextStyle(fontFamily:'Momo',fontSize:13,color:Color(0xFF66BB6A))),
    MiniLeaderboard(gameSlug:'texas-poker',gameName:"Texas Hold'em"),
    const Spacer(),
    GestureDetector(onTap: _start, child:Container(width:double.infinity,height:56,
      decoration:BoxDecoration(
        gradient:const LinearGradient(colors:[Color(0xFF388E3C),Color(0xFF1B5E20)]),
        borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:const Color(0xFF388E3C).withOpacity(0.4),
          blurRadius:20,offset:const Offset(0,6))]),
      child:const Center(child:T('Deal Me In! 🃏',
        style:TextStyle(fontFamily:'Alfa',fontSize:20,color:Colors.white))))),
  ]));

  Widget _game() => Stack(children: [
    Column(children: [
      GameHUD(
        score: '\$$_playerChips',
        level: '$_phase · Game $_totalGames',
        paused: _paused, onPause: () => setState(() => _paused = !_paused),
        onQuit: _handleQuit,
        extra: Text('Pot: \$$_pot', style: const TextStyle(
          fontFamily:'Alfa',fontSize:13,color:Color(0xFFFFD700))),
      ),
      // CPU area
      Container(color: const Color(0xFF1B5E20).withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisAlignment:MainAxisAlignment.spaceAround,
          children: List.generate(_cpuCount, (i) => _cpuArea(i)))),
      // Community cards
      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Text(_phase, style: const TextStyle(fontFamily:'Alfa',fontSize:16,
            color:Color(0xFFFFD700))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment:MainAxisAlignment.center,
            children: _community.isEmpty
              ? [T('Community cards will appear here',
                  style:TextStyle(fontFamily:'Momo',fontSize:12,
                    color:Colors.white.withOpacity(0.4)))]
              : _community.map((c) => _cardWidget(c, revealed:true)).toList()),
        ])),
      // Pot
      Container(padding: const EdgeInsets.all(8),
        child: Row(mainAxisAlignment:MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4))),
            child: Text('💰 Pot: \$$_pot',
              style: const TextStyle(fontFamily:'Alfa',fontSize:16,color:Color(0xFFFFD700)))),
        ])),
      // Message
      Container(margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black38,
          borderRadius: BorderRadius.circular(10)),
        child: Text(_message, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white))),
      const Spacer(),
      // Player hand
      Padding(padding: const EdgeInsets.all(8),
        child: Column(children: [
          T('Your Hand', style: TextStyle(fontFamily:'Momo',fontSize:11,
            color:Colors.white.withOpacity(0.6))),
          const SizedBox(height:6),
          Row(mainAxisAlignment:MainAxisAlignment.center,
            children: _playerHand.map((c) => _cardWidget(c, revealed:true)).toList()),
          if (_round >= 3) ...[
            const SizedBox(height:4),
            Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
              decoration:BoxDecoration(color:Colors.white10,
                borderRadius:BorderRadius.circular(8)),
              child:Text(_evaluate([..._playerHand,..._community]).name,
                style:const TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
                  fontSize:12,color:Color(0xFFFFD700)))),
          ],
        ])),
      // Actions
      if (!_playerActed && !_playerFolded && _round < 4)
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(child: _actionBtn('Fold','fold',Colors.red.shade700)),
            const SizedBox(width:8),
            Expanded(child: _actionBtn('Check','check',Colors.blueGrey)),
            const SizedBox(width:8),
            Expanded(child: _actionBtn('Call \$$_currentBet','call',Colors.blue.shade700)),
            const SizedBox(width:8),
            Expanded(child: _actionBtn('Raise','raise',const Color(0xFF388E3C))),
          ])),
      const SizedBox(height: 4),
    ]),
    if (_paused) PauseOverlay(gameName:"Texas Hold'em",
      onResume:()=>setState(()=>_paused=false),onQuit:_handleQuit),
  ]);

  Widget _cpuArea(int i) => Column(mainAxisSize:MainAxisSize.min, children: [
    Text('CPU ${i+1}', style:TextStyle(fontFamily:'Momo',fontSize:10,
      color:_cpuFolded[i]?Colors.white24:Colors.white60)),
    const SizedBox(height:4),
    Row(mainAxisSize:MainAxisSize.min, children: _cpuHands.length>i
      ? _cpuHands[i].map((c)=>_cardWidget(c,revealed:_round>=4||_cpuFolded[i])).toList()
      : []),
    Text('\$${_cpuChips.length>i?_cpuChips[i]:0}',
      style:TextStyle(fontFamily:'Alfa',fontSize:11,
        color:_cpuFolded[i]?Colors.white24:const Color(0xFFFFD700))),
    if(_cpuFolded[i]) T('FOLDED',style:TextStyle(fontFamily:'Momo',
      fontSize:9,color:Colors.red.shade300)),
  ]);

  Widget _cardWidget(_Card card, {required bool revealed}) {
    return AnimatedBuilder(animation:_cardAnim, builder:(_,__){
      return Container(
        width:36,height:52,margin:const EdgeInsets.all(3),
        decoration:BoxDecoration(
          color:revealed?Colors.white:const Color(0xFF1565C0),
          borderRadius:BorderRadius.circular(6),
          boxShadow:[BoxShadow(color:Colors.black45,blurRadius:4,offset:const Offset(1,2))]),
        child:revealed?Column(
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            Text(card.label,style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
              fontSize:14,color:card.color)),
            Text(card.suit,style:TextStyle(fontSize:14,color:card.color)),
          ])
        :Center(child:T('🂠',style:TextStyle(fontSize:24,
          color:Colors.white.withOpacity(0.3)))));
    });
  }

  Widget _actionBtn(String label, String action, Color color) => GestureDetector(
    onTap: () => _playerAction(action, raiseAmt: _bigBlind * 2),
    child: Container(height:44,
      decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(10)),
      child:Center(child:Text(label,style:const TextStyle(fontFamily:'Arch',
        fontWeight:FontWeight.bold,fontSize:11,color:Colors.white)))));
}