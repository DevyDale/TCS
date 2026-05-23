// lib/screens/chat/chat_audio_player.dart
// (place this where your chat_room import points — currently
//  package:tcs_app/screens/chat/chat_audio_player.dart)
//
// Sage reskin only — the just_audio playback logic is unchanged.

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

// ── Sage palette ──
const _kSageDk = Color(0xFF6E8159);
const _kInk    = Color(0xFF2E3A24);
const _kSlate  = Color(0xFF7C846F);

class ChatAudioPlayer extends StatefulWidget {
  final String url;
  final int duration;
  final bool isMe;

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
  bool _ready = false;
  bool _failed = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

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
        _total = dur ?? Duration(seconds: widget.duration);
      });

      _player.positionStream.listen((p) => mounted ? setState(() => _position = p) : null);
      _player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
          setState(() => _position = Duration.zero);
        }
      });
    } catch (_) {
      if (mounted) setState(() { _ready = true; _failed = true; });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_failed || !_ready) return;
    _player.playing ? _player.pause() : _player.play();
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;

    // On a sage outgoing bubble, dark controls read best; on a light
    // incoming bubble, olive controls.
    final accent   = isMe ? _kInk : _kSageDk;            // icon + progress fill
    final circleBg = isMe ? Colors.white.withOpacity(0.40)
                          : _kSageDk.withOpacity(0.12);
    final track    = isMe ? _kInk.withOpacity(0.18) : const Color(0xFFD7D9CC);
    final timeColor = isMe ? _kInk.withOpacity(0.70) : _kSlate;

    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleBg,
              ),
              child: Icon(
                _failed
                    ? Icons.error_outline_rounded
                    : (_player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                color: accent,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
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
                          color: accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(_position > Duration.zero ? _total - _position : _total),
                  style: TextStyle(fontSize: 11, color: timeColor, fontFamily: 'Momo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}