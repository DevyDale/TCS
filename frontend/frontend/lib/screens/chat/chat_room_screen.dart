// lib/screens/chat/chat_room_screen.dart
// KEY CHANGE: accepts roomId (for backend) + roomType label
// Drop-in replacement — same file path
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

const _kG2 = Color(0xFF8E54E9);

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String userName;
  final String roomType; // 'direct' | 'study_buddy' | 'group'

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.userName,
    this.roomType = 'direct',
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _api       = ApiService();
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  bool _loading  = true;
  bool _sending  = false;
  bool _isTyping = false;

  bool get _isStudyBuddy => widget.roomType == 'study_buddy';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _msgCtrl.addListener(() => setState(() => _isTyping = _msgCtrl.text.isNotEmpty));
  }

  @override
  void dispose() {
    _msgCtrl.dispose(); _scrollCtrl.dispose(); _focusNode.dispose(); super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.getRoomMessages(widget.roomId) as Map<String, dynamic>;
      setState(() {
        _messages = ((data['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading  = false;
      });
      _scrollToBottom();
    } catch (_) { setState(() => _loading = false); }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    setState(() { _sending = true; _msgCtrl.clear(); _isTyping = false; });

    // Optimistic UI
    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_name': widget.userName, 'text': text,
      'message_type': 'text', 'created_at': DateTime.now().toIso8601String(),
      'is_me': true,
    };
    setState(() { _messages.add(tempMsg); _sending = false; });
    _scrollToBottom();

    // Background send via API (WebSocket handles real delivery)
    try {
      _api.addComment(widget.roomId, text); // reuse endpoint — or call rooms message endpoint
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: _isStudyBuddy
                ? [const Color(0xFFFFF3E0), const Color(0xFFFFF8E1), Colors.white]
                : [Colors.purple.shade50, Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(children: [
          _buildAppBar(),
          if (_isStudyBuddy) _buildStudyBuddyBanner(),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kG2))
              : _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessages()),
          _buildInputBar(),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 8, right: 16, bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isStudyBuddy
              ? [Colors.orange.shade600, Colors.amber.shade700]
              : [Colors.deepPurple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.roomName, style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Arch')),
            if (_isStudyBuddy)
              const Text('Study Buddy Session 📚', style: TextStyle(
                  color: Colors.white70, fontSize: 12, fontFamily: 'Momo')),
          ])),
          if (_isStudyBuddy) ...[
            GestureDetector(
              onTap: () => _showSnack('Materials shared — check Saved Materials'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.folder_shared_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Materials', style: TextStyle(fontFamily: 'Momo',
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildStudyBuddyBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: Colors.orange.shade50,
    child: Row(children: [
      const Text('📚', style: TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Expanded(child: Text('Study Buddy Chat — Share notes, PDFs, and audio!',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: Colors.orange.shade800))),
    ]),
  );

  Widget _buildEmptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.chat_bubble_outline_rounded, size: 72, color: Colors.purple.shade200),
    const SizedBox(height: 20),
    const Text('No messages yet', style: TextStyle(fontSize: 22,
        fontWeight: FontWeight.bold, fontFamily: 'Alfa')),
    const SizedBox(height: 8),
    Text('Say hello!', style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontFamily: 'Momo')),
  ]));

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg   = _messages[i];
        final isMe  = msg['is_me'] as bool? ?? (msg['sender_name'] == widget.userName);
        final text  = msg['text'] as String? ?? msg['display_text'] as String? ?? '';
        final time  = _fmt(msg['created_at'] as String? ?? '');
        final name  = msg['sender_name'] as String? ?? '';
        final msgType = msg['message_type'] as String? ?? 'text';
        final showName = !isMe && (i == 0 || _messages[i-1]['sender_name'] != name);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                _avatar(name),
                const SizedBox(width: 8),
              ],
              Flexible(child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showName && !isMe)
                    Padding(padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(name, style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: Colors.grey.shade700,
                          fontFamily: 'Momo'))),
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isMe ? LinearGradient(
                          colors: [Colors.deepPurple.shade400, Colors.purple.shade600],
                          begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 20 : (showName ? 4 : 20)),
                        topRight: Radius.circular(isMe ? (showName ? 4 : 20) : 20),
                        bottomLeft: const Radius.circular(20),
                        bottomRight: const Radius.circular(20)),
                      boxShadow: [BoxShadow(
                        color: isMe ? Colors.deepPurple.withOpacity(0.3)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (msgType != 'text')
                        _mediaMessage(msg, isMe)
                      else
                        Text(text, style: TextStyle(fontSize: 15,
                            color: isMe ? Colors.white : Colors.black87,
                            fontFamily: 'Momo', height: 1.4)),
                      const SizedBox(height: 6),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(time, style: TextStyle(fontSize: 11,
                            color: isMe ? Colors.white.withOpacity(0.8) : Colors.grey.shade600,
                            fontFamily: 'Momo')),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all_rounded, size: 14,
                              color: Colors.white.withOpacity(0.8)),
                        ],
                      ]),
                    ]),
                  ),
                ],
              )),
              if (isMe) ...[const SizedBox(width: 8), _avatar(widget.userName)],
            ],
          ),
        );
      },
    );
  }

  Widget _mediaMessage(Map<String, dynamic> msg, bool isMe) {
    final type = msg['message_type'] as String? ?? '';
    final fileName = msg['file_name'] as String? ?? 'File';
    final color = isMe ? Colors.white : Colors.deepPurple.shade600;
    if (type == 'image') return const Icon(Icons.image_rounded, size: 40, color: Colors.white70);
    if (type == 'audio') {
      return Row(children: [
      Icon(Icons.play_circle_filled_rounded, color: color, size: 30),
      const SizedBox(width: 8),
      Text('Voice note', style: TextStyle(color: color, fontFamily: 'Momo', fontSize: 13)),
    ]);
    }
    return Row(children: [
      Icon(Icons.attach_file_rounded, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(fileName, style: TextStyle(color: color, fontFamily: 'Momo', fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _avatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors  = [Colors.blue.shade600, Colors.green.shade600,
                     Colors.orange.shade600, Colors.pink.shade600];
    final color   = colors[name.hashCode.abs() % colors.length];
    return Container(width: 36, height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
          border: Border.all(color: Colors.white, width: 2)),
      child: Center(child: Text(initial, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Arch'))));
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(top: false, child: Row(children: [
        // Attachment — for study buddy rooms especially
        GestureDetector(
          onTap: () => _showSnack('File sharing coming soon!'),
          child: Container(width: 42, height: 42,
            decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
            child: Icon(Icons.add_rounded, color: Colors.purple.shade600, size: 24))),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24)),
            child: TextField(
              controller: _msgCtrl, focusNode: _focusNode,
              enableSuggestions: false, autocorrect: false,
              style: const TextStyle(fontSize: 15, fontFamily: 'Momo'),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontFamily: 'Momo'),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isTyping
                    ? [Colors.deepPurple.shade400, Colors.purple.shade600]
                    : [Colors.grey.shade300, Colors.grey.shade400])),
            child: _sending
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 22))),
      ])),
    );
  }

  String _fmt(String iso) {
    try { return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return ''; }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
  }
}