// lib/widgets/dale_greeting_cloud.dart
//
// Dale greeting chat-cloud — an animated speech bubble that pops out near the
// Dale (robot) button, shows a short greeting, and auto-dismisses. Tapping it
// opens Dale. Reusable across student + staff. Extracted from the student feed.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/theme/app_colors.dart';

class DaleGreetingCloud extends StatefulWidget {
  final double tailFromRight;   // tail x measured from the cloud's right edge
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const DaleGreetingCloud({
    super.key,
    required this.onTap,
    required this.onDismiss,
    this.tailFromRight = 28,
    this.title = 'Hey, I’m Dale 👋',
    this.subtitle = 'Tap me to draft a notice, plan a lesson or ask anything.',
  });

  @override
  State<DaleGreetingCloud> createState() => _DaleGreetingCloudState();
}

class _DaleGreetingCloudState extends State<DaleGreetingCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 640))..forward();
    _timer = Timer(const Duration(milliseconds: 6500), _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop  = CurvedAnimation(parent: _c, curve: Curves.elasticOut,
        reverseCurve: Curves.easeInBack);
    final fade = CurvedAnimation(parent: _c,
        curve: const Interval(0.0, 0.45),
        reverseCurve: const Interval(0.55, 1.0));
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: pop.value.clamp(0.0, 1.15),
          alignment: const Alignment(0.25, -1.0),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () { _timer?.cancel(); widget.onTap(); _close(); },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: CustomPaint(
            painter: _BubblePainter(
              color: AppC.card, border: AppC.border,
              tailFromRight: widget.tailFromRight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 23, 12, 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 34, height: 34,
                  child: Lottie.asset('assets/images/robot.json',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.smart_toy_rounded,
                          color: Color(0xFF8E54E9), size: 26)),
                ),
                const SizedBox(width: 10),
                Flexible(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title,
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, fontSize: 13.5,
                            color: AppC.text)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            height: 1.3, color: AppC.sub)),
                  ],
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color, border;
  final double tailFromRight;
  _BubblePainter({required this.color, required this.border,
      required this.tailFromRight});

  @override
  void paint(Canvas canvas, Size size) {
    const tailW = 18.0, tailH = 13.0, radius = 18.0;
    final tailCx = (size.width - tailFromRight)
        .clamp(radius + tailW, size.width - radius - tailW);
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, tailH, size.width, size.height - tailH),
        const Radius.circular(radius));
    final tail = Path()
      ..moveTo(tailCx - tailW / 2, tailH)
      ..lineTo(tailCx, 0)
      ..lineTo(tailCx + tailW / 2, tailH)
      ..close();
    final full = Path.combine(
        PathOperation.union, Path()..addRRect(body), tail);
    canvas.drawShadow(full, Colors.black.withValues(alpha: 0.22), 7, false);
    canvas.drawPath(full, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(full, Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.color != color || old.tailFromRight != tailFromRight;
}
