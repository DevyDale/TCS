// lib/widgets/welcome_banner.dart
//
// Phase 1 spec: dashboard welcome animation.
//   - Animates IN FROM THE TOP (slides down, never up)
//   - Auto-dismisses after a short duration
//   - Used once on dashboard load, not on every tab switch
//
// Drop into a Stack as the last child so it floats above other content:
//
//   Stack(children: [
//     mainContent,
//     const WelcomeBanner(name: 'Matthew'),
//   ])
//
// Set `name` to the user's preferred name. The banner is a self-contained
// stateful widget — it controls its own animation lifecycle and removes
// itself from the visual tree when dismissed.

import 'package:flutter/material.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class WelcomeBanner extends StatefulWidget {
  /// User's preferred name to address. Falls back to a generic greeting if empty.
  final String name;

  /// How long the banner stays fully visible before sliding back up.
  /// Defaults to 2.4 seconds — long enough to read, short enough not to nag.
  final Duration visibleDuration;

  /// Slide-in / slide-out timing.
  final Duration animationDuration;

  /// Optional callback fired once the banner has fully dismissed.
  final VoidCallback? onDismissed;

  const WelcomeBanner({
    super.key,
    required this.name,
    this.visibleDuration   = const Duration(milliseconds: 2400),
    this.animationDuration = const Duration(milliseconds: 480),
    this.onDismissed,
  });

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;
  bool _gone = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: widget.animationDuration);

    // Slide FROM the top: starts at y = -1 (fully above the screen),
    // ends at y = 0 (its natural position). Spec is explicit about this:
    // animate FROM TOP, not from bottom.
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Slight delay so it doesn't fight the dashboard's own entrance.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await _ctrl.forward();

    await Future.delayed(widget.visibleDuration);
    if (!mounted) return;
    await _ctrl.reverse();

    if (!mounted) return;
    setState(() => _gone = true);
    widget.onDismissed?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _line {
    final n = widget.name.trim();
    if (n.isEmpty) return 'Welcome back 👋';
    return 'Welcome back, $n 👋';
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();

    return Positioned(
      top: 0, left: 0, right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                elevation: 14,
                shadowColor: _kG2.withOpacity(0.35),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kG1, _kG2, _kG3, _kG4],
                      begin: Alignment.centerLeft,
                      end:   Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text('👋', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting,
                              style: const TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 11,
                                color: Colors.white70,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _line,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Alfa',
                                fontSize: 16,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}