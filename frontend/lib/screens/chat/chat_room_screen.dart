// lib/screens/chat/chat_room_screen.dart
//
// Phase 7: Dale AI in chat (Meta-AI style).
//
// What's new on top of the previous version:
//   • Dale button in the app bar (top-right). Tap behaviour:
//       - Dale OFF → enables Dale, who joins the room and posts a
//         "Dale joined" system pill + a first context-aware reply
//       - Dale ON  → opens the Ask Dale bottom sheet
//   • Dale messages render via DaleMessageBubble (gradient avatar,
//     gradient-bordered white bubble, "Dale ✨ AI" label).
//   • System messages (is_system: true) render as centered pills.
//   • Room metadata is fetched on init so we know whether Dale is
//     already enabled when reopening the room.
//
// Existing features (text, stickers, audio, file, websocket optimistic
// UI) are preserved unchanged.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tcs_app/screens/chat/chat_audio_recorder.dart';
import 'package:tcs_app/widgets/ask_dale_sheet.dart';
import 'package:tcs_app/widgets/dale_appbar_button.dart';
import 'package:tcs_app/screens/chat/dale_message_bubble.dart';
import 'package:tcs_app/screens/chat/chat_Sticker_picker.dart';
import 'package:tcs_app/screens/chat/chat_audio_player.dart';
import 'package:tcs_app/screens/chat/chat_sticker_bubble.dart';
import 'package:tcs_app/screens/ai/system_message_pill.dart';

import '../../services/api_service.dart';


const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String userName;
  final String roomType; // 'direct' | 'study_buddy' | 'group'
  final String? description;
  
  

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.userName,
    this.roomType = 'direct',
    this.description,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _api        = ApiService();
  final _chatWs     = ChatWebSocketService();
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  

  List<Map<String, dynamic>> _messages = [];
  bool _loading  = true;
  bool _sending  = false;
  bool _analyzing = false;
  bool _isTyping = false;

  // ── Dale state ──
  String? _myUserId;   // Will help as a more reliable fallback
  final _picker = ImagePicker();
  String? _avatarUrl;          // Bubble avatar from room metadata
  bool _aiEnabled  = false;   // true if Dale is currently in the room
  bool _aiBusy     = false;   // true while a Dale-related API call is in flight

  /// Cache of sticker_id → image_url so optimistic bubbles render
  /// instantly without a re-fetch.
  final Map<int, String> _stickerById = {};

  bool get _isStudyBuddy => widget.roomType == 'study_buddy';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadRoomMeta();
    _connectWebSocket();
    _msgCtrl.addListener(() => setState(() => _isTyping = _msgCtrl.text.isNotEmpty));
  }

  @override
  void dispose() {
    _chatWs.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }


Future<void> _pickAndSendMedia() async {
  final picked = await _picker.pickMedia(
    requestFullMetadata: false,
  );
  if (picked == null) return;

  HapticFeedback.lightImpact();

  final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
  final isVideo = picked.path.toLowerCase().endsWith('.mp4') ||
                  picked.path.toLowerCase().endsWith('.mov');

  final tempMsg = {
    'id': tempId,
    'sender_name': widget.userName,
    'message_type': isVideo ? 'video' : 'image',
    'media_url': '',
    'local_path': picked.path,
    'created_at': DateTime.now().toIso8601String(),
    'is_me': true,
    '_uploading': true,
  };

  setState(() => _messages.add(tempMsg));
  _scrollToBottom();

  try {
    final mimeType = isVideo ? 'video/mp4' : 'image/jpeg';

    final res = await _api.uploadChatMedia(
      roomId: widget.roomId,
      file: File(picked.path),
      mimeType: mimeType,
    ) as Map<String, dynamic>;

    final mediaUrl = (res['media_url'] ?? res['url']) as String? ?? '';
    final messageId = res['message_id'] ?? res['id'] ?? tempId;

    if (!mounted) return;

    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == tempId);
      if (idx != -1) {
        _messages[idx] = {
          ..._messages[idx],
          'id': messageId,
          'media_url': mediaUrl,
          '_uploading': false,
        };
      }
    });

    // Send via WebSocket
    try {
      _chatWs.sendMedia(
        messageType: isVideo ? 'video' : 'image',
        mediaUrl: mediaUrl,
      );
    } catch (_) {}
  } catch (e) {
    if (!mounted) return;
    setState(() => _messages.removeWhere((m) => m['id'] == tempId));
    _showSnack("Couldn't send media. Try again.");
  }
}
  // ── Data ──────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    try {
      await _chatWs.connect(widget.roomId);
      _chatWs.stream.listen(_onWsMessage);
    } catch (_) {
      // Without WS, optimistic UI still works — just no live updates
      // from other room members until refresh.
    }
  }

void _onWsMessage(Map<String, dynamic> event) {
  final type = event['type'] as String? ?? '';
  if (type != 'message' && type != 'new_message') return;

  final msg = (event['message'] as Map?)?.cast<String, dynamic>();
  if (msg == null) return;

  final id = msg['id']?.toString();
  if (id != null && _messages.any((m) => m['id']?.toString() == id)) return;

  final senderName = (msg['sender_name'] as String?)?.trim().toLowerCase() ?? '';
  final currentNameLower = widget.userName.trim().toLowerCase();

  msg['is_me'] = senderName == currentNameLower ||
                 (msg['sender_id']?.toString() == _myUserId);

  setState(() => _messages.add(msg));
  _scrollToBottom();
}
Future<void> _loadHistory() async {
  try {
    final data = await _api.getRoomMessages(widget.roomId) as Map<String, dynamic>;
    final rawMessages = ((data['results'] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    final currentNameLower = widget.userName.trim().toLowerCase();

    for (final msg in rawMessages) {
      final senderName = (msg['sender_name'] as String?)?.trim().toLowerCase() ?? '';
      
      // Multiple reliable checks
      msg['is_me'] = 
          (msg['is_me'] as bool?) == true ||
          senderName == currentNameLower ||
          (msg['sender_id']?.toString() == _myUserId) ||
          (msg['user_id']?.toString() == _myUserId);
    }

    setState(() {
      _messages = rawMessages;
      _loading = false;
    });
    _scrollToBottom();
  } catch (_) {
    setState(() => _loading = false);
  }
}
  /// Fetch the room object so we know if Dale is already a member.
  /// Falls back silently if the endpoint isn't reachable — in which
  /// case the Dale button will start in the OFF state and the user
  /// can still enable him.
 Future<void> _loadRoomMeta() async {
  try {
    final res = await _api.get('/chat/rooms/${widget.roomId}/');
    if (!mounted || res is! Map) return;

    setState(() {
      _aiEnabled = res['ai_enabled'] as bool? ?? false;
      _avatarUrl = res['avatar_url'] as String?;
      
      // Try to capture current user ID if available
      if (res['current_user_id'] != null) {
        _myUserId = res['current_user_id'].toString();
      } else if (res['me'] != null && res['me'] is Map) {
        _myUserId = (res['me']['user_id'] ?? res['me']['id']).toString();
      }
    });
  } catch (_) { /* silent */ }
}

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  // Dale AI
  // ══════════════════════════════════════════════════════════

  Future<void> _handleDaleTap() async {
    if (_aiBusy) return;
    HapticFeedback.lightImpact();

    if (!_aiEnabled) {
      await _enableDale();
    } else {
      // Dale already here — open Ask Dale sheet.
      await showAskDaleSheet(
        context,
        onAsk:    _askDale,
        onRemove: _disableDale,
      );
    }
  }

  Future<void> _enableDale() async {
    setState(() => _aiBusy = true);
    try {
      final res = await _api.post('/chat/rooms/${widget.roomId}/ai/enable/')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _aiEnabled = res['ai_enabled'] as bool? ?? true;
      });
      // The endpoint returns Dale's first reply directly. The "Dale
      // joined" system message is emitted by the backend before that
      // reply, so when we refresh the message list it'll appear in
      // order. Easiest path: reload history.
      await _loadHistory();
    } catch (e) {
      _showSnack('Couldn\'t add Dale. Try again.');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _askDale(String message) async {
    setState(() => _aiBusy = true);
    try {
      await _api.post(
        '/chat/rooms/${widget.roomId}/ai/summon/',
        body: {if (message.isNotEmpty) 'message': message},
      );
      if (!mounted) return;
      // Pull the new Dale reply (and the user's question if it was
      // posted as a system note) into the local list.
      await _loadHistory();
    } catch (_) {
      _showSnack('Dale couldn\'t reply right now.');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _disableDale() async {
    setState(() => _aiBusy = true);
    try {
      await _api.post('/chat/rooms/${widget.roomId}/ai/disable/');
      if (!mounted) return;
      setState(() => _aiEnabled = false);
      await _loadHistory();
    } catch (_) {
      _showSnack('Couldn\'t remove Dale right now.');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ── Send: text ───────────────────────────────────────────

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

    try { _chatWs.sendText(text); } catch (_) {}
  }

  // ── Send: sticker ────────────────────────────────────────

  Future<void> _openStickerPicker() async {
    _focusNode.unfocus();
    await showStickerPicker(context, onPicked: _onStickerSelected);
  }

  Future<void> _onStickerSelected(Map<String, dynamic> sticker) async {
    // Local sticker added from gallery: upload + send as image.
    if (sticker['is_local'] == true) {
      final path = sticker['file_path'] as String?;
      if (path != null) await _sendLocalImage(path);
      return;
    }
    final id  = sticker['id'] as int?;
    final url = sticker['image_url'] as String? ?? '';
    if (id == null) return;

    if (url.isNotEmpty) _stickerById[id] = url;

    final tempMsg = {
      'id':           'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_name':  widget.userName,
      'message_type': 'sticker',
      'sticker_id':   id,
      'media_url':    url,
      'created_at':   DateTime.now().toIso8601String(),
      'is_me':        true,
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();
    HapticFeedback.lightImpact();

    try { _chatWs.sendSticker(id); } catch (_) {}
  }


  Future<void> _sendLocalImage(String filePath) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id':           tempId,
      'sender_name':  widget.userName,
      'message_type': 'image',
      'media_url':    '',
      'local_path':   filePath,
      'created_at':   DateTime.now().toIso8601String(),
      'is_me':        true,
      '_uploading':   true,
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();
    HapticFeedback.lightImpact();

    try {
      final ext = filePath.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png'
                 : (ext == 'gif') ? 'image/gif'
                 : 'image/jpeg';
      final res = await _api.uploadChatMedia(
        roomId:   widget.roomId,
        file:     File(filePath),
        mimeType: mime,
      ) as Map<String, dynamic>;

      final mediaUrl  = (res['media_url'] ?? res['url']) as String? ?? '';
      final messageId = res['message_id'] ?? res['id'] ?? tempId;

      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == tempId);
        if (idx != -1) {
          _messages[idx] = {
            ..._messages[idx],
            'id':         messageId,
            'media_url':  mediaUrl,
            '_uploading': false,
          };
        }
      });

      try {
        _chatWs.sendMedia(messageType: 'image', mediaUrl: mediaUrl);
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      _showSnack("Couldn't send sticker. Try again.");
    }
  }

  // ── Send: voice note ─────────────────────────────────────

  Future<void> _onAudioRecorded(AudioRecording rec) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id':           tempId,
      'sender_name':  widget.userName,
      'message_type': 'audio',
      'duration':     rec.durationSeconds,
      'media_url':    '',
      'created_at':   DateTime.now().toIso8601String(),
      'is_me':        true,
      '_uploading':   true,
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      final res = await _api.uploadChatMedia(
        roomId:   widget.roomId,
        file:     File(rec.filePath),
        mimeType: 'audio/m4a',
      ) as Map<String, dynamic>;

      final mediaUrl  = (res['media_url'] ?? res['url']) as String? ?? '';
      final messageId = res['message_id'] ?? res['id'] ?? tempId;

      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == tempId);
        if (idx != -1) {
          _messages[idx] = {
            ..._messages[idx],
            'id':         messageId,
            'media_url':  mediaUrl,
            '_uploading': false,
          };
        }
      });

      try {
        _chatWs.sendMedia(
          messageType: 'audio',
          mediaUrl:    mediaUrl,
          duration:    rec.durationSeconds.toDouble(),
        );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      _showSnack('Couldn\'t send voice note. Try again.');
    } finally {
      try { File(rec.filePath).deleteSync(); } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

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
        left: 8, right: 12, bottom: 12),
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

        _buildRoomAvatar(),
        const SizedBox(width: 10),

        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName, style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Arch')),

            if (_isStudyBuddy)
              const Text('Study Buddy Session 📚', style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontFamily: 'Momo')),
          ],
        )),

        if (_isStudyBuddy) ...[
          GestureDetector(
            onTap: () => _showSnack('Materials shared — check Saved Materials'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.folder_shared_rounded, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Materials', style: TextStyle(
                    fontFamily: 'Momo',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    ),
  );
}

  Widget _buildRoomAvatar() {
    final hasUrl  = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    final initial = widget.roomName.isNotEmpty
        ? widget.roomName[0].toUpperCase() : '?';
    final isBubble = widget.roomType == 'group';
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUrl ? null : const LinearGradient(
            colors: [Color(0xFFF7971E), Color(0xFFFF5858)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        image: hasUrl
            ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
            : null,
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: hasUrl ? null : Center(
        child: isBubble
            ? const Icon(Icons.bubble_chart_rounded,
                color: Colors.white, size: 18)
            : Text(initial, style: const TextStyle(
                color: Colors.white, fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92, height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isStudyBuddy
                  ? [Colors.orange.shade300, Colors.amber.shade400]
                  : [Colors.deepPurple.shade300, Colors.purple.shade400]),
              boxShadow: [BoxShadow(
                color: Colors.deepPurple.withOpacity(0.18),
                blurRadius: 20, offset: const Offset(0, 8))]),
            child: Icon(
              _isStudyBuddy
                ? Icons.menu_book_rounded
                : Icons.celebration_rounded,
              color: Colors.white, size: 42),
          ),
          const SizedBox(height: 22),
          Text('Welcome to ' + widget.roomName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, fontFamily: 'Alfa')),
          const SizedBox(height: 10),
          Text(
            (widget.description != null && widget.description!.isNotEmpty)
              ? widget.description!
              : (_isStudyBuddy
                ? 'Start your study session here — share notes, ask questions, work through problems together.'
                : 'This is the beginning of the conversation. Introduce yourself, share materials, or just say hello.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontFamily: 'Momo',
              height: 1.55)),
        ],
      ),
    ),
  );

  Widget _buildMessages() {
  return ListView.builder(
    controller: _scrollCtrl,
    padding: const EdgeInsets.all(16),
    itemCount: _messages.length,
    itemBuilder: (_, i) {
      final msg = _messages[i];
      final prev = i > 0 ? _messages[i - 1] : null;

      // System Message
      if (msg['is_system'] == true) {
        final text = (msg['text'] as String?) ?? '';
        return SystemMessagePill(text: text);
      }

      // Dale AI Message
      if (msg['is_ai'] == true) {
        final prevAi = prev != null &&
            prev['is_ai'] == true &&
            prev['is_system'] != true;
        return DaleMessageBubble(message: msg, collapseHeader: prevAi);
      }

      // Regular Message - SUPER ROBUST isMe
      final senderName = (msg['sender_name'] as String?)?.trim() ?? '';
      final isMe = (msg['is_me'] as bool?) == true ||
                   senderName.toLowerCase() == widget.userName.trim().toLowerCase();

      final time = _fmt(msg['created_at'] as String? ?? '');
      final msgType = msg['message_type'] as String? ?? 'text';
      final showName = !isMe && 
          (i == 0 || (_messages[i - 1]['sender_name'] as String?) != senderName);

      // Sticker
      if (msgType == 'sticker') {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                _avatar(senderName),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showName && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(senderName, style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                  ChatStickerBubble(
                    message: msg,
                    isMe: isMe,
                    stickerMap: _stickerById,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 4, left: isMe ? 0 : 6, right: isMe ? 6 : 0),
                    child: Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                _avatar(widget.userName),
              ],
            ],
          ),
        );
      }

      // Regular Text / Media Message
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _avatar(senderName),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showName && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(senderName, style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 20 : 4),
                        topRight: Radius.circular(isMe ? 4 : 20),
                        bottomLeft: const Radius.circular(20),
                        bottomRight: const Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msgType != 'text')
                          _mediaMessage(msg, isMe)
                        else
                          Text(
                            msg['text'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              color: isMe ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(time, style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : Colors.grey.shade600)),
                            if (isMe)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.done_all_rounded,
                                    size: 14, color: Colors.white70),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              _avatar(widget.userName),
            ],
          ],
        ),
      );
    },
  );
}
Widget _mediaMessage(Map<String, dynamic> msg, bool isMe) {
  final type = msg['message_type'] as String? ?? '';
  final url = msg['media_url'] as String? ?? '';
  final localPath = msg['local_path'] as String? ?? '';
  final isUploading = msg['_uploading'] == true;

  // Audio
  if (type == 'audio') {
    if (isUploading) {
      return const SizedBox(
        width: 220,
        height: 50,
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Uploading voice note...', style: TextStyle(fontFamily: 'Momo')),
          ],
        ),
      );
    }
    return ChatAudioPlayer(
      url: url,
      duration: (msg['duration'] as int?) ?? 0,
      isMe: isMe,
    );
  }

  // Image
  if (type == 'image') {
    if (isUploading && localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(localPath),
          width: 220,
          height: 220,
          fit: BoxFit.cover,
        ),
      );
    }
    if (url.isEmpty) {
      return const Icon(Icons.broken_image_rounded, size: 60, color: Colors.grey);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 220,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220,
          height: 220,
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 60),
      ),
    );
  }

  // Video
  if (type == 'video') {
    if (isUploading && localPath.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(localPath), width: 220, height: 220, fit: BoxFit.cover),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
          ),
          if (isUploading)
            const Positioned(
              bottom: 8,
              child: Text('Uploading video...', style: TextStyle(color: Colors.white)),
            ),
        ],
      );
    }

    if (url.isEmpty) return const Icon(Icons.video_library_rounded, size: 60);

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade800),
          ),
        ),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
        ),
      ],
    );
  }

  // Fallback for other file types
  return Row(children: [
    Icon(Icons.attach_file_rounded, color: isMe ? Colors.white : Colors.deepPurple, size: 20),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        msg['file_name'] as String? ?? 'File',
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontFamily: 'Momo',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
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

  // ── Input bar ─────────────────────────────────────────────
Widget _buildInputBar() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, -2),
      )],
    ),
    child: SafeArea(
      top: false,
      child: Row(children: [
        // Sticker Button
        GestureDetector(
          onTap: _openStickerPicker,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_emotions_rounded,
                color: Colors.purple, size: 22),
          ),
        ),

        const SizedBox(width: 8),

        // NEW: Media Picker (Images + Videos)
        GestureDetector(
          onTap: _pickAndSendMedia,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_camera_rounded,
                color: Colors.blue, size: 22),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _msgCtrl,
              focusNode: _focusNode,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(fontSize: 15, fontFamily: 'Momo'),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                    color: Colors.grey.shade500, fontFamily: 'Momo'),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        _isTyping
            ? GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.purple],
                    ),
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                ),
              )
            : ChatAudioRecorderButton(
                onRecorded: _onAudioRecorded,
                onTooShort: () =>
                    _showSnack('Hold the mic a bit longer to record.'),
              ),
      ]),
    ),
  );
}
  Future<void> _summonDale() async {
    if (_analyzing) return;
    setState(() => _analyzing = true);
    try {
      await _api.analyzeWithDale(widget.roomId);
    } catch (_) {
      if (mounted) _showSnack("Dale couldn't respond right now.");
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
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