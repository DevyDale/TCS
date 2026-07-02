// lib/screens/chat/chat_room_screen.dart
//
// Sage chat room + this pass's additions:
//   • Header avatar shows the receiver's profile picture (direct chats);
//     subtitle shows live presence — "typing…", "recording…", "Active now",
//     or "last seen <time>".
//   • Voice-note duplicate ("the box") killed: dedupe by media_url + id, and
//     any audio URL is routed to the player even if mistyped.
//   • Input field is clean (no icons inside); sticker + camera are separate
//     buttons to the left; mic/send to the right.
//   • Long-press a message → "Delete for me" (always) / "Delete for everyone"
//     (only your own message, within 10 minutes of sending).
//
// NEEDS BACKEND / WS (marked TODO below):
//   • Peer avatar + presence fields on GET /chat/rooms/<id>/ (see _loadRoomMeta).
//   • WS to emit typing/recording/presence events (receive side is wired).
//   • WS sendTyping/sendRecording so the PEER sees my status (send side is a
//     no-op hook for now — _onMyRecordingChanged / typing listener).
//   • DELETE endpoint POST /chat/messages/<id>/delete/ {scope: me|everyone}.

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/screens/chat/chat_audio_recorder.dart';
import 'package:tcs_app/screens/dashboard/other_user_profile_Screen.dart';
import 'package:tcs_app/widgets/ask_dale_sheet.dart';
import 'package:tcs_app/screens/chat/dale_message_bubble.dart';
import 'package:tcs_app/services/quiz_share.dart';
import 'package:tcs_app/widgets/quiz_share_card.dart';
import 'package:tcs_app/screens/ai/scam_check_screen.dart';
import 'package:tcs_app/screens/chat/chat_Sticker_picker.dart';
import 'package:tcs_app/screens/chat/chat_audio_player.dart';
import 'package:tcs_app/screens/chat/chat_sticker_bubble.dart';
import 'package:tcs_app/screens/ai/system_message_pill.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/screens/auth/session_keys.dart';
import '../../services/api_service.dart';

// ── Sage palette ──
Color get _kBg => AppC.bg;
const _kSage   = Color(0xFFA9BC95);
const _kSageDk = Color(0xFF6E8159);
const _kSageLt = Color(0xFFE7E8DD);
const _kInk    = Color(0xFF2E3A24);
Color get _kSlate => AppC.sub;
const _kHair   = Color(0xFFE3E2DA);
const _kWarm   = Color(0xFFC9A24B);
const _kDanger = Color(0xFFC0392B);

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
  bool _loading = true;
  bool _sending = false;
  bool _isTyping = false;

  // ── Dale state ──
  String _myUserId = '';
  final _picker = ImagePicker();
  String? _avatarUrl;       // group/bubble avatar
  String? _peerAvatarUrl;   // direct: the other person's picture
  bool _aiEnabled = false;
  bool _aiBusy    = false;

  // ── Peer presence ──
  bool _peerOnline = false;
  bool _peerTyping = false;
  bool _peerRecording = false;
  DateTime? _peerLastSeen;
  Timer? _peerTypingTimer;

  final Map<int, String> _stickerById = {};

  bool get _isStudyBuddy => widget.roomType == 'study_buddy';
  bool get _isDirect => widget.roomType == 'direct';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadRoomMeta();
    _connectWebSocket();
    _msgCtrl.addListener(() {
      final typing = _msgCtrl.text.isNotEmpty;
      if (typing != _isTyping) {
        setState(() => _isTyping = typing);
        // Tell the peer I'm typing (they render "typing…" in the header).
        _chatWs.sendTyping(typing);
      }
    });
  }

  @override
  void dispose() {
    _peerTypingTimer?.cancel();
    _chatWs.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Called by the recorder when I start/stop recording.
  void _onMyRecordingChanged(bool recording) {
    // Tell the peer I'm recording so they see "recording audio…".
    _chatWs.sendRecording(recording);
  }

  Future<void> _pickAndSendMedia() async {
    final picked = await _picker.pickMedia(requestFullMetadata: false);
    if (picked == null) return;

    HapticFeedback.lightImpact();

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final isVideo = picked.path.toLowerCase().endsWith('.mp4') ||
        picked.path.toLowerCase().endsWith('.mov');

    final tempMsg = {
      'id': tempId,
      'sender_id': _myUserId,
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
      final mimeType = isVideo
          ? (picked.path.toLowerCase().endsWith('.mov')
              ? 'video/quicktime'
              : 'video/mp4')
          : 'image/jpeg';

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

      try {
        _chatWs.sendMedia(
          messageType: isVideo ? 'video' : 'image',
          mediaUrl: mediaUrl,
        );
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      debugPrint('📷 media upload failed: $e');
      _showSnack('Media failed: $e');
    }
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    try {
      await _chatWs.connect(widget.roomId);
      _chatWs.stream.listen(_onWsMessage);
    } catch (_) {}
  }

  void _onWsMessage(Map<String, dynamic> event) {
    // Backend keys events with "event"; keep "type" as a fallback.
    final type = (event['event'] ?? event['type']) as String? ?? '';

    // Presence / typing / recording events (receive side).
    if (type == 'typing' || type == 'recording' || type == 'presence' ||
        type == 'last_seen' || type == 'online' || type == 'offline') {
      _handlePresenceEvent(type, event);
      return;
    }

    // Delivery / read receipts → update my sent messages' ticks.
    if (type == 'delivered_receipt') {
      _applyReceipt(event['message_id']?.toString(), 'delivered');
      return;
    }
    if (type == 'read_receipt') {
      _applyReceipt(event['message_id']?.toString(), 'read');
      return;
    }

    if (type != 'message' && type != 'new_message') return;

    // The message payload is spread across the event (backend:
    // {"event":"message", ...fields}); older shape nested it under "message".
    final msg = (event['message'] as Map?)?.cast<String, dynamic>() ??
        (Map<String, dynamic>.from(event)..remove('event'));

    final id = msg['id']?.toString();
    // Already have the real message → ignore the echo.
    if (id != null && _messages.any((m) => m['id']?.toString() == id)) return;

    final senderName = (msg['sender_name'] as String?)?.trim().toLowerCase() ?? '';
    final isMe = senderName == widget.userName.trim().toLowerCase() ||
        (msg['sender_id']?.toString() == _myUserId);
    msg['is_me'] = isMe;
    if (isMe && msg['status'] == null) msg['status'] = 'sent';

    // My own echo: reconcile with the optimistic temp bubble (same text/type)
    // so it isn't duplicated — upgrade it to the real id + status instead.
    if (isMe) {
      final tIdx = _messages.indexWhere((m) =>
          (m['id']?.toString().startsWith('temp_') ?? false) &&
          (m['text'] ?? '') == (msg['text'] ?? '') &&
          (m['message_type'] ?? 'text') == (msg['message_type'] ?? 'text'));
      if (tIdx != -1) {
        setState(() => _messages[tIdx] = {..._messages[tIdx], ...msg});
        return;
      }
    }

    // Dedupe media echoes (kills the duplicate audio "box").
    final mu = (msg['media_url'] as String?) ?? '';
    if (mu.isNotEmpty &&
        _messages.any((m) => (m['media_url'] as String?) == mu)) return;

    if (!isMe) {
      // A peer message means they're around — clear typing, mark online, and
      // since I'm looking at the room, immediately mark it read (blue ticks
      // for them).
      _peerTyping = false;
      _peerRecording = false;
      _peerOnline = true;
      if (id != null) _chatWs.sendRead(id);
    }

    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  // Update a sent message's tick state from a receipt. Never downgrade
  // read → delivered.
  void _applyReceipt(String? messageId, String status) {
    if (messageId == null) return;
    final idx = _messages.indexWhere((m) => m['id']?.toString() == messageId);
    if (idx == -1) return;
    if (status == 'delivered' && _messages[idx]['status'] == 'read') return;
    setState(() => _messages[idx]['status'] = status);
  }

  // WhatsApp-style delivery tick for my own messages:
  //   sent      → single grey ✓
  //   delivered → double grey ✓✓
  //   read      → double blue ✓✓
  Widget _statusTick(String? status) {
    const blue = Color(0xFF34B7F1);
    final grey = _kSlate.withOpacity(0.6);
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all_rounded, size: 14, color: blue);
      case 'delivered':
        return Icon(Icons.done_all_rounded, size: 14, color: grey);
      case 'sent':
      default:
        return Icon(Icons.done_rounded, size: 14, color: grey);
    }
  }

  void _handlePresenceEvent(String type, Map<String, dynamic> event) {
    final uid = event['user_id']?.toString() ?? event['sender_id']?.toString();
    if (uid != null && uid == _myUserId) return; // ignore my own

    setState(() {
      switch (type) {
        case 'typing':
          // Backend field is is_typing.
          _peerTyping = (event['is_typing'] ?? event['typing']) as bool? ?? true;
          _peerRecording = false;
          _peerOnline = true;
          break;
        case 'recording':
          _peerRecording =
              (event['is_recording'] ?? event['recording']) as bool? ?? true;
          _peerTyping = false;
          _peerOnline = true;
          break;
        case 'offline':
          _peerOnline = false;
          _peerTyping = false;
          _peerRecording = false;
          final ls = event['last_seen'];
          if (ls is String) _peerLastSeen = DateTime.tryParse(ls)?.toLocal();
          break;
        case 'online':
          _peerOnline = true;
          break;
        case 'presence':
        case 'last_seen':
          // Backend field is is_online.
          _peerOnline =
              (event['is_online'] ?? event['online']) as bool? ?? _peerOnline;
          final ls = event['last_seen'];
          if (ls is String) _peerLastSeen = DateTime.tryParse(ls)?.toLocal();
          if (!_peerOnline) {
            _peerTyping = false;
            _peerRecording = false;
          }
          break;
      }
    });

    // Safety auto-clear in case a "stopped" event is missed.
    if ((type == 'typing' && _peerTyping) ||
        (type == 'recording' && _peerRecording)) {
      _peerTypingTimer?.cancel();
      _peerTypingTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() {
            _peerTyping = false;
            _peerRecording = false;
          });
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    if (_myUserId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _myUserId = prefs.getString(SessionKeys.userId) ?? '';
        });
      }
    }
    try {
      final data = await _api.getRoomMessages(widget.roomId) as Map<String, dynamic>;
      final rawMessages =
          ((data['results'] as List?) ?? []).cast<Map<String, dynamic>>();

      final currentNameLower = widget.userName.trim().toLowerCase();

      // Dedupe by id and by non-empty media_url (collapses any server-side
      // double-create of voice notes so the "box" can't reappear on reload).
      final seenIds = <String>{};
      final seenUrls = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final msg in rawMessages) {
        final id = msg['id']?.toString() ?? '';
        final mu = (msg['media_url'] as String?) ?? '';
        if (id.isNotEmpty && seenIds.contains(id)) continue;
        if (mu.isNotEmpty && seenUrls.contains(mu)) continue;
        if (id.isNotEmpty) seenIds.add(id);
        if (mu.isNotEmpty) seenUrls.add(mu);

        final senderName =
            (msg['sender_name'] as String?)?.trim().toLowerCase() ?? '';
        msg['is_me'] = (msg['is_me'] as bool?) == true ||
            senderName == currentNameLower ||
            (msg['sender_id']?.toString() == _myUserId) ||
            (msg['user_id']?.toString() == _myUserId);

        deduped.add(msg);
      }

      setState(() {
        _messages = deduped;
        _loading = false;
      });
      _scrollToBottom();

      // Opening the chat = I've read the peer's messages. Persist it (drives
      // their ✓✓ turning blue) and send a live WS read for the latest one.
      try { await _api.markRoomRead(widget.roomId); } catch (_) {}
      for (final m in deduped.reversed) {
        if (m['is_me'] != true) {
          final id = m['id']?.toString();
          if (id != null && !id.startsWith('temp_')) _chatWs.sendRead(id);
          break;
        }
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRoomMeta() async {
    try {
      final res = await _api.get('/chat/rooms/${widget.roomId}/');
      if (!mounted || res is! Map) return;

      setState(() {
        _aiEnabled = res['ai_enabled'] as bool? ?? false;
        _avatarUrl = res['avatar_url'] as String?;
        _peerAvatarUrl = _extractPeerAvatar(res);

        // Presence seed (TODO backend: expose these on the room serializer).
        _peerOnline = res['peer_online'] as bool? ??
            res['other_user_online'] as bool? ??
            false;
        final ls = res['peer_last_seen'] ??
            res['other_user_last_seen'] ??
            res['last_seen'];
        if (ls is String) _peerLastSeen = DateTime.tryParse(ls)?.toLocal();

        if (res['current_user_id'] != null) {
          _myUserId = res['current_user_id'].toString();
        } else if (res['me'] != null && res['me'] is Map) {
          _myUserId = (res['me']['user_id'] ?? res['me']['id']).toString();
        }
      });
    } catch (_) {/* silent */}
  }

  /// Best-effort: pull the OTHER participant's avatar from the room payload.
  /// TODO(backend): for direct rooms, return the peer's avatar explicitly
  /// (e.g. `peer_avatar_url`) so this isn't guesswork.
  String? _extractPeerAvatar(Map res) {
    for (final c in [
      res['peer_avatar_url'],
      res['other_user_avatar_url'],
      (res['other_user'] is Map) ? res['other_user']['avatar_url'] : null,
      (res['peer'] is Map) ? res['peer']['avatar_url'] : null,
    ]) {
      if (c is String && c.isNotEmpty) return c;
    }
    final parts = res['participants'] ?? res['members'];
    if (parts is List) {
      for (final p in parts) {
        if (p is Map) {
          final pid = (p['user_id'] ?? p['id'])?.toString();
          if (pid != null && pid != _myUserId) {
            final a = p['avatar_url'];
            if (a is String && a.isNotEmpty) return a;
          }
        }
      }
    }
    return null;
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
      await showAskDaleSheet(context, onAsk: _askDale, onRemove: _disableDale);
    }
  }

  Future<void> _enableDale() async {
    setState(() => _aiBusy = true);
    try {
      final res = await _api.post('/chat/rooms/${widget.roomId}/ai/enable/')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _aiEnabled = res['ai_enabled'] as bool? ?? true);
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
    setState(() {
      _sending = true;
      _msgCtrl.clear();
      _isTyping = false;
    });

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _myUserId,
      'sender_name': widget.userName,
      'text': text,
      'message_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
      'is_me': true,
    };
    setState(() {
      _messages.add(tempMsg);
      _sending = false;
    });
    _scrollToBottom();

    try {
      _chatWs.sendText(text);
    } catch (_) {}
  }

  // ── Send: sticker ────────────────────────────────────────

  Future<void> _openStickerPicker() async {
    _focusNode.unfocus();
    await showStickerPicker(context, onPicked: _onStickerSelected);
  }

  Future<void> _onStickerSelected(Map<String, dynamic> sticker) async {
    if (sticker['is_local'] == true) {
      final path = sticker['file_path'] as String?;
      if (path != null) await _sendLocalImage(path);
      return;
    }
    final id = sticker['id'] as int?;
    final url = sticker['image_url'] as String? ?? '';
    if (id == null) return;
    if (url.isNotEmpty) _stickerById[id] = url;

    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': _myUserId,
      'sender_name': widget.userName,
      'message_type': 'sticker',
      'sticker_id': id,
      'media_url': url,
      'created_at': DateTime.now().toIso8601String(),
      'is_me': true,
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();
    HapticFeedback.lightImpact();

    try {
      _chatWs.sendSticker(id);
    } catch (_) {}
  }

  Future<void> _sendLocalImage(String filePath) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'sender_id': _myUserId,
      'sender_name': widget.userName,
      'message_type': 'image',
      'media_url': '',
      'local_path': filePath,
      'created_at': DateTime.now().toIso8601String(),
      'is_me': true,
      '_uploading': true,
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();
    HapticFeedback.lightImpact();

    try {
      final ext = filePath.split('.').last.toLowerCase();
      final mime = (ext == 'png')
          ? 'image/png'
          : (ext == 'gif')
              ? 'image/gif'
              : 'image/jpeg';
      final res = await _api.uploadChatMedia(
        roomId: widget.roomId,
        file: File(filePath),
        mimeType: mime,
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
      'id': tempId,
      'sender_id': _myUserId,
      'sender_name': widget.userName,
      'message_type': 'audio',
      'duration': rec.durationSeconds,
      'media_url': '',
      'created_at': DateTime.now().toIso8601String(),
      'is_me': true,
      '_uploading': true,
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      final res = await _api.uploadChatMedia(
        roomId: widget.roomId,
        file: File(rec.filePath),
        mimeType: 'audio/mp4',
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

      // NOTE: the HTTP upload already creates + broadcasts the message, so we
      // do NOT also _chatWs.sendMedia() for audio — that second send is what
      // produced the duplicate "box". (Dedup above is the belt-and-braces.)
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      debugPrint('🎤 voice upload failed: $e');
      _showSnack('Voice note failed: $e');
    } finally {
      try {
        File(rec.filePath).deleteSync();
      } catch (_) {}
    }
  }

  // ── Delete (long-press) ──────────────────────────────────

  void _showMessageActions(Map<String, dynamic> msg, bool isMe) {
    final id = msg['id']?.toString() ?? '';
    final isTemp = id.startsWith('temp_');
    final within10 =
        DateTime.now().difference(_ts(msg)).inMinutes < 10;
    final canDeleteEveryone = isMe && !isTemp && within10;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _kHair, borderRadius: BorderRadius.circular(2)),
          ),
          // Scam links often arrive through chat — let users check a message.
          if (((msg['text'] as String?) ?? '').trim().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.shield_rounded, color: Color(0xFF0EA5A4)),
              title: const T('Check for scams',
                  style: TextStyle(fontFamily: 'Momo', color: _kInk)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ScamCheckScreen(
                        initialText: (msg['text'] as String?) ?? '')));
              },
            ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: _kSlate),
            title: const T('Delete for me',
                style: TextStyle(fontFamily: 'Momo', color: _kInk)),
            onTap: () {
              Navigator.pop(ctx);
              _deleteForMe(msg);
            },
          ),
          if (canDeleteEveryone)
            ListTile(
              leading:
                  const Icon(Icons.delete_forever_rounded, color: _kDanger),
              title: const T('Delete for everyone',
                  style: TextStyle(fontFamily: 'Momo', color: _kDanger)),
              subtitle: T('Within 10 minutes of sending',
                  style: TextStyle(
                      fontFamily: 'Momo', fontSize: 11, color: _kSlate)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteForEveryone(msg);
              },
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Future<void> _deleteForMe(Map<String, dynamic> msg) async {
    final id = msg['id']?.toString() ?? '';
    setState(() => _messages.removeWhere((m) => m['id']?.toString() == id));
    if (!id.startsWith('temp_')) {
      // TODO(backend): POST /chat/messages/<id>/delete/ {scope:'me'}
      try {
        await _api.post('/chat/messages/$id/delete/', body: {'scope': 'me'});
      } catch (_) {}
    }
  }

  Future<void> _deleteForEveryone(Map<String, dynamic> msg) async {
    final id = msg['id']?.toString() ?? '';
    setState(() => _messages.removeWhere((m) => m['id']?.toString() == id));
    // TODO(backend): POST /chat/messages/<id>/delete/ {scope:'everyone'}
    // (server should verify ownership + 10-minute window, then broadcast a
    //  'message_deleted' WS event so the peer's copy disappears too.)
    try {
      await _api.post('/chat/messages/$id/delete/', body: {'scope': 'everyone'});
    } catch (_) {
      _showSnack('Couldn\'t delete for everyone right now.');
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildAppBar(),
        if (_isStudyBuddy) _buildStudyBuddyBanner(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isStudyBuddy
                    ? [Color(0xFFFBF7EC), _kBg]
                    : [Color(0xFFF7F9F1), _kBg],
              ),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kSageDk))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessages(),
          ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  String _statusLine() {
    if (_isDirect) {
      if (_peerTyping) return 'typing…';
      if (_peerRecording) return 'recording…';
      if (_peerOnline) return 'Active now';
      if (_peerLastSeen != null) return 'last seen ${_lastSeenFmt(_peerLastSeen!)}';
      return _aiEnabled ? 'Dale is in this chat' : '';
    }
    if (_aiEnabled) return 'Dale is in this chat';
    if (_isStudyBuddy) return 'Study Buddy Session';
    if (widget.roomType == 'group') return 'Chat Bubble';
    return '';
  }

  bool get _statusIsLive => _peerTyping || _peerRecording || _peerOnline;

  Widget _buildAppBar() {
    final status = _statusLine();
    return Container(
      decoration: BoxDecoration(
        color: AppC.card,
        border: Border(bottom: BorderSide(color: _kHair)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kInk, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            _buildRoomAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _kInk,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Arch')),
                  if (status.isNotEmpty)
                    Text(status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: (_statusIsLive || _aiEnabled)
                                ? _kSageDk
                                : _kSlate,
                            fontSize: 11.5,
                            fontFamily: 'Momo',
                            fontWeight: _statusIsLive
                                ? FontWeight.w600
                                : FontWeight.normal)),
                ],
              ),
            ),
            if (_isStudyBuddy) ...[
              GestureDetector(
                onTap: () =>
                    _showSnack('Materials shared — check Saved Materials'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: _kWarm.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.folder_shared_rounded, color: _kWarm, size: 16),
                    SizedBox(width: 4),
                    T('Materials',
                        style: TextStyle(
                            fontFamily: 'Momo',
                            color: _kWarm,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: _handleDaleTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                      colors: [_kSage, _kSageDk],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: _aiEnabled
                      ? [
                          BoxShadow(
                              color: _kSageDk.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]
                      : null,
                ),
                child: _aiBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Opacity(
                        opacity: _aiEnabled ? 1.0 : 0.55,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Lottie.asset(
                            'assets/images/robot.json',
                            errorBuilder: (context, error, stack) => Icon(
                                Icons.smart_toy_rounded,
                                color: AppC.card,
                                size: 22),
                          ),
                        ),
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRoomAvatar() {
    // Direct → the receiver's profile picture; otherwise the bubble avatar.
    final url = _isDirect ? _peerAvatarUrl : _avatarUrl;
    final hasUrl = url != null && url.isNotEmpty;
    final initial =
        widget.roomName.isNotEmpty ? widget.roomName[0].toUpperCase() : '?';
    final isBubble = widget.roomType == 'group';

    return Stack(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasUrl
              ? null
              : const LinearGradient(
                  colors: [_kSage, _kSageDk],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          image: hasUrl
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
          border: Border.all(color: _kHair, width: 1.5),
        ),
        child: hasUrl
            ? null
            : Center(
                child: isBubble
                    ? const Icon(Icons.bubble_chart_rounded,
                        color: Colors.white, size: 19)
                    : Text(initial,
                        style: TextStyle(
                            color: AppC.text,
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
      ),
      // Online dot for direct chats.
      if (_isDirect && _peerOnline)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ]);
  }

  Widget _buildStudyBuddyBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        color: _kWarm.withOpacity(0.10),
        child: Row(children: [
          const T('📚', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
              child: T('Study Buddy Chat — share notes, PDFs, and audio',
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 12,
                      color: _kWarm.withOpacity(0.95)))),
        ]),
      );

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: _isStudyBuddy
                          ? const [_kWarm, Color(0xFFA9803A)]
                          : const [_kSage, _kSageDk],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: (_isStudyBuddy ? _kWarm : _kSageDk)
                            .withOpacity(0.30),
                        blurRadius: 22,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: Icon(
                    _isStudyBuddy
                        ? Icons.menu_book_rounded
                        : Icons.waving_hand_rounded,
                    color: AppC.card,
                    size: 40),
              ),
              const SizedBox(height: 22),
              Text('Welcome to ${widget.roomName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Alfa',
                      color: _kInk)),
              const SizedBox(height: 10),
              Text(
                (widget.description != null && widget.description!.isNotEmpty)
                    ? widget.description!
                    : (_isStudyBuddy
                        ? 'Start your study session here — share notes, ask questions, work through problems together.'
                        : 'This is the beginning of the conversation. Say hello, share materials, or tap ✨ to bring in Dale.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5,
                    color: _kSlate,
                    fontFamily: 'Momo',
                    height: 1.55),
              ),
            ],
          ),
        ),
      );

  // ── Messages ─────────────────────────────────────────────

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showDateSeparator(i)) _dateSeparator(_dayLabel(_ts(_messages[i]))),
            _buildMessageAt(i),
          ],
        );
      },
    );
  }

  Widget _buildMessageAt(int i) {
    final msg = _messages[i];

    if (msg['is_system'] == true) {
      return SystemMessagePill(text: (msg['text'] as String?) ?? '');
    }

    if (msg['is_ai'] == true) {
      return DaleMessageBubble(message: msg, collapseHeader: !_isFirstInGroup(i));
    }

    final senderName = (msg['sender_name'] as String?)?.trim() ?? '';
    final senderId = msg['sender_id'] as String? ?? '';
    final isMe = senderId.isNotEmpty
        ? senderId == _myUserId
        : ((msg['is_me'] as bool?) == true ||
            senderName.toLowerCase() == widget.userName.trim().toLowerCase());

    final url = msg['media_url'] as String? ?? '';
    final rawType = msg['message_type'] as String? ?? 'text';
    // Any audio URL is audio, even if the type arrived wrong → no broken box.
    final msgType = (rawType == 'audio' || _isAudioUrl(url)) ? 'audio' : rawType;

    final first = _isFirstInGroup(i);
    final last = _isLastInGroup(i);
    final time = _fmt(msg['created_at'] as String? ?? '');

    // Shared-profile link → tappable card (sent from the Share-profile sheet).
    final txt = msg['text'] as String? ?? '';
    final sharedProfileId =
        msgType == 'text' ? _sharedProfileId(txt) : null;
    // Shared quiz → tappable quiz card.
    final quizShare = msgType == 'text' ? QuizShare.parse(txt) : null;

    final Widget bubble;
    if (quizShare != null) {
      bubble = QuizShareCard(
          quiz: quizShare, sharedBy: isMe ? null : senderName);
    } else if (sharedProfileId != null) {
      bubble = _profileShareCard(sharedProfileId, _sharedProfileName(txt), isMe);
    } else if (msgType == 'sticker') {
      bubble = ChatStickerBubble(message: msg, isMe: isMe, stickerMap: _stickerById);
    } else if (msgType == 'image' || msgType == 'video') {
      bubble = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _mediaMessage(msg, isMe),
      );
    } else {
      bubble = _contentBubble(msg, isMe, msgType, first, last);
    }

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showMessageActions(msg, isMe);
      },
      child: Padding(
        padding: EdgeInsets.only(top: first ? 6 : 0, bottom: last ? 12 : 3),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              last ? _avatar(senderName) : const SizedBox(width: 32),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (first && !isMe && quizShare == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 4),
                      child: Text(senderName,
                          style: TextStyle(
                              fontFamily: 'Arch',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kSlate)),
                    ),
                  bubble,
                  if (last) ...[
                    const SizedBox(height: 3),
                    Padding(
                      padding:
                          EdgeInsets.only(left: isMe ? 0 : 6, right: isMe ? 4 : 0),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(time,
                            style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 10.5,
                                color: _kSlate.withOpacity(0.8))),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          _statusTick(msg['status'] as String?),
                        ],
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared profile link ──────────────────────────────────
  // Messages sent from the Share-profile sheet look like:
  //   "Check out this profile: <Name> [profile:<user_id>]"
  static final RegExp _profileTokenRe = RegExp(r'\[profile:([^\]]+)\]');

  String? _sharedProfileId(String text) =>
      _profileTokenRe.firstMatch(text)?.group(1)?.trim();

  String _sharedProfileName(String text) {
    var t = text.replaceAll(_profileTokenRe, '').trim();
    const prefix = 'Check out this profile:';
    if (t.startsWith(prefix)) t = t.substring(prefix.length).trim();
    return t.isEmpty ? 'their profile' : t;
  }

  Widget _profileShareCard(String userId, String name, bool isMe) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtherUserProfileScreen(userId: userId),
        ));
      },
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? _kSage : _kSageLt,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: _kHair),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [_kSage, _kSageDk],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Center(
              child: Text(initial,
                  style: TextStyle(
                      color: AppC.text,
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: isMe ? Colors.white : _kInk)),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_rounded,
                      size: 12,
                      color: isMe ? Colors.white70 : _kSageDk),
                  const SizedBox(width: 4),
                  T('Tap to view profile',
                      style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 11,
                          color: isMe ? Colors.white70 : _kSlate)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: isMe ? Colors.white70 : _kSlate),
        ]),
      ),
    );
  }

  Widget _contentBubble(
      Map<String, dynamic> msg, bool isMe, String msgType, bool first, bool last) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMe ? 18 : (first ? 18 : 6)),
      topRight: Radius.circular(isMe ? (first ? 18 : 6) : 18),
      bottomLeft: Radius.circular(isMe ? 18 : (last ? 18 : 6)),
      bottomRight: Radius.circular(isMe ? (last ? 18 : 6) : 18),
    );
    final isText = msgType == 'text';
    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: isText
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
          : const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? _kSage : _kSageLt,
        borderRadius: radius,
        border: isMe ? null : Border.all(color: _kHair),
      ),
      child: isText
          ? Text(msg['text'] as String? ?? '',
              style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 14.5,
                  height: 1.35,
                  color: _kInk))
          : _mediaMessage(msg, isMe),
    );
  }

  Widget _mediaMessage(Map<String, dynamic> msg, bool isMe) {
    final type = msg['message_type'] as String? ?? '';
    final url = msg['media_url'] as String? ?? '';
    final localPath = msg['local_path'] as String? ?? '';
    final isUploading = msg['_uploading'] == true;

    // Audio first — covers mistyped audio so it never renders as a box.
    if (type == 'audio' || _isAudioUrl(url)) {
      if (isUploading) {
        return const SizedBox(
          width: 220,
          height: 50,
          child: Row(children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            T('Uploading voice note...', style: TextStyle(fontFamily: 'Momo')),
          ]),
        );
      }
      return ChatAudioPlayer(
        url: url,
        duration: (msg['duration'] as int?) ?? 0,
        isMe: isMe,
      );
    }

    if (type == 'image') {
      if (isUploading && localPath.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(File(localPath),
              width: 220, height: 220, fit: BoxFit.cover),
        );
      }
      if (url.isEmpty) {
        return const Icon(Icons.broken_image_rounded, size: 60, color: Colors.grey);
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 220,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 220,
            height: 220,
            color: AppC.border,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.broken_image_rounded, size: 60),
        ),
      );
    }

    if (type == 'video') {
      if (isUploading && localPath.isNotEmpty) {
        return Stack(alignment: Alignment.center, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(File(localPath),
                width: 220, height: 220, fit: BoxFit.cover),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 32),
          ),
          Positioned(
            bottom: 8,
            child:
                T('Uploading video...', style: TextStyle(color: AppC.text)),
          ),
        ]);
      }
      if (url.isEmpty) return const Icon(Icons.video_library_rounded, size: 60);
      return Stack(alignment: Alignment.center, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppC.sub),
            errorWidget: (_, __, ___) => Container(
              width: 220,
              height: 220,
              color: AppC.sub,
              child: const Icon(Icons.videocam_off_rounded, color: Colors.white),
            ),
          ),
        ),
        Container(
          width: 60,
          height: 60,
          decoration:
              const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child:
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
        ),
      ]);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.attach_file_rounded, color: _kSageDk, size: 20),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          msg['file_name'] as String? ?? 'File',
          style: const TextStyle(color: _kInk, fontFamily: 'Momo'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }

  Widget _avatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    const palettes = [
      [_kSage, _kSageDk],
      [Color(0xFFB6A06B), Color(0xFF8A7437)],
      [Color(0xFF8FAE9B), Color(0xFF5E7A66)],
      [Color(0xFFC2A38A), Color(0xFF94765C)],
      [Color(0xFF9DB0C0), Color(0xFF6E8499)],
    ];
    final colors = palettes[name.hashCode.abs() % palettes.length];
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
          child: Text(initial,
              style: TextStyle(
                  color: AppC.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Arch'))),
    );
  }

  // ── Input bar ─────────────────────────────────────────────

  Widget _circleIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: _kSageDk.withOpacity(0.10), shape: BoxShape.circle),
          child: Icon(icon, color: _kSageDk, size: 22),
        ),
      );

  Widget _sendButton() => GestureDetector(
        onTap: _sendMessage,
        child: Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_kSage, _kSageDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _sending
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
        ),
      );

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppC.card,
        border: Border(top: BorderSide(color: _kHair)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Icons live OUTSIDE the field now.
          _circleIconBtn(Icons.emoji_emotions_rounded, _openStickerPicker),
          const SizedBox(width: 6),
          _circleIconBtn(Icons.photo_camera_rounded, _pickAndSendMedia),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kSageLt,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kHair),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode: _focusNode,
                enableSuggestions: false,
                autocorrect: false,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 15, fontFamily: 'Momo', color: _kInk),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: TranslationService.I.tr('Type a message…'),
                  hintStyle: TextStyle(
                      color: _kSlate.withOpacity(0.8),
                      fontFamily: 'Momo',
                      fontSize: 14),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isTyping
              ? _sendButton()
              : ChatAudioRecorderButton(
                  onRecorded: _onAudioRecorded,
                  onRecordingChanged: _onMyRecordingChanged,
                  onTooShort: () =>
                      _showSnack('Hold the mic a bit longer to record.'),
                ),
        ]),
      ),
    );
  }

  // ── Grouping + date + helpers ────────────────────────────

  bool _isAudioUrl(String url) {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.m4a') ||
        u.endsWith('.aac') ||
        u.endsWith('.mp3') ||
        u.endsWith('.wav') ||
        u.endsWith('.ogg') ||
        u.endsWith('.opus');
  }

  DateTime _ts(Map<String, dynamic> m) =>
      DateTime.tryParse((m['created_at'] as String?) ?? '')?.toLocal() ??
      DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _showDateSeparator(int i) {
    if (i == 0) return true;
    return !_isSameDay(_ts(_messages[i]), _ts(_messages[i - 1]));
  }

  String _senderKey(Map<String, dynamic> m) {
    if (m['is_ai'] == true) return '__dale__';
    final sid = (m['sender_id'] as String?) ?? '';
    if (sid.isNotEmpty) return sid;
    return (m['sender_name'] as String?) ?? '';
  }

  bool _isFirstInGroup(int i) {
    if (i == 0) return true;
    if (_showDateSeparator(i)) return true;
    final prev = _messages[i - 1];
    if (prev['is_system'] == true) return true;
    return _senderKey(prev) != _senderKey(_messages[i]);
  }

  bool _isLastInGroup(int i) {
    if (i == _messages.length - 1) return true;
    final next = _messages[i + 1];
    if (next['is_system'] == true) return true;
    if (!_isSameDay(_ts(next), _ts(_messages[i]))) return true;
    return _senderKey(next) != _senderKey(_messages[i]);
  }

  Widget _dateSeparator(String label) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kSageDk.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 11.5,
                  color: _kSlate,
                  fontWeight: FontWeight.w600)),
        ),
      );

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    if (today.difference(d).inDays < 7) return DateFormat('EEEE').format(dt);
    if (dt.year == now.year) return DateFormat('EEEE, MMM d').format(dt);
    return DateFormat('MMM d, y').format(dt);
  }

  String _lastSeenFmt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (_isSameDay(dt, now)) return 'today ${DateFormat('h:mm a').format(dt)}';
    final y = now.subtract(const Duration(days: 1));
    if (_isSameDay(dt, y)) return 'yesterday ${DateFormat('h:mm a').format(dt)}';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  String _fmt(String iso) {
    try {
      return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
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
