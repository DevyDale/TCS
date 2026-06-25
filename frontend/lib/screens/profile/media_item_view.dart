// lib/widgets/media_item_view.dart
//
// Renders ONE media item from a post — handles both images and
// videos. Designed to drop into an existing PageView carousel as
// the per-item builder, so the parent keeps owning page indicators,
// counter badges, gradient overlays, etc.
//
// For images: lazy-loaded CachedNetworkImage at the configured size.
// For videos: the Cloudinary-generated `thumbnail_url` (with `url`
// as fallback for videos uploaded before that field existed) and a
// centered play badge overlay. Tapping opens FullscreenVideoPlayer
// in a modal route — we deliberately do NOT instantiate
// VideoPlayerController here because feeds with N posts × M items
// would be a memory disaster otherwise.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

import '../dashboard/full_screen_video_player.dart';

const _kViolet = Color(0xFF7C3AED);

class MediaItemView extends StatelessWidget {
  /// One item from `post['media']`:
  ///   {url, thumbnail_url, media_type, order, id}
  final Map<String, dynamic> item;

  /// Sized by the parent — typically matches the carousel height.
  final double  height;
  final double? width;
  final BoxFit  fit;

  /// Set false to disable tap-to-open (e.g. inside a static preview).
  final bool playable;

  const MediaItemView({
    super.key,
    required this.item,
    this.height   = 300,
    this.width,
    this.fit      = BoxFit.cover,
    this.playable = true,
  });

  bool   get _isVideo  => item['media_type'] == 'video';

  /// Image to render. For videos, prefer the auto-generated thumbnail
  /// but fall back to `url` so older uploads (no thumbnail) still render
  /// something instead of a grey square.
  String get _heroUrl  {
    if (_isVideo) {
      final t = (item['thumbnail_url'] ?? '').toString();
      if (t.isNotEmpty) return t;
    }
    return (item['url'] ?? '').toString();
  }

  String get _videoUrl => (item['url'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl:    _heroUrl,
      height:      height,
      width:       width ?? double.infinity,
      fit:         fit,
      placeholder: (_, __) => Container(
        height: height,
        color: const Color(0xFFF0F0F5),
        child: const Center(child: CircularProgressIndicator(
            color: _kViolet, strokeWidth: 2))),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: const Color(0xFFF0F0F5),
        child: Center(child: Icon(
            _isVideo ? Icons.videocam_off_outlined : Icons.image_outlined,
            size: 48, color: AppC.border))),
    );

    if (!_isVideo) return image;

    return GestureDetector(
      onTap: playable ? () {
        if (_videoUrl.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => FullscreenVideoPlayer(url: _videoUrl),
          ),
        );
      } : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          image,
          // Subtle dim so the play badge stays readable on bright frames.
          IgnorePointer(child: Container(
            height: height,
            color: Colors.black.withOpacity(0.18),
          )),
          // Play badge — centered, soft drop shadow.
          IgnorePointer(child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 44),
          )),
        ],
      ),
    );
  }
}