// lib/widgets/fullscreen_video_player.dart
//
// Modal fullscreen video player. Push as a fullscreenDialog from
// MediaItemView when the user taps a video thumbnail in any post
// card. One VideoPlayerController per route — created in initState,
// disposed in dispose, never leaks.
//
// Controls UX:
//   • Tap anywhere on the video → toggle controls overlay
//   • Tap the centered play badge → toggle play/pause
//   • Top-right speaker icon → toggle mute
//   • Top-left X → close (also pop on system back)
//   • Bottom slider → scrub
//
// Auto-plays as soon as the controller initializes. Doesn't loop —
// reaches the end and stops (user can tap to replay).

import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPlayer extends StatefulWidget {
  final String url;
  const FullscreenVideoPlayer({super.key, required this.url});

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  late final VideoPlayerController _ctrl;
  bool _showControls = true;
  bool _initFailed   = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(false);
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _ctrl.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _initFailed = true);
    });
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    // The controller fires for position/buffering/end. Drive a rebuild
    // so the scrubber and play badge stay in sync.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_ctrl.value.isPlaying) {
        _ctrl.pause();
      } else {
        // If the video reached the end, restart from 0 instead of
        // sitting at the last frame doing nothing.
        if (_ctrl.value.position >= _ctrl.value.duration) {
          _ctrl.seekTo(Duration.zero);
        }
        _ctrl.play();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _ctrl.setVolume(_ctrl.value.volume > 0 ? 0 : 1);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            children: [

              // ── Video / loading / error ──────────────────────
              Center(
                child: _initFailed
                    ? const T('Couldn\'t load video.',
                        style: TextStyle(color: Colors.white,
                            fontFamily: 'Momo', fontSize: 14))
                    : !_ctrl.value.isInitialized
                        ? const SizedBox(width: 40, height: 40,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : AspectRatio(
                            aspectRatio: _ctrl.value.aspectRatio,
                            child: VideoPlayer(_ctrl)),
              ),

              // ── Centered play badge (visible when paused) ───
              if (_ctrl.value.isInitialized
                  && !_ctrl.value.isPlaying
                  && _showControls)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 48),
                    ),
                  ),
                ),

              // ── Top bar: close + mute ───────────────────────
              if (_showControls)
                Positioned(top: 8, left: 8, right: 8,
                  child: Row(children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    if (_ctrl.value.isInitialized)
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Icon(
                          _ctrl.value.volume > 0
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white, size: 26,
                        ),
                      ),
                  ])),

              // ── Bottom bar: scrubber + timestamps ───────────
              if (_showControls && _ctrl.value.isInitialized)
                Positioned(left: 16, right: 16, bottom: 16,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight:        3,
                        thumbShape:         const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape:       const RoundSliderOverlayShape(
                            overlayRadius: 12),
                        activeTrackColor:   Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbColor:         Colors.white,
                        overlayColor:       Colors.white.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _ctrl.value.position.inMilliseconds
                            .clamp(0, _ctrl.value.duration.inMilliseconds)
                            .toDouble(),
                        min: 0,
                        max: _ctrl.value.duration.inMilliseconds
                            .toDouble().clamp(1, double.infinity),
                        onChanged: (v) {
                          _ctrl.seekTo(Duration(milliseconds: v.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Text(_fmt(_ctrl.value.position),
                            style: const TextStyle(color: Colors.white,
                                fontFamily: 'Momo', fontSize: 12)),
                        const Spacer(),
                        Text(_fmt(_ctrl.value.duration),
                            style: const TextStyle(color: Colors.white,
                                fontFamily: 'Momo', fontSize: 12)),
                      ]),
                    ),
                  ])),
            ],
          ),
        ),
      ),
    );
  }
}