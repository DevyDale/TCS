// lib/screens/staff/staff_chats_screen.dart
//
// Staff-shaped conversations list. Reuses the same chat data (/chat/rooms/)
// and opens the existing ChatRoomScreen, but the list surface is its own
// staff landing (StaffHeader + clean rows) rather than the student chat UI.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/chat/chat_room_screen.dart';
import 'package:tcs_app/screens/chat/create_chat_bubble_Screen.dart';

class StaffChatsScreen extends StatefulWidget {
  const StaffChatsScreen({super.key});

  @override
  State<StaffChatsScreen> createState() => _StaffChatsScreenState();
}

class _StaffChatsScreenState extends State<StaffChatsScreen> {
  final _api = ApiService();
  final _search = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _roomName(Map<String, dynamic> c) {
    final isGroup = (c['room_type'] ?? 'direct').toString() != 'direct';
    final other = c['other_user'] as Map?;
    return isGroup
        ? (c['name'] ?? 'Group').toString()
        : (other?['display_name'] ?? other?['name'] ?? 'Chat').toString();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rooms;
    return _rooms.where((c) {
      final last = (c['last_message'] as Map?);
      final hay = '${_roomName(c)} ${last?['content'] ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getChatRooms();
      final list = (res is Map ? (res['results'] as List?) : (res as List?)) ?? [];
      if (!mounted) return;
      setState(() {
        _rooms = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeLabel(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  Future<void> _open(Map<String, dynamic> c) async {
    final roomId = (c['id'] ?? '').toString();
    final roomType = (c['room_type'] ?? 'direct').toString();
    final isGroup = roomType != 'direct';
    final other = c['other_user'] as Map?;
    final name = isGroup
        ? (c['name'] ?? 'Group').toString()
        : (other?['display_name'] ?? other?['name'] ?? 'Chat').toString();
    setState(() => c['unread_count'] = 0);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatRoomScreen(
          roomId: roomId, roomName: name, userName: 'You',
          roomType: roomType),
    ));
    if (roomId.isNotEmpty) {
      try { await _api.markRoomRead(roomId); } catch (_) {/* non-fatal */}
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CreateChatBubbleScreen()));
          _load();
        },
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            const SizedBox(height: 14),
            if (!_loading) ...[
              StaffSearchBar(
                  controller: _search,
                  hint: 'Search conversations…',
                  onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Padding(padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF2563EB))))
            else if (_rooms.isEmpty)
              _empty()
            else if (_filtered.isEmpty)
              staffNoResults('No conversations match.')
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(children: [
                  for (final c in _filtered) ...[
                    _roomRow(c),
                    const SizedBox(height: 10),
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 22,
      horizontal: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20)),
          ),
          const Spacer(),
          const Icon(Icons.chat_bubble_rounded, color: Colors.white70, size: 20),
        ]),
        const SizedBox(height: 14),
        const Text('Messages',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 6),
        Text('Your colleague & group conversations',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.85))),
      ]),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 12),
          Text('No conversations yet',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
          const SizedBox(height: 6),
          Text('Tap the pencil to start one.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
        ])),
      );

  Widget _roomRow(Map<String, dynamic> c) {
    final roomType = (c['room_type'] ?? 'direct').toString();
    final isGroup = roomType != 'direct';
    final other = c['other_user'] as Map?;
    final name = isGroup
        ? (c['name'] ?? 'Group').toString()
        : (other?['display_name'] ?? other?['name'] ?? 'Chat').toString();
    final avatar = isGroup ? '' : (other?['avatar_url'] ?? '').toString();
    final online = !isGroup && (other?['is_online'] == true);
    final unread = (c['unread_count'] as int?) ?? 0;
    final lastMsg = c['last_message'] as Map?;
    final preview = (lastMsg?['content'] ?? lastMsg?['text'] ?? '').toString();
    final time = _timeLabel((lastMsg?['created_at'] ?? '').toString());
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _open(c),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: staffCard(),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                image: avatar.isNotEmpty
                    ? DecorationImage(image: NetworkImage(avatar),
                        fit: BoxFit.cover)
                    : null),
              alignment: Alignment.center,
              child: avatar.isNotEmpty ? null : Text(isGroup ? '👥' : initial,
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 18,
                      fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
            if (online)
              Positioned(right: 0, bottom: 0, child: Container(
                width: 13, height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E), shape: BoxShape.circle,
                  border: Border.all(color: AppC.card, width: 2)))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                        fontWeight: FontWeight.bold, color: AppC.text))),
                if (time.isNotEmpty)
                  Text(time, style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                      color: unread > 0 ? const Color(0xFF2563EB) : AppC.faint)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text(
                    preview.isEmpty ? 'No messages yet' : preview,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        color: unread > 0 ? AppC.text : AppC.sub))),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(9)),
                    child: Text(unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Momo', fontSize: 10,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}
