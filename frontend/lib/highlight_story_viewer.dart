// lib/screens/highlights/highlight_story_viewer.dart
//
// HighlightStoryViewer — a full-screen, Instagram / WhatsApp-style story
// player for campus highlights.
//
// ── Usage ───────────────────────────────────────────────────
//   Navigator.of(context).push(MaterialPageRoute(
//     builder: (_) => HighlightStoryViewer(
//       stories: stories,           // List<HighlightStory>
//       initialIndex: 0,
//       highlightTitle: 'First day vibes',  // optional fallback
//     ),
//   ));
//
// ── Gestures ────────────────────────────────────────────────
//   • tap right 2/3   → next story
//   • tap left  1/3   → previous story
//   • press & hold    → pause
//   • swipe down      → close
//
// ── This revision ───────────────────────────────────────────
//   • The title is no longer rendered at the top of the viewer. It
//     now appears as a pill at the BOTTOM-LEFT of the screen, sitting
//     above the caption (if any). Each HighlightStory can carry its
//     own `title` so a grouped feed (multiple highlights from one
//     poster) can show the parent highlight title that the current
//     story belongs to. `widget.highlightTitle` is kept as a fallback
//     for callers that pass a single shared title.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:video_player/video_player.dart';

// ── Theme tokens (match the rest of the TCS app) ─────────────
const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);

// ═════════════════════════════════════════════════════════════
// MODEL
// ═════════════════════════════════════════════════════════════

enum HighlightMediaType { image, video }

class HighlightStory {
  final String id;
  final String mediaUrl;
  final HighlightMediaType mediaType;
  final String? caption;

  /// Title of the parent highlight this story belongs to. Used when
  /// multiple highlights from one poster are flattened into a single
  /// viewer session — each story carries the title of the highlight
  /// it came from so the bottom-left label can switch as the user
  /// taps through.
  final String? title;

  final String? authorName;
  final String? authorAvatarUrl;
  final DateTime? createdAt;

  /// How long an image stays on screen. Videos ignore this and advance
  /// when playback finishes.
  final Duration imageDuration;

  const HighlightStory({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.title,
    this.authorName,
    this.authorAvatarUrl,
    this.createdAt,
    this.imageDuration = const Duration(seconds: 5),
  });

  bool get isVideo => mediaType == HighlightMediaType.video;

  /// Maps a backend JSON object to a HighlightStory. Adjust the keys
  /// here to match whatever your Django highlights endpoint returns.
  factory HighlightStory.fromJson(Map<String, dynamic> j) {
    final type = (j['media_type'] as String? ?? 'image').toLowerCase();
    final rawCaption = (j['caption'] as String?)?.trim();
    final rawTitle   = (j['title'] as String?)?.trim();
    return HighlightStory(
      id:        j['id']?.toString() ?? '',
      mediaUrl:  (j['media_url'] ?? j['url'] ?? '').toString(),
      mediaType: type == 'video'
          ? HighlightMediaType.video
          : HighlightMediaType.image,
      caption:   (rawCaption == null || rawCaption.isEmpty) ? null : rawCaption,
      title:     (rawTitle   == null || rawTitle.isEmpty)   ? null : rawTitle,
      authorName:      j['author_name']   as String?,
      authorAvatarUrl: j['author_avatar'] as String?,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// VIEWER
// ═════════════════════════════════════════════════════════════

class HighlightStoryViewer extends StatefulWidget {
  final List<HighlightStory> stories;
  final int initialIndex;

  /// Fallback title used when a story doesn't carry its own. The title
  /// renders as a pill at the bottom-left of the viewer.
  final String? highlightTitle;

  const HighlightStoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.highlightTitle,
  });

  @override
  State<HighlightStoryViewer> createState() => _HighlightStoryViewerState();
}

class _HighlightStoryViewerState extends State<HighlightStoryViewer>
    with SingleTickerProviderStateMixin {
  // Drives the progress bar for the CURRENT story (0 -> 1). For images
  // its duration is the image's display time; for videos it's matched
  // to the clip length so the bar tracks playback.
  late final AnimationController _progressCtrl;

  late int _index;
  VideoPlayerController? _videoCtrl;
  bool _loading = false;
  bool _paused  = false;

  // Bumped on every _loadStory call so a slow async load from a story
  // the user has already skipped past can't apply its side effects.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.stories.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.stories.length - 1);

    _progressCtrl = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Defer so we're not mutating the controller inside its own
          // status callback.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _next();
          });
        }
      });

    // Defer first load until we have a context for precacheImage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.stories.isNotEmpty) _loadStory(_index);
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ── Loading ───────────────────────────────────────────────

  Future<void> _loadStory(int i) async {
    final token = ++_loadToken;

    _progressCtrl.stop();
    _progressCtrl.value = 0; // avoids the new segment flashing full
    await _videoCtrl?.pause();
    _videoCtrl?.dispose();
    _videoCtrl = null;

    final story = widget.stories[i];
    setState(() {
      _loading = true;
      _paused  = false;
    });

    try {
      if (story.isVideo) {
        final c = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
        await c.initialize();
        if (!mounted || token != _loadToken) {
          c.dispose();
          return;
        }
        _videoCtrl = c;
        c.setLooping(false);
        _progressCtrl.duration = c.value.duration == Duration.zero
            ? const Duration(seconds: 5)
            : c.value.duration;
        setState(() => _loading = false);
        await c.play();
        _progressCtrl.forward(from: 0);
      } else {
        await precacheImage(
          CachedNetworkImageProvider(story.mediaUrl),
          context,
        );
        if (!mounted || token != _loadToken) return;
        _progressCtrl.duration = story.imageDuration;
        setState(() => _loading = false);
        _progressCtrl.forward(from: 0);
      }
    } catch (_) {
      // Couldn't load this story's media — skip past it after a beat so
      // the viewer never gets stuck on a broken item.
      if (!mounted || token != _loadToken) return;
      setState(() => _loading = false);
      _progressCtrl
        ..duration = const Duration(milliseconds: 1200)
        ..forward(from: 0);
    }
  }

  // ── Navigation ────────────────────────────────────────────

  void _next() {
    if (_index < widget.stories.length - 1) {
      HapticFeedback.selectionClick();
      setState(() => _index++);
      _loadStory(_index);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_index > 0) {
      HapticFeedback.selectionClick();
      setState(() => _index--);
      _loadStory(_index);
    } else {
      _loadStory(_index); // already on the first story — restart it
    }
  }

  void _pause() {
    if (_paused) return;
    setState(() => _paused = true);
    _progressCtrl.stop();
    _videoCtrl?.pause();
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _progressCtrl.forward();
    if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
      _videoCtrl!.play();
    }
  }

  void _onTapUp(TapUpDetails d) {
    final w = MediaQuery.of(context).size.width;
    if (d.localPosition.dx < w / 3) {
      _prev();
    } else {
      _next();
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No highlights to show',
              style: TextStyle(fontFamily: 'Momo', color: Colors.white70)),
        ),
      );
    }

    final story = widget.stories[_index];
    final title = (story.title ?? widget.highlightTitle ?? '').trim();
    final caption = (story.caption ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _onTapUp,
        onLongPressStart: (_) => _pause(),
        onLongPressEnd:   (_) => _resume(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 250) Navigator.of(context).maybePop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Media ──
            _buildMedia(story),

            // ── Top scrim so the progress bars + header stay legible ──
            Positioned(
              top: 0, left: 0, right: 0, height: 170,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Progress segments + header (title is NOT here anymore) ──
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProgressBars(),
                    const SizedBox(height: 12),
                    _buildHeader(story),
                  ],
                ),
              ),
            ),

            // ── Bottom-left title + caption overlay ──
            // The title pill sits at the bottom-left of the viewer (above
            // the caption, if any). It updates per story so a grouped
            // viewing session shows the right parent highlight title for
            // whichever story is currently on screen.
            if (title.isNotEmpty || caption.isNotEmpty)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _buildBottomTextOverlay(title: title, caption: caption),
              ),

            // ── Paused hint ──
            if (_paused)
              const Center(
                child: Icon(Icons.pause_rounded,
                    color: Colors.white70, size: 56),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(HighlightStory story) {
    if (_loading) {
      return const Center(
        child: SpinKitFadingCircle(color: Colors.white, size: 36),
      );
    }

    if (story.isVideo) {
      final c = _videoCtrl;
      if (c == null || !c.value.isInitialized) {
        return const Center(
          child: SpinKitFadingCircle(color: Colors.white, size: 36),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: story.mediaUrl,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: SpinKitFadingCircle(color: Colors.white, size: 36),
      ),
      errorWidget: (_, __, ___) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white38, size: 44),
            SizedBox(height: 8),
            Text("Couldn't load this highlight",
                style: TextStyle(fontFamily: 'Momo',
                    color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars() {
    return Row(
      children: List.generate(widget.stories.length, (i) {
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              borderRadius: BorderRadius.circular(2),
            ),
            child: i < _index
                // already watched — full
                ? _segmentFill(1.0)
                : i > _index
                    // not reached — empty
                    ? const SizedBox.shrink()
                    // current — animated
                    : AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (_, __) => _segmentFill(_progressCtrl.value),
                      ),
          ),
        );
      }),
    );
  }

  Widget _segmentFill(double fraction) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kG1, _kG2]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(HighlightStory story) {
    final name    = (story.authorName ?? '').trim();
    final avatar  = (story.authorAvatarUrl ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_kG1, _kG2]),
          ),
          child: ClipOval(
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    fit: BoxFit.cover,
                    width: 38, height: 38,
                    errorWidget: (_, __, ___) => _avatarFallback(initial),
                  )
                : _avatarFallback(initial),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'Highlight' : name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14, color: Colors.white,
                ),
              ),
              if (story.createdAt != null)
                Text(
                  _ago(story.createdAt!),
                  style: TextStyle(
                    fontFamily: 'Momo', fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String initial) => Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white, fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 16,
          ),
        ),
      );

  Widget _buildBottomTextOverlay({
    required String title,
    required String caption,
  }) {
    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          // Pull-up gradient height — gives the text room to breathe over
          // dark photos without obscuring the whole frame.
          caption.isNotEmpty ? 90 : 60,
          16,
          MediaQuery.of(context).padding.bottom + 22,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.72),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty) ...[
              // Bottom-left title pill — distinct from the caption so the
              // poster-defined highlight name reads as a label, not body.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Alfa',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (caption.isNotEmpty) const SizedBox(height: 12),
            ],
            if (caption.isNotEmpty)
              Text(
                caption,
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.isNegative)     return 'Just now';
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours   < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}