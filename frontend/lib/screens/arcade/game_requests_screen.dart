// lib/screens/arcade/game_requests_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'game_engine.dart';

// ─── Game request model ───────────────────────────────────────
class GameRequest {
  final String id, senderTag, receiverTag, gameSlug, gameName, senderId;
  final int wager;
  final String status; // pending|accepted|declined|expired
  const GameRequest({
    required this.id, required this.senderTag, required this.receiverTag,
    required this.gameSlug, required this.gameName,
    required this.wager, required this.status, required this.senderId,
  });
  factory GameRequest.fromJson(Map<String,dynamic> j) => GameRequest(
    id:         j['id']?.toString()           ?? '',
    senderTag:  j['sender_tag']               ?? '',
    receiverTag:j['receiver_tag']             ?? '',
    gameSlug:   j['game_slug']                ?? '',
    gameName:   j['game_name']                ?? '',
    wager:      (j['wager'] as num?)?.toInt() ?? 0,
    status:     j['status']                   ?? 'pending',
    senderId:   j['sender_id']?.toString()    ?? '',
  );
}

// ─────────────────────────────────────────────────────────────
class GameRequestsScreen extends StatefulWidget {
  final int myTokens;
  const GameRequestsScreen({super.key, required this.myTokens});
  @override State<GameRequestsScreen> createState() => _GameRequestsScreenState();
}

class _GameRequestsScreenState extends State<GameRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _api        = ApiService();
  final _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;
  Timer? _pollTimer;

  List<Map<String,dynamic>> _searchResults = [];
  List<GameRequest>         _incoming      = [];
  List<GameRequest>         _outgoing      = [];
  bool _searching = false, _loadingReqs = true;

  // New request form state
  String? _selectedGameSlug, _selectedGameName;
  int     _wager = 0;
  Map<String,dynamic>? _selectedUser;

  final _games = [
    {'slug':'quiz-battle',    'name':'Quiz Battle',    'emoji':'🧠'},
    {'slug':'tic-tac-toe',    'name':'Tic Tac Toe',    'emoji':'⭕'},
    {'slug':'basketball',     'name':'Stickman Hoops', 'emoji':'🏀'},
    {'slug':'texas-poker',    'name':"Texas Hold'em",  'emoji':'🃏'},
    {'slug':'ninja-tag',      'name':'Ninja Tag',      'emoji':'🥷'},
    {'slug':'sushi-rush',     'name':'Sushi Rush',     'emoji':'🍣'},
    {'slug':'battle-bots',    'name':'Battle Bots',    'emoji':'🤖'},
    {'slug':'campus-craft',   'name':'Campus Craft',   'emoji':'🏗️'},
    {'slug':'pool-royale',    'name':'Pool Royale',    'emoji':'🎱'},
    {'slug':'spirit-racers',  'name':'Spirit Racers',  'emoji':'🏎️'},
    {'slug':'memory-match',   'name':'Memory Match',   'emoji':'🃏'},
    {'slug':'snake',          'name':'Snake',          'emoji':'🐍'},
    {'slug':'number-guesser', 'name':'Number Guesser', 'emoji':'🔢'},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadRequests();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadRequests());
  }

  @override
  void dispose() { _tabCtrl.dispose(); _searchCtrl.dispose();
    _pollTimer?.cancel(); super.dispose(); }

  Future<void> _loadRequests() async {
    try {
      final data = await _api.get('/arcade/game-requests/') as Map<String,dynamic>;
      if (!mounted) return;
      setState(() {
        _incoming = ((data['incoming'] as List?) ?? [])
            .map((e) => GameRequest.fromJson(e as Map<String,dynamic>)).toList();
        _outgoing = ((data['outgoing'] as List?) ?? [])
            .map((e) => GameRequest.fromJson(e as Map<String,dynamic>)).toList();
        _loadingReqs = false;
      });
    } catch (_) { if (mounted) setState(() => _loadingReqs = false); }
  }

  Future<void> _searchUsers(String q) async {
    if (q.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final data = await _api.get('/accounts/search/?q=${Uri.encodeComponent(q)}')
          as Map<String,dynamic>;
      if (!mounted) return;
      setState(() {
        _searchResults = ((data['results'] as List?) ?? [])
            .cast<Map<String,dynamic>>();
        _searching = false;
      });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  Future<void> _sendRequest() async {
    if (_selectedUser == null || _selectedGameSlug == null || _wager <= 0) {
      _snack('Select a player, game and wager amount');
      return;
    }
    if (_wager > widget.myTokens) {
      _snack('Not enough tokens! You have ${widget.myTokens} 🪙');
      return;
    }
    HapticFeedback.heavyImpact();
    try {
      await _api.post('/arcade/game-requests/', body: {
        'receiver_id':  _selectedUser!['user_id']?.toString() ?? _selectedUser!['id']?.toString(),
        'game_slug':    _selectedGameSlug,
        'wager':        _wager,
      });
      _snack('⚔️ Challenge sent to @${_selectedUser!['gamer_tag'] ?? _selectedUser!['name']}!',
        success: true);
      setState(() { _selectedUser = null; _selectedGameSlug = null; _wager = 0; });
      _loadRequests();
    } catch (e) { _snack('Failed: $e'); }
  }

  Future<void> _respond(GameRequest req, bool accept) async {
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/arcade/game-requests/${req.id}/${accept ? "accept" : "decline"}/', body: {});
      if (accept) {
        _snack('✅ Challenge accepted! Game starting...', success: true);
        // Navigate to the game with multiplayer session
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          Navigator.pop(context, {'action':'start_game','request':req});
        });
      } else {
        _snack('Declined the challenge');
        _loadRequests();
      }
    } catch (e) { _snack('Failed: $e'); }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily:'Momo')),
      backgroundColor: success ? Colors.green.shade700 : kDarkCard2,
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Column(children: [
        // Header
        Container(padding: const EdgeInsets.fromLTRB(16,12,16,0),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width:40,height:40,
                decoration:BoxDecoration(color:kDarkCard2,
                  borderRadius:BorderRadius.circular(12),
                  border:Border.all(color:Colors.white.withOpacity(0.08))),
                child:const Icon(Icons.arrow_back_rounded,color:Colors.white60,size:20))),
            const SizedBox(width:12),
            const Expanded(child:Text('⚔️ Game Challenges',
              style:TextStyle(fontFamily:'Alfa',fontSize:22,color:Colors.white))),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration:BoxDecoration(color:kNeonOrange.withOpacity(0.12),
                borderRadius:BorderRadius.circular(10),
                border:Border.all(color:kNeonOrange.withOpacity(0.3))),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                const Text('🪙',style:TextStyle(fontSize:14)),
                const SizedBox(width:4),
                Text('${widget.myTokens}',style:const TextStyle(fontFamily:'Alfa',
                  fontSize:14,color:kNeonOrange)),
              ])),
          ])),
        const SizedBox(height:12),
        // Tabs
        Container(margin:const EdgeInsets.symmetric(horizontal:16),
          decoration:BoxDecoration(color:kDarkCard,
            borderRadius:BorderRadius.circular(12),
            border:Border.all(color:Colors.white.withOpacity(0.06))),
          child:TabBar(controller:_tabCtrl,
            indicator:BoxDecoration(
              gradient:const LinearGradient(colors:[kNeonPurple,kNeonBlue]),
              borderRadius:BorderRadius.circular(10)),
            indicatorSize:TabBarIndicatorSize.tab,
            labelStyle:const TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,fontSize:13),
            unselectedLabelColor:Colors.white38,
            labelColor:Colors.white,
            dividerColor:Colors.transparent,
            tabs:const[Tab(text:'📨 Received'),Tab(text:'🗡 Challenge')])),
        Expanded(child:TabBarView(controller:_tabCtrl,children:[
          _requestsTab(),
          _challengeTab(),
        ])),
      ])),
    );
  }

  // ── Received requests ─────────────────────────────────────

  Widget _requestsTab() {
    if (_loadingReqs) {
      return const Center(
        child: CircularProgressIndicator(color: kNeonPurple));
    }

    final pending = _incoming.where((r) => r.status == 'pending').toList();

    if (pending.isEmpty) {
      return Center(child: Column(
      mainAxisSize:MainAxisSize.min, children:[
      const Text('⚔️',style:TextStyle(fontSize:52)),
      const SizedBox(height:14),
      const Text('No Challenges',style:TextStyle(fontFamily:'Alfa',
        fontSize:18,color:Colors.white)),
      const SizedBox(height:6),
      Text('Challenge friends from the Challenge tab!',
        style:TextStyle(fontFamily:'Momo',fontSize:13,
          color:Colors.white.withOpacity(0.4))),
    ]));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16,12,16,80),
      children: pending.map((req) => _RequestCard(
        req: req,
        onAccept: () => _respond(req, true),
        onDecline: () => _respond(req, false),
      )).toList(),
    );
  }

  // ── Send challenge ────────────────────────────────────────

  Widget _challengeTab() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16,12,16,80),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Step 1: Search player
      _stepLabel('1', 'Find a player'),
      const SizedBox(height:8),
      Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:4),
        decoration:BoxDecoration(color:kDarkCard,borderRadius:BorderRadius.circular(14),
          border:Border.all(color:Colors.white.withOpacity(0.07))),
        child:TextField(controller:_searchCtrl,
          style:const TextStyle(fontFamily:'Momo',fontSize:14,color:Colors.white),
          decoration:InputDecoration(
            hintText:'Search gamer tag...',
            hintStyle:TextStyle(fontFamily:'Momo',color:Colors.white38),
            prefixIcon:_searching
              ?const Padding(padding:EdgeInsets.all(12),
                child:SizedBox(width:16,height:16,child:CircularProgressIndicator(
                  color:kNeonPurple,strokeWidth:2)))
              :const Icon(Icons.search_rounded,color:Colors.white38),
            border:InputBorder.none,
            contentPadding:const EdgeInsets.symmetric(vertical:14)),
          onChanged:_searchUsers)),
      // Search results
      if (_searchResults.isNotEmpty)
        Container(margin:const EdgeInsets.only(top:8),
          decoration:BoxDecoration(color:kDarkCard2,borderRadius:BorderRadius.circular(12)),
          child:Column(children:_searchResults.take(5).map((u){
            final name=u['gamer_tag']??u['display_name']??'Unknown';
            final sel=_selectedUser==u;
            return GestureDetector(onTap:()=>setState(()=>_selectedUser=u),
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                decoration:BoxDecoration(
                  color:sel?kNeonPurple.withOpacity(0.15):Colors.transparent,
                  borderRadius:BorderRadius.circular(12),
                  border:sel?Border.all(color:kNeonPurple.withOpacity(0.4)):null),
                child:Row(children:[
                  Container(width:36,height:36,
                    decoration:BoxDecoration(gradient:const LinearGradient(
                      colors:[kNeonBlue,kNeonPurple]),shape:BoxShape.circle),
                    child:Center(child:Text(name.isNotEmpty?name[0].toUpperCase():'?',
                      style:const TextStyle(color:Colors.white,fontFamily:'Arch',
                        fontWeight:FontWeight.bold)))),
                  const SizedBox(width:12),
                  Expanded(child:Text('@$name',style:const TextStyle(fontFamily:'Arch',
                    fontWeight:FontWeight.bold,fontSize:14,color:Colors.white))),
                  if(sel)const Icon(Icons.check_circle_rounded,
                    color:kNeonPurple,size:18),
                ])));
          }).toList())),

      if (_selectedUser != null) ...[
        const SizedBox(height:6),
        Container(padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:kNeonPurple.withOpacity(0.08),
            borderRadius:BorderRadius.circular(10)),
          child:Row(children:[
            const Text('⚔️ Challenging: ',style:TextStyle(fontFamily:'Momo',
              fontSize:12,color:Colors.white54)),
            Text('@${_selectedUser!['gamer_tag']??_selectedUser!['display_name']}',
              style:const TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
                fontSize:13,color:kNeonPurple)),
          ])),
      ],

      const SizedBox(height:20),

      // Step 2: Select game
      _stepLabel('2','Pick a game'),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:_games.map((g){
        final sel=_selectedGameSlug==g['slug'];
        return GestureDetector(onTap:()=>setState((){
          _selectedGameSlug=g['slug'] as String;
          _selectedGameName=g['name'] as String;
        }),child:AnimatedContainer(duration:const Duration(milliseconds:200),
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(
            gradient:sel?const LinearGradient(colors:[kNeonBlue,kNeonPurple]):null,
            color:sel?null:kDarkCard2,borderRadius:BorderRadius.circular(10),
            border:Border.all(color:sel?Colors.transparent:Colors.white.withOpacity(0.07))),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
            Text(g['emoji'] as String,style:const TextStyle(fontSize:16)),
            const SizedBox(width:6),
            Text(g['name'] as String,style:TextStyle(fontFamily:'Arch',
              fontWeight:FontWeight.bold,fontSize:12,
              color:sel?Colors.white:Colors.white60)),
          ])));
      }).toList()),

      const SizedBox(height:20),

      // Step 3: Wager
      _stepLabel('3','Set wager'),
      const SizedBox(height:8),
      Text('You have ${widget.myTokens} 🪙 tokens',
        style:TextStyle(fontFamily:'Momo',fontSize:12,color:Colors.white38)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[10,25,50,100,200,500].map((amt){
        final sel=_wager==amt;
        final enough=amt<=widget.myTokens;
        return GestureDetector(onTap:enough?()=>setState(()=>_wager=amt):null,
          child:AnimatedContainer(duration:const Duration(milliseconds:200),
            padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
            decoration:BoxDecoration(
              gradient:sel?const LinearGradient(colors:[kNeonOrange,kNeonRed]):null,
              color:sel?null:enough?kDarkCard2:kDarkCard2.withOpacity(0.4),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:sel?Colors.transparent:
                Colors.white.withOpacity(enough?0.08:0.03))),
            child:Text('🪙 $amt',style:TextStyle(fontFamily:'Arch',
              fontWeight:FontWeight.bold,fontSize:13,
              color:sel?Colors.white:enough?Colors.white60:Colors.white24))));
      }).toList()),

      const SizedBox(height:24),

      // Summary & send
      if (_selectedUser != null && _selectedGameSlug != null && _wager > 0)
        Container(padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:kDarkCard,borderRadius:BorderRadius.circular(16),
            border:Border.all(color:kNeonOrange.withOpacity(0.2))),
          child:Column(children:[
            Row(children:[
              const Text('🎮',style:TextStyle(fontSize:18)),
              const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('vs @${_selectedUser!['gamer_tag']??'?'}',
                  style:const TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
                    fontSize:15,color:Colors.white)),
                Text('$_selectedGameName · 🪙 $_wager at stake',
                  style:const TextStyle(fontFamily:'Momo',fontSize:12,color:Colors.white54)),
              ])),
            ]),
            const SizedBox(height:14),
            GestureDetector(onTap:_sendRequest,
              child:Container(width:double.infinity,height:50,
                decoration:BoxDecoration(
                  gradient:const LinearGradient(colors:[kNeonOrange,kNeonRed]),
                  borderRadius:BorderRadius.circular(12)),
                child:const Center(child:Text('⚔️ Send Challenge!',
                  style:TextStyle(fontFamily:'Arch',fontWeight:FontWeight.bold,
                    fontSize:16,color:Colors.white))))),
          ])),
    ]),
  );

  Widget _stepLabel(String n, String label) => Row(children:[
    Container(width:26,height:26,
      decoration:BoxDecoration(gradient:const LinearGradient(colors:[kNeonPurple,kNeonBlue]),
        shape:BoxShape.circle),
      child:Center(child:Text(n,style:const TextStyle(fontFamily:'Alfa',
        fontSize:13,color:Colors.white)))),
    const SizedBox(width:8),
    Text(label,style:const TextStyle(fontFamily:'Alfa',fontSize:16,color:Colors.white)),
  ]);
}

// ─── Request card ─────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final GameRequest req;
  final VoidCallback onAccept, onDecline;
  const _RequestCard({required this.req, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom:12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kDarkCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kNeonOrange.withOpacity(0.2)),
        boxShadow:[BoxShadow(color:kNeonOrange.withOpacity(0.08),
          blurRadius:12,offset:const Offset(0,4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width:44,height:44,
            decoration:BoxDecoration(gradient:const LinearGradient(
              colors:[kNeonPurple,kNeonBlue]),shape:BoxShape.circle),
            child:Center(child:Text(
              req.senderTag.isNotEmpty?req.senderTag[0].toUpperCase():'?',
              style:const TextStyle(color:Colors.white,fontFamily:'Arch',
                fontWeight:FontWeight.bold,fontSize:18)))),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('@${req.senderTag}',style:const TextStyle(fontFamily:'Arch',
              fontWeight:FontWeight.bold,fontSize:15,color:Colors.white)),
            Text('challenged you!',style:TextStyle(fontFamily:'Momo',
              fontSize:12,color:Colors.white.withOpacity(0.5))),
          ])),
          Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
            decoration:BoxDecoration(color:kNeonOrange.withOpacity(0.12),
              borderRadius:BorderRadius.circular(20),
              border:Border.all(color:kNeonOrange.withOpacity(0.3))),
            child:Text('🪙 ${req.wager}',style:const TextStyle(fontFamily:'Alfa',
              fontSize:14,color:kNeonOrange))),
        ]),
        const SizedBox(height:12),
        Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(color:kDarkCard2,borderRadius:BorderRadius.circular(10)),
          child:Row(children:[
            const Text('🎮',style:TextStyle(fontSize:16)),
            const SizedBox(width:8),
            Text(req.gameName,style:const TextStyle(fontFamily:'Arch',
              fontWeight:FontWeight.bold,fontSize:14,color:Colors.white)),
          ])),
        const SizedBox(height:10),
        Text('Accepting deducts 🪙 ${req.wager} from your wallet.',
          style:TextStyle(fontFamily:'Momo',fontSize:11,color:Colors.white38)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:GestureDetector(onTap:onDecline,
            child:Container(height:44,
              decoration:BoxDecoration(color:kNeonRed.withOpacity(0.1),
                borderRadius:BorderRadius.circular(12),
                border:Border.all(color:kNeonRed.withOpacity(0.3))),
              child:const Center(child:Text('✕  Decline',style:TextStyle(
                fontFamily:'Arch',fontWeight:FontWeight.bold,
                fontSize:14,color:kNeonRed)))))),
          const SizedBox(width:10),
          Expanded(child:GestureDetector(onTap:onAccept,
            child:Container(height:44,
              decoration:BoxDecoration(
                gradient:const LinearGradient(colors:[Color(0xFF388E3C),Color(0xFF1B5E20)]),
                borderRadius:BorderRadius.circular(12)),
              child:const Center(child:Text('⚔️  Accept!',style:TextStyle(
                fontFamily:'Arch',fontWeight:FontWeight.bold,
                fontSize:14,color:Colors.white)))))),
        ]),
      ]),
    );
  }
}