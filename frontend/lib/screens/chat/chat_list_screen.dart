// lib/screens/chat/chat_list_screen.dart
//
// Phase 3B: WhatsApp-grade chat list + Chat Bubbles.
//
// What's new on top of Phase 8:
//   • Bubble create button moves to the app bar (where the notification
//     icon used to live). Tap → CreateChatBubbleScreen wizard.
//   • Bottom-right FAB is now a single "New" pill (1-on-1 chats).
//   • Requests tab now shows BOTH pending bubble invites AND legacy DM
//     chat-requests, with accept/decline. Tab badge counts both.
//
// Realtime indicators (typing / recording / new_message / presence /
// ai_enabled) and last-message preview rendering are unchanged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/chat/chat_list_ws_Service.dart';
import 'package:tcs_app/screens/chat/create_chat_bubble_Screen.dart';

import 'chat_search_screen.dart';
import 'chat_room_screen.dart';
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);
const _kTyping     = Color(0xFF10B981);   // green
const _kRecording  = Color(0xFFF59E0B);   // amber

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _api    = ApiService();
  final _listWs = ChatListWebSocketService();
  late final TabController _tabCtrl;
  StreamSubscription? _wsSub;

  List<Map<String, dynamic>> _chats          = [];
  List<Map<String, dynamic>> _requests       = [];   // 1-on-1 chat requests
  List<Map<String, dynamic>> _bubbleInvites  = [];   // pending bubble invites
  bool _loadingChats    = true;
  bool _loadingRequests = true;

  /// Per-room ephemeral state (kept in memory, fed by WebSocket events)
  final Map<String, Set<String>> _typingByRoom    = {};
  final Map<String, Map<String, String>> _typingNames = {};
  final Map<String, Set<String>> _recordingByRoom = {};

  String? _meUserId;

  int get _totalRequests => _requests.length + _bubbleInvites.length;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadChats();
    _loadRequestsAndInvites();
    _bootstrapMe();
    _connectWs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _wsSub?.cancel();
    _listWs.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _bootstrapMe() async {
    try {
      final me = await _api.get('/auth/me/');
      if (me is Map) _meUserId = me['user_id'] as String?;
    } catch (_) { /* not fatal */ }
  }

  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    try {
      final data = await _api.getChatRooms() as List;
      if (!mounted) return;
      final list = data.cast<Map<String, dynamic>>();
      _sortChats(list);
      setState(() {
        _chats        = list;
        _loadingChats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingChats = false);
    }
  }

  Future<void> _loadRequestsAndInvites() async {
    setState(() => _loadingRequests = true);
    final results = await Future.wait([
      _api.get('/chat/requests/').catchError((_) => <dynamic>[]),
      _api.getMyBubbleInvites().catchError((_) => <dynamic>[]),
    ]);
    if (!mounted) return;
    final dmReqs   = results[0] is List ? (results[0] as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    final invites  = results[1] is List ? (results[1] as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
    setState(() {
      _requests        = dmReqs;
      _bubbleInvites   = invites;
      _loadingRequests = false;
    });
  }

  /// WhatsApp-style sort: most recent activity first.
  void _sortChats(List<Map<String, dynamic>> list) {
    int ts(Map<String, dynamic> c) {
      final last = c['last_message'] as Map<String, dynamic>?;
      final iso  = (last?['created_at'] as String?)
                ?? (c['updated_at'] as String?)
                ?? (c['created_at'] as String?)
                ?? '';
      try { return DateTime.parse(iso).millisecondsSinceEpoch; }
      catch (_) { return 0; }
    }
    list.sort((a, b) => ts(b).compareTo(ts(a)));
  }

  // ── WebSocket ────────────────────────────────────────────

  Future<void> _connectWs() async {
    await _listWs.connect();
    _wsSub = _listWs.stream.listen(_onWsEvent);
  }

  void _onWsEvent(Map<String, dynamic> event) {
    final type = event['event'] as String? ?? '';
    final roomId = event['room_id'] as String? ?? '';

    switch (type) {
      case 'new_message':
        final msg = (event['message'] as Map?)?.cast<String, dynamic>();
        if (msg != null && roomId.isNotEmpty) _handleNewMessage(roomId, msg);
        break;
      case 'typing':
        final uid  = event['user_id']   as String? ?? '';
        final name = event['user_name'] as String? ?? '';
        final on   = event['is_typing'] as bool?   ?? false;
        if (roomId.isNotEmpty && uid.isNotEmpty) _handleTyping(roomId, uid, name, on);
        break;
      case 'recording':
        final uid = event['user_id']      as String? ?? '';
        final on  = event['is_recording'] as bool?   ?? false;
        if (roomId.isNotEmpty && uid.isNotEmpty) _handleRecording(roomId, uid, on);
        break;
      case 'presence':
        final uid  = event['user_id']        as String? ?? '';
        final on   = event['is_online']      as bool?   ?? false;
        final last = event['last_active_at'] as String? ?? '';
        if (uid.isNotEmpty) _handlePresence(uid, on, last);
        break;
      case 'ai_enabled':
        final on = event['ai_enabled'] as bool? ?? false;
        if (roomId.isNotEmpty) _handleAi(roomId, on);
        break;
    }
  }

  void _handleNewMessage(String roomId, Map<String, dynamic> msg) {
    final senderId = msg['sender_id'] as String? ?? '';
    final isMe = _meUserId != null && senderId == _meUserId;

    final idx = _chats.indexWhere((c) => c['id'] == roomId);
    if (idx == -1) {
      _loadChats();   // brand-new room → refresh
      return;
    }

    final chat = Map<String, dynamic>.from(_chats[idx]);
    chat['last_message'] = msg;

    if (!isMe) {
      chat['unread_count'] = (chat['unread_count'] as int? ?? 0) + 1;
    }

    _typingByRoom[roomId]?.remove(senderId);
    _typingNames[roomId]?.remove(senderId);
    _recordingByRoom[roomId]?.remove(senderId);

    setState(() {
      _chats.removeAt(idx);
      _chats.insert(0, chat);
    });
  }

  void _handleTyping(String roomId, String userId, String userName, bool isTyping) {
    if (userId == _meUserId) return;
    final set   = _typingByRoom.putIfAbsent(roomId, () => <String>{});
    final names = _typingNames.putIfAbsent(roomId, () => <String, String>{});
    if (isTyping) {
      set.add(userId);
      if (userName.isNotEmpty) names[userId] = userName;
    } else {
      set.remove(userId);
      names.remove(userId);
    }
    _recordingByRoom[roomId]?.remove(userId);
    if (mounted) setState(() {});
  }

  void _handleRecording(String roomId, String userId, bool isRecording) {
    if (userId == _meUserId) return;
    final set = _recordingByRoom.putIfAbsent(roomId, () => <String>{});
    if (isRecording) { set.add(userId); } else { set.remove(userId); }
    if (mounted) setState(() {});
  }

  void _handlePresence(String userId, bool isOnline, String lastActiveAt) {
    var changed = false;
    for (final c in _chats) {
      final other = c['other_user'] as Map<String, dynamic>?;
      if (other == null) continue;
      if (other['user_id'] != userId) continue;
      other['is_online']      = isOnline;
      other['last_active_at'] = lastActiveAt;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  void _handleAi(String roomId, bool aiEnabled) {
    final idx = _chats.indexWhere((c) => c['id'] == roomId);
    if (idx == -1) return;
    setState(() => _chats[idx]['ai_enabled'] = aiEnabled);
  }

  // ── Requests / Invites tab actions ───────────────────────

  Future<void> _acceptRequest(String reqId, int index) async {
    try {
      final res = await _api.post('/chat/requests/$reqId/accept/') as Map<String, dynamic>;
      setState(() => _requests.removeAt(index));
      final room = res['room'] as Map<String, dynamic>?;
      if (room != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId:   room['id']   as String? ?? '',
            roomName: room['name'] as String? ?? 'Chat',
            userName: 'You',
          ),
        ));
        _loadChats();
      }
    } catch (e) { _snack('Failed: $e'); }
  }

  Future<void> _declineRequest(String reqId, int index) async {
    try {
      await _api.post('/chat/requests/$reqId/decline/');
      setState(() => _requests.removeAt(index));
    } catch (e) { _snack('Failed: $e'); }
  }

  Future<void> _acceptBubbleInvite(String inviteId, int index) async {
    try {
      final res = await _api.acceptBubbleInvite(inviteId) as Map<String, dynamic>;
      setState(() => _bubbleInvites.removeAt(index));
      final room = res['room'] as Map<String, dynamic>?;
      if (room != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId:   room['id']   as String? ?? '',
            roomName: room['name'] as String? ?? 'Bubble',
            userName: 'You',
            roomType: 'group',
          ),
        ));
        _loadChats();
      } else if (mounted) {
        _loadChats();
      }
    } catch (e) { _snack('Couldn\'t accept: $e'); }
  }

  Future<void> _declineBubbleInvite(String inviteId, int index) async {
    try {
      await _api.declineBubbleInvite(inviteId);
      setState(() => _bubbleInvites.removeAt(index));
    } catch (e) { _snack('Couldn\'t decline: $e'); }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating, backgroundColor: _kG2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          _buildTabBar(),
          Expanded(child: TabBarView(controller: _tabCtrl, children: [
            _buildChatsTab(),
            _buildRequestsTab(),
          ])),
        ]),
      ),
      floatingActionButton: _buildNewFab(),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1))),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kG1, _kG2],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        const Expanded(child: Text('Messages', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 22, color: _kInk))),
        // Search button
        GestureDetector(
          onTap: _openSearch,
          child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.search_rounded, color: Colors.grey.shade600, size: 20)),
        ),
        const SizedBox(width: 8),
        // Bubble create button (took the notification icon's spot)
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); _openCreateBubble(); },
          child: Container(width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG3, _kG4],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _kG4.withOpacity(0.35),
                    blurRadius: 10, offset: const Offset(0, 4))]),
              child: const Icon(Icons.bubble_chart_rounded,
                  color: Colors.white, size: 20)),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _kG2, unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _kG2, indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Arch', fontSize: 13),
        tabs: [
          const Tab(text: 'All Chats'),
          Tab(text: _totalRequests == 0 ? 'Requests' : 'Requests ($_totalRequests)'),
        ],
      ),
    );
  }

  // ── Chats tab ─────────────────────────────────────────────

  Widget _buildChatsTab() {
    if (_loadingChats) return const Center(child: CircularProgressIndicator(color: _kG2));
    if (_chats.isEmpty) {
      return RefreshIndicator(
        color: _kG2, onRefresh: _loadChats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No Messages Yet', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 20, color: _kInk)),
              const SizedBox(height: 8),
              Text('Start a conversation!',
                  style: TextStyle(fontFamily: 'Momo', color: Colors.grey.shade500)),
            ]),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kG2, onRefresh: _loadChats,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _chats.length,
        itemBuilder: (_, i) => _buildChatTile(_chats[i]),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> c) {
    final roomId       = c['id']        as String? ?? '';
    final roomType     = c['room_type'] as String? ?? 'direct';
    final isStudyBuddy = roomType == 'study_buddy';
    final isGroup      = roomType == 'group';
    final isAiEnabled  = c['ai_enabled'] as bool? ?? false;
    final other        = c['other_user'] as Map<String, dynamic>?;

    final name      = isGroup
        ? (c['name'] as String? ?? 'Group')
        : (other?['name'] as String? ?? 'Unknown');
    final avatarUrl = isGroup ? null : other?['avatar_url'] as String?;
    final isOnline  = isGroup ? false : (other?['is_online'] as bool? ?? false);
    final lastActiveIso = (other?['last_active_at'] as String?) ?? '';
    final unread    = c['unread_count'] as int? ?? 0;
    final lastMsg   = c['last_message'] as Map<String, dynamic>?;
    final lastTime  = _timeLabel(lastMsg?['created_at'] as String? ?? '');
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final typingSet    = _typingByRoom[roomId];
    final recordingSet = _recordingByRoom[roomId];
    final isTyping     = typingSet != null && typingSet.isNotEmpty;
    final isRecording  = !isTyping && recordingSet != null && recordingSet.isNotEmpty;

    final _PreviewLine preview;
    if (isTyping) {
      String label = 'typing…';
      if (isGroup && typingSet!.length > 1) {
        label = '${typingSet.length} people typing…';
      } else if (isGroup) {
        final names = _typingNames[roomId];
        final first = names?.values.firstOrNull ?? 'Someone';
        label = '$first is typing…';
      }
      preview = _PreviewLine(
        text: label, color: _kTyping,
        icon: Icons.more_horiz_rounded, italic: false, bold: true,
      );
    } else if (isRecording) {
      preview = const _PreviewLine(
        text: 'recording audio…', color: _kRecording,
        icon: Icons.mic_rounded, italic: false, bold: true,
      );
    } else {
      preview = _previewLastMessage(lastMsg);
    }

    String? presenceLabel;
    if (!isGroup) {
      if (isOnline) {
        presenceLabel = 'Active now';
      } else if (lastActiveIso.isNotEmpty) {
        final ago = _timeAgo(lastActiveIso);
        if (ago != null) presenceLabel = 'Last seen $ago';
      }
    }

    return GestureDetector(
      onTap: () async {
        setState(() => c['unread_count'] = 0);
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
              roomId: roomId, roomName: name, userName: 'You',
              roomType: roomType),
        ));
        _loadChats();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGroup ? BorderRadius.circular(14) : null,
                image: avatarUrl != null && avatarUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Center(child: Text(
                      isStudyBuddy ? '📚' : (isGroup ? '👥' : initial),
                      style: TextStyle(color: Colors.white, fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: isStudyBuddy || isGroup ? 22 : 18)))
                  : null),
            if (isOnline)
              Positioned(bottom: 1, right: 1,
                child: Container(width: 13, height: 13,
                  decoration: BoxDecoration(color: Colors.green.shade500,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)))),
          ]),
          const SizedBox(width: 12),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Arch', fontSize: 15,
                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                          color: _kInk)),
                ),
                if (isStudyBuddy) ...[
                  const SizedBox(width: 6),
                  _miniTag('Study Buddy', _kG3),
                ],
                if (isAiEnabled) ...[
                  const SizedBox(width: 6),
                  _miniTag('Dale', _kG2, withIcon: true),
                ],
              ]),
              const SizedBox(height: 3),

              Row(children: [
                if (preview.icon != null) ...[
                  Icon(preview.icon,
                      size: 13,
                      color: preview.color
                          ?? (unread > 0 ? _kG2 : Colors.grey.shade400)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    preview.text,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 13,
                      color: preview.color
                          ?? (unread > 0
                              ? Colors.grey.shade700
                              : Colors.grey.shade500),
                      fontWeight: preview.bold || unread > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontStyle: preview.italic
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ]),

              if (presenceLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  presenceLabel,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 11,
                    color: isOnline
                        ? Colors.green.shade600
                        : Colors.grey.shade400,
                    fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          )),

          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(lastTime, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                color: unread > 0 ? _kG2 : Colors.grey.shade400,
                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(height: 6),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _kG2, borderRadius: BorderRadius.circular(10)),
                child: Text(unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold, fontFamily: 'Momo'))),
          ]),
        ]),
      ),
    );
  }

  Widget _miniTag(String label, Color tint, {bool withIcon = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (withIcon) ...[
          Icon(Icons.smart_toy_rounded, size: 10, color: tint),
          const SizedBox(width: 3),
        ],
        Text(label,
            style: TextStyle(
              fontFamily: 'Momo', fontSize: 9,
              fontWeight: FontWeight.bold, color: tint,
            )),
      ]),
    );
  }

  // ── Requests tab (DM requests + bubble invites) ──────────

  Widget _buildRequestsTab() {
    if (_loadingRequests) return const Center(child: CircularProgressIndicator(color: _kG2));
    if (_requests.isEmpty && _bubbleInvites.isEmpty) {
      return RefreshIndicator(
        color: _kG2, onRefresh: _loadRequestsAndInvites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.mail_outline_rounded, size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No Pending Requests', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 20, color: _kInk)),
              const SizedBox(height: 8),
              Text('Chat requests and bubble invites will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Momo', color: Colors.grey.shade500)),
            ]),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kG2, onRefresh: _loadRequestsAndInvites,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (_bubbleInvites.isNotEmpty) ...[
            _sectionHeader('Bubble invites', _bubbleInvites.length),
            const SizedBox(height: 8),
            for (var i = 0; i < _bubbleInvites.length; i++)
              _buildBubbleInviteCard(_bubbleInvites[i], i),
            const SizedBox(height: 8),
          ],
          if (_requests.isNotEmpty) ...[
            _sectionHeader('Chat requests', _requests.length),
            const SizedBox(height: 8),
            for (var i = 0; i < _requests.length; i++)
              _buildChatRequestCard(_requests[i], i),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
    child: Row(children: [
      Text(label.toUpperCase(),
          style: TextStyle(fontFamily: 'Arch', fontSize: 11,
              fontWeight: FontWeight.bold, color: Colors.grey.shade500,
              letterSpacing: 0.6)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        child: Text('$count', style: const TextStyle(fontFamily: 'Momo',
            fontSize: 10, fontWeight: FontWeight.bold, color: _kInk)),
      ),
    ]),
  );

  Widget _buildBubbleInviteCard(Map<String, dynamic> r, int index) {
    final reqId        = r['id']            as String? ?? '';
    final inviter      = r['inviter_name']  as String? ?? r['inviter']?['name']?.toString() ?? 'Someone';
    final bubbleName   = r['room_name']     as String? ?? r['room']?['name']?.toString()    ?? 'Bubble';
    final bubbleAbout  = r['room_about']    as String? ?? r['room']?['about']?.toString()   ?? '';
    final isPublic     = (r['room_is_public'] as bool?)
                       ?? (r['room']?['is_public'] as bool?) ?? false;
    final memberCount  = (r['room_member_count'] as int?)
                       ?? (r['room']?['member_count'] as int?) ?? 0;
    final message      = r['message']       as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kG4.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG3, _kG4]),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.bubble_chart_rounded,
                color: Colors.white, size: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(bubbleName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 15, color: _kInk)),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _miniTag(isPublic ? 'Public' : 'Private',
                  isPublic ? _kG1 : _kG2),
              if (memberCount > 0)
                Text('· $memberCount member${memberCount == 1 ? '' : 's'}',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                        color: Colors.grey.shade500)),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _kG4.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Bubble', style: TextStyle(fontFamily: 'Momo',
                fontSize: 10, fontWeight: FontWeight.bold, color: _kG4))),
        ]),
        const SizedBox(height: 10),
        Text('$inviter invited you to join.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                color: Colors.grey.shade700)),
        if (bubbleAbout.isNotEmpty || message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Text(message.isNotEmpty ? message : bubbleAbout,
                style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                    color: Colors.grey.shade700, height: 1.4))),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _declineBubbleInvite(reqId, index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)),
              child: const Center(child: Text('Decline', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: _kInk)))),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => _acceptBubbleInvite(reqId, index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG3, _kG4]),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Join', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
          )),
        ]),
      ]),
    );
  }

  Widget _buildChatRequestCard(Map<String, dynamic> r, int i) {
    final reqId     = r['id'] as String? ?? '';
    final name      = r['sender_name']   as String? ?? 'Unknown';
    final role      = r['sender_role']   as String? ?? '';
    final avatarUrl = r['sender_avatar'] as String? ?? '';
    final message   = r['message']       as String? ?? '';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kG3.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_kG3, _kG4]),
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null),
            child: avatarUrl.isEmpty ? Center(child: Text(initial, style: const TextStyle(
                color: Colors.white, fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 20))) : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 15, color: _kInk)),
            Text(role, style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: Colors.grey.shade500)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _kG3.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Chat Request', style: TextStyle(fontFamily: 'Momo',
                fontSize: 10, fontWeight: FontWeight.bold, color: _kG3))),
        ]),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Text(message, style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _declineRequest(reqId, i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
              child: const Center(child: Text('Decline', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: _kInk)))),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => _acceptRequest(reqId, i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Accept', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
          )),
        ]),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // FAB — single "New" pill for 1-on-1 chats
  // ══════════════════════════════════════════════════════════

  Widget _buildNewFab() {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); _openSearch(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kG1, _kG2],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _kG2.withOpacity(0.4), blurRadius: 16,
              offset: const Offset(0, 6))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('New', style: TextStyle(fontFamily: 'Arch', color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }

  // ── Navigation ───────────────────────────────────────────

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const ChatSearchScreen()));
    if (result != null && result['action'] == 'open_room') {
      final roomId   = result['room_id']   as String? ?? '';
      final userName = result['user_name'] as String? ?? 'Chat';
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
            roomId: roomId, roomName: userName, userName: 'You'),
      ));
      _loadChats();
    }
  }

  Future<void> _openCreateBubble() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const CreateChatBubbleScreen(),
    ));
    // Refresh in case the user created a bubble — they may already be inside
    // it (we used pushReplacement on success), but if they backed out we want
    // any new room/state reflected.
    _loadChats();
    _loadRequestsAndInvites();
  }

  // ── Helpers ───────────────────────────────────────────────

  _PreviewLine _previewLastMessage(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) {
      return const _PreviewLine(text: 'No messages yet', italic: true);
    }
    final type    = (lastMsg['message_type'] as String?) ?? 'text';
    final rawText = (lastMsg['text']         as String?) ?? '';
    final fname   = (lastMsg['file_name']    as String?) ?? '';
    final dur     = (lastMsg['duration']     as int?)    ?? 0;
    final isAi    = lastMsg['is_ai'] == true;

    if (isAi && type == 'text' && rawText.isNotEmpty) {
      return _PreviewLine(
        text: 'Dale: $rawText',
        icon: Icons.smart_toy_rounded,
      );
    }

    switch (type) {
      case 'sticker':
        return const _PreviewLine(
            text: 'Sticker', italic: true,
            icon: Icons.emoji_emotions_rounded);
      case 'audio':
        return _PreviewLine(
            text: dur > 0 ? 'Voice note · ${_fmtDuration(dur)}' : 'Voice note',
            italic: true, icon: Icons.mic_rounded);
      case 'image':
        return const _PreviewLine(
            text: 'Photo', italic: true, icon: Icons.photo_rounded);
      case 'video':
        return const _PreviewLine(
            text: 'Video', italic: true, icon: Icons.videocam_rounded);
      case 'gif':
        return const _PreviewLine(
            text: 'GIF', italic: true, icon: Icons.gif_rounded);
      case 'file':
      case 'document':
        return _PreviewLine(
            text: fname.isNotEmpty ? fname : 'File',
            italic: true, icon: Icons.attach_file_rounded);
      case 'text':
      default:
        if (rawText.isNotEmpty) return _PreviewLine(text: rawText);
        return const _PreviewLine(text: 'Message deleted', italic: true);
    }
  }

  String _fmtDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mm = seconds ~/ 60;
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _timeLabel(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24)   return '${diff.inHours}h';
      if (diff.inDays < 7)     return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }

  String? _timeAgo(String iso) {
    if (iso.isEmpty) return null;
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'just now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)    return '${diff.inHours}h ago';
      if (diff.inDays  < 2)     return 'yesterday';
      if (diff.inDays  < 7)     return '${diff.inDays}d ago';
      return null;
    } catch (_) { return null; }
  }
}

class _PreviewLine {
  final String   text;
  final IconData? icon;
  final Color?   color;
  final bool     italic;
  final bool     bold;
  const _PreviewLine({
    required this.text,
    this.icon,
    this.color,
    this.italic = false,
    this.bold   = false,
  });
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}