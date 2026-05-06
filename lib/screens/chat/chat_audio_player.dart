// lib/widgets/chat/chat_audio_player.dart
//
// Audio playback widget — used inside chat bubbles for voice notes
// and any other audio messages.
//
// Hooks the `just_audio` package to a play/pause button + a scrubbable
// progress bar. Each instance manages its own player. If you want
// "only one plays at a time", the simplest approach is to listen to
// `playerState` events and pause others — out of scope for this
// widget; one player per visible bubble is fine for typical chat
// volume.
//
// Usage inside chat_room_screen's _mediaMessage:
//   if (msgType == 'audio') {
//     return ChatAudioPlayer(
//       url:      msg['media_url'] as String,
//       duration: (msg['duration'] as int?) ?? 0,
//       isMe:     isMe,
//     );
//   }
//
// Required package (add to pubspec.yaml — see pubspec_additions.md):
//   just_audio: ^0.9.40

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ChatAudioPlayer extends StatefulWidget {
  final String url;
  final int    duration;       // seconds, from msg.duration; can be 0
  final bool   isMe;            // tints colors against your message bubble

  const ChatAudioPlayer({
    super.key,
    required this.url,
    required this.duration,
    required this.isMe,
  });

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  late final AudioPlayer _player;
  bool _ready    = false;
  bool _failed   = false;
  Duration _position = Duration.zero;
  Duration _total    = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      final dur = await _player.setUrl(widget.url);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _total = dur ??
            Duration(seconds: widget.duration > 0 ? widget.duration : 0);
      });

      _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
      _player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          // Reset to start when finished
          _player.seek(Duration.zero);
          _player.pause();
          setState(() => _position = Duration.zero);
        } else {
          setState(() {});
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ready  = true;
        _failed = true;
        _total  = Duration(seconds: widget.duration);
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_failed || !_ready) return;
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMe   = widget.isMe;
    final fg     = isMe ? Colors.white : Colors.deepPurple.shade600;
    final track  = isMe
        ? Colors.white.withOpacity(0.30)
        : Colors.deepPurple.shade100;
    final fill   = isMe ? Colors.white : Colors.deepPurple.shade600;
    final isPlaying = _player.playing;
    final progress  = (_total.inMilliseconds == 0)
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    final remaining = _total - _position;
    final shownDur  = isPlaying || _position > Duration.zero
        ? remaining
        : (_total > Duration.zero
            ? _total
            : Duration(seconds: widget.duration));

    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play / pause
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe
                    ? Colors.white.withOpacity(0.20)
                    : Colors.deepPurple.shade50,
              ),
              child: _ready
                  ? Icon(
                      _failed
                          ? Icons.error_outline_rounded
                          : (isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                      color: fg, size: 22,
                    )
                  : SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: fg)),
            ),
          ),
          const SizedBox(width: 10),

          // Progress bar + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom slim bar (cheaper than Slider for chat)
                Stack(children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  _failed ? 'Couldn\'t load' : _fmt(shownDur),
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 11,
                    color: isMe
                        ? Colors.white.withOpacity(0.85)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
