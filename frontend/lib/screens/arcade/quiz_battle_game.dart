// lib/screens/arcade/quiz_battle_game.dart
import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

const _questions = [
  // Math
  {'q':'What is 15 × 8?','a':'120','opts':['96','120','112','128'],'cat':'Math'},
  {'q':'√196 = ?','a':'14','opts':['12','13','14','16'],'cat':'Math'},
  {'q':'What is 25% of 200?','a':'50','opts':['25','40','50','75'],'cat':'Math'},
  {'q':'If 3x + 7 = 22, what is x?','a':'5','opts':['3','4','5','6'],'cat':'Math'},
  {'q':'What is 2⁸?','a':'256','opts':['128','192','256','512'],'cat':'Math'},
  // Science
  {'q':'What gas do plants absorb from the atmosphere?','a':'Carbon Dioxide','opts':['Oxygen','Nitrogen','Carbon Dioxide','Hydrogen'],'cat':'Science'},
  {'q':'What is the speed of light (approx)?','a':'3×10⁸ m/s','opts':['3×10⁶ m/s','3×10⁷ m/s','3×10⁸ m/s','3×10⁹ m/s'],'cat':'Science'},
  {'q':'What is the chemical symbol for Gold?','a':'Au','opts':['Go','Gd','Au','Ag'],'cat':'Science'},
  {'q':'How many bones in the adult human body?','a':'206','opts':['196','206','212','222'],'cat':'Science'},
  {'q':'What planet is known as the Red Planet?','a':'Mars','opts':['Venus','Jupiter','Mars','Saturn'],'cat':'Science'},
  // Tech & Taylors
  {'q':'What does CPU stand for?','a':'Central Processing Unit','opts':['Central Power Unit','Core Processing Unit','Central Processing Unit','Computer Power Unit'],'cat':'Tech'},
  {'q':'Which programming language uses the ".py" extension?','a':'Python','opts':['Perl','PHP','Python','Pascal'],'cat':'Tech'},
  {'q':'What does HTML stand for?','a':'HyperText Markup Language','opts':['HyperText Makeup Language','HyperText Markup Language','High Text Markup Language','HyperText Make Language'],'cat':'Tech'},
  {'q':'Which data structure works on LIFO principle?','a':'Stack','opts':['Queue','Stack','Array','Tree'],'cat':'Tech'},
  {'q':'What is the binary representation of 10?','a':'1010','opts':['1001','1100','1010','0110'],'cat':'Tech'},
  // General
  {'q':'What is the capital of Malaysia?','a':'Kuala Lumpur','opts':['Penang','Johor Bahru','Ipoh','Kuala Lumpur'],'cat':'General'},
  {'q':'How many sides does a hexagon have?','a':'6','opts':['5','6','7','8'],'cat':'General'},
  {'q':'Who invented the telephone?','a':'Alexander Graham Bell','opts':['Thomas Edison','Nikola Tesla','Alexander Graham Bell','Albert Einstein'],'cat':'General'},
  {'q':'What is the largest ocean?','a':'Pacific','opts':['Atlantic','Indian','Pacific','Arctic'],'cat':'General'},
  {'q':'In what year did World War II end?','a':'1945','opts':['1943','1944','1945','1946'],'cat':'General'},
];

class QuizBattleGame extends StatefulWidget {
  const QuizBattleGame({super.key});
  @override
  State<QuizBattleGame> createState() => _QuizBattleGameState();
}

class _QuizBattleGameState extends State<QuizBattleGame>
    with TickerProviderStateMixin {
  // ── Levels ─────────────────────────────────────────────────
  static const _levelCfg = [
    {'name':'Freshman Quiz',  'questions':8,  'timePerQ':20, 'label':'Easy'},
    {'name':'Campus Classic', 'questions':12, 'timePerQ':15, 'label':'Medium'},
    {'name':'Academic Duel',  'questions':15, 'timePerQ':10, 'label':'Hard'},
  ];

  int  _level     = 0;
  bool _showStory = true;
  bool _paused    = false;
  bool _started   = false;
  int  _qIndex  = 0;
  int  _score   = 0;
  int  _streak  = 0;
  int  _timeLeft = 20;
  String? _selected;
  bool _answered = false;
  Timer? _timer;
  late final AnimationController _timerCtrl;
  late final AnimationController _ansCtrl;
  late List<Map<String, dynamic>> _shuffled;

  @override
  void initState() {
    super.initState();
    _shuffled = List.from(_questions)..shuffle();
    _shuffled = _shuffled.take(_levelCfg[_level]['questions'] as int).toList();
    _timerCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 20));
    _ansCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() { _timer?.cancel(); _timerCtrl.dispose(); _ansCtrl.dispose(); super.dispose(); }

  void _startGame() { setState(() => _started = true); _startQuestion(); }

  void _startQuestion() {
    _timer?.cancel();
    _timerCtrl.reset(); _timerCtrl.forward();
    setState(() { _selected = null; _answered = false; _timeLeft = _levelCfg[_level]['timePerQ'] as int; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_paused) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) { t.cancel(); _answerTimeout(); }
    });
  }

  void _answerTimeout() {
    setState(() { _answered = true; _streak = 0; });
    Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _selectAnswer(String opt) {
    if (_answered) return;
    _timer?.cancel();
    HapticFeedback.lightImpact();
    final correct = opt == _shuffled[_qIndex]['a'];
    if (correct) {
      HapticFeedback.mediumImpact();
      _streak++;
      final timeBonus = _timeLeft * 2;
      final streakBonus = _streak > 2 ? (_streak - 2) * 10 : 0;
      _score += 100 + timeBonus + streakBonus;
    } else {
      _streak = 0;
    }
    setState(() { _selected = opt; _answered = true; });
    _ansCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1500), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_qIndex >= _shuffled.length - 1) { _finish(); return; }
    setState(() => _qIndex++);
    _startQuestion();
  }

  void _finish() {
    _timer?.cancel();
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => GameOverScreen(result: GameResult(
          gameSlug: 'quiz-battle', gameName: 'Quiz Battle',
          score: _score, outcome: 'complete',
          extra: {'correct': _score ~/ 100, 'total': _shuffled.length},
        ))));
  }

  Future<void> _handleQuit() async {
    _timer?.cancel();
    setState(() => _paused = true);
    final quit = await showQuitDialog(context);
    if (!mounted) return;
    if (quit) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => GameOverScreen(result: GameResult(
          gameSlug: 'quiz-battle', gameName: 'Quiz Battle',
          score: _score, outcome: 'complete'))));
    } else {
      setState(() => _paused = false);
      _startQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showStory && shouldShowStory('quiz-battle')) {
      return GameStoryScreen(
        gameSlug: 'quiz-battle',
        onPlay: () => setState(() => _showStory = false));
    }
    if (!_started) {
      return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _buildLanding()));
    }
    return Scaffold(backgroundColor: kDarkBg,
      body: SafeArea(child: Stack(children: [
        _buildGame(),
        if (_paused) PauseOverlay(
          gameName: 'Quiz Battle',
          onResume: () { setState(() => _paused = false); _startQuestion(); },
          onQuit: _handleQuit),
      ])));
  }

  Widget _buildLanding() {
    return Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Align(alignment: Alignment.centerLeft, child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white60, size: 20)))),
      const Spacer(),
      const T('🧠', style: TextStyle(fontSize: 80)),
      const SizedBox(height: 20),
      ShaderMask(
        shaderCallback: (b) => const LinearGradient(
            colors: [kNeonBlue, kNeonPurple]).createShader(b),
        blendMode: BlendMode.srcIn,
        child: const T('Quiz Battle', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 40, color: Colors.white))),
      const SizedBox(height: 10),
      T('10 questions · 20 sec each\n+100 pts per correct answer\n+Time & Streak Bonuses!',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13,
              color: Colors.white.withOpacity(0.5), height: 1.6)),
      const SizedBox(height: 16),
      // Level selector
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) {
      final sel = i == _level;
      return GestureDetector(
        onTap: () => setState(() {
          _level = i;
          _shuffled = List.from(_questions)..shuffle();
          _shuffled = _shuffled.take(_levelCfg[i]['questions'] as int).toList();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: sel ? const LinearGradient(colors: [kNeonPurple, kNeonBlue]) : null,
            color: sel ? null : kDarkCard2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? Colors.transparent : Colors.white.withOpacity(0.08))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Lv.${i+1}', style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 12,
              color: sel ? Colors.white : Colors.white60)),
            Text(_levelCfg[i]['label'] as String, style: TextStyle(
              fontFamily: 'Momo', fontSize: 10,
              color: sel ? Colors.white70 : Colors.white38)),
          ])));
    })),
    const SizedBox(height: 4),
    Text('${_levelCfg[_level]['questions']} questions · ${_levelCfg[_level]['timePerQ']}s each',
      style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: Colors.white38)),
    const SizedBox(height: 12),
    MiniLeaderboard(gameSlug: 'quiz-battle', gameName: 'Quiz Battle'),
      const Spacer(),
      GestureDetector(onTap: _startGame,
        child: Container(width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kNeonPurple, kNeonBlue]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: kNeonPurple.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 6))]),
          child: const Center(child: T('Start Quiz ▶', style: TextStyle(
              fontFamily: 'Alfa', fontSize: 20, color: Colors.white))))),
    ]));
  }

  Widget _buildGame() {
    final q = _shuffled[_qIndex];
    final opts = List<String>.from(q['opts'] as List);
    return Column(children: [
      // Header
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          GestureDetector(onTap: _handleQuit,
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.07))),
              child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Q ${_qIndex + 1} / ${_shuffled.length}',
                style: const TextStyle(fontFamily: 'Alfa', fontSize: 16, color: Colors.white)),
            Text(q['cat'] as String, style: TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: Colors.white.withOpacity(0.4))),
          ])),
          // Score
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: kNeonPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kNeonPurple.withOpacity(0.3))),
            child: Text('$_score pts', style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 14, color: kNeonPurple))),
        ])),
      // Progress bar
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: AnimatedBuilder(animation: _timerCtrl, builder: (_, __) =>
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1 - _timerCtrl.value,
              minHeight: 6,
              backgroundColor: kDarkCard2,
              valueColor: AlwaysStoppedAnimation(
                  _timeLeft > 10 ? kNeonBlue : _timeLeft > 5 ? kNeonOrange : kNeonRed),
            )))),
      // Timer + streak
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('⏱ $_timeLeft s', style: TextStyle(fontFamily: 'Alfa', fontSize: 14,
              color: _timeLeft > 10 ? kNeonBlue : _timeLeft > 5 ? kNeonOrange : kNeonRed)),
          if (_streak > 1) Text('🔥 $_streak streak!',
              style: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 13, color: kNeonOrange)),
        ])),
      const SizedBox(height: 20),
      // Question
      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: kDarkCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.07))),
            child: Text(q['q'] as String, textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 20, color: Colors.white, height: 1.4))),
          const SizedBox(height: 20),
          ...opts.map((opt) {
            Color bg = kDarkCard; Color border = Colors.white.withOpacity(0.07);
            if (_answered) {
              if (opt == q['a']) { bg = Colors.green.shade900; border = Colors.green.shade500; }
              else if (opt == _selected) { bg = Colors.red.shade900; border = kNeonRed; }
            } else if (opt == _selected) { bg = kNeonPurple.withOpacity(0.2); border = kNeonPurple; }
            return GestureDetector(
              onTap: () => _selectAnswer(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5)),
                child: Row(children: [
                  Expanded(child: Text(opt, style: TextStyle(fontFamily: 'Momo', fontSize: 15,
                      color: _answered && opt == q['a'] ? Colors.green.shade300 : Colors.white,
                      height: 1.3))),
                  if (_answered && opt == q['a'])
                    const T('✓', style: TextStyle(fontSize: 18, color: Colors.green)),
                  if (_answered && opt == _selected && opt != q['a'])
                    const T('✗', style: TextStyle(fontSize: 18, color: kNeonRed)),
                ]),
              ),
            );
          }),
        ]))),
    ]);
  }
}