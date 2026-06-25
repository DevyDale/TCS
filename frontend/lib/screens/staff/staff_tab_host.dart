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

const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

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
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 14, right: 14, bottom: 10),
      decoration: BoxDecoration(
        color: AppC.card,
        border: Border(bottom: BorderSide(color: AppC.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(widget.title,
              style: TextStyle(fontFamily: 'Alfa', fontSize: 20,
                  color: AppC.text)),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: AppC.card2,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppC.border)),
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
                          gradient: const LinearGradient(
                              colors: [_kIndigo, _kDeep]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(
                              color: _kIndigo.withOpacity(0.30),
                              blurRadius: 8, offset: const Offset(0, 2))])
                      : null,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.icon, size: 15,
                            color: sel ? Colors.white : AppC.sub),
                        const SizedBox(width: 6),
                        Text(s.label,
                            style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel ? Colors.white : AppC.sub)),
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
