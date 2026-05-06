// lib/widgets/chat/chat_audio_recorder.dart
//
// Hold-to-record audio button for the chat input bar.
//
// Behaviour:
//   • Press and HOLD the mic to start recording (with mic permission)
//   • Release to stop and trigger the upload callback
//   • Slide UP and release to cancel
//   • Maximum recording duration: 5 minutes (capped to keep file sizes
//     reasonable; backend already validates at 50 MB)
//
// Audio is recorded to AAC m4a in the OS temp directory; the caller
// is responsible for uploading via api.uploadChatMedia(...) and
// deleting the temp file afterwards.
//
// Required packages (add to pubspec.yaml — see pubspec_additions.md):
//   record:               ^5.1.2
//   path_provider:        ^2.1.4
//   permission_handler:   ^11.3.1

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

const _kG1   = Color(0xFF6DD5FA);
const _kG2   = Color(0xFF8E54E9);
const _kG4   = Color(0xFFFF5858);
const _kInk  = Color(0xFF1A1A2E);

const _kMaxRecordSeconds = 5 * 60;

/// Result handed back when the user releases (without cancelling).
class AudioRecording {
  final String filePath;
  final int    durationSeconds;
  const AudioRecording({
    required this.filePath,
    required this.durationSeconds,
  });
}

class ChatAudioRecorderButton extends StatefulWidget {
  /// Called when the user finishes a recording and didn't cancel.
  final void Function(AudioRecording recording) onRecorded;

  /// Called when permission is denied. Defaults to a snackbar.
  final VoidCallback? onPermissionDenied;

  /// Optional — surface a recording-too-short message in the parent UI.
  final VoidCallback? onTooShort;

  /// Smallest accepted recording length. Anything shorter is silently
  /// cancelled (like a fat-finger tap).
  final int minDurationSeconds;

  const ChatAudioRecorderButton({
    super.key,
    required this.onRecorded,
    this.onPermissionDenied,
    this.onTooShort,
    this.minDurationSeconds = 1,
  });

  @override
  State<ChatAudioRecorderButton> createState() =>
      _ChatAudioRecorderButtonState();
}

class _ChatAudioRecorderButtonState extends State<ChatAudioRecorderButton> {
  late final AudioRecorder _recorder;
  Timer? _ticker;

  bool   _recording        = false;
  bool   _cancelHovered    = false;
  int    _elapsed          = 0;
  String? _activePath;

  // Drag state
  Offset _pressStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Recording lifecycle ──────────────────────────────────

  Future<void> _start() async {
    final granted = await _ensureMicPermission();
    if (!granted) {
      widget.onPermissionDenied?.call();
      _showPermissionSnack();
      return;
    }
    if (!await _recorder.hasPermission()) {
      _showPermissionSnack();
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final stamp  = DateTime.now().millisecondsSinceEpoch;
    final path   = '${tmpDir.path}/voice_$stamp.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder:    AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate:     128000,
        ),
        path: path,
      );
    } catch (e) {
      _showError('Could not start recording: $e');
      return;
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _recording   = true;
      _elapsed     = 0;
      _activePath  = path;
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += 1);
      if (_elapsed >= _kMaxRecordSeconds) {
        _stop();   // auto-cap at 5 minutes
      }
    });
  }

  Future<void> _stop({bool cancelled = false}) async {
    _ticker?.cancel();
    _ticker = null;

    String? finalPath;
    try {
      finalPath = await _recorder.stop();
    } catch (_) {
      finalPath = _activePath;
    }

    final duration = _elapsed;
    final path     = finalPath ?? _activePath;

    if (!mounted) return;
    setState(() {
      _recording     = false;
      _cancelHovered = false;
      _elapsed       = 0;
      _activePath    = null;
    });

    if (cancelled) {
      HapticFeedback.heavyImpact();
      _safeDelete(path);
      return;
    }

    if (duration < widget.minDurationSeconds || path == null) {
      widget.onTooShort?.call();
      _safeDelete(path);
      return;
    }

    HapticFeedback.lightImpact();
    widget.onRecorded(AudioRecording(
      filePath:        path,
      durationSeconds: duration,
    ));
  }

  void _safeDelete(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  void _showPermissionSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
        'Microphone permission is needed to record voice notes.',
        style: TextStyle(fontFamily: 'Momo', color: Colors.white),
      ),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      action: SnackBarAction(
        label: 'Settings',
        textColor: Colors.white,
        onPressed: openAppSettings,
      ),
    ));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(
              fontFamily: 'Momo', color: Colors.white)),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _fmtElapsed(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        _pressStart = details.globalPosition;
        _start();
      },
      onLongPressMoveUpdate: (details) {
        if (!_recording) return;
        final dy = details.globalPosition.dy - _pressStart.dy;
        // Sliding up by 60+ px enters cancel state.
        final shouldCancel = dy < -60;
        if (shouldCancel != _cancelHovered) {
          HapticFeedback.selectionClick();
          setState(() => _cancelHovered = shouldCancel);
        }
      },
      onLongPressEnd: (_) {
        if (!_recording) return;
        _stop(cancelled: _cancelHovered);
      },
      onLongPressCancel: () {
        if (!_recording) return;
        _stop(cancelled: true);
      },
      child: _recording
          ? _buildRecordingPill()
          : _buildIdleButton(),
    );
  }

  // Compact mic button — sits in the input bar.
  Widget _buildIdleButton() {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: _kG2.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.mic_rounded, color: _kG2, size: 22),
    );
  }

  // Expanded "recording" UI — stretches across the input bar while held.
  Widget _buildRecordingPill() {
    final cancel = _cancelHovered;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: cancel
            ? LinearGradient(colors: [_kG4, Colors.red.shade700])
            : const LinearGradient(colors: [_kG1, _kG2]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (cancel ? _kG4 : _kG2).withOpacity(0.30),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        // Pulsing dot
        _PulseDot(color: Colors.white),
        const SizedBox(width: 10),
        // Time
        Text(_fmtElapsed(_elapsed),
            style: const TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            cancel ? 'Release to cancel' : 'Slide up to cancel',
            style: const TextStyle(
                fontFamily: 'Momo',
                color: Colors.white,
                fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(
          cancel
              ? Icons.delete_outline_rounded
              : Icons.keyboard_arrow_up_rounded,
          color: Colors.white, size: 20,
        ),
      ]),
    );
  }
}

/// Small pulsing dot used inside the recording pill.
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final scale   = 0.7 + (_ctrl.value * 0.5);
        final opacity = 0.5 + (_ctrl.value * 0.5);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }
}
