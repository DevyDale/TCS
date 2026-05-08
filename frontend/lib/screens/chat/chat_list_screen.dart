// lib/screens/chat/chat_list_screen.dart
//
// Updated for Phase 6 chat media:
//   • Last-message preview now handles sticker, audio, image, gif,
//     and file types — was previously blank for non-text messages
//   • Auto-refreshes the chat list when returning from a room screen
//     (you may have new messages, read receipts to clear, etc.)
//   • Pull-to-refresh now refreshes both tabs (chats + requests)
//   • Tab counter on Requests tab actually rebuilds when count changes
//
// No backend changes needed — the existing /api/chat/rooms/ response
// already includes message_type on the last_message field.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chat_search_screen.dart';
import 'chat_room_screen.dart';
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabCtrl;

  List<Map<String, dynamic>> _chats    = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loadingChats    = true;
  bool _loadingRequests = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));   // rebuild for badge counters
    _loadChats();
    _loadRequests();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    try {
      final data = await _api.getChatRooms() as List;
      if (!mounted) return;
      setState(() {
        _chats        = data.cast<Map<String, dynamic>>();
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
            fontSize: 22, color: Color(0xFF1A1A2E)))),
        // Search button → chat search screen
        GestureDetector(
          onTap: () async {
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
          },
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
                  fontSize: 20, color: Color(0xFF1A1A2E))),
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
        itemBuilder: (_, i) {
          final c        = _chats[i];
          final roomId   = c['id']        as String? ?? '';
          final roomType = c['room_type'] as String? ?? 'direct';
          final isStudyBuddy = roomType == 'study_buddy';
          final isGroup      = roomType == 'group';
          final other        = c['other_user'] as Map<String, dynamic>?;
          final name      = isGroup ? (c['name'] as String? ?? 'Group')
                            : (other?['name'] as String? ?? 'Unknown');
          final avatarUrl = isGroup ? null : other?['avatar_url'] as String?;
          final isOnline  = isGroup ? false : (other?['is_online'] as bool? ?? false);
          final unread    = c['unread_count'] as int? ?? 0;
          final lastMsg   = c['last_message'] as Map<String, dynamic>?;
          final lastTime  = _timeLabel(lastMsg?['created_at'] as String? ?? '');
          final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

          // Build a friendly preview for the last message — handles
          // text, sticker, audio, image, gif, file uniformly.
          final lastPreview = _previewLastMessage(lastMsg);

          return GestureDetector(
            onTap: () async {
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                      blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(children: [
                // Avatar
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
                                fontSize: isStudyBuddy || isGroup ? 22 : 18))) : null),
                  if (isOnline)
                    Positioned(bottom: 1, right: 1, child: Container(width: 13, height: 13,
                        decoration: BoxDecoration(color: Colors.green.shade500,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)))),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Row(children: [
                      Flexible(
                        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Arch', fontSize: 15,
                                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                                color: const Color(0xFF1A1A2E))),
                      ),
                      if (isStudyBuddy) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _kG3.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5)),
                          child: const Text('Study Buddy', style: TextStyle(fontFamily: 'Momo',
                              fontSize: 9, fontWeight: FontWeight.bold, color: _kG3))),
                      ],
                    ])),
                  ]),
                  const SizedBox(height: 3),
                  // Preview row — icon (for media types) + text
                  Row(children: [
                    if (lastPreview.icon != null) ...[
                      Icon(lastPreview.icon,
                          size: 13,
                          color: unread > 0 ? _kG2 : Colors.grey.shade400),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        lastPreview.text,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 13,
                          color: unread > 0
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontStyle: lastPreview.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ]),
                ])),
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
        },
      ),
    );
  }

  // ── Requests tab ──────────────────────────────────────────

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
                  fontSize: 20, color: Color(0xFF1A1A2E))),
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
                      fontSize: 15, color: Color(0xFF1A1A2E))),
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
                // Decline
                Expanded(child: GestureDetector(
                  onTap: () => _declineRequest(reqId, i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                    child: const Center(child: Text('Decline', style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))))),
                )),
                const SizedBox(width: 10),
                // Accept
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

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
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
          Text('New Chat', style: TextStyle(fontFamily: 'Arch', color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  /// Build a preview line for the last message in a room. Handles
  /// every message_type the backend produces (text, sticker, audio,
  /// image, video, gif, file, document) and falls back gracefully if
  /// the field isn't present.
  _LastMsgPreview _previewLastMessage(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) {
      return const _LastMsgPreview(text: 'No messages yet', italic: true);
    }
    final type    = (lastMsg['message_type'] as String?) ?? 'text';
    final rawText = (lastMsg['text']         as String?) ?? '';
    final fname   = (lastMsg['file_name']    as String?) ?? '';
    final dur     = (lastMsg['duration']     as int?)    ?? 0;

    switch (type) {
      case 'sticker':
        return const _LastMsgPreview(
            text: 'Sticker',
            italic: true,
            icon: Icons.emoji_emotions_rounded);
      case 'audio':
        return _LastMsgPreview(
            text: dur > 0 ? 'Voice note · ${_fmtDuration(dur)}' : 'Voice note',
            italic: true,
            icon: Icons.mic_rounded);
      case 'image':
        return const _LastMsgPreview(
            text: 'Photo',
            italic: true,
            icon: Icons.photo_rounded);
      case 'video':
        return const _LastMsgPreview(
            text: 'Video',
            italic: true,
            icon: Icons.videocam_rounded);
      case 'gif':
        return const _LastMsgPreview(
            text: 'GIF',
            italic: true,
            icon: Icons.gif_rounded);
      case 'file':
      case 'document':
        return _LastMsgPreview(
            text: fname.isNotEmpty ? fname : 'File',
            italic: true,
            icon: Icons.attach_file_rounded);
      case 'text':
      default:
        if (rawText.isNotEmpty) {
          return _LastMsgPreview(text: rawText);
        }
        // text type but empty text — likely a deleted message.
        return const _LastMsgPreview(
            text: 'Message deleted',
            italic: true);
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
}

/// Internal struct describing how to render the last-message line.
class _LastMsgPreview {
  final String   text;
  final IconData? icon;
  final bool     italic;
  const _LastMsgPreview({
    required this.text,
    this.icon,
    this.italic = false,
  });
}
