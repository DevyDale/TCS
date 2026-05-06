// lib/widgets/chat/chat_sticker_bubble.dart
//
// Renders a sticker inside a chat bubble.
//
// The Message model carries `sticker_id` (int) when message_type ==
// 'sticker'. We resolve the image URL by either:
//   (a) looking it up in a cached sticker map you pass in (faster), or
//   (b) reading `media_url` if your backend serializer fills it in.
//
// Stickers are deliberately rendered WITHOUT a bubble background —
// they sit "naked" against the chat backdrop, like Telegram and
// WhatsApp. Just an image + the timestamp.
//
// Usage inside chat_room_screen's message renderer:
//   if (msgType == 'sticker') {
//     return ChatStickerBubble(
//       message:    msg,
//       isMe:       isMe,
//       stickerMap: _stickerById,   // optional Map<int, String> id → url
//     );
//   }

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ChatStickerBubble extends StatelessWidget {
  final Map<String, dynamic>  message;
  final bool                  isMe;
  final Map<int, String>?     stickerMap;
  final double                size;

  const ChatStickerBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.stickerMap,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl();
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: size, height: size,
          child: url == null
              ? _placeholder()
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => _placeholder(broken: true),
                  placeholder: (_, __) => _placeholder(loading: true),
                ),
        ),
      ],
    );
  }

  String? _resolveUrl() {
    final mediaUrl = message['media_url'] as String? ?? '';
    if (mediaUrl.isNotEmpty) return mediaUrl;

    final id = message['sticker_id'];
    if (id is int && stickerMap != null && stickerMap!.containsKey(id)) {
      return stickerMap![id];
    }
    return null;
  }

  Widget _placeholder({bool broken = false, bool loading = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEF3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF8E54E9))
            : Icon(
                broken
                    ? Icons.broken_image_rounded
                    : Icons.emoji_emotions_rounded,
                color: Colors.grey.shade400,
                size: 32,
              ),
      ),
    );
  }
}
