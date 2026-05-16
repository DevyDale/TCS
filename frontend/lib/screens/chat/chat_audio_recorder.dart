// lib/screens/chat/chat_audio_recorder.dart
// CLEAN STABLE VERSION - NO LAYOUT CRASHES

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecording {
  final String filePath;
  final int durationSeconds;
  const AudioRecording({required this.filePath, required this.durationSeconds});
}

class ChatAudioRecorderButton extends StatefulWidget {
  final void Function(AudioRecording recording) onRecorded;
  final VoidCallback? onTooShort;

  const ChatAudioRecorderButton({
    super.key,
    required this.onRecorded,
    this.onTooShort,
  });

  @override
  State<ChatAudioRecorderButton> createState() => _ChatAudioRecorderButtonState();
}

class _ChatAudioRecorderButtonState extends State<ChatAudioRecorderButton> {
  final _recorder = AudioRecorder();
  Timer? _timer;

  bool _isRecording = false;
  int _seconds = 0;
  String? _filePath;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnack("Microphone permission required");
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _seconds = 0;
        _filePath = path;
      });

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

    if (path != null && duration >= 1) {
      widget.onRecorded(AudioRecording(filePath: path, durationSeconds: duration));
    } else if (path != null) {
      widget.onTooShort?.call();
      try { File(path).delete(); } catch (_) {}
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
    if (_isRecording) {
      return _buildRecordingUI();
    }

    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.purple, size: 24),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      width: 260,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.stop_rounded, color: Color(0xFF7C3AED), size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}