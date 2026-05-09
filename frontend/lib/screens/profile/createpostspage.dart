// lib/screens/create_post_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_service.dart';
import '../../widgets/location_picker.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);
const _kGradient = LinearGradient(
  colors: [_kG1, _kG2, _kG3, _kG4],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Caps (must match backend) ──────────────────────────────────
// Backend enforces these too. Client-side checks are for instant
// feedback before the file leaves the device.
const _kMaxMedia      = 5;   // total photos + videos per post
const _kMaxVideos     = 1;   // at most one video per post
const _kMaxImageMb    = 8;   // MAX_IMAGE_MB in settings/base.py
const _kMaxImageBytes = _kMaxImageMb * 1024 * 1024;
const _kMaxVideoMb    = 50;  // MAX_VIDEO_MB in settings/base.py
const _kMaxVideoBytes = _kMaxVideoMb * 1024 * 1024;

const _kAllowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
const _kAllowedVideoExtensions = ['mp4', 'mov', 'webm'];

// ── Campus quick picks for the LocationPicker ─────────────────
const _kCampusLocations = [
  'Taylors College', 'Library', 'Cafeteria', 'Sports Hall',
  'Lecture Hall A', 'Lecture Hall B', 'Study Hub', 'Auditorium',
  'Student Lounge', 'Science Lab',
];


class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with TickerProviderStateMixin {
  final _api          = ApiService();
  final _captionCtrl  = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker       = ImagePicker();

  // Mixed list of photos and videos. Each item knows its type and,
  // for videos, owns its own VideoPlayerController for the preview.
  final List<_MediaItem> _media = [];

  String  _visibility      = 'Public';
  bool    _isPosting       = false;
  bool    _altText         = false;
  bool    _pickingLocation = false;     // NEW — drives the location row spinner
  String? _feeling;
  String? _tag;
  int     _previewPage     = 0;
  int     _uploadProgress  = 0;
  String  _uploadingLabel  = 'photo';   // 'photo' | 'video' for progress text

  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;

  final _feelings = [
    '😊 Happy', '📚 Studying', '🎮 Gaming', '🏃 Active',
    '😴 Tired', '🎉 Excited', '🤔 Thinking', '💪 Motivated',
  ];
  final _tags = [
    '#CampusLife', '#StudyVibes', '#TaylorsPride',
    '#TCSKL', '#ArcadeTime', '#StudyGroup', '#WeekendVibes',
  ];

  // ── Computed counts ───────────────────────────────────────

  int  get _videoCount   => _media.where((m) => m.isVideo).length;
  bool get _canAddMedia  => _media.length < _kMaxMedia;
  bool get _canAddVideo  => _canAddMedia && _videoCount < _kMaxVideos;
  bool get _hasContent   =>
      _captionCtrl.text.trim().isNotEmpty || _media.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _captionCtrl.addListener(() => setState(() {}));
    _locationCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // Tear down every video controller before disposing controllers.
    for (final m in _media) {
      m.dispose();
    }
    _entryCtrl.dispose();
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Size / format helpers ─────────────────────────────────

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Returns null if the file is valid, or an error message if not.
  String? _validateImageFile(File file) {
    final sizeBytes = file.lengthSync();
    if (sizeBytes > _kMaxImageBytes) {
      return 'That photo is ${_formatBytes(sizeBytes)}, which is over the '
          '$_kMaxImageMb MB limit. Try a lower-resolution shot or trim it in '
          'your gallery first.';
    }
    final ext = file.path.split('.').last.toLowerCase();
    if (!_kAllowedImageExtensions.contains(ext)) {
      return 'That file type (.$ext) isn\'t supported. '
          'Please use a JPG, PNG, WebP, or GIF.';
    }
    return null;
  }

  String? _validateVideoFile(File file) {
    final sizeBytes = file.lengthSync();
    if (sizeBytes > _kMaxVideoBytes) {
      return 'That video is ${_formatBytes(sizeBytes)}, which is over the '
          '$_kMaxVideoMb MB limit. Trim it or compress it first.';
    }
    final ext = file.path.split('.').last.toLowerCase();
    if (!_kAllowedVideoExtensions.contains(ext)) {
      return 'That video format (.$ext) isn\'t supported. '
          'Please use MP4, MOV, or WebM.';
    }
    return null;
  }

  // ── Toast system ──────────────────────────────────────────
  // Three toast types: error (red), warning (amber), success (green).

  void _toast({
    required String title,
    required String message,
    _ToastType type = _ToastType.error,
  }) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    final Color bg;
    final Color fg;
    final IconData icon;

    switch (type) {
      case _ToastType.error:
        bg   = const Color(0xFFFF3B3B);
        fg   = Colors.white;
        icon = Icons.error_outline_rounded;
        break;
      case _ToastType.warning:
        bg   = const Color(0xFFF59E0B);
        fg   = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case _ToastType.success:
        bg   = const Color(0xFF10B981);
        fg   = Colors.white;
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior:        SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation:       0,
        margin:          const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration:        const Duration(seconds: 5),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: bg.withOpacity(0.4),
                  blurRadius: 20, offset: const Offset(0, 8)),
            ]),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 14, color: fg)),
                const SizedBox(height: 3),
                Text(message, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: fg.withOpacity(0.9), height: 1.4)),
              ])),
          ]),
        ),
      ));
  }

  // ── Image picking ─────────────────────────────────────────

  Future<void> _pickImages() async {
    final remaining = _kMaxMedia - _media.length;
    if (remaining <= 0) {
      _toast(
        title:   'Limit reached',
        message: 'You can attach up to $_kMaxMedia items per post. '
                 'Remove one to swap it out.',
        type:    _ToastType.warning,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth:     1080,
      maxHeight:    1080,
    );
    if (picked.isEmpty) return;

    final List<_MediaItem> valid  = [];
    final List<String>     errors = [];

    for (final x in picked.take(remaining)) {
      final file = File(x.path);
      final err  = _validateImageFile(file);
      if (err != null) {
        errors.add('• ${file.uri.pathSegments.last}: $err');
      } else {
        valid.add(_MediaItem.image(file));
      }
    }

    if (valid.isNotEmpty) {
      setState(() {
        _media.addAll(valid);
        _previewPage = 0;
      });
    }

    if (errors.isNotEmpty) {
      _toast(
        title:   errors.length == 1
            ? 'One photo couldn\'t be added'
            : '${errors.length} photos couldn\'t be added',
        message: errors.length == 1
            ? errors.first.replaceFirst('• ', '')
            : errors.join('\n'),
        type: _ToastType.error,
      );
    }

    if (picked.length > remaining) {
      _toast(
        title:   'Some photos skipped',
        message: 'You only had room for $remaining more item'
                 '${remaining == 1 ? '' : 's'}. '
                 'The rest weren\'t added.',
        type: _ToastType.warning,
      );
    }
  }

  Future<void> _pickCamera() async {
    if (!_canAddMedia) {
      _toast(
        title:   'Limit reached',
        message: 'You can attach up to $_kMaxMedia items per post. '
                 'Remove one to swap it out.',
        type:    _ToastType.warning,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final picked = await _picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 85,
      maxWidth:     1080,
      maxHeight:    1080,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final err  = _validateImageFile(file);
    if (err != null) {
      _toast(title: 'Photo too large', message: err, type: _ToastType.error);
      return;
    }

    setState(() => _media.insert(0, _MediaItem.image(file)));
  }

  // ── Video picking ─────────────────────────────────────────

  Future<void> _pickVideo() async {
    // Cap checks happen in this order so the user gets the most
    // specific message: video cap → total cap → pick.
    if (_videoCount >= _kMaxVideos) {
      _toast(
        title:   'Video limit reached',
        message: 'Only $_kMaxVideos video per post. '
                 'Remove the existing one first.',
        type:    _ToastType.warning,
      );
      return;
    }
    if (!_canAddMedia) {
      _toast(
        title:   'Limit reached',
        message: 'You\'re at $_kMaxMedia items. Remove a photo to make room '
                 'for the video.',
        type:    _ToastType.warning,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final picked = await _picker.pickVideo(
      source:      ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;

    final file = File(picked.path);
    final err  = _validateVideoFile(file);
    if (err != null) {
      _toast(title: 'Video can\'t be added', message: err, type: _ToastType.error);
      return;
    }

    final item = _MediaItem.video(file);
    setState(() {
      _media.add(item);
      _previewPage = _media.length - 1;
    });

    // VideoPlayerController.initialize() is async — show the spinner
    // placeholder until it resolves, then re-render to swap in the
    // actual VideoPlayer widget.
    try {
      await item.initController();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      _toast(
        title:   'Couldn\'t load video preview',
        message: 'You can still post it — the preview just won\'t play here.',
        type:    _ToastType.warning,
      );
    }
  }

  void _removeMedia(int i) {
    setState(() {
      final removed = _media.removeAt(i);
      removed.dispose();
      if (_previewPage >= _media.length && _previewPage > 0) {
        _previewPage = _media.length - 1;
      }
    });
  }

  // ── Location picker entry point ──────────────────────────

  Future<void> _openLocationPicker() async {
    if (_pickingLocation) return;
    HapticFeedback.lightImpact();
    setState(() => _pickingLocation = true);

    final result = await LocationPicker.show(
      context,
      quickPicks:   _kCampusLocations,
      initialQuery: _locationCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _pickingLocation = false;
      if (result != null) _locationCtrl.text = result.name;
    });
  }

  // ── Post to backend ───────────────────────────────────────

  Future<void> _post() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _media.isEmpty) {
      _toast(
        title:   'Nothing to post',
        message: 'Write a caption or add at least one photo or video first.',
        type:    _ToastType.warning,
      );
      return;
    }

    HapticFeedback.heavyImpact();

    // Pause any playing video so it doesn't keep playing during upload.
    for (final m in _media) {
      m.videoController?.pause();
    }

    setState(() {
      _isPosting      = true;
      _uploadProgress = 0;
      _uploadingLabel = 'photo';
    });

    try {
      // Step 1 — create the text post
      final created = await _api.createPost(
        content:    caption,
        postType:   'post',
        visibility: _visibility.toLowerCase(),
        location:   _locationCtrl.text.trim(),
      ) as Map<String, dynamic>;

      final postId = created['id']?.toString() ?? '';

      // Step 2 — upload each media item, passing the type so the
      // backend routes images through CloudinaryField and videos
      // through cloudinary.uploader.upload(resource_type='video').
      final List<Map<String, dynamic>> mediaResults = [];
      for (int i = 0; i < _media.length; i++) {
        final item = _media[i];
        setState(() {
          _uploadProgress = i + 1;
          _uploadingLabel = item.isVideo ? 'video' : 'photo';
        });
        try {
          final res = await _api.uploadPostMedia(
            postId,
            item.file,
            mediaType: item.isVideo ? 'video' : 'image',
          ) as Map<String, dynamic>;
          mediaResults.add(res);
        } catch (e) {
          // Surface server-side rejections (size / format) to the user
          final msg = e.toString();
          if (msg.contains('MB') || msg.contains('format')) {
            _toast(
              title:   'Upload rejected',
              message: msg,
              type:    _ToastType.error,
            );
          }
          // Continue uploading the rest regardless
        }
      }

      final postWithMedia = {...created, 'media': mediaResults};

      if (!mounted) return;
      Navigator.pop(context, {
        'caption':    caption,
        'media':      _media,                 // was 'images'
        'visibility': _visibility,
        'location':   _locationCtrl.text.trim(),
        'feeling':    _feeling,
        'tag':        _tag,
        'post':       postWithMedia,
      });
    } catch (e) {
      setState(() => _isPosting = false);
      _toast(
        title:   'Post failed',
        message: 'Something went wrong. Check your connection and try again.',
        type:    _ToastType.error,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          _buildHeader(),
          Expanded(child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildMediaSection(),
              _buildCaptionArea(),
              _buildTagsRow(),
              _buildDetailsSection(),
              const SizedBox(height: 100),
            ]),
          )),
          _buildPostBar(),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8, right: 16, bottom: 14),
      decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))]),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.close_rounded, color: _kInk, size: 20))),
        const SizedBox(width: 12),
        const Text('Create Post', style: TextStyle(
            fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
        const Spacer(),
        if (_media.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _kG2.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${_media.length}/$_kMaxMedia',
                style: const TextStyle(fontFamily: 'Momo', fontSize: 11,
                    fontWeight: FontWeight.bold, color: _kG2))),
        GestureDetector(
          onTap: _pickVisibility,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: _kG2.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kG2.withOpacity(0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_visibilityIcon, color: _kG2, size: 14),
              const SizedBox(width: 5),
              Text(_visibility, style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 12, color: _kG2)),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _kG2, size: 14),
            ]))),
      ]),
    );
  }

  IconData get _visibilityIcon => _visibility == 'Public'
      ? Icons.public_rounded
      : _visibility == 'Followers' ? Icons.people_rounded : Icons.lock_rounded;

  void _pickVisibility() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Who can see this post?',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
          const SizedBox(height: 16),
          ...[
            ('Public',    Icons.public_rounded,  'Everyone on TCS'),
            ('Followers', Icons.people_rounded,  'Only your followers'),
            ('Private',   Icons.lock_rounded,    'Only you'),
          ].map((opt) => GestureDetector(
            onTap: () {
              setState(() => _visibility = opt.$1);
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _visibility == opt.$1
                    ? _kG2.withOpacity(0.08) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _visibility == opt.$1
                      ? _kG2.withOpacity(0.3) : Colors.grey.shade200,
                  width: _visibility == opt.$1 ? 1.5 : 1)),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_visibility == opt.$1
                            ? _kG2 : Colors.grey.shade300)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(opt.$2,
                      color: _visibility == opt.$1
                          ? _kG2 : Colors.grey.shade500, size: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(opt.$1, style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: _visibility == opt.$1 ? _kG2 : _kInk)),
                  Text(opt.$3, style: TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: Colors.grey.shade500)),
                ]),
                const Spacer(),
                if (_visibility == opt.$1)
                  Icon(Icons.check_circle_rounded, color: _kG2, size: 20),
              ]))),
          )]),
        ),
      );
  }

  // ── Media section (carousel + thumbnails) ─────────────────

  Widget _buildMediaSection() {
    if (_media.isEmpty) {
      return GestureDetector(
        onTap: _showMediaPicker,
        child: Container(
          margin: const EdgeInsets.all(16),
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 10, offset: const Offset(0, 3))]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ShaderMask(
              shaderCallback: (b) => _kGradient.createShader(b),
              blendMode: BlendMode.srcIn,
              child: const Icon(Icons.add_photo_alternate_rounded, size: 52)),
            const SizedBox(height: 14),
            const Text('Add Media', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
            const SizedBox(height: 6),
            Text('Up to $_kMaxMedia items · $_kMaxImageMb MB photos · '
                 '$_kMaxVideoMb MB video',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _MediaBtn(icon: Icons.photo_library_rounded,
                  label: 'Gallery', onTap: _pickImages),
              const SizedBox(width: 10),
              _MediaBtn(icon: Icons.videocam_rounded,
                  label: 'Video', onTap: _pickVideo),
              const SizedBox(width: 10),
              _MediaBtn(icon: Icons.camera_alt_rounded,
                  label: 'Camera', onTap: _pickCamera),
            ]),
          ]),
        ),
      );
    }

    final hasMultiple = _media.length > 1;
    return Column(children: [

      // Carousel preview
      Stack(children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            itemCount: _media.length,
            onPageChanged: (p) {
              // Pause whatever's playing when the user swipes away.
              for (final m in _media) {
                m.videoController?.pause();
              }
              setState(() => _previewPage = p);
            },
            itemBuilder: (_, i) => _buildMediaPage(i),
          ),
        ),
        if (hasMultiple)
          Positioned(top: 10, left: 26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_previewPage + 1} / ${_media.length}',
                  style: const TextStyle(color: Colors.white,
                      fontFamily: 'Momo', fontSize: 11,
                      fontWeight: FontWeight.bold)))),
        if (hasMultiple)
          Positioned(bottom: 10, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_media.length, (i) {
                final active = i == _previewPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3)));
              }))),
      ]),

      // Thumbnail strip + add button
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          ...List.generate(
            _media.length > 4 ? 4 : _media.length,
            (i) {
              final item = _media[i];
              return GestureDetector(
                onTap: () => setState(() => _previewPage = i),
                child: Container(
                  width: 48, height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: item.isVideo ? Colors.black : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _previewPage == i ? _kG2 : Colors.transparent,
                      width: 2),
                    image: item.isVideo ? null : DecorationImage(
                        image: FileImage(item.file), fit: BoxFit.cover)),
                  child: item.isVideo
                      ? const Center(child: Icon(
                          Icons.play_circle_filled_rounded,
                          color: Colors.white, size: 24))
                      : null));
            }),
          if (_media.length < _kMaxMedia)
            GestureDetector(
              onTap: _showMediaPicker,
              child: Container(width: 48, height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _kG2.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kG2.withOpacity(0.3), width: 1.5)),
                child: Icon(Icons.add_rounded, color: _kG2, size: 22))),
          const Spacer(),
          Text('${_media.length}/$_kMaxMedia',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: _media.length == _kMaxMedia
                  ? _kG4 : Colors.grey.shade400,
              fontWeight: _media.length == _kMaxMedia
                  ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    ]);
  }

  /// One slide of the carousel — image or video.
  Widget _buildMediaPage(int i) {
    final item = _media[i];
    return Stack(children: [
      // Background — image (decoration) or video (custom widget).
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: item.isVideo ? Colors.black : null,
          borderRadius: BorderRadius.circular(20),
          image: item.isVideo ? null : DecorationImage(
              image: FileImage(item.file), fit: BoxFit.cover)),
        child: item.isVideo
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildVideoPlayer(item))
            : null,
      ),

      // Close button
      Positioned(top: 10, right: 24,
        child: GestureDetector(
          onTap: () => _removeMedia(i),
          child: Container(width: 30, height: 30,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 16)))),

      // VIDEO badge (top-left, only for videos)
      if (item.isVideo)
        Positioned(top: 10, left: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _kG4.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_rounded, color: Colors.white, size: 11),
              SizedBox(width: 4),
              Text('VIDEO', style: TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  color: Colors.white, fontSize: 10)),
            ]))),

      // Size + duration badge (bottom-left)
      Positioned(bottom: 10, left: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20)),
          child: Text(
            item.isVideo
                ? '${_formatDuration(item.videoController?.value.duration)} '
                  '· ${_formatBytes(item.file.lengthSync())}'
                : _formatBytes(item.file.lengthSync()),
            style: const TextStyle(fontFamily: 'Momo',
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.bold)))),
    ]);
  }

  /// Video preview that toggles play/pause on tap. Shows a spinner
  /// while the controller is initializing.
  Widget _buildVideoPlayer(_MediaItem item) {
    final ctrl = item.videoController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(child: SizedBox(
        width: 28, height: 28,
        child: CircularProgressIndicator(
            color: Colors.white, strokeWidth: 2.5),
      ));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          if (ctrl.value.isPlaying) {
            ctrl.pause();
          } else {
            ctrl.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          )),
          if (!ctrl.value.isPlaying)
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 40),
            ),
        ],
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Add to your post', style: TextStyle(
              fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
          const SizedBox(height: 6),
          Text(
            '$_kMaxMedia items per post · '
            '$_kMaxImageMb MB photos · '
            '$_kMaxVideoMb MB video',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: Colors.grey.shade400)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _BigMediaBtn(
              icon: Icons.photo_library_rounded, label: 'Gallery', color: _kG2,
              onTap: () { Navigator.pop(context); _pickImages(); })),
            const SizedBox(width: 10),
            Expanded(child: _BigMediaBtn(
              icon: Icons.videocam_rounded, label: 'Video', color: _kG1,
              onTap: () { Navigator.pop(context); _pickVideo(); })),
            const SizedBox(width: 10),
            Expanded(child: _BigMediaBtn(
              icon: Icons.camera_alt_rounded, label: 'Camera', color: _kG3,
              onTap: () { Navigator.pop(context); _pickCamera(); })),
          ]),
        ]),
      ),
    );
  }

  // ── Caption ───────────────────────────────────────────────

  Widget _buildCaptionArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kG1, _kG2],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.person_rounded,
                color: Colors.white, size: 22))),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _captionCtrl,
            maxLines: null,
            minLines: 3,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'Momo', fontSize: 15,
                color: _kInk, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Write a caption...',
              hintStyle: TextStyle(fontFamily: 'Momo',
                  color: Colors.grey.shade400, fontSize: 15),
              border: InputBorder.none))),
        ]),
        if (_feeling != null) ...[
          const SizedBox(height: 10),
          _PostChip(_feeling!, _kG2, () => setState(() => _feeling = null)),
        ],
        if (_tag != null) ...[
          const SizedBox(height: 6),
          _PostChip(_tag!, _kG3, () => setState(() => _tag = null)),
        ],
      ]),
    );
  }

  // ── Tags ──────────────────────────────────────────────────

  Widget _buildTagsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _tags.map((t) => GestureDetector(
          onTap: () => setState(() => _tag = _tag == t ? null : t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _tag == t ? _kG2.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _tag == t ? _kG2.withOpacity(0.4) : Colors.grey.shade200,
                width: 1.5)),
            child: Text(t, style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _tag == t ? _kG2 : Colors.grey.shade500))),
        )).toList()),
      ),
    );
  }

  // ── Details ───────────────────────────────────────────────

  Widget _buildDetailsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        // ── Location row — opens LocationPicker, shows spinner while open ──
        _buildLocationRow(),
        Divider(height: 1, color: Colors.grey.shade100),
        _DetailRow(icon: Icons.emoji_emotions_rounded, color: _kG3,
          child: GestureDetector(
            onTap: _pickFeeling,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                Text(_feeling ?? 'How are you feeling?',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                      color: _feeling != null
                          ? _kInk : Colors.grey.shade400)),
                const Spacer(),
                Icon(Icons.keyboard_arrow_right_rounded,
                    color: Colors.grey.shade300, size: 20),
              ])))),
        ]),
    );
  }

  /// Tappable location row. Opens LocationPicker on tap. Shows a
  /// SpinKitFadingCircle in place of the pin icon while the picker
  /// is on screen, then returns to the icon as soon as the user
  /// picks (or dismisses).
  Widget _buildLocationRow() {
    final hasLocation = _locationCtrl.text.trim().isNotEmpty;
    final label = _pickingLocation
        ? 'Picking…'
        : (hasLocation ? _locationCtrl.text.trim() : 'Add location');

    return GestureDetector(
      onTap: _openLocationPicker,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(children: [
          // Icon OR loading spinner — same footprint either way
          SizedBox(
            width: 20, height: 20,
            child: _pickingLocation
                ? const SpinKitFadingCircle(color: _kG4, size: 20)
                : const Icon(Icons.location_on_rounded,
                    color: _kG4, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 14,
                color: _pickingLocation || !hasLocation
                    ? Colors.grey.shade400 : _kInk,
              ),
            ),
          )),
          if (hasLocation && !_pickingLocation)
            GestureDetector(
              onTap: () => setState(() => _locationCtrl.clear()),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close_rounded,
                    size: 16, color: Colors.grey.shade400),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.keyboard_arrow_right_rounded,
                  color: Colors.grey.shade300, size: 20),
            ),
        ]),
      ),
    );
  }

  void _pickFeeling() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('How are you feeling?', style: TextStyle(
              fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10,
            children: _feelings.map((f) => GestureDetector(
              onTap: () {
                setState(() => _feeling = f);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _feeling == f
                      ? _kG2.withOpacity(0.12) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _feeling == f
                        ? _kG2.withOpacity(0.3) : Colors.grey.shade200)),
                child: Text(f, style: TextStyle(fontFamily: 'Momo',
                    fontWeight: FontWeight.w600, fontSize: 14,
                    color: _feeling == f ? _kG2 : _kInk))),
            )).toList()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Post bar ──────────────────────────────────────────────

  Widget _buildPostBar() {
    final String barLabel;
    if (_isPosting && _media.isNotEmpty) {
      barLabel = 'Uploading $_uploadingLabel '
                 '$_uploadProgress of ${_media.length}...';
    } else if (_captionCtrl.text.isNotEmpty) {
      barLabel = '${_captionCtrl.text.length} characters';
    } else {
      barLabel = '';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16,
          MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, -3))]),
      child: Row(children: [
        if (barLabel.isNotEmpty)
          Expanded(child: Text(barLabel,
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: Colors.grey.shade400)))
        else
          const Spacer(),
        GestureDetector(
          onTap: _hasContent && !_isPosting ? _post : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: _hasContent && !_isPosting
                  ? _kGradient
                  : const LinearGradient(
                      colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _hasContent && !_isPosting ? [BoxShadow(
                  color: _kG2.withOpacity(0.35),
                  blurRadius: 14, offset: const Offset(0, 4))] : []),
            child: _isPosting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Post', style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white, fontSize: 15)),
                  ]))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MEDIA ITEM — owns the file + (for video) a VideoPlayerController
// ─────────────────────────────────────────────────────────────

class _MediaItem {
  final File   file;
  final String type;                    // 'image' | 'video'
  VideoPlayerController? videoController;

  _MediaItem.image(this.file) : type = 'image';
  _MediaItem.video(this.file) : type = 'video';

  bool get isVideo => type == 'video';

  /// Lazy-init the VideoPlayerController once the user picks a video.
  /// Throws on init failure — caller decides how to surface that.
  Future<void> initController() async {
    if (!isVideo || videoController != null) return;
    final c = VideoPlayerController.file(file);
    videoController = c;
    await c.initialize();
    c.setLooping(false);
    c.setVolume(1.0);
  }

  void dispose() {
    videoController?.dispose();
    videoController = null;
  }
}

// ── Toast type ────────────────────────────────────────────────

enum _ToastType { error, warning, success }

// ── Helper widgets ────────────────────────────────────────────

class _MediaBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _MediaBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 13, color: Colors.grey.shade700)),
      ])));
}

class _BigMediaBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  final VoidCallback onTap;
  const _BigMediaBtn({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5)),
      child: Column(children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ])));
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final Color color; final Widget child;
  const _DetailRow({required this.icon, required this.color, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16, right: 8),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(child: child),
    ]));
}

class _PostChip extends StatelessWidget {
  final String label; final Color color; final VoidCallback onRemove;
  const _PostChip(this.label, this.color, this.onRemove);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 12,
          fontWeight: FontWeight.bold, color: color)),
      const SizedBox(width: 5),
      GestureDetector(
        onTap: onRemove,
        child: Icon(Icons.close_rounded, size: 13, color: color)),
    ]));
}