// lib/widgets/slide_to_confirm.dart
//
// A deliberate "slide to confirm" control for high-consequence actions
// (emergency / evacuation). A single tap can't fire it — the user must drag
// the thumb to the far end, then onConfirmed runs. Designed to read clearly:
// a gradient track that fills as you slide, animated chevrons hinting the
// direction, and a glowing thumb.

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

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _busy = false;
  late final AnimationController _hint =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() { _hint.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const h = 62.0, thumb = 54.0;
    final disabled = !widget.enabled || _busy;
    return LayoutBuilder(builder: (context, c) {
      final maxDx = c.maxWidth - thumb - 8;
      final pct = maxDx <= 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);
      return Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: h,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(h / 2),
            border: Border.all(color: widget.color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(h / 2),
            child: Stack(alignment: Alignment.center, children: [
              // Track fill that grows behind the thumb as you slide.
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: (_dx + thumb + 4).clamp(0.0, c.maxWidth),
                child: DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    widget.color.withValues(alpha: 0.28),
                    widget.color.withValues(alpha: 0.55),
                  ]),
                )),
              ),
              // Animated direction chevrons (fade out as the track fills).
              Positioned(
                right: 24,
                child: Opacity(
                  opacity: (1 - pct).clamp(0.0, 1.0),
                  child: AnimatedBuilder(
                    animation: _hint,
                    builder: (_, __) => Row(mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final t = ((_hint.value * 3) - i).clamp(0.0, 1.0);
                          final o = (1 - (t - 0.5).abs() * 2).clamp(0.25, 1.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Icon(Icons.chevron_right_rounded,
                                size: 22,
                                color: widget.color.withValues(alpha: o)),
                          );
                        })),
                  ),
                ),
              ),
              // Label (fades as you slide).
              Opacity(
                opacity: (1 - pct * 1.4).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Text(widget.label,
                      style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                          fontWeight: FontWeight.bold, letterSpacing: 0.3,
                          color: widget.color)),
                ),
              ),
              // Thumb.
              Positioned(
                left: 4 + _dx, top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: disabled ? null : (d) {
                    setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx));
                  },
                  onHorizontalDragEnd: disabled ? null : (_) async {
                    if (pct > 0.9) {
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
                      gradient: LinearGradient(
                        colors: [widget.color, widget.color.withValues(alpha: 0.82)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5),
                          blurRadius: 14, offset: const Offset(0, 4))]),
                    child: _busy
                        ? const Padding(padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
