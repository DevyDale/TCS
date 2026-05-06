// lib/screens/arcade/_arcade_carousel_card.dart
import 'package:flutter/material.dart';

class ArcadeCarouselCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final String content;
  final bool isActive;
  final VoidCallback? onTap;

  const ArcadeCarouselCard({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.content,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<ArcadeCarouselCard> createState() => _ArcadeCarouselCardState();
}

class _ArcadeCarouselCardState extends State<ArcadeCarouselCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) {
        _pressCtrl.forward();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressCtrl.forward(),
      child: ScaleTransition(
        scale: _pressCtrl,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Stack(
            children: [
              // ── Card body ─────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradient.colors.first.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                // FIX: reduced vertical padding from 22 → 14
                // so the column has more breathing room
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    // Icon circle — slightly smaller
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(widget.icon, size: 26, color: Colors.white),
                    ),
                    const SizedBox(width: 14),

                    // Text column — FIX: use Expanded + Flexible
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // FIX
                        children: [
                          // FIX: maxLines:1 + smaller font so it never wraps
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Alfa',
                              fontSize: 15, // reduced from 19
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // FIX: Flexible prevents unbounded height
                          Flexible(
                            child: Text(
                              widget.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'Momo',
                                fontSize: 12, // reduced from 13
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    // Arrow
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ],
                ),
              ),

              // ── Active pulse dot ───────────────────────────
              if (widget.isActive)
                Positioned(
                  top: 12,
                  right: 14,
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, __) => Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withOpacity(0.5 + 0.5 * _shimmerCtrl.value),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white
                                .withOpacity(0.4 * _shimmerCtrl.value),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dot page indicator
class CarouselDotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;

  const CarouselDotIndicator({
    super.key,
    required this.count,
    required this.current,
    this.activeColor = const Color(0xFF8E54E9),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}