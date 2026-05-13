// lib/screens/chat/chat_audio_recorder.dart
//
// WhatsApp-style audio recorder:
//   • Tap            → snackbar hint ("Hold the mic to record...")
//   • Hold           → recording starts, expanded pill appears
//   • Release        → sends (default)
//   • Slide ←        → cancel preview, release cancels
//   • Slide ↑        → lock preview, release locks (recording continues
//                       hands-free with explicit Stop + Cancel buttons)
//   • In locked mode → tap Stop (white circle) to send, X to discard

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

const _kMaxRecordSeconds = 5 * 60;
const _kLockThreshold    = -90.0;  // dy slide-up px to lock
const _kCancelThreshold  = -60.0;  // dx slide-left px to cancel

class AudioRecording {
  final String filePath;
  final int    durationSeconds;
  const AudioRecording({
    required this.filePath,
    required this.durationSeconds,
  });
}

enum _RecState { idle, holding, lockPreview, cancelPreview, locked }

class ChatAudioRecorderButton extends StatefulWidget {
  final void Function(AudioRecording recording) onRecorded;
  final VoidCallback? onPermissionDenied;
  final VoidCallback? onTooShort;
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

  _RecState _state    = _RecState.idle;
  int       _elapsed  = 0;
  String?   _activePath;
  Offset    _pressStart = Offset.zero;

  bool get _isLocked   => _state == _RecState.locked;
  bool get _isHolding  => _state == _RecState.holding
                       || _state == _RecState.lockPreview
                       || _state == _RecState.cancelPreview;

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

  // ── Lifecycle ────────────────────────────────────────────

  Future<void> _start() async {
    final granted = await _ensurePermission();
    if (!granted) {
      widget.onPermissionDenied?.call();
      _showPermSnack();
      return;
    }
    if (!await _recorder.hasPermission()) {
      _showPermSnack();
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final stamp  = DateTime.now().millisecondsSinceEpoch;
    final path   = '${tmpDir.path}/voice_$stamp.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder:     AudioEncoder.aacLc,
          sampleRate:  44100,
          numChannels: 1,
          bitRate:     128000,
        ),
        path: path,
      );
    } catch (_) {
      _showErr('Could not start recording.');
      return;
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _state      = _RecState.holding;
      _elapsed    = 0;
      _activePath = path;
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += 1);
      if (_elapsed >= _kMaxRecordSeconds) _stop();
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
      _state      = _RecState.idle;
      _elapsed    = 0;
      _activePath = null;
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

  Future<bool> _ensurePermission() async {
    final s = await Permission.microphone.status;
    if (s.isGranted) return true;
    final r = await Permission.microphone.request();
    return r.isGranted;
  }

  // ── Gesture handlers ─────────────────────────────────────

  void _onMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_state == _RecState.idle || _isLocked) return;
    final dx = details.globalPosition.dx - _pressStart.dx;
    final dy = details.globalPosition.dy - _pressStart.dy;

    _RecState next;
    if (dx < _kCancelThreshold) {
      next = _RecState.cancelPreview;
    } else if (dy < _kLockThreshold) {
      next = _RecState.lockPreview;
    } else {
      next = _RecState.holding;
    }
    if (next != _state) {
      HapticFeedback.selectionClick();
      setState(() => _state = next);
    }
  }

  void _onPressEnd(LongPressEndDetails _) {
    if (_state == _RecState.idle || _isLocked) return;
    switch (_state) {
      case _RecState.cancelPreview:
        _stop(cancelled: true);
        break;
      case _RecState.lockPreview:
        HapticFeedback.mediumImpact();
        setState(() => _state = _RecState.locked);
        break;
      default:
        _stop(cancelled: false);
    }
  }

  void _onPressCancel() {
    if (_isHolding) _stop(cancelled: true);
  }

  void _onTap() {
    if (_state != _RecState.idle) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
        'Hold to record · slide ↑ to lock · ← to cancel',
        style: TextStyle(fontFamily: 'Momo'),
      ),
      duration: const Duration(milliseconds: 1800),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showPermSnack() {
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

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _fmt(int s) {
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Locked: separate widget — no long-press needed.
    if (_isLocked) return _buildLockedPill();

    // Idle and holding share a single GestureDetector so the long-press
    // gesture survives the rebuild when state flips from idle → holding.
    return GestureDetector(
      onTap:                 _onTap,
      onLongPressStart:      (d) {
        _pressStart = d.globalPosition;
        _start();
      },
      onLongPressMoveUpdate: _onMoveUpdate,
      onLongPressEnd:        _onPressEnd,
      onLongPressCancel:     _onPressCancel,
      child: _isHolding ? _buildHoldingPill() : _buildIdleButton(),
    );
  }

  Widget _buildIdleButton() => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: _kG2.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.mic_rounded, color: _kG2, size: 22),
  );

  Widget _buildHoldingPill() {
    final cancel = _state == _RecState.cancelPreview;
    final lock   = _state == _RecState.lockPreview;
    final hint   = cancel ? 'Release to cancel'
                 : lock   ? 'Release to lock'
                          : 'Slide ↑ to lock · ← to cancel';
    final icon   = cancel ? Icons.delete_outline_rounded
                 : lock   ? Icons.lock_outline_rounded
                          : Icons.keyboard_arrow_up_rounded;
    final gradient = cancel
        ? LinearGradient(colors: [_kG4, Colors.red.shade700])
        : lock
            ? const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)])
            : const LinearGradient(colors: [_kG1, _kG2]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (cancel ? _kG4 : _kG2).withOpacity(0.30),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        const _PulseDot(color: Colors.white),
        const SizedBox(width: 10),
        Text(_fmt(_elapsed),
            style: const TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(hint,
              style: const TextStyle(
                  fontFamily: 'Momo',
                  color: Colors.white,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        Icon(icon, color: Colors.white, size: 20),
      ]),
    );
  }

  Widget _buildLockedPill() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kG1, _kG2]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _kG2.withOpacity(0.30),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: 6),
        const _PulseDot(color: Colors.white),
        const SizedBox(width: 10),
        Text(_fmt(_elapsed),
            style: const TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 13)),
        const Spacer(),
        // ── Cancel ──
        GestureDetector(
          onTap: () => _stop(cancelled: true),
          child: Container(
            width: 30, height: 30,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        // ── Stop & Send (the dynamic stop button) ──
        GestureDetector(
          onTap: () => _stop(cancelled: false),
          child: Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded,
                color: _kG2, size: 18),
          ),
        ),
      ]),
    );
  }
}

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
  void dispose() { _ctrl.dispose(); super.dispose(); }
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
