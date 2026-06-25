// lib/screens/arcade/spirit_racers_game.dart
import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_engine.dart';

class SpiritRacersGame extends StatefulWidget {
  const SpiritRacersGame({super.key});
  @override
  State<SpiritRacersGame> createState() => _SpiritRacersGameState();
}

class _SpiritRacersGameState extends State<SpiritRacersGame>
    with SingleTickerProviderStateMixin {
  // ── Level config ──────────────────────────────────────────
  static const _levels = [
    {'name':'Rookie Track',   'speed':4.0, 'spawnRate':80,  'lanes':3, 'obstacleW':0.18},
    {'name':'Street Circuit', 'speed':6.5, 'spawnRate':55,  'lanes':3, 'obstacleW':0.22},
    {'name':'Turbo Challenge','speed':9.0, 'spawnRate':35,  'lanes':4, 'obstacleW':0.25},
  ];

  int    _level    = 0;
  bool   _showStory = true;
  bool   _started  = false;
  bool   _dead     = false;
  bool   _paused   = false;
  int    _lane     = 1;
  int    _score    = 0;
  int    _tick     = 0;
  double _bgOffset = 0;

  // obstacles: {lane, y, color}
  List<Map<String, dynamic>> _obstacles = [];
  List<Map<String, dynamic>> _coins     = [];
  Timer? _timer;
  final _rng = Random();

  // Car colours per lane
  final _carColors = [
    const Color(0xFF6DD5FA), const Color(0xFF8E54E9),
    const Color(0xFFF7971E), const Color(0xFFFF5858),
  ];
  final _obsColors = [
    Colors.red.shade700, Colors.orange.shade800,
    Colors.purple.shade800, Colors.teal.shade700,
  ];

  Future<void> _handleQuit() async {
    _timer?.cancel();
    setState(()=>_paused=true);
    final quit=await showQuitDialog(context);
    if(!mounted)return;
    if(quit){
      Navigator.pushReplacement(context,MaterialPageRoute(
        builder:(_)=>GameOverScreen(result:GameResult(
          gameSlug:'spirit-racers',gameName:'Spirit Racers',
          score:_score,outcome:'complete'))));
    } else {
      setState(()=>_paused=false);
      _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick_());
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Map get _cfg => _levels[_level];
  int get _laneCount => _cfg['lanes'] as int;

  void _start() {
    setState(() { _started=true; _dead=false; _score=0; _tick=0;
      _obstacles=[]; _coins=[]; _lane=_laneCount~/2; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick_());
  }

  void _tick_() {
    if (!mounted || _paused) return;
    setState(() {
      _tick++;
      final speed = (_cfg['speed'] as double) + _score / 200.0;
      _bgOffset = (_bgOffset + speed) % 100;

      // Move obstacles
      for (final o in _obstacles) {
        o['y'] = (o['y'] as double) + speed;
      }
      for (final c in _coins) {
        c['y'] = (c['y'] as double) + speed;
      }

      // Spawn obstacles
      if (_tick % (_cfg['spawnRate'] as int) == 0) {
        final lane = _rng.nextInt(_laneCount);
        _obstacles.add({'lane': lane, 'y': -80.0,
            'color': _obsColors[_rng.nextInt(_obsColors.length)]});
      }

      // Spawn coins
      if (_tick % 120 == 0) {
        final lane = _rng.nextInt(_laneCount);
        _coins.add({'lane': lane, 'y': -40.0});
      }

      // Remove off-screen
      _obstacles.removeWhere((o) => (o['y'] as double) > 900);
      _coins.removeWhere((c) => (c['y'] as double) > 900);

      // Collision
      for (final o in _obstacles) {
        if (o['lane'] == _lane && (o['y'] as double) > 580 && (o['y'] as double) < 680) {
          _gameOver(); return;
        }
      }

      // Coin collect
      _coins.removeWhere((c) {
        if (c['lane'] == _lane && (c['y'] as double) > 580 && (c['y'] as double) < 680) {
          _score += 5; HapticFeedback.lightImpact(); return true;
        }
        return false;
      });

      _score++;
    });
  }

  void _gameOver() {
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _dead = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => GameOverScreen(result: GameResult(
          gameSlug: 'spirit-racers', gameName: 'Spirit Racers',
          score: _score, outcome: 'lose',
          extra: {'level': _level + 1},
        ))));
    });
  }

  void _steer(int dir) {
    if (_dead || !_started) return;
    HapticFeedback.lightImpact();
    setState(() => _lane = (_lane + dir).clamp(0, _laneCount - 1));
  }

  @override
  Widget build(BuildContext context) {
    if(_showStory&&shouldShowStory('spirit-racers')){
      return GameStoryScreen(gameSlug:'spirit-racers',
        onPlay:()=>setState(()=>_showStory=false));
    }
    if (!_started) return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: _landing()));
    return Scaffold(backgroundColor: kDarkBg, body: SafeArea(child: Stack(children: [
      _game(context),
      if(_paused) PauseOverlay(gameName:'Spirit Racers',
        onResume:()=>setState(()=>_paused=false),onQuit:_handleQuit),
    ])));
  }

  Widget _landing() => Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: () => Navigator.pop(context),
      child: Container(width:40,height:40,decoration:BoxDecoration(color:kDarkCard2,
        borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white.withOpacity(0.08))),
        child:const Icon(Icons.arrow_back_rounded,color:Colors.white60,size:20)))),
    const Spacer(),
    const T('🏎️', style: TextStyle(fontSize:80)),
    const SizedBox(height:16),
    ShaderMask(shaderCallback:(b)=>const LinearGradient(colors:[kNeonBlue,kNeonOrange]).createShader(b),
      blendMode:BlendMode.srcIn, child:const T('Spirit Racers',
        style:TextStyle(fontFamily:'Alfa',fontSize:38,color:Colors.white))),
    const SizedBox(height:10),
    T('Dodge obstacles · Collect coins\nSwipe left/right to steer',
      textAlign:TextAlign.center,
      style:TextStyle(fontFamily:'Momo',fontSize:13,color:Colors.white.withOpacity(0.5),height:1.6)),
    const SizedBox(height:20),
    // Level selector
    Row(mainAxisAlignment:MainAxisAlignment.center, children:List.generate(3,(i){
      final sel = i==_level;
      return GestureDetector(onTap:()=>setState(()=>_level=i),
        child:AnimatedContainer(duration:const Duration(milliseconds:200),
          margin:const EdgeInsets.symmetric(horizontal:6),
          padding:const EdgeInsets.symmetric(horizontal:18,vertical:10),
          decoration:BoxDecoration(
            gradient:sel?const LinearGradient(colors:[kNeonBlue,kNeonOrange]):null,
            color:sel?null:kDarkCard2,borderRadius:BorderRadius.circular(12),
            border:Border.all(color:sel?Colors.transparent:Colors.white.withOpacity(0.08))),
          child:Text('Lv.${i+1}',style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
            fontSize:13,color:sel?Colors.white:Colors.white60))));
    })),
    const SizedBox(height:8),
    Text((_levels[_level]['name'] as String),
      style:const TextStyle(fontFamily:'Momo',fontSize:13,color:kNeonOrange)),
    MiniLeaderboard(gameSlug:'spirit-racers',gameName:'Spirit Racers'),
    const Spacer(),
    GestureDetector(onTap:_start,child:Container(width:double.infinity,height:56,
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[kNeonBlue,kNeonOrange]),
        borderRadius:BorderRadius.circular(16),
        boxShadow:[BoxShadow(color:kNeonBlue.withOpacity(0.4),blurRadius:20,offset:const Offset(0,6))]),
      child:const Center(child:T('Race! 🏁',style:TextStyle(fontFamily:'Alfa',fontSize:20,color:Colors.white))))),
  ]));

  Widget _game(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onHorizontalDragEnd: (d) => _steer(d.primaryVelocity!.sign.toInt()),
      child: Column(children: [
        // HUD
        Padding(padding:const EdgeInsets.fromLTRB(16,10,16,0),
          child:Row(children:[
            Text('Lv.${_level+1}',style:const TextStyle(fontFamily:'Alfa',fontSize:14,color:kNeonBlue)),
            const Spacer(),
            Text('$_score pts',style:const TextStyle(fontFamily:'Alfa',fontSize:18,color:kNeonOrange)),
            const Spacer(),
            GestureDetector(onTap:()=>setState(()=>_paused=true),
              child:const Icon(Icons.pause_rounded,color:Colors.white60,size:22)),
          ])),
        // Road
        Expanded(child:ClipRect(child:CustomPaint(
          painter:_RoadPainter(
            laneCount:_laneCount, playerLane:_lane,
            obstacles:_obstacles, coins:_coins,
            bgOffset:_bgOffset, dead:_dead,
            carColors:_carColors,
          ),
          child:const SizedBox.expand()))),
        // Controls
        Container(color:kDarkCard,padding:const EdgeInsets.fromLTRB(24,12,24,16),
          child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            GestureDetector(onTap:()=>_steer(-1),child:Container(width:70,height:50,
              decoration:BoxDecoration(color:kNeonBlue.withOpacity(0.15),
                borderRadius:BorderRadius.circular(12),
                border:Border.all(color:kNeonBlue.withOpacity(0.3))),
              child:const Icon(Icons.arrow_back_rounded,color:kNeonBlue,size:28))),
            Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
              decoration:BoxDecoration(color:kDarkCard2,borderRadius:BorderRadius.circular(10)),
              child:Text('Lane ${_lane+1}/$_laneCount',
                style:const TextStyle(fontFamily:'Momo',fontSize:12,color:Colors.white54))),
            GestureDetector(onTap:()=>_steer(1),child:Container(width:70,height:50,
              decoration:BoxDecoration(color:kNeonOrange.withOpacity(0.15),
                borderRadius:BorderRadius.circular(12),
                border:Border.all(color:kNeonOrange.withOpacity(0.3))),
              child:const Icon(Icons.arrow_forward_rounded,color:kNeonOrange,size:28))),
          ])),
      ]),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final int laneCount, playerLane;
  final List<Map<String,dynamic>> obstacles, coins;
  final double bgOffset;
  final bool dead;
  final List<Color> carColors;
  const _RoadPainter({required this.laneCount,required this.playerLane,
    required this.obstacles,required this.coins,required this.bgOffset,
    required this.dead,required this.carColors});

  @override
  void paint(Canvas canvas, Size size) {
    final laneW = size.width / laneCount;
    // Road bg
    canvas.drawRect(Rect.fromLTWH(0,0,size.width,size.height),
      Paint()..color=const Color(0xFF1A2030));
    // Road stripes
    final stripePaint = Paint()..color=Colors.white.withOpacity(0.15)..strokeWidth=2;
    for(int l=1;l<laneCount;l++){
      final x = laneW*l;
      for(double y=-bgOffset%40;y<size.height;y+=40) {
        canvas.drawLine(Offset(x,y),Offset(x,y+20),stripePaint);
      }
    }
    // Road edges
    canvas.drawRect(Rect.fromLTWH(0,0,8,size.height),
      Paint()..color=const Color(0xFFF7971E));
    canvas.drawRect(Rect.fromLTWH(size.width-8,0,8,size.height),
      Paint()..color=const Color(0xFFF7971E));

    // Coins
    for(final c in coins){
      final cx = laneW*(c['lane'] as int)+laneW/2;
      final cy = c['y'] as double;
      canvas.drawCircle(Offset(cx,cy),10,Paint()..color=const Color(0xFFFFD700));
      canvas.drawCircle(Offset(cx,cy),6,Paint()..color=Colors.white.withOpacity(0.8));
    }

    // Obstacles (other cars)
    for(final o in obstacles){
      final ox = laneW*(o['lane'] as int)+laneW*0.15;
      final oy = o['y'] as double;
      final ow = laneW*0.7; const oh = 60.0;
      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(ox,oy,ow,oh),const Radius.circular(10));
      canvas.drawRRect(rr,Paint()..color=(o['color'] as Color));
      // windows
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox+6,oy+8,ow-12,14),const Radius.circular(4)),
        Paint()..color=Colors.lightBlue.shade200.withOpacity(0.8));
    }

    // Player car
    final px = laneW*playerLane+laneW*0.1;
    const py = 600.0; final pw = laneW*0.8; const ph = 70.0;
    final carColor = dead ? Colors.red.shade700 : carColors[playerLane % carColors.length];
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px,py,pw,ph),const Radius.circular(12)),
      Paint()..color=carColor);
    // windshield
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px+6,py+10,pw-12,18),const Radius.circular(5)),
      Paint()..color=Colors.lightBlue.withOpacity(0.7));
    // wheels
    for(final wx in [px+6.0,px+pw-14.0]){
      for(final wy in [py+4.0,py+ph-14.0]){
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wx,wy,8,10),const Radius.circular(3)),
          Paint()..color=Colors.black87);
      }
    }
    // flame when dead
    if(dead){
      final flamePaint = Paint()..color=Colors.orange.shade600.withOpacity(0.8);
      canvas.drawOval(Rect.fromLTWH(px+pw*0.2,py-20,pw*0.6,30),flamePaint);
    }
  }
  @override bool shouldRepaint(_RoadPainter old) => true;
}