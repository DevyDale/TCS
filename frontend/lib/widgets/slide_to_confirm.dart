// lib/widgets/slide_to_confirm.dart
//
// A deliberate "slide to confirm" control for high-consequence actions
// (emergency / evacuation). A single tap can't fire it — the user must drag
// the thumb to the far end, then onConfirmed runs.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideToConfirm extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onConfirmed;
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.color = const Color(0xFFDC2626),
    this.icon = Icons.warning_amber_rounded,
    this.enabled = true,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _dx = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    const h = 58.0, thumb = 50.0;
    final disabled = !widget.enabled || _busy;
    return LayoutBuilder(builder: (context, c) {
      final maxDx = c.maxWidth - thumb - 8;
      final pct = maxDx <= 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);
      return Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(h / 2),
            border: Border.all(color: widget.color.withValues(alpha: 0.4)),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: (1 - pct).clamp(0.0, 1.0),
              child: Text(widget.label,
                  style: TextStyle(fontFamily: 'Arch', fontSize: 13.5,
                      fontWeight: FontWeight.bold, color: widget.color)),
            ),
            Positioned(
              left: 4 + _dx, top: 4,
              child: GestureDetector(
                onHorizontalDragUpdate: disabled ? null : (d) {
                  setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx));
                },
                onHorizontalDragEnd: disabled ? null : (_) async {
                  if (pct > 0.92) {
                    setState(() { _dx = maxDx; _busy = true; });
                    HapticFeedback.heavyImpact();
                    try { await widget.onConfirmed(); }
                    finally { if (mounted) setState(() { _dx = 0; _busy = false; }); }
                  } else {
                    setState(() => _dx = 0);
                  }
                },
                child: Container(
                  width: thumb, height: thumb,
                  decoration: BoxDecoration(
                    color: widget.color, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 10, offset: const Offset(0, 3))]),
                  child: _busy
                      ? const Padding(padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(widget.icon, color: Colors.white, size: 24),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
