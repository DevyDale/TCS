// lib/screens/arcade/game_requests_screen.dart
//
// Two tabs:
//   • Incoming  — challenges sent to me (accept/decline)
//   • New       — search players, pick a game, set a wager, send invite
//
// "New" tab supports up to 4 recipients for ROYALE games; 1-on-1 for
// FIRST_COME games; and hides the "Challenge" button entirely for
// SOLO_ONLY games.

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'arcade_registry.dart';


const _kDarkBg     = Color(0xFF0D0D1A);
Color get _kDarkCard => AppC.card;
Color get _kDarkCard2 => AppC.card2;
const _kNeonBlue   = Color(0xFF6DD5FA);
const _kNeonPurple = Color(0xFF8E54E9);
const _kNeonOrange = Color(0xFFF7971E);
const _kNeonRed    = Color(0xFFFF5858);
const _kTokenColor = Color(0xFFFFD700);

const _kMaxRecipients = 4;
const _kWagerOptions  = [0, 10, 25, 50, 100, 200, 500];


// ─────────────────────────────────────────────────────────────
class GameRequestsScreen extends StatefulWidget {
  final int myTokens;
  const GameRequestsScreen({super.key, required this.myTokens});
  @override
  State<GameRequestsScreen> createState() => _GameRequestsScreenState();
}

class _GameRequestsScreenState extends State<GameRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _api  = ApiService();
  late TabController _tab;

  List<_Req>      _incoming  = [];
  List<dynamic>   _games     = [];
  bool _loading = true;
  int  _myTokens = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _myTokens = widget.myTokens;
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final reqs  = await _api.getGameRequests();
      final games = await _api.getGames();
      final wallet = await _api.getTokenWallet();
      if (!mounted) return;
      setState(() {
        _incoming = (reqs as List? ?? const [])
            .map((m) => _Req.fromJson(m as Map<String, dynamic>))
            .toList();
        _games    = games as List? ?? const [];
        _myTokens = (wallet as Map?)?['tokens'] as int? ?? _myTokens;
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Accept / decline ───────────────────────────────────
  Future<void> _accept(_Req r) async {
    if (r.wager > _myTokens) {
      _snack('You only have $_myTokens 🪙 — wager is ${r.wager}');
      return;
    }
    HapticFeedback.mediumImpact();
    try {
      final res = await _api.acceptChallenge(r.id) as Map<String, dynamic>;
      _snack('⚔️ Challenge accepted!', success: true);
      if (!mounted) return;
      Navigator.pop(context, {
        'action':  'start_game',
        'session': res['session'],
      });
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _decline(_Req r) async {
    HapticFeedback.lightImpact();
    try {
      await _api.declineChallenge(r.id);
      _snack('Declined');
      _loadAll();
    } catch (e) { _snack('Failed: $e'); }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: success ? Colors.green.shade700 : _kNeonRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg,
        elevation: 0,
        title: T('Challenges',
          style: TextStyle(fontFamily: 'Alfa', color: AppC.text)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kNeonPurple,
          labelStyle: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Incoming (${_incoming.length})'),
            const Tab(text: 'New Challenge'),
          ],
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: _kNeonBlue))
        : TabBarView(controller: _tab, children: [
            _IncomingList(
              items:    _incoming,
              myTokens: _myTokens,
              onAccept: _accept,
              onDecline:_decline,
              onRefresh:_loadAll,
            ),
            _NewChallengeTab(
              games:    _games,
              myTokens: _myTokens,
              onSent:   _loadAll,
            ),
          ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────
//                          DATA
// ─────────────────────────────────────────────────────────────
class _Req {
  final String id, gameSlug, gameName, senderTag, senderName,
               senderAvatar, inviteId;
  final int    wager, senderLevel;
  _Req({
    required this.id, required this.inviteId,
    required this.gameSlug, required this.gameName,
    required this.senderTag, required this.senderName,
    required this.senderAvatar, required this.wager,
    required this.senderLevel,
  });
  factory _Req.fromJson(Map<String, dynamic> j) => _Req(
    id:           j['id']            as String? ?? '',
    inviteId:     j['invite_id']     as String? ?? '',
    gameSlug:     j['game_slug']     as String? ?? '',
    gameName:     j['game_name']     as String? ?? '',
    senderTag:    j['sender_tag']    as String? ?? '',
    senderName:   j['sender_name']   as String? ?? 'Player',
    senderAvatar: j['sender_avatar'] as String? ?? '',
    wager:        j['wager']         as int?    ?? 0,
    senderLevel:  j['sender_level']  as int?    ?? 1,
  );
}


// ─────────────────────────────────────────────────────────────
//                       INCOMING LIST
// ─────────────────────────────────────────────────────────────
class _IncomingList extends StatelessWidget {
  final List<_Req> items;
  final int        myTokens;
  final Function(_Req) onAccept, onDecline;
  final VoidCallback   onRefresh;
  const _IncomingList({
    required this.items, required this.myTokens,
    required this.onAccept, required this.onDecline,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(children: const [
          SizedBox(height: 120),
          Center(child: T('🎮', style: TextStyle(fontSize: 64))),
          SizedBox(height: 12),
          Center(child: T('No challenges right now',
            style: TextStyle(fontFamily: 'Alfa', color: Colors.white60,
                fontSize: 16))),
          SizedBox(height: 6),
          Center(child: T('Pull down to refresh',
            style: TextStyle(fontFamily: 'Momo', color: Colors.white24,
                fontSize: 12))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _IncomingCard(
          req: items[i], myTokens: myTokens,
          onAccept: () => onAccept(items[i]),
          onDecline:() => onDecline(items[i]),
        ),
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  final _Req req;
  final int  myTokens;
  final VoidCallback onAccept, onDecline;
  const _IncomingCard({
    required this.req, required this.myTokens,
    required this.onAccept, required this.onDecline,
  });
  @override
  Widget build(BuildContext context) {
    final canAfford = req.wager <= myTokens;
    return Container(
      margin:  const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDarkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kNeonPurple.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _kNeonPurple.withOpacity(0.25),
            backgroundImage: req.senderAvatar.isNotEmpty
                ? NetworkImage(req.senderAvatar) : null,
            child: req.senderAvatar.isEmpty
                ? Text(req.senderName.isNotEmpty
                    ? req.senderName[0].toUpperCase() : '?',
                  style: TextStyle(color: AppC.text,
                      fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 18))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment:
              CrossAxisAlignment.start, children: [
            Text('@${req.senderTag.isNotEmpty ? req.senderTag : req.senderName}',
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 15,
                  color: AppC.text)),
            Text('Lv ${req.senderLevel} · challenged you',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                  color: AppC.text.withOpacity(0.5))),
          ])),
          Container(padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kNeonOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kNeonOrange.withOpacity(0.3))),
            child: Text('🪙 ${req.wager}',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 14, color: _kNeonOrange))),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _kDarkCard2,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const T('🎮', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(req.gameName,
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: AppC.text)),
          ])),
        const SizedBox(height: 10),
        Text(canAfford
            ? 'Accepting deducts 🪙 ${req.wager} from your wallet.'
            : '⚠ Not enough tokens (you have $myTokens 🪙).',
          style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: canAfford ? Colors.white38 : _kNeonRed)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(onTap: onDecline,
            child: Container(height: 44,
              decoration: BoxDecoration(color: _kNeonRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kNeonRed.withOpacity(0.3))),
              child: const Center(child: T('✕  Decline',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 14,
                    color: _kNeonRed)))))),
          const SizedBox(width: 10),
          Expanded(child: Opacity(opacity: canAfford ? 1.0 : 0.4,
            child: GestureDetector(onTap: canAfford ? onAccept : null,
              child: Container(height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF388E3C), Color(0xFF1B5E20)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: T('⚔  Accept',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 14,
                      color: AppC.text)))))))
        ]),
      ]),
    );
  }
}


// ─────────────────────────────────────────────────────────────
//                       NEW CHALLENGE TAB
// ─────────────────────────────────────────────────────────────
class _NewChallengeTab extends StatefulWidget {
  final List<dynamic> games;
  final int           myTokens;
  final VoidCallback  onSent;
  const _NewChallengeTab({
    required this.games, required this.myTokens, required this.onSent,
  });
  @override
  State<_NewChallengeTab> createState() => _NewChallengeTabState();
}

class _NewChallengeTabState extends State<_NewChallengeTab> {
  final _api    = ApiService();
  final _search = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults  = [];
  bool                       _searching      = false;

  // Selected players (max 4)
  final List<Map<String, dynamic>> _selected = [];

  Map<String, dynamic>? _selectedGame;
  int _wager = 0;
  bool _sending = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  // ── Game properties ────────────────────────────────────
  bool get _isRoyale =>
      _selectedGame?['invite_mode'] == 'royale';
  bool get _isMultiCapable =>
      _isRoyale; // only royale supports >1 recipient
  int  get _maxSelectable => _isMultiCapable ? _kMaxRecipients : 1;

  void _onSearchChange(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _api.searchGamers(query: q.trim()) as Map?;
      if (!mounted) return;
      setState(() {
        _searchResults = (res?['results'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleSelected(Map<String, dynamic> u) {
    HapticFeedback.lightImpact();
    final id = u['user_id'] as String? ?? '';
    if (id.isEmpty) return;
    final already = _selected.indexWhere((x) => x['user_id'] == id);
    setState(() {
      if (already >= 0) {
        _selected.removeAt(already);
      } else {
        if (_selected.length >= _maxSelectable) {
          // For 1v1 games, replace; for royale, ignore extra clicks beyond max.
          if (_maxSelectable == 1) _selected.clear();
          else return;
        }
        _selected.add(u);
      }
    });
  }

  void _pickGame(Map<String, dynamic> g) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedGame = g;
      // If switching from a royale to a 1v1 game with multiple selections,
      // trim to 1.
      if (!_isMultiCapable && _selected.length > 1) {
        _selected.removeRange(1, _selected.length);
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty) {
      _snack('Pick at least one player');         return;
    }
    if (_selectedGame == null) {
      _snack('Pick a game');                       return;
    }
    final perPlayerCost = _wager;
    if (perPlayerCost > widget.myTokens) {
      _snack('Wager exceeds your wallet (${widget.myTokens} 🪙)'); return;
    }

    setState(() => _sending = true);
    try {
      await _api.createChallenge(
        gameSlug:         _selectedGame!['slug'] as String,
        recipientUserIds: _selected
            .map((u) => u['user_id'] as String).toList(),
        wager:            perPlayerCost,
      );
      if (!mounted) return;
      _snack('⚔️ Challenge sent to ${_selected.length} player'
          '${_selected.length > 1 ? 's' : ''}!', success: true);
      setState(() {
        _selected.clear();
        _selectedGame = null;
        _wager = 0;
        _searchResults = [];
        _search.clear();
        _sending = false;
      });
      widget.onSent();
    } catch (e) {
      _snack('Failed: $e');
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String m, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: success ? Colors.green.shade700 : _kNeonRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── UI ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Only offer games that are actually built AND aren't solo-only — so an
    // accepted challenge never dead-ends on a "coming soon" message.
    final challengable = (widget.games as List)
        .where((g) =>
            (g as Map)['invite_mode'] != 'solo_only' &&
            isGameBuilt((g['slug'] ?? '').toString())).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepLabel('1', 'Find players'),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged:  _onSearchChange,
          style: TextStyle(color: AppC.text,
              fontFamily: 'Momo', fontSize: 14),
          decoration: InputDecoration(
            hintText: TranslationService.I.tr('Search by gamer tag or name...'),
            hintStyle: TextStyle(fontFamily: 'Momo',
                color: AppC.text.withOpacity(0.3)),
            filled: true, fillColor: _kDarkCard,
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searching
              ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: _kNeonBlue)))
              : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:   BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),

        // Selected pills
        if (_selected.isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6,
            children: _selected.map((u) => _selectedPill(u)).toList()),

        // Search results
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: _kDarkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05))),
            padding: const EdgeInsets.all(8),
            child: Column(children: _searchResults.map((u) {
              final id  = u['user_id']      as String? ?? '';
              final tag = u['gamer_tag']    as String? ?? '';
              final n   = u['display_name'] as String? ?? 'Player';
              final av  = u['avatar_url']   as String? ?? '';
              final sel = _selected.any((x) => x['user_id'] == id);
              return GestureDetector(onTap: () => _toggleSelected(u),
                child: Container(margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sel ? _kNeonPurple.withOpacity(0.15)
                               : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel
                        ? _kNeonPurple.withOpacity(0.5) : Colors.transparent)),
                  child: Row(children: [
                    CircleAvatar(radius: 16,
                      backgroundColor: _kNeonPurple.withOpacity(0.25),
                      backgroundImage: av.isNotEmpty ? NetworkImage(av) : null,
                      child: av.isEmpty ? Text(
                        n.isNotEmpty ? n[0].toUpperCase() : '?',
                        style: TextStyle(color: AppC.text,
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold)) : null),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment:
                        CrossAxisAlignment.start, children: [
                      Text('@${tag.isNotEmpty ? tag : n}',
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: AppC.text)),
                      Text(n, style: TextStyle(fontFamily: 'Momo',
                          fontSize: 10, color: Colors.white38)),
                    ])),
                    if (sel) const Icon(Icons.check_circle_rounded,
                        color: _kNeonPurple, size: 20),
                  ])));
            }).toList()),
          ),
        ],

        const SizedBox(height: 22),
        _stepLabel('2', 'Pick a game'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: challengable.map((g) {
          final m   = g as Map<String, dynamic>;
          final sel = _selectedGame?['slug'] == m['slug'];
          final royale = m['invite_mode'] == 'royale';
          return GestureDetector(onTap: () => _pickGame(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(
                    colors: [_kNeonBlue, _kNeonPurple]) : null,
                color:    sel ? null : _kDarkCard2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? Colors.transparent
                               : Colors.white.withOpacity(0.07))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m['name'] as String? ?? '',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 12,
                      color: sel ? Colors.white : Colors.white60)),
                if (royale) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kNeonOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4)),
                    child: const T('1-4',
                      style: TextStyle(fontFamily: 'Momo',
                          fontWeight: FontWeight.bold, fontSize: 9,
                          color: _kNeonOrange))),
                ],
              ])));
        }).toList()),
        if (_selectedGame != null) ...[
          const SizedBox(height: 10),
          Text(_isMultiCapable
              ? '💡 Royale: invite up to $_kMaxRecipients players. '
                  'Winner takes the whole pot.'
              : '🆚 1-on-1 challenge.',
            style: const TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: Colors.white54)),
        ],

        const SizedBox(height: 22),
        _stepLabel('3', 'Set wager'),
        const SizedBox(height: 6),
        Text('You have ${widget.myTokens} 🪙',
          style: const TextStyle(fontFamily: 'Momo',
              fontSize: 12, color: Colors.white38)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _kWagerOptions.map((amt) {
          final sel = _wager == amt;
          final ok  = amt <= widget.myTokens;
          return GestureDetector(
            onTap: ok ? () { HapticFeedback.lightImpact();
                              setState(() => _wager = amt); } : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(
                    colors: [_kNeonOrange, _kNeonRed]) : null,
                color:    sel ? null : _kDarkCard2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? Colors.transparent
                               : Colors.white.withOpacity(0.07))),
              child: Text(amt == 0 ? 'Free' : '🪙 $amt',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: ok ? (sel ? Colors.white : Colors.white60)
                              : Colors.white24))));
        }).toList()),

        const SizedBox(height: 32),

        // Send button
        Opacity(opacity: _sending ? 0.6 : 1.0,
          child: GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kNeonBlue, _kNeonPurple]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _kNeonPurple.withOpacity(0.3),
                    blurRadius: 16, offset: const Offset(0, 6))]),
              child: Center(child: _sending
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : T('⚔  Send Challenge',
                    style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 16, color: AppC.text))))),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _selectedPill(Map<String, dynamic> u) {
    final tag = u['gamer_tag'] as String? ?? '';
    final n   = u['display_name'] as String? ?? '';
    return GestureDetector(onTap: () => _toggleSelected(u),
      child: Container(padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kNeonPurple.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kNeonPurple.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('@${tag.isNotEmpty ? tag : n}',
            style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 12, color: AppC.text)),
          const SizedBox(width: 6),
          const Icon(Icons.close, size: 14, color: Colors.white70),
        ])));
  }

  Widget _stepLabel(String num, String text) => Row(children: [
    Container(width: 22, height: 22,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kNeonBlue, _kNeonPurple]),
        shape: BoxShape.circle),
      child: Center(child: Text(num,
        style: TextStyle(color: AppC.text, fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 12)))),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(fontFamily: 'Alfa',
        fontSize: 16, color: AppC.text)),
  ]);
}