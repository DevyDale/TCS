// lib/screens/staff/staff_tab_host.dart
//
// Shared sub-tab host for the staff Connect / Campus / Dale / Protect tabs.
// A segmented pill bar at the top switches between embedded full screens
// (their own headers stay; the staff dashboard is the root route so no stray
// back buttons appear). Top padding is removed from embedded screens so their
// headers sit flush under the segmented bar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kIndigo = kStaffG1;
const _kDeep   = kStaffG2;

class StaffSeg {
  final String label;
  final IconData icon;
  final Widget child;
  const StaffSeg(this.label, this.icon, this.child);
}

class StaffTabHost extends StatefulWidget {
  final String title;
  final String emoji;
  final List<StaffSeg> segments;
  const StaffTabHost({
    super.key,
    required this.title,
    required this.emoji,
    required this.segments,
  });

  @override
  State<StaffTabHost> createState() => _StaffTabHostState();
}

class _StaffTabHostState extends State<StaffTabHost> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _header(),
        Expanded(
          child: IndexedStack(
            index: _i,
            children: widget.segments
                .map((s) => MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: s.child,
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 12,
      horizontal: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(widget.title,
              style: const TextStyle(fontFamily: 'Alfa', fontSize: 21,
                  color: Colors.white)),
        ]),
        const SizedBox(height: 12),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
          child: Row(children: List.generate(widget.segments.length, (i) {
            final sel = _i == i;
            final s = widget.segments[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_i == i) return;
                  HapticFeedback.selectionClick();
                  setState(() => _i = i);
                },
                child: Container(
                  margin: const EdgeInsets.all(3),
                  decoration: sel
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8, offset: const Offset(0, 2))])
                      : null,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.icon, size: 15,
                            color: sel ? _kDeep : Colors.white70),
                        const SizedBox(width: 6),
                        Text(s.label,
                            style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel ? _kDeep : Colors.white70)),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          })),
        ),
      ]),
    );
  }
}

/// A simple "launch a full-screen experience" panel for sub-tabs whose target
/// is a standalone screen (e.g. the Arcade).
class StaffLaunchPanel extends StatelessWidget {
  final String emoji, title, subtitle, cta;
  final VoidCallback onTap;
  const StaffLaunchPanel({
    super.key,
    required this.emoji, required this.title,
    required this.subtitle, required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18,
                  color: AppC.text)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  height: 1.5, color: AppC.sub)),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: _kIndigo.withOpacity(0.30),
                    blurRadius: 12, offset: const Offset(0, 5))]),
              child: T(cta, style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14,
                  color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
