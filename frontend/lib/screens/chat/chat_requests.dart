// lib/screens/chat/chat_requests_screen.dart
//
// Requests page — opened from the Requests button in the chat list app bar.
//
// Mirrors the look of the old "Requests" tab from the chat list, but is now
// its own screen with two segmented tabs:
//   • Incoming  — chat requests + bubble invites that were sent TO me
//                 (each with Accept / Decline actions).
//   • Outgoing  — chat requests I have SENT that are still pending.
//
// The app bar carries a search button identical to the chat list's, which
// opens ChatSearchScreen and, on a result, jumps straight into that room.

import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_room_screen.dart';
import 'chat_search_screen.dart';
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);

class ChatRequestsScreen extends StatefulWidget {
  const ChatRequestsScreen({super.key});

  @override
  State<ChatRequestsScreen> createState() => _ChatRequestsScreenState();
}

class _ChatRequestsScreenState extends State<ChatRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabCtrl;

  List<Map<String, dynamic>> _requests         = []; // chat requests TO me
  List<Map<String, dynamic>> _bubbleInvites     = []; // bubble invites TO me
  List<Map<String, dynamic>> _outgoingRequests  = []; // requests I sent
  bool _loading = true;

  int get _incomingCount => _requests.length + _bubbleInvites.length;
  int get _outgoingCount => _outgoingRequests.length;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.get('/chat/requests/').catchError((_) => <dynamic>[]),
      _api.getMyBubbleInvites().catchError((_) => <dynamic>[]),
      _api.get('/chat/requests/sent/').catchError((_) => <dynamic>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _requests = results[0] is List
          ? (results[0] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      _bubbleInvites = results[1] is List
          ? (results[1] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      _outgoingRequests = results[2] is List
          ? (results[2] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      _loading = false;
    });
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _acceptRequest(String reqId, int index) async {
    try {
      final res =
          await _api.post('/chat/requests/$reqId/accept/') as Map<String, dynamic>;
      setState(() => _requests.removeAt(index));
      final room = res['room'] as Map<String, dynamic>?;
      if (room != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: room['id'] as String? ?? '',
            roomName: room['name'] as String? ?? 'Chat',
            userName: 'You',
          ),
        ));
        _load();
      }
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _declineRequest(String reqId, int index) async {
    try {
      await _api.post('/chat/requests/$reqId/decline/');
      setState(() => _requests.removeAt(index));
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _acceptBubbleInvite(String inviteId, int index) async {
    try {
      final res =
          await _api.acceptBubbleInvite(inviteId) as Map<String, dynamic>;
      setState(() => _bubbleInvites.removeAt(index));
      final room = res['room'] as Map<String, dynamic>?;
      if (room != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: room['id'] as String? ?? '',
            roomName: room['name'] as String? ?? 'Bubble',
            userName: 'You',
            roomType: 'group',
          ),
        ));
        _load();
      }
    } catch (e) {
      _snack('Couldn\'t accept: $e');
    }
  }

  Future<void> _declineBubbleInvite(String inviteId, int index) async {
    try {
      await _api.declineBubbleInvite(inviteId);
      setState(() => _bubbleInvites.removeAt(index));
    } catch (e) {
      _snack('Couldn\'t decline: $e');
    }
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const ChatSearchScreen()));
    if (result != null && result['action'] == 'open_room') {
      final roomId = result['room_id'] as String? ?? '';
      final userName = result['user_name'] as String? ?? 'Chat';
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
            roomId: roomId, roomName: userName, userName: 'You'),
      ));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kG2,
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
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildIncomingTab(),
                _buildOutgoingTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1)),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text('Requests',
              style:
                  TextStyle(fontFamily: 'Alfa', fontSize: 22, color: _kInk)),
        ),
        // Search button — same as the chat list's.
        GestureDetector(
          onTap: _openSearch,
          child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.search_rounded,
                  color: Colors.grey.shade600, size: 20)),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    final inLabel = _incomingCount == 0 ? 'Incoming' : 'Incoming ($_incomingCount)';
    final outLabel =
        _outgoingCount == 0 ? 'Outgoing' : 'Outgoing ($_outgoingCount)';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: SizedBox(
        height: 48,
        child: SegmentedTabControl(
          controller: _tabCtrl,
          indicatorPadding: const EdgeInsets.all(4),
          barDecoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          indicatorDecoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kG1, _kG2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
          tabTextColor: Colors.grey.shade600,
          selectedTabTextColor: Colors.white,
          textStyle: const TextStyle(
              fontFamily: 'Arch', fontSize: 13, fontWeight: FontWeight.w600),
          selectedTextStyle: const TextStyle(
              fontFamily: 'Arch', fontSize: 13, fontWeight: FontWeight.bold),
          splashColor: _kG2.withOpacity(0.10),
          splashHighlightColor: _kG2.withOpacity(0.06),
          tabs: [
            SegmentTab(label: inLabel),
            SegmentTab(label: outLabel),
          ],
        ),
      ),
    );
  }

  // ── Incoming tab (chat requests + bubble invites) ─────────

  Widget _buildIncomingTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_requests.isEmpty && _bubbleInvites.isEmpty) {
      return _emptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'No incoming requests',
        sub: 'Chat requests and bubble invites sent to you appear here',
      );
    }
    return RefreshIndicator(
      color: _kG2,
      onRefresh: _load,
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

  // ── Outgoing tab (requests I sent) ────────────────────────

  Widget _buildOutgoingTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_outgoingRequests.isEmpty) {
      return _emptyState(
        icon: Icons.send_rounded,
        title: 'No outgoing requests',
        sub: 'Requests you send to others appear here while pending',
      );
    }
    return RefreshIndicator(
      color: _kG2,
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _sectionHeader('Sent requests', _outgoingRequests.length),
          const SizedBox(height: 8),
          for (var i = 0; i < _outgoingRequests.length; i++)
            _buildOutgoingCard(_outgoingRequests[i]),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String sub,
  }) {
    return RefreshIndicator(
      color: _kG2,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Momo', color: Colors.grey.shade500)),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────

  Widget _sectionHeader(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontFamily: 'Arch',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.6)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8)),
            child: Text('$count',
                style: const TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _kInk)),
          ),
        ]),
      );

  Widget _miniTag(String label, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
            fontFamily: 'Momo',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: tint,
          )),
    );
  }

  Widget _buildBubbleInviteCard(Map<String, dynamic> r, int index) {
    final reqId = r['id'] as String? ?? '';
    final inviter =
        r['inviter_name'] as String? ?? r['inviter']?['name']?.toString() ?? 'Someone';
    final bubbleName =
        r['room_name'] as String? ?? r['room']?['name']?.toString() ?? 'Bubble';
    final bubbleAbout =
        r['room_about'] as String? ?? r['room']?['about']?.toString() ?? '';
    final isPublic = (r['room_is_public'] as bool?) ??
        (r['room']?['is_public'] as bool?) ??
        false;
    final memberCount = (r['room_member_count'] as int?) ??
        (r['room']?['member_count'] as int?) ??
        0;
    final message = r['message'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kG4.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG3, _kG4]),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.bubble_chart_rounded,
                  color: Colors.white, size: 26)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(bubbleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _kInk)),
                const SizedBox(height: 3),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _miniTag(isPublic ? 'Public' : 'Private',
                      isPublic ? _kG1 : _kG2),
                  if (memberCount > 0)
                    Text('· $memberCount member${memberCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                ]),
              ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _kG4.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Bubble',
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _kG4))),
        ]),
        const SizedBox(height: 10),
        Text('$inviter invited you to join.',
            style: TextStyle(
                fontFamily: 'Momo', fontSize: 12, color: Colors.grey.shade700)),
        if (bubbleAbout.isNotEmpty || message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(message.isNotEmpty ? message : bubbleAbout,
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4))),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: GestureDetector(
            onTap: () => _declineBubbleInvite(reqId, index),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300)),
                child: const Center(
                    child: Text('Decline',
                        style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _kInk)))),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: GestureDetector(
            onTap: () => _acceptBubbleInvite(reqId, index),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kG3, _kG4]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Text('Join',
                        style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white)))),
          )),
        ]),
      ]),
    );
  }

  Widget _buildChatRequestCard(Map<String, dynamic> r, int i) {
    final reqId = r['id'] as String? ?? '';
    final name = r['sender_name'] as String? ?? 'Unknown';
    final role = r['sender_role'] as String? ?? '';
    final avatarUrl = r['sender_avatar'] as String? ?? '';
    final message = r['message'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kG3.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_kG3, _kG4]),
                  image: avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                      : null),
              child: avatarUrl.isEmpty
                  ? Center(
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 20)))
                  : null),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _kInk)),
                Text(role,
                    style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 12,
                        color: Colors.grey.shade500)),
              ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _kG3.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('Chat Request',
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _kG3))),
        ]),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(message,
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4))),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: GestureDetector(
            onTap: () => _declineRequest(reqId, i),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300)),
                child: const Center(
                    child: Text('Decline',
                        style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _kInk)))),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: GestureDetector(
            onTap: () => _acceptRequest(reqId, i),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kG1, _kG2]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Center(
                    child: Text('Accept',
                        style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white)))),
          )),
        ]),
      ]),
    );
  }

  Widget _buildOutgoingCard(Map<String, dynamic> r) {
    final avatar = (r['receiver_avatar'] as String?) ?? '';
    final name = r['receiver_name'] as String? ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(initial,
                    style: const TextStyle(fontFamily: 'Alfa', fontSize: 18))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style:
                        const TextStyle(fontFamily: 'Alfa', fontSize: 14)),
                const SizedBox(height: 2),
                Text('Awaiting response',
                    style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 12,
                        color: Colors.grey.shade600)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Pending',
                style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 11,
                    color: Color(0xFF856404),
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}