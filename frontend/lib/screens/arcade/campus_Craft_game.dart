// lib/screens/arcade/campus_craft_game.dart
// Slide puzzle: arrange tiles in order
import 'dart:math';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/arcade/game_engine.dart';

class CampusCraftGame extends StatefulWidget {
  const CampusCraftGame({super.key});
  @override State<CampusCraftGame> createState()=>_CampusCraftGameState();
}

class _CampusCraftGameState extends State<CampusCraftGame>{
  static const _levels=[
    {'name':'Freshman Puzzle','size':3,'shuffles':20},
    {'name':'Campus Builder', 'size':4,'shuffles':60},
    {'name':'Master Architect','size':5,'shuffles':120},
  ];
  // Tiles represent campus buildings
  static const _emojis=['🏫','🏛️','🏟️','🎭','🏋️','📚','🎨','🔬','💻','🎓',
    '🏥','🌳','⚽','🎵','🍕','🏨','🛒','🎪','🚉','🌉','🏗️','🎠','🏄','🎡'];

  int _level=0;
  bool _showStory=true;
  bool _paused=false;
  bool _started=false;
  List<int> _tiles=[];
  final int _score=0;
  int _moves=0;
  bool _solved=false;
  int _size=3;
  Stopwatch _sw=Stopwatch();

  int get _n=>_size;
  int get _total=>_n*_n;

  Future<void> _handleQuit() async {
    setState(()=>_paused=true);
    final quit=await showQuitDialog(context);
    if(!mounted)return;
    if(quit){
      Navigator.pushReplacement(context,MaterialPageRoute(
        builder:(_)=>GameOverScreen(result:GameResult(
          gameSlug:'campus-craft',gameName:'Campus Craft',
          score:_score,outcome:'complete'))));
    } else { setState(()=>_paused=false); }
  }

  void _start(){
    _size=_levels[_level]['size'] as int;
    // Goal state: 0..n*n-1, blank=last
    _tiles=List.generate(_total,(i)=>i);
    // Shuffle with valid moves only
    int blank=_total-1;
    final rng=Random();
    for(int s=0;s<(_levels[_level]['shuffles'] as int);s++){
      final moves=_validMoves(blank);
      final next=moves[rng.nextInt(moves.length)];
      _tiles[blank]=_tiles[next]; _tiles[next]=_total-1; blank=next;
    }
    _sw=Stopwatch()..start();
    setState((){_started=true;_moves=0;_solved=false;});
  }

  List<int> _validMoves(int blank){
    final moves=<int>[];
    final row=blank~/_n; final col=blank%_n;
    if(row>0) moves.add(blank-_n);
    if(row<_n-1) moves.add(blank+_n);
    if(col>0) moves.add(blank-1);
    if(col<_n-1) moves.add(blank+1);
    return moves;
  }

  void _tap(int idx){
    if(_solved) return;
    final blank=_tiles.indexOf(_total-1);
    final moves=_validMoves(blank);
    if(!moves.contains(idx)) return;
    HapticFeedback.lightImpact();
    setState((){
      _tiles[blank]=_tiles[idx]; _tiles[idx]=_total-1; _moves++;
      _solved=_checkSolved();
      if(_solved){
        _sw.stop();
        HapticFeedback.heavyImpact();
        final timeBonus=(max(0,120-_sw.elapsed.inSeconds))*5;
        final moveBonus=(max(0,200-_moves))*2;
        final score=500+timeBonus+moveBonus;
        Future.delayed(const Duration(milliseconds:800),()=>
          Navigator.pushReplacement(context,MaterialPageRoute(
            builder:(_)=>GameOverScreen(result:GameResult(
              gameSlug:'campus-craft',gameName:'Campus Craft',
              score:score,outcome:'win',
              extra:{'level':_level+1,'moves':_moves,'time':_sw.elapsed.inSeconds})))));
      }
    });
  }

  bool _checkSolved(){
    for(int i=0;i<_total-1;i++) {
      if(_tiles[i]!=i) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context){
    if(_showStory&&shouldShowStory('campus-craft')){
      return GameStoryScreen(gameSlug:'campus-craft',
        onPlay:()=>setState(()=>_showStory=false));
    }
    if(!_started)return Scaffold(backgroundColor:kDarkBg,body:SafeArea(child:_landing()));
    return Scaffold(backgroundColor:kDarkBg,body:SafeArea(child:Stack(children:[
      _game(context),
      if(_paused)PauseOverlay(gameName:'Campus Craft',
        onResume:()=>setState(()=>_paused=false),onQuit:_handleQuit),
    ])));
  }

  Widget _landing()=>Padding(padding:const EdgeInsets.all(24),child:Column(children:[
    Align(alignment:Alignment.centerLeft,child:GestureDetector(onTap:()=>Navigator.pop(context),
      child:Container(width:40,height:40,decoration:BoxDecoration(color:kDarkCard2,
        borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(0.08))),
        child:const Icon(Icons.arrow_back_rounded,color:Colors.white60,size:20)))),
    const Spacer(),
    const T('🏗️',style:TextStyle(fontSize:80)),
    const SizedBox(height:16),
    ShaderMask(shaderCallback:(b)=>const LinearGradient(colors:[kNeonOrange,kNeonBlue]).createShader(b),
      blendMode:BlendMode.srcIn,child:const T('Campus Craft',
        style:TextStyle(fontFamily:'Alfa',fontSize:36,color:Colors.white))),
    const SizedBox(height:10),
    T('Slide tiles to restore the campus!\nFewest moves = highest score',
      textAlign:TextAlign.center,
      style:TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white.withOpacity(0.5),height:1.6)),
    const SizedBox(height:20),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(3,(i){
      final sel=i==_level; final cfg=_levels[i];
      return GestureDetector(onTap:()=>setState(()=>_level=i),
        child:AnimatedContainer(duration:const Duration(milliseconds:200),
          margin:const EdgeInsets.symmetric(horizontal:6),
          padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
          decoration:BoxDecoration(
            gradient:sel?const LinearGradient(colors:[kNeonOrange,kNeonBlue]):null,
            color:sel?null:kDarkCard2,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:sel?Colors.transparent:Colors.white.withOpacity(0.08))),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text('Lv.${i+1}',style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
              fontSize:12,color:sel?Colors.white:Colors.white60)),
            Text('${cfg['size']}×${cfg['size']}',style:TextStyle(fontFamily:'Momo',
              fontSize:10,color:sel?Colors.white70:Colors.white38)),
          ])));
    })),
    const SizedBox(height:8),
    Text((_levels[_level]['name'] as String),
      style:const TextStyle(fontFamily:'Momo',fontSize:13,color:kNeonOrange)),
    MiniLeaderboard(gameSlug:'campus-craft',gameName:'Campus Craft'),
    const Spacer(),
    GestureDetector(onTap:_start,child:Container(width:double.infinity,height:56,
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[kNeonOrange,kNeonBlue]),
        borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:kNeonOrange.withOpacity(0.4),blurRadius:20,offset:const Offset(0,6))]),
      child:const Center(child:T('Start Building! 🏗️',style:TextStyle(fontFamily:'Alfa',fontSize:20,color:Colors.white))))),
  ]));

  Widget _game(BuildContext context){
    final size=MediaQuery.of(context).size;
    final gridPx=size.width-48;
    final cellSize=gridPx/_n;
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,10,16,0),child:Row(children:[
        Text('Lv.${_level+1}',style:const TextStyle(fontFamily:'Alfa',fontSize:14,color:kNeonOrange)),
        const Spacer(),
        Text('$_moves moves',style:const TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white60)),
        const Spacer(),
        StreamBuilder(stream:Stream.periodic(const Duration(seconds:1)),builder:(_,__)=>
          Text('${_sw.elapsed.inSeconds}s',
            style:const TextStyle(fontFamily:'Alfa',fontSize:14,color:kNeonBlue))),
      ])),
      const SizedBox(height:8),
      if(_solved) Container(margin:const EdgeInsets.symmetric(horizontal:16),
        padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:Colors.green.shade900.withOpacity(0.5),
          borderRadius:BorderRadius.circular(12),
          border:Border.all(color:Colors.green.shade500)),
        child:const Center(child:T('🎉 Campus Restored!',
          style:TextStyle(fontFamily:'Alfa',fontSize:18,color:Colors.white)))),
      const Spacer(),
      Center(child:Container(width:gridPx,height:gridPx,
        decoration:BoxDecoration(color:kDarkCard,borderRadius:BorderRadius.circular(16),
          border:Border.all(color:Colors.white.withOpacity(0.07))),
        child:GridView.builder(
          physics:const NeverScrollableScrollPhysics(),
          gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:_n),
          itemCount:_total,
          itemBuilder:(_,i){
            final val=_tiles[i];
            final isBlank=val==_total-1;
            final isGoal=val==i;
            return GestureDetector(onTap:()=>_tap(i),
              child:AnimatedContainer(duration:const Duration(milliseconds:150),
                margin:const EdgeInsets.all(2),
                decoration:BoxDecoration(
                  gradient:isBlank?null:isGoal&&_solved?
                    const LinearGradient(colors:[Color(0xFF4CAF50),Color(0xFF2E7D32)]):
                    LinearGradient(colors:[const Color(0xFF3F51B5).withOpacity(0.8),
                      const Color(0xFF512DA8)]),
                  color:isBlank?Colors.transparent:null,
                  borderRadius:BorderRadius.circular(8),
                  boxShadow:isBlank?null:[BoxShadow(color:Colors.black26,
                    blurRadius:4,offset:const Offset(0,2))]),
                child:isBlank?null:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Text(_emojis[val%_emojis.length],
                    style:TextStyle(fontSize:cellSize*0.42)),
                  Text('${val+1}',style:TextStyle(fontFamily:'Momo',
                    fontSize:cellSize*0.2,color:Colors.white70)),
                ]))));
          }))),
      const Spacer(),
      // Goal preview
      Padding(padding:const EdgeInsets.fromLTRB(16,0,16,12),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Goal: tiles in order 1→${_total-1} with blank at end',
          style:TextStyle(fontFamily:'Momo',fontSize:11,color:Colors.white38)),
      ])),
    ]);
  }
}