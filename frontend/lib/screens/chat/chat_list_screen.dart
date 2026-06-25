// lib/screens/chat/chat_list_screen.dart
//
// Phase 3B: WhatsApp-grade chat list + Chat Bubbles.
//
// CHANGE LOG (this revision):
//   • Renamed the first tab from "All" to "Inbox". The Inbox tab now shows
//     ONLY 1-on-1 direct chats (i.e. accepted chat requests). Study-buddy
//     chats and chat-bubble (group) chats are intentionally excluded — they
//     live in their own dedicated tabs.
//   • The filter key passed to _buildChatsList for the first tab is now
//     'inbox' (was 'all') and _filteredChats() keeps only room_type=='direct'
//     rooms for it.
//
// CHANGE LOG (previous revision):
//   • Replaced the stock Material `TabBar` with `SegmentedTabControl` from
//     the `animated_segmented_tab_control` package — a pill / segmented
//     control with an animated sliding indicator, matching the rest of
//     the app's gradient/rounded design system.
//   • The TabController is still owned by this screen, so ChatRoomScreen
//     navigation and tab-state listeners work exactly as before.
//   • The Requests-tab badge is preserved by injecting the count straight
//     into the SegmentTab `label` (e.g. "Requests (3)"), since the package
//     accepts plain text labels.
//
// Everything else (realtime indicators, presence, AI tag, last-message
// preview, FAB navigation) is untouched.

import 'dart:async';

import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/chat/chat_list_ws_Service.dart';
import 'package:tcs_app/screens/chat/chat_requests.dart';
import 'package:tcs_app/screens/chat/create_chat_bubble_Screen.dart';

import 'chat_room_screen.dart';
import '../../services/api_service.dart';
import '../../services/cache_store.dart';

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
  final _searchCtrl = TextEditingController();
  String _chatQuery = '';
  late final TabController _tabCtrl;
  StreamSubscription? _wsSub;

  List<Map<String, dynamic>> _chats          = [];
  List<Map<String, dynamic>> _requests       = [];   // 1-on-1 chat requests
  List<Map<String, dynamic>> _bubbleInvites  = [];   // pending bubble invites
  List<Map<String, dynamic>> _outgoingRequests = []; // 1-on-1 outgoing chat requests
  bool _loadingChats    = true;
  bool _loadingRequests = true;

  /// Per-room ephemeral state (kept in memory, fed by WebSocket events)
  final Map<String, Set<String>> _typingByRoom    = {};
  final Map<String, Map<String, String>> _typingNames = {};
  final Map<String, Set<String>> _recordingByRoom = {};

  String? _meUserId;

  int get _totalRequests => _requests.length + _outgoingRequests.length + _bubbleInvites.length;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // We still listen so the badge / any tab-aware UI re-renders on swipe.
    _tabCtrl.addListener(() => setState(() {}));
    _loadChats();
    _loadRequestsAndInvites();
    _bootstrapMe();
    _connectWs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  // SWR: paints instantly from the cached room list, then revalidates.
  // _loadingChats defaults true so the spinner shows only on first-ever load.
  // Returns a Future that completes on the fresh value so it can still be
  // used as a RefreshIndicator.onRefresh callback (pull-to-refresh awaits it).
  Future<void> _loadChats() {
    final c = Completer<void>();
    CacheStore.I.swr(
      'chat:rooms',
      fetch: () => _api.getChatRooms(),
      onData: (data, fresh) {
        if (!mounted) return;
        final list = (data as List).cast<Map<String, dynamic>>();
        _sortChats(list);
        setState(() {
          _chats        = list;
          _loadingChats = false;
        });
        if (fresh && !c.isCompleted) c.complete();
      },
      onError: (_) {
        if (mounted) setState(() => _loadingChats = false);
        if (!c.isCompleted) c.complete();
      },
    );
    return c.future;
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

    // Outgoing chat requests (pending, sent by me)
    try {
      final sent = await _api.get('/chat/requests/sent/');
      if (mounted && sent is List) {
        setState(() => _outgoingRequests =
            sent.cast<Map<String, dynamic>>().toList());
      }
    } catch (_) {/* ignore — endpoint is opportunistic */}
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
          _buildSearchField(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildChatsList('inbox'),
                _buildChatsList('study_buddy'),
                _buildChatsList('group'),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1))),
      child: Row(children: [
        const Expanded(child: Text('Messages', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 22, color: _kInk))),
        // Requests button (opens the Requests page) with pending badge
        GestureDetector(
          onTap: _openRequests,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.mark_email_unread_rounded,
                    color: Colors.grey.shade600, size: 20)),
            if (_totalRequests > 0)
              Positioned(top: -4, right: -4, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(color: _kG4,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: Center(child: Text(
                    _totalRequests > 99 ? '99+' : '$_totalRequests',
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold, fontFamily: 'Momo'))),
              )),
          ]),
        ),
        const SizedBox(width: 8),
        // Bubble create button
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

  // ── Animated Segmented Tab Control ──────────────────────────
  // Replaces the stock Material TabBar. Visually it's a "pill" track with
  // an animated, gradient-filled indicator that slides between segments.
  // The package wires itself to our existing TabController, so the rest of
  // the screen (TabBarView, swipe, badge updates) keeps working unchanged.
  Widget _buildTabBar() {
    return Container(
      // White surround so the segmented bar sits cleanly under the app bar.
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: SizedBox(
        // SegmentedTabControl wants a bounded height. 48 matches its default
        // touch target and looks balanced against the surrounding paddings.
        height: 48,
        child: SegmentedTabControl(
          // Bind to OUR TabController so swipes on TabBarView and taps on the
          // segmented control stay perfectly in sync.
          controller: _tabCtrl,

          // Slight inset so the indicator doesn't kiss the bar's edges.
          indicatorPadding: const EdgeInsets.all(4),

          // Bar (the unselected track behind the pill indicator).
          barDecoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),

          // Indicator (the moving pill). Uses our brand gradient so it
          // matches the AppBar logo + bubble button.
          indicatorDecoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kG1, _kG2],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: _kG2.withOpacity(0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),

          // Text styling: brand fonts on both states; just swap the color.
          tabTextColor: Colors.grey.shade600,
          selectedTabTextColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Arch',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          selectedTextStyle: const TextStyle(
            fontFamily: 'Arch',
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),

          // Subtle ripple that feels in-family with the rest of the UI.
          splashColor: _kG2.withOpacity(0.10),
          splashHighlightColor: _kG2.withOpacity(0.06),

          // Three segments — Inbox (direct chats), study buddies, bubbles.
          tabs: const [
            SegmentTab(label: 'Inbox'),
            SegmentTab(label: 'Study Buddies'),
            SegmentTab(label: 'Chat Bubbles'),
          ],
        ),
      ),
    );
  }

  // ── Search field ──────────────────────────────────────────
Widget _buildSearchField() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
    child: SizedBox(
      height: 46,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) =>
            setState(() => _chatQuery = v.trim().toLowerCase()),
        style: const TextStyle(
          fontFamily: 'Momo',
          fontSize: 14,
          color: _kInk,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,

          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade500,
            size: 20,
          ),

          suffixIcon: _chatQuery.isNotEmpty
              ? IconButton(
                  splashRadius: 18,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _chatQuery = '');
                  },
                )
              : null,

          hintText: 'Search your chats…',
          hintStyle: TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            color: Colors.grey.shade500,
          ),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: _kG2,
              width: 1.2,
            ),
          ),
        ),
      ),
    ),
  );
}  // ── Chats list (filtered by tab type + search query) ──────

  List<Map<String, dynamic>> _filteredChats(String filter) {
    Iterable<Map<String, dynamic>> list = _chats;
    if (filter == 'study_buddy') {
      list = list.where((c) => (c['room_type'] as String?) == 'study_buddy');
    } else if (filter == 'group') {
      list = list.where((c) => (c['room_type'] as String?) == 'group');
    } else if (filter == 'inbox') {
      // Inbox = 1-on-1 direct chats only (i.e. accepted chat requests).
      // Study-buddy and group/bubble chats have their own tabs and must
      // never appear here.
      list = list.where((c) => ((c['room_type'] as String?) ?? 'direct') == 'direct');
    }
    if (_chatQuery.isNotEmpty) {
      list = list.where((c) {
        final isGroup = (c['room_type'] as String?) == 'group';
        final name = (isGroup
                    ? (c['name'] as String?)
                    : ((c['other_user'] as Map<String, dynamic>?)?['name']
                        as String?))
                ?.toLowerCase() ??
            '';
        final last = ((c['last_message'] as Map<String, dynamic>?)?['text']
                    as String?)
                ?.toLowerCase() ??
            '';
        return name.contains(_chatQuery) || last.contains(_chatQuery);
      });
    }
    return list.toList();
  }

  Widget _buildChatsList(String filter) {
    if (_loadingChats) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    final items = _filteredChats(filter);
    if (items.isEmpty) {
      final searching = _chatQuery.isNotEmpty;
      final title = searching
          ? 'No matches'
          : filter == 'study_buddy'
              ? 'No study buddy chats'
              : filter == 'group'
                  ? 'No chat bubbles yet'
                  : 'No Messages Yet';
      final sub = searching
          ? 'Try a different name'
          : filter == 'group'
              ? 'Join or create a bubble to get started'
              : filter == 'study_buddy'
                  ? 'Pair up with a study buddy to chat'
                  : 'Accepted chat requests show up here';
      final icon = searching
          ? Icons.search_off_rounded
          : filter == 'group'
              ? Icons.bubble_chart_outlined
              : filter == 'study_buddy'
                  ? Icons.menu_book_rounded
                  : Icons.chat_bubble_outline_rounded;
      return RefreshIndicator(
        color: _kG2, onRefresh: _loadChats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 20, color: _kInk)),
              const SizedBox(height: 8),
              Text(sub, textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Momo', color: Colors.grey.shade500)),
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
        itemCount: items.length,
        itemBuilder: (_, i) => _buildChatTile(items[i]),
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
        // Persist the read on the backend (advances last_read_message) BEFORE
        // refreshing — otherwise _loadChats() refetches the stale unread count
        // and the badge reappears.
        if (roomId.isNotEmpty) {
          try { await _api.markRoomRead(roomId); } catch (_) {/* non-fatal */}
        }
        if (mounted) _loadChats();
      },
      onLongPress: () => _showChatTileMenu(c),
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


  // ══════════════════════════════════════════════════════════
  // Long-press menu (delete chat / block & delete)
  // ══════════════════════════════════════════════════════════

  Future<void> _showChatTileMenu(Map<String, dynamic> c) async {
    HapticFeedback.lightImpact();
    final isGroup = c['room_type'] == 'group';
    final other   = c['other_user'] as Map<String, dynamic>?;
    final name    = isGroup
        ? (c['name'] as String? ?? 'this chat')
        : (other?['name'] as String? ?? 'this chat');
    final canBlock = !isGroup &&
        other != null &&
        ((other['user_id']?.toString().isNotEmpty) ?? false);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Alfa', fontSize: 16, color: _kInk),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: _kG4),
              title: Text(
                isGroup ? 'Leave chat' : 'Delete chat',
                style: const TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14.5, color: _kInk),
              ),
              subtitle: Text(
                isGroup
                    ? "You'll stop receiving messages from this bubble."
                    : 'Removes this conversation from your chats.',
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11.5,
                  color: Colors.grey.shade600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteChat(c);
              },
            ),
            if (canBlock)
              ListTile(
                leading: const Icon(Icons.block_rounded, color: _kG4),
                title: const Text(
                  'Block & delete',
                  style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14.5, color: _kInk),
                ),
                subtitle: Text(
                  "$name won't be able to message you or send requests.",
                  style: TextStyle(
                    fontFamily: 'Momo', fontSize: 11.5,
                    color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlockAndDelete(c);
                },
              ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: Colors.grey.shade500),
              title: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14.5, color: Colors.grey.shade600),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlockAndDelete(Map<String, dynamic> c) async {
    final other = c['other_user'] as Map<String, dynamic>?;
    final name  = (other?['name'] as String?) ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Block & delete?',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk),
        ),
        content: Text(
          '$name will be blocked — they won\'t be able to message you or send '
          'you chat requests, and this conversation will be removed. You can '
          'unblock them anytime from Settings → Blocked users.',
          style: TextStyle(
            fontFamily: 'Momo', fontSize: 13,
            color: Colors.grey.shade700, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block',
              style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold, color: _kG4,
              )),
          ),
        ],
      ),
    );

    if (confirmed == true) await _blockAndDelete(c);
  }

  Future<void> _blockAndDelete(Map<String, dynamic> c) async {
    final other   = c['other_user'] as Map<String, dynamic>?;
    final otherId = (other?['user_id'] ?? '').toString();
    if (otherId.isEmpty) {
      _snack('Couldn\'t identify this person to block.');
      return;
    }

    final roomId  = c['id'] as String? ?? '';
    final idx     = _chats.indexWhere((x) => x['id'] == roomId);
    final removed = idx == -1 ? null : _chats[idx];
    if (idx != -1) setState(() => _chats.removeAt(idx));

    try {
      await _api.blockUser(otherId);
      if (roomId.isNotEmpty) {
        // Best-effort: also clear our copy of the chat. The block is the part
        // that matters, so a delete hiccup shouldn't undo it.
        try {
          await _api.delete('/chat/rooms/$roomId/');
        } catch (_) {}
      }
      _snack('Blocked & deleted');
    } catch (e) {
      if (idx != -1 && removed != null) {
        setState(() => _chats.insert(idx, removed));
      }
      _snack('Couldn\'t block: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // Long-press delete (chat tile menu)
  // ══════════════════════════════════════════════════════════

  Future<void> _confirmDeleteChat(Map<String, dynamic> c) async {
    final isGroup = c['room_type'] == 'group';
    final name = isGroup
        ? (c['name'] as String? ?? 'this chat')
        : ((c['other_user'] as Map?)?['name'] as String? ?? 'this chat');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete chat?',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk),
        ),
        content: Text(
          isGroup
              ? 'You\'ll leave "$name" and won\'t receive messages from this bubble anymore.'
              : 'Your conversation with $name will be removed from your chats. This can\'t be undone.',
          style: TextStyle(
            fontFamily: 'Momo', fontSize: 13,
            color: Colors.grey.shade700, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
              style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              )),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
              style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold, color: _kG4,
              )),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteChat(c);
  }

  Future<void> _deleteChat(Map<String, dynamic> c) async {
    final roomId = c['id'] as String? ?? '';
    if (roomId.isEmpty) return;

    final idx = _chats.indexWhere((x) => x['id'] == roomId);
    if (idx == -1) return;
    final removed = _chats[idx];
    setState(() => _chats.removeAt(idx));

    try {
      await _api.delete('/chat/rooms/$roomId/');
      _snack('Chat deleted');
    } catch (e) {
      setState(() => _chats.insert(idx, removed));
      _snack('Couldn\'t delete: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // Navigation
  // ══════════════════════════════════════════════════════════

  Future<void> _openRequests() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ChatRequestsScreen(),
    ));
    // Coming back: refresh the badge and chats (a request may have become
    // a room).
    _loadRequestsAndInvites();
    _loadChats();
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
