// lib/screens/arcade/sushi_rush_game.dart
import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

class SushiRushGame extends StatefulWidget {
  const SushiRushGame({super.key});
  @override State<SushiRushGame> createState() => _SushiRushGameState();
}

class _SushiRushGameState extends State<SushiRushGame> {
  static const _sushiItems = ['🍣','🍱','🦐','🐟','🥢','🍜','🥗','🍙','🦑','🥩'];

  static const _levels = [
    {'name':'Apprentice Chef',  'orderLen':3,'rounds':5, 'showTime':2000,'inputTime':8000},
    {'name':'Head Chef',        'orderLen':5,'rounds':7, 'showTime':1500,'inputTime':7000},
    {'name':'Iron Chef',        'orderLen':7,'rounds':10,'showTime':1000,'inputTime':6000},
  ];

  int _level=0;
  bool _showStory=true;
  bool _paused=false;
  bool _started=false;
  int _score=0, _round=0, _lives=3;
  List<String> _order=[], _playerInput=[];
  bool _showing=true, _roundWon=false, _roundLost=false, _gameOver=false;
  Timer? _showTimer, _inputTimer;
  int _inputTimeLeft=0;
  final _rng=Random();

  Future<void> _handleQuit() async {
    _showTimer?.cancel(); _inputTimer?.cancel();
    setState(()=>_paused=true);
    final quit=await showQuitDialog(context);
    if(!mounted)return;
    if(quit){
      Navigator.pushReplacement(context,MaterialPageRoute(
        builder:(_)=>GameOverScreen(result:GameResult(
          gameSlug:'sushi-rush',gameName:'Sushi Rush',
          score:_score,outcome:'complete'))));
    } else {
      setState(()=>_paused=false);
      _nextRound();
    }
  }

  @override void dispose(){ _showTimer?.cancel(); _inputTimer?.cancel(); super.dispose(); }

  Map get _cfg=>_levels[_level];

  void _startGame(){
    setState((){_started=true;_score=0;_round=0;_lives=3;_gameOver=false;});
    _nextRound();
  }

  void _nextRound(){
    _showTimer?.cancel(); _inputTimer?.cancel();
    if(_round>=(_cfg['rounds'] as int)){_finish();return;}
    final len=(_cfg['orderLen'] as int)+(_round~/3);
    final items=List<String>.from(_sushiItems)..shuffle(_rng);
    setState((){
      _round++;
      _order=items.take(len).toList();
      _playerInput=[]; _showing=true; _roundWon=false; _roundLost=false;
    });
    _showTimer=Timer(Duration(milliseconds:_cfg['showTime'] as int),(){
      if(!mounted)return;
      setState(()=>_showing=false);
      _inputTimeLeft=_cfg['inputTime'] as int;
      _inputTimer=Timer.periodic(const Duration(milliseconds:100),(_){
        if(!mounted||_paused)return;
        setState((){
          _inputTimeLeft-=100;
          if(_inputTimeLeft<=0){_checkWrong();_inputTimer?.cancel();}
        });
      });
    });
  }

  void _tap(String item){
    if(_showing||_roundWon||_roundLost||_gameOver)return;
    HapticFeedback.lightImpact();
    setState(()=>_playerInput.add(item));
    // Check so far
    for(int i=0;i<_playerInput.length;i++){
      if(_playerInput[i]!=_order[i]){_checkWrong();return;}
    }
    if(_playerInput.length==_order.length){
      // Correct!
      _inputTimer?.cancel();
      HapticFeedback.heavyImpact();
      final timeBonus=(_inputTimeLeft/100).round();
      setState((){_score+=100+timeBonus; _roundWon=true;});
      Future.delayed(const Duration(milliseconds:1200),_nextRound);
    }
  }

  void _checkWrong(){
    _inputTimer?.cancel();
    HapticFeedback.vibrate();
    setState((){_roundLost=true; _lives--;});
    if(_lives<=0){Future.delayed(const Duration(milliseconds:800),_finish);return;}
    Future.delayed(const Duration(milliseconds:1200),_nextRound);
  }

  void _finish(){
    Navigator.pushReplacement(context,MaterialPageRoute(
      builder:(_)=>GameOverScreen(result:GameResult(
        gameSlug:'sushi-rush',gameName:'Sushi Rush',
        score:_score,outcome:_lives>0?'win':'lose',
        extra:{'level':_level+1,'rounds':_round}))));
  }

  @override
  Widget build(BuildContext context){
    if(_showStory&&shouldShowStory('sushi-rush')){
      return GameStoryScreen(gameSlug:'sushi-rush',
        onPlay:()=>setState(()=>_showStory=false));
    }
    if(!_started)return Scaffold(backgroundColor:kDarkBg,body:SafeArea(child:_landing()));
    return Scaffold(backgroundColor:kDarkBg,body:SafeArea(child:Stack(children:[
      _game(),
      if(_paused)PauseOverlay(gameName:'Sushi Rush',
        onResume:()=>setState(()=>_paused=false),onQuit:_handleQuit),
    ])));
  }

  Widget _landing()=>Padding(padding:const EdgeInsets.all(24),child:Column(children:[
    Align(alignment:Alignment.centerLeft,child:GestureDetector(onTap:()=>Navigator.pop(context),
      child:Container(width:40,height:40,decoration:BoxDecoration(color:kDarkCard2,
        borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(0.08))),
        child:const Icon(Icons.arrow_back_rounded,color:Colors.white60,size:20)))),
    const Spacer(),
    const T('🍣',style:TextStyle(fontSize:80)),
    const SizedBox(height:16),
    ShaderMask(shaderCallback:(b)=>const LinearGradient(colors:[kNeonOrange,kNeonRed]).createShader(b),
      blendMode:BlendMode.srcIn,child:const T('Sushi Rush',
        style:TextStyle(fontFamily:'Alfa',fontSize:38,color:Colors.white))),
    const SizedBox(height:10),
    T('Memorize the order!\nTap the sushi in the correct sequence',
      textAlign:TextAlign.center,
      style:TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white.withOpacity(0.5),height:1.6)),
    const SizedBox(height:20),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(3,(i){
      final sel=i==_level;
      return GestureDetector(onTap:()=>setState(()=>_level=i),
        child:AnimatedContainer(duration:const Duration(milliseconds:200),
          margin:const EdgeInsets.symmetric(horizontal:6),
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:10),
          decoration:BoxDecoration(
            gradient:sel?const LinearGradient(colors:[kNeonOrange,kNeonRed]):null,
            color:sel?null:kDarkCard2,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:sel?Colors.transparent:Colors.white.withOpacity(0.08))),
          child:Text('Lv.${i+1}',style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
            fontSize:13,color:sel?Colors.white:Colors.white60))));
    })),
    const SizedBox(height:8),
    Text((_levels[_level]['name'] as String),
      style:const TextStyle(fontFamily:'Momo',fontSize:13,color:kNeonOrange)),
    MiniLeaderboard(gameSlug:'sushi-rush',gameName:'Sushi Rush'),
    const Spacer(),
    GestureDetector(onTap:_startGame,child:Container(width:double.infinity,height:56,
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[kNeonOrange,kNeonRed]),
        borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:kNeonOrange.withOpacity(0.4),blurRadius:20,offset:const Offset(0,6))]),
      child:const Center(child:T('Start Rush! 🍜',style:TextStyle(fontFamily:'Alfa',fontSize:20,color:Colors.white))))),
  ]));

  Widget _game()=>Column(children:[
    // HUD
    Padding(padding:const EdgeInsets.fromLTRB(16,10,16,0),child:Row(children:[
      Text('Round $_round/${_cfg['rounds']}',style:const TextStyle(fontFamily:'Alfa',fontSize:14,color:kNeonOrange)),
      const Spacer(),
      Row(children:List.generate(_lives,(_)=>const Padding(
        padding:EdgeInsets.only(left:4),child:T('❤️',style:TextStyle(fontSize:16))))),
      const Spacer(),
      Text('$_score pts',style:const TextStyle(fontFamily:'Alfa',fontSize:14,color:kNeonBlue)),
    ])),
    const SizedBox(height:12),

    // Order display
    Container(margin:const EdgeInsets.symmetric(horizontal:16),
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:kDarkCard,borderRadius:BorderRadius.circular(16),
        border:Border.all(color:(_roundWon?Colors.green:_roundLost?kNeonRed:kNeonOrange).withOpacity(0.3))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Text(_showing?'📋 Memorize!':'🧠 Repeat the order!',
            style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,fontSize:13,
              color:_roundWon?Colors.green:_roundLost?kNeonRed:Colors.white70)),
          const Spacer(),
          if(!_showing&&!_roundWon&&!_roundLost)
            Text('⏱ ${(_inputTimeLeft/1000).toStringAsFixed(1)}s',
              style:TextStyle(fontFamily:'Alfa',fontSize:13,
                color:_inputTimeLeft<2000?kNeonRed:kNeonBlue)),
        ]),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:_order.asMap().entries.map((e){
          final idx=e.key; final item=e.value;
          bool revealed=_showing;
          bool correct=idx<_playerInput.length&&_playerInput[idx]==item;
          bool wrong=idx<_playerInput.length&&_playerInput[idx]!=item;
          return AnimatedContainer(duration:const Duration(milliseconds:200),
            width:44,height:44,
            decoration:BoxDecoration(
              color:correct?Colors.green.shade900:wrong?Colors.red.shade900:
                revealed?kDarkCard2:kDarkCard,
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:correct?Colors.green:wrong?kNeonRed:
                revealed?kNeonOrange.withOpacity(0.4):Colors.white.withOpacity(0.1))),
            child:Center(child:Text(revealed||correct||wrong?item:'?',
              style:const TextStyle(fontSize:22))));
        }).toList()),
      ])),

    const SizedBox(height:12),

    // Input progress
    if(!_showing) Container(margin:const EdgeInsets.symmetric(horizontal:16),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:kDarkCard2,borderRadius:BorderRadius.circular(12)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Your answer (${_playerInput.length}/${_order.length})',
          style:TextStyle(fontFamily:'Momo',fontSize:11,color:Colors.white38)),
        const SizedBox(height:8),
        _playerInput.isEmpty
          ?T('Tap below ↓',style:TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white24))
          :Wrap(spacing:6,runSpacing:6,children:_playerInput.map((s)=>
              Container(width:36,height:36,decoration:BoxDecoration(
                color:kDarkCard,borderRadius:BorderRadius.circular(8)),
                child:Center(child:Text(s,style:const TextStyle(fontSize:20))))).toList()),
      ])),

    const Spacer(),

    // Sushi selector
    if(!_showing&&!_roundWon&&!_roundLost)
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,16),
        child:Wrap(spacing:10,runSpacing:10,alignment:WrapAlignment.center,
          children:_sushiItems.map((s)=>GestureDetector(onTap:()=>_tap(s),
            child:Container(width:54,height:54,
              decoration:BoxDecoration(color:kDarkCard,borderRadius:BorderRadius.circular(12),
                border:Border.all(color:Colors.white.withOpacity(0.08))),
              child:Center(child:Text(s,style:const TextStyle(fontSize:28)))))).toList())),

    if(_roundWon) Center(child:Text('✅ Correct! +${100+(_inputTimeLeft~/100)} pts',
      style:const TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
        fontSize:16,color:Colors.green))),
    if(_roundLost) Center(child:Text('❌ Wrong! $_lives lives left',
      style:const TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
        fontSize:16,color:kNeonRed))),
    const SizedBox(height:8),
  ]);
}