// lib/screens/arcade/ninja_tag_game.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

class NinjaTagGame extends StatefulWidget {
  const NinjaTagGame({super.key});
  @override
  State<NinjaTagGame> createState() => _NinjaTagGameState();
}

class _NinjaTagGameState extends State<NinjaTagGame> {
  static const _levels = [
    {'name':'Training Dojo',    'grid':6,'enemies':1,'speed':700,'powerups':true},
    {'name':'Shadow Village',   'grid':7,'enemies':2,'speed':500,'powerups':true},
    {'name':'Final Showdown',   'grid':8,'enemies':3,'speed':320,'powerups':false},
  ];

  int _level = 0;
  bool _showStory = true;
  bool _paused   = false;
  bool _started = false, _dead = false, _won = false;
  int _px = 0, _py = 0;
  int _score = 0, _timeLeft = 60;
  List<Map<String,int>> _enemies = [];
  List<Map<String,int>> _stars   = [];
  List<Map<String,int>> _walls   = [];
  Set<String> _powerCells = {};
  Timer? _gameTimer, _enemyTimer;
  final _rng = Random();

  Future<void> _handleQuit() async {
    _gameTimer?.cancel(); _enemyTimer?.cancel();
    setState(()=>_paused=true);
    final quit=await showQuitDialog(context);
    if(!mounted)return;
    if(quit){
      Navigator.pushReplacement(context,MaterialPageRoute(
        builder:(_)=>GameOverScreen(result:GameResult(
          gameSlug:'ninja-tag',gameName:'Ninja Tag',
          score:_score,outcome:'complete'))));
    } else {
      setState(()=>_paused=false);
      _start(); // restart timers
    }
  }

  @override void dispose() { _gameTimer?.cancel(); _enemyTimer?.cancel(); super.dispose(); }

  Map get _cfg => _levels[_level];
  int get _grid => _cfg['grid'] as int;

  void _start() {
    final g = _grid;
    _px = g ~/ 2; _py = g - 1;
    _enemies = List.generate(_cfg['enemies'] as int, (i) => {'x':i,'y':0});
    _stars   = [];
    _walls   = [];
    _powerCells = {};
    // Random walls
    for(int i=0;i<g*2;i++) {
      final x=_rng.nextInt(g); final y=_rng.nextInt(g);
      if((x!=_px||y!=_py)&&!_enemies.any((e)=>e['x']==x&&e['y']==y)) {
        _walls.add({'x':x,'y':y});
      }
    }
    // Stars to collect
    for(int i=0;i<5+_level*3;i++) {
      _spawnStar();
    }
    setState(() { _started=true; _dead=false; _won=false;
      _score=0; _timeLeft=60+_level*0; });
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds:1), (_) {
      if(!mounted) return;
      if(_paused)return;
      setState(() { _timeLeft--; if(_timeLeft<=0) _finishGame(); });
    });
    _enemyTimer?.cancel();
    _enemyTimer = Timer.periodic(Duration(milliseconds:_cfg['speed'] as int), (_) {
      if(!mounted||_dead||_won||_paused) return;
      _moveEnemies();
    });
  }

  void _spawnStar() {
    final g=_grid;
    for(int t=0;t<50;t++){
      final x=_rng.nextInt(g); final y=_rng.nextInt(g);
      if((x!=_px||y!=_py) &&
         !_enemies.any((e)=>e['x']==x&&e['y']==y) &&
         !_walls.any((w)=>w['x']==x&&w['y']==y) &&
         !_stars.any((s)=>s['x']==x&&s['y']==y)) {
        _stars.add({'x':x,'y':y}); return;
      }
    }
  }

  void _moveEnemies() {
    setState(() {
      for(int i=0;i<_enemies.length;i++){
        final e=_enemies[i];
        final dx=(_px-e['x']!).sign; final dy=(_py-e['y']!).sign;
        // Try to move toward player
        final nx=e['x']!+dx; final ny=e['y']!+dy;
        bool wallBlocked=_walls.any((w)=>w['x']==nx&&w['y']==ny);
        if(!wallBlocked&&nx>=0&&nx<_grid&&ny>=0&&ny<_grid) {
          _enemies[i]={'x':nx,'y':ny};
        } else {
          // Try horizontal only
          final nx2=e['x']!+dx; final ny2=e['y']!;
          if(!_walls.any((w)=>w['x']==nx2&&w['y']==ny2)&&nx2>=0&&nx2<_grid) {
            _enemies[i]={'x':nx2,'y':ny2};
          } else {
            final nx3=e['x']!; final ny3=e['y']!+dy;
            if(!_walls.any((w)=>w['x']==nx3&&w['y']==ny3)&&ny3>=0&&ny3<_grid) {
              _enemies[i]={'x':nx3,'y':ny3};
            }
          }
        }
        // Check tag
        if(_enemies[i]['x']==_px&&_enemies[i]['y']==_py) { _die(); return; }
      }
    });
  }

  void _move(int dx, int dy) {
    if(_dead||_won||!_started) return;
    final nx=(_px+dx).clamp(0,_grid-1);
    final ny=(_py+dy).clamp(0,_grid-1);
    if(_walls.any((w)=>w['x']==nx&&w['y']==ny)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _px=nx; _py=ny;
      // Collect stars
      _stars.removeWhere((s) {
        if(s['x']==_px&&s['y']==_py) { _score+=10; HapticFeedback.mediumImpact(); return true; }
        return false;
      });
      if(_stars.isEmpty) _finishGame();
      // Check enemy
      if(_enemies.any((e)=>e['x']==_px&&e['y']==_py)) _die();
    });
  }

  void _die() {
    _gameTimer?.cancel(); _enemyTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _dead=true);
    Future.delayed(const Duration(milliseconds:800), () {
      if(!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder:(_)=>GameOverScreen(result:GameResult(
          gameSlug:'ninja-tag',gameName:'Ninja Tag',
          score:_score,outcome:'lose',extra:{'level':_level+1}))));
    });
  }

  void _finishGame() {
    _gameTimer?.cancel(); _enemyTimer?.cancel();
    final finalScore = _score + _timeLeft*2;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder:(_)=>GameOverScreen(result:GameResult(
        gameSlug:'ninja-tag',gameName:'Ninja Tag',
        score:finalScore,outcome:_stars.isEmpty?'win':'complete',
        extra:{'level':_level+1,'time':_timeLeft}))));
  }

  @override
  Widget build(BuildContext context) {
    if(_showStory&&shouldShowStory('ninja-tag')){
      return GameStoryScreen(gameSlug:'ninja-tag',
        onPlay:()=>setState(()=>_showStory=false));
    }
    if(!_started) return Scaffold(backgroundColor:kDarkBg,body:SafeArea(child:_landing()));
    return Scaffold(backgroundColor:kDarkBg,body:SafeArea(child:Stack(children:[
      _game(context),
      if(_paused)PauseOverlay(gameName:'Ninja Tag',
        onResume:()=>setState(()=>_paused=false),onQuit:_handleQuit),
    ])));
  }

  Widget _landing() => Padding(padding:const EdgeInsets.all(24),child:Column(children:[
    Align(alignment:Alignment.centerLeft,child:GestureDetector(onTap:()=>Navigator.pop(context),
      child:Container(width:40,height:40,decoration:BoxDecoration(color:kDarkCard2,
        borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(0.08))),
        child:const Icon(Icons.arrow_back_rounded,color:Colors.white60,size:20)))),
    const Spacer(),
    const Text('🥷',style:TextStyle(fontSize:80)),
    const SizedBox(height:16),
    ShaderMask(shaderCallback:(b)=>const LinearGradient(colors:[kNeonRed,kNeonPurple]).createShader(b),
      blendMode:BlendMode.srcIn,child:const Text('Ninja Tag',
        style:TextStyle(fontFamily:'Alfa',fontSize:38,color:Colors.white))),
    const SizedBox(height:10),
    Text('Collect ⭐ stars · Dodge 👹 enemies\nUse d-pad to move',
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
            gradient:sel?const LinearGradient(colors:[kNeonRed,kNeonPurple]):null,
            color:sel?null:kDarkCard2,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:sel?Colors.transparent:Colors.white.withOpacity(0.08))),
          child:Text('Lv.${i+1}',style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
            fontSize:13,color:sel?Colors.white:Colors.white60))));
    })),
    const SizedBox(height:8),
    Text((_levels[_level]['name'] as String),
      style:const TextStyle(fontFamily:'Momo',fontSize:13,color:kNeonRed)),
    MiniLeaderboard(gameSlug:'ninja-tag',gameName:'Ninja Tag'),
    const Spacer(),
    GestureDetector(onTap:_start,child:Container(width:double.infinity,height:56,
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[kNeonRed,kNeonPurple]),
        borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:kNeonRed.withOpacity(0.4),blurRadius:20,offset:const Offset(0,6))]),
      child:const Center(child:Text('Enter Dojo 🥷',style:TextStyle(fontFamily:'Alfa',fontSize:20,color:Colors.white))))),
  ]));

  Widget _game(BuildContext context) {
    final size=MediaQuery.of(context).size;
    final gridPx=size.width-32;
    final cellSize=gridPx/_grid;
    return Column(children:[
      // HUD
      // HUD with Pause & Quit buttons
GameHUD(
  score: '$_score pts',
  level: 'Lv.${_level + 1} • ${_cfg['name']}',
  paused: _paused,
  onPause: () => setState(() => _paused = true),
  onQuit: _handleQuit,
  extra: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('⭐ ${_stars.length}', style: const TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white70)),
      const SizedBox(width: 12),
      Text('⏱ $_timeLeft s', style: TextStyle(
        fontFamily:'Alfa',
        fontSize:14,
        color: _timeLeft < 10 ? kNeonRed : kNeonBlue,
      )),
    ],
  ),
),
      const SizedBox(height:8),
      // Grid
      Container(margin:const EdgeInsets.symmetric(horizontal:16),
        width:gridPx,height:gridPx,
        decoration:BoxDecoration(color:kDarkCard,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:Colors.white.withOpacity(0.07))),
        child:CustomPaint(
          painter:_NinjaPainter(grid:_grid,px:_px,py:_py,
            enemies:_enemies,stars:_stars,walls:_walls,dead:_dead,
            cellSize:cellSize),
          child:const SizedBox.expand())),
      const Spacer(),
      // D-pad
      Padding(padding:const EdgeInsets.fromLTRB(40,0,40,16),child:Column(children:[
        _dpad(Icons.keyboard_arrow_up_rounded,  ()=>_move(0,-1)),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          _dpad(Icons.keyboard_arrow_left_rounded, ()=>_move(-1,0)),
          const SizedBox(width:52),
          _dpad(Icons.keyboard_arrow_right_rounded,()=>_move(1,0)),
        ]),
        _dpad(Icons.keyboard_arrow_down_rounded, ()=>_move(0,1)),
      ])),
    ]);
  }

  Widget _dpad(IconData icon,VoidCallback onTap)=>GestureDetector(onTap:onTap,
    child:Container(width:52,height:52,margin:const EdgeInsets.all(2),
      decoration:BoxDecoration(color:kDarkCard2,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:Colors.white.withOpacity(0.1))),
      child:Icon(icon,color:Colors.white70,size:28)));
}

class _NinjaPainter extends CustomPainter {
  final int grid,px,py;
  final List<Map<String,int>> enemies,stars,walls;
  final bool dead;
  final double cellSize;
  const _NinjaPainter({required this.grid,required this.px,required this.py,
    required this.enemies,required this.stars,required this.walls,
    required this.dead,required this.cellSize});

  Rect _cell(int x,int y)=>Rect.fromLTWH(x*cellSize+2,y*cellSize+2,cellSize-4,cellSize-4);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines
    final gp=Paint()..color=Colors.white.withOpacity(0.05)..strokeWidth=0.5;
    for(int i=0;i<=grid;i++){
      canvas.drawLine(Offset(i*cellSize,0),Offset(i*cellSize,size.height),gp);
      canvas.drawLine(Offset(0,i*cellSize),Offset(size.width,i*cellSize),gp);
    }
    // Walls
    for(final w in walls){
      canvas.drawRRect(RRect.fromRectAndRadius(_cell(w['x']!,w['y']!),const Radius.circular(4)),
        Paint()..color=Colors.blueGrey.shade800);
    }
    // Stars
    final tp=TextPainter(textDirection:TextDirection.ltr);
    for(final s in stars){
      tp.text=TextSpan(text:'⭐',style:TextStyle(fontSize:cellSize*0.55));
      tp.layout();
      tp.paint(canvas,Offset(s['x']!*cellSize+(cellSize-tp.width)/2,
          s['y']!*cellSize+(cellSize-tp.height)/2));
    }
    // Enemies
    for(final e in enemies){
      canvas.drawCircle(Offset(e['x']!*cellSize+cellSize/2,e['y']!*cellSize+cellSize/2),
        cellSize*0.38,Paint()..color=Colors.red.shade700);
      tp.text=TextSpan(text:'👹',style:TextStyle(fontSize:cellSize*0.45));
      tp.layout();
      tp.paint(canvas,Offset(e['x']!*cellSize+(cellSize-tp.width)/2,
          e['y']!*cellSize+(cellSize-tp.height)/2));
    }
    // Player
    canvas.drawCircle(Offset(px*cellSize+cellSize/2,py*cellSize+cellSize/2),
      cellSize*0.42,Paint()..color=(dead?Colors.red.shade900:const Color(0xFF6DD5FA)).withOpacity(0.8));
    tp.text=TextSpan(text:'🥷',style:TextStyle(fontSize:cellSize*0.5));
    tp.layout();
    tp.paint(canvas,Offset(px*cellSize+(cellSize-tp.width)/2,
        py*cellSize+(cellSize-tp.height)/2));
  }
  @override bool shouldRepaint(_NinjaPainter old)=>true;
}