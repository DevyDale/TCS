// lib/screens/chat/chat_audio_recorder.dart
//
// Compact recorder: TAP to start, the button pulsates and shows a STOP icon
// while recording, TAP again to stop + send. No expanding bar (so it can't
// crush the text field). Sage themed.
//
// New: optional onRecordingChanged(bool) so the chat room can broadcast a
// "recording…" status to the peer (wire it to a WS event when ready).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

const _kSageDk = Color(0xFF6E8159);

class AudioRecording {
  final String filePath;
  final int durationSeconds;
  const AudioRecording({required this.filePath, required this.durationSeconds});
}

class ChatAudioRecorderButton extends StatefulWidget {
  final void Function(AudioRecording recording) onRecorded;
  final VoidCallback? onTooShort;
  final void Function(bool recording)? onRecordingChanged;

  const ChatAudioRecorderButton({
    super.key,
    required this.onRecorded,
    this.onTooShort,
    this.onRecordingChanged,
  });

  @override
  State<ChatAudioRecorderButton> createState() => _ChatAudioRecorderButtonState();
}

class _ChatAudioRecorderButtonState extends State<ChatAudioRecorderButton>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  Timer? _timer;
  late final AnimationController _pulse;

  bool _isRecording = false;
  int _seconds = 0;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnack("Microphone permission required");
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      HapticFeedback.lightImpact();
      setState(() {
        _isRecording = true;
        _seconds = 0;
        _filePath = path;
      });
      widget.onRecordingChanged?.call(true);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (_) {
      _showSnack("Failed to start recording");
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    String? finalPath;
    try {
      finalPath = await _recorder.stop();
    } catch (_) {}

    final path = finalPath ?? _filePath;
    final duration = _seconds;

    if (!mounted) return;
    setState(() => _isRecording = false);
    widget.onRecordingChanged?.call(false);
    HapticFeedback.lightImpact();

    if (path != null && duration >= 1) {
      widget.onRecorded(AudioRecording(filePath: path, durationSeconds: duration));
    } else if (path != null) {
      widget.onTooShort?.call();
      try {
        File(path).delete();
      } catch (_) {}
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      // Idle — sage mic.
      return GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _kSageDk.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic_rounded, color: _kSageDk, size: 24),
        ),
      );
    }

    // Recording — pulsating sage button with a STOP icon. Tap to stop + send.
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final t = _pulse.value; // 0..1
          return Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kSageDk,
              boxShadow: [
                BoxShadow(
                  color: _kSageDk.withOpacity(0.20 + 0.30 * t),
                  blurRadius: 6 + 12 * t,
                  spreadRadius: 1 + 5 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}