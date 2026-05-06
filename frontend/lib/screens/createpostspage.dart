// lib/screens/create_post_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

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

const _kMaxImages  = 5;

// ── Size limits (must match backend settings) ──────────────────
// These are enforced client-side for instant feedback before
// the file even leaves the device.
const _kMaxImageMb  = 8;    // MAX_IMAGE_MB in settings/base.py
const _kMaxImageBytes = _kMaxImageMb * 1024 * 1024;  // 8 388 608

const _kAllowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];

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

  final List<File> _images       = [];
  String     _visibility   = 'Public';
  bool       _isPosting    = false;
  bool       _altText      = false;
  String?    _feeling;
  String?    _tag;
  int        _previewPage  = 0;
  int        _uploadProgress = 0;

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

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _captionCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
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

  // ── Toast system ──────────────────────────────────────────
  // Three toast types: error (red), warning (amber), success (green).
  // Each shows an icon, a title, and a body message.

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

  // Legacy single-message snack (kept for non-critical notices)
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kG4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Image picking ─────────────────────────────────────────

  Future<void> _pickImages() async {
    final remaining = _kMaxImages - _images.length;
    if (remaining <= 0) {
      _toast(
        title:   'Photo limit reached',
        message: 'You can add up to $_kMaxImages photos per post. '
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

    final List<File> valid   = [];
    final List<String> errors = [];

    for (final x in picked.take(remaining)) {
      final file = File(x.path);
      final err  = _validateImageFile(file);
      if (err != null) {
        errors.add('• ${file.uri.pathSegments.last}: $err');
      } else {
        valid.add(file);
      }
    }

    if (valid.isNotEmpty) {
      setState(() { _images.addAll(valid); _previewPage = 0; });
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
        message: 'You only had room for $remaining more photo'
                 '${remaining == 1 ? '' : 's'}. '
                 'The rest weren\'t added.',
        type: _ToastType.warning,
      );
    }
  }

  Future<void> _pickCamera() async {
    if (_images.length >= _kMaxImages) {
      _toast(
        title:   'Photo limit reached',
        message: 'You can add up to $_kMaxImages photos per post. '
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

    setState(() => _images.insert(0, file));
  }

  void _removeImage(int i) {
    setState(() {
      _images.removeAt(i);
      if (_previewPage >= _images.length && _previewPage > 0) {
        _previewPage = _images.length - 1;
      }
    });
  }

  // ── Post to backend ───────────────────────────────────────

  Future<void> _post() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _images.isEmpty) {
      _toast(
        title:   'Nothing to post',
        message: 'Write a caption or add at least one photo before posting.',
        type:    _ToastType.warning,
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() { _isPosting = true; _uploadProgress = 0; });

    try {
      // Step 1 — create the text post
      final created = await _api.createPost(
        content:    caption,
        postType:   'post',
        visibility: _visibility.toLowerCase(),
        location:   _locationCtrl.text.trim(),
      ) as Map<String, dynamic>;

      final postId = created['id']?.toString() ?? '';

      // Step 2 — upload each image one by one
      final List<Map<String, dynamic>> mediaResults = [];
      for (int i = 0; i < _images.length; i++) {
        setState(() => _uploadProgress = i + 1);
        try {
          final res = await _api.uploadPostMedia(postId, _images[i])
              as Map<String, dynamic>;
          mediaResults.add(res);
        } catch (e) {
          // Surface the server error message if it's a size/type rejection
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
        'images':     _images,
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

  bool get _hasContent =>
      _captionCtrl.text.trim().isNotEmpty || _images.isNotEmpty;

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
              _buildImageSection(),
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
        if (_images.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _kG2.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${_images.length}/$_kMaxImages photos',
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

  // ── Image section ─────────────────────────────────────────

  Widget _buildImageSection() {
    if (_images.isEmpty) {
      return GestureDetector(
        onTap: _showMediaPicker,
        child: Container(
          margin: const EdgeInsets.all(16),
          height: 220,
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
            const Text('Add Photos', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
            const SizedBox(height: 6),
            Text('Up to $_kMaxImages photos · max $_kMaxImageMb MB each',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _MediaBtn(icon: Icons.photo_library_rounded,
                  label: 'Gallery', onTap: _pickImages),
              const SizedBox(width: 12),
              _MediaBtn(icon: Icons.camera_alt_rounded,
                  label: 'Camera', onTap: _pickCamera),
            ]),
          ]),
        ),
      );
    }

    final hasMultiple = _images.length > 1;
    return Column(children: [

      // Carousel preview
      Stack(children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: _images.length,
            onPageChanged: (p) => setState(() => _previewPage = p),
            itemBuilder: (_, i) => Stack(children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                      image: FileImage(_images[i]), fit: BoxFit.cover))),
              Positioned(top: 10, right: 24,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16)))),
              // File size badge
              Positioned(bottom: 10, left: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _formatBytes(_images[i].lengthSync()),
                    style: const TextStyle(fontFamily: 'Momo',
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)))),
            ]),
          ),
        ),
        if (hasMultiple)
          Positioned(top: 10, left: 26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${_previewPage + 1} / ${_images.length}',
                  style: const TextStyle(color: Colors.white,
                      fontFamily: 'Momo', fontSize: 11,
                      fontWeight: FontWeight.bold)))),
        if (hasMultiple)
          Positioned(bottom: 10, left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (i) {
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
            _images.length > 4 ? 4 : _images.length,
            (i) => GestureDetector(
              onTap: () => setState(() => _previewPage = i),
              child: Container(
                width: 48, height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _previewPage == i ? _kG2 : Colors.transparent,
                    width: 2),
                  image: DecorationImage(
                      image: FileImage(_images[i]), fit: BoxFit.cover))))),
          if (_images.length < _kMaxImages)
            GestureDetector(
              onTap: _pickImages,
              child: Container(width: 48, height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _kG2.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kG2.withOpacity(0.3), width: 1.5)),
                child: Icon(Icons.add_rounded, color: _kG2, size: 22))),
          const Spacer(),
          Text('${_images.length}/$_kMaxImages',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: _images.length == _kMaxImages
                  ? _kG4 : Colors.grey.shade400,
              fontWeight: _images.length == _kMaxImages
                  ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    ]);
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
          const Text('Add to your post', style: TextStyle(
              fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
          const SizedBox(height: 6),
          Text(
            'Up to $_kMaxImages photos · max $_kMaxImageMb MB each · '
            'JPG, PNG, WebP or GIF',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: Colors.grey.shade400)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _BigMediaBtn(
              icon: Icons.photo_library_rounded, label: 'Gallery', color: _kG2,
              onTap: () { Navigator.pop(context); _pickImages(); })),
            const SizedBox(width: 14),
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
        _DetailRow(icon: Icons.location_on_rounded, color: _kG4,
          child: TextField(
            controller: _locationCtrl,
            style: const TextStyle(fontFamily: 'Momo',
                fontSize: 14, color: _kInk),
            decoration: InputDecoration(
              hintText: 'Add location',
              hintStyle: TextStyle(fontFamily: 'Momo',
                  color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16)))),
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
        Divider(height: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.accessibility_new_rounded, color: _kG1, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('Add alt text', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
              Text('Make your post accessible to everyone',
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: Colors.grey.shade400)),
            ])),
            Switch(
              value:              _altText,
              onChanged:          (v) => setState(() => _altText = v),
              activeThumbColor:        Colors.white,
              activeTrackColor:   _kG1,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade300),
          ])),
      ]),
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
    if (_isPosting && _images.isNotEmpty) {
      barLabel = 'Uploading photo $_uploadProgress of ${_images.length}...';
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5)),
      child: Column(children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 14, color: color)),
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