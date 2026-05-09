// lib/screens/chat/chat_list_screen.dart
//
// Phase 8: WhatsApp-grade chat list.
//
// What's new:
//   • Realtime typing / recording indicators per chat tile
//     (replace the last-message preview while active, accent-coloured)
//   • "Active now" / "Last seen Xm ago" subtitle line under the preview
//   • New messages auto-bump the chat to the top of the list,
//     unread count increments live
//   • WhatsApp-style FAB → bottom sheet with two options:
//     "Start new chat" (existing flow) and "Create chat bubble"
//   • Connects to ChatListWebSocketService for live updates across
//     all of the user's rooms in a single socket
//
// All previous functionality (request tab, last-msg preview for media
// types, pull-to-refresh) is preserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/chat/chat_list_ws_Service.dart';

import '../chat_search_screen.dart';
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

  List<Map<String, dynamic>> _chats    = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loadingChats    = true;
  bool _loadingRequests = true;

  /// Per-room ephemeral state (kept in memory, fed by WebSocket events)
  final Map<String, Set<String>> _typingByRoom    = {};   // roomId → user_ids typing
  final Map<String, Map<String, String>> _typingNames = {}; // roomId → {userId: name}
  final Map<String, Set<String>> _recordingByRoom = {};

  /// Current user's ID — fetched once so we can suppress events from ourselves
  String? _meUserId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadChats();
    _loadRequests();
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

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final data = await _api.get('/chat/requests/') as List;
      if (!mounted) return;
      setState(() {
        _requests        = data.cast<Map<String, dynamic>>();
        _loadingRequests = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadChats(), _loadRequests()]);
  }

  /// WhatsApp-style sort: most recent activity first.
  /// Falls back to created_at if no last_message_at.
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
      // Brand-new room: just refresh the list to pick it up
      _loadChats();
      return;
    }

    final chat = Map<String, dynamic>.from(_chats[idx]);
    chat['last_message'] = msg;

    if (!isMe) {
      chat['unread_count'] = (chat['unread_count'] as int? ?? 0) + 1;
    }

    // Clear any typing/recording state from this user once their msg lands
    _typingByRoom[roomId]?.remove(senderId);
    _typingNames[roomId]?.remove(senderId);
    _recordingByRoom[roomId]?.remove(senderId);

    setState(() {
      _chats.removeAt(idx);
      _chats.insert(0, chat);     // bump to top
    });
  }

  void _handleTyping(String roomId, String userId, String userName, bool isTyping) {
    if (userId == _meUserId) return;     // never show our own typing
    final set   = _typingByRoom.putIfAbsent(roomId, () => <String>{});
    final names = _typingNames.putIfAbsent(roomId, () => <String, String>{});
    if (isTyping) {
      set.add(userId);
      if (userName.isNotEmpty) names[userId] = userName;
    } else {
      set.remove(userId);
      names.remove(userId);
    }
    // Typing supersedes recording from the same user
    _recordingByRoom[roomId]?.remove(userId);
    if (mounted) setState(() {});
  }

  void _handleRecording(String roomId, String userId, bool isRecording) {
    if (userId == _meUserId) return;
    final set = _recordingByRoom.putIfAbsent(roomId, () => <String>{});
    if (isRecording) {
      set.add(userId);
    } else {
      set.remove(userId);
    }
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
    setState(() {
      _chats[idx]['ai_enabled'] = aiEnabled;
    });
  }

  // ── Request tab actions ──────────────────────────────────

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
      floatingActionButton: _buildFAB(),
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
        GestureDetector(
          onTap: _openSearch,
          child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.search_rounded, color: Colors.grey.shade600, size: 20)),
        ),
        const SizedBox(width: 8),
        Stack(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.notifications_rounded, color: Colors.grey.shade600, size: 20)),
          if (_requests.isNotEmpty)
            Positioned(right: 8, top: 8,
              child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: _kG4, shape: BoxShape.circle))),
        ]),
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
          Tab(text: _requests.isEmpty ? 'Requests' : 'Requests (${_requests.length})'),
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

    // ── Preview state: typing > recording > last message ──
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

    // ── Presence subtitle ──
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
        // Clear unread on entry; the room's own logic will mark-read on the server
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
          // ── Avatar ──
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

          // ── Body (3 rows: name / preview / presence) ──
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: name + tags
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

              // Row 2: preview (typing / recording / last message)
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

              // Row 3 (optional): presence subtitle
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

          // ── Right column: time + unread badge ──
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

  // ── Requests tab (unchanged) ──────────────────────────────

  Widget _buildRequestsTab() {
    if (_loadingRequests) return const Center(child: CircularProgressIndicator(color: _kG2));
    if (_requests.isEmpty) {
      return RefreshIndicator(
        color: _kG2, onRefresh: _loadRequests,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.mail_outline_rounded, size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No Message Requests', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 20, color: _kInk)),
              const SizedBox(height: 8),
              Text('Chat requests will appear here', style: TextStyle(
                  fontFamily: 'Momo', color: Colors.grey.shade500)),
            ]),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kG2, onRefresh: _loadRequests,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final r         = _requests[i];
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
        },
      ),
    );
  }

  // ── FAB → bottom sheet with two options ──────────────────

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showNewChatMenu();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kG1, _kG2, _kG3, _kG4],
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

  void _showNewChatMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(height: 18),
              _newMenuTile(
                icon: Icons.chat_bubble_rounded,
                gradient: const [_kG1, _kG2],
                title: 'Start new chat',
                subtitle: 'Find someone and start a 1-on-1 conversation',
                onTap: () { Navigator.pop(context); _openSearch(); },
              ),
              _newMenuTile(
                icon: Icons.group_add_rounded,
                gradient: const [_kG3, _kG4],
                title: 'Create chat bubble',
                subtitle: 'Group chat with custom members + AI support',
                onTap: () { Navigator.pop(context); _openCreateBubble(); },
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newMenuTile({
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: Colors.grey.shade500)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
        ]),
      ),
    );
  }

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
    // Phase 3B will replace this with the real wizard.
    _snack('Create-bubble wizard ships in the next phase.');
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Build a preview line for the last message in a room. Handles
  /// every message_type the backend produces and falls back gracefully.
  _PreviewLine _previewLastMessage(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) {
      return const _PreviewLine(text: 'No messages yet', italic: true);
    }
    final type    = (lastMsg['message_type'] as String?) ?? 'text';
    final rawText = (lastMsg['text']         as String?) ?? '';
    final fname   = (lastMsg['file_name']    as String?) ?? '';
    final dur     = (lastMsg['duration']     as int?)    ?? 0;
    final isAi    = lastMsg['is_ai'] == true;

    // Dale's messages get a special preview prefix
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

  /// Returns a human-readable "ago" string, or null for very old timestamps.
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
      return null;        // too long ago — don't surface
    } catch (_) { return null; }
  }
}

// ── Internal helper ──

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