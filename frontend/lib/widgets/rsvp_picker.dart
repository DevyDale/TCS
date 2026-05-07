// lib/widgets/rsvp_picker.dart
//
// Phase 2 spec 9.4 — three-state RSVP control: Going / Interested / Not going.
// The control is a segmented pill row with strong active-state visual; the
// caller passes the current status (or null for "no response") and a callback
// that receives the new status. Sending the same status again clears it
// (i.e. tapping "Going" while already Going emits null).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kViolet = Color(0xFF8E54E9);
const _kAmber  = Color(0xFFF7971E);
const _kCoral  = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);

/// Backend-facing values: must match `EventRSVP.Status` choices.
const String kRsvpGoing      = 'going';
const String kRsvpInterested = 'interested';
const String kRsvpNotGoing   = 'not_going';

class RsvpPicker extends StatelessWidget {
  /// Current status from the API: 'going', 'interested', 'not_going', or null.
  final String? status;

  /// Called when the user picks a status. The new value is passed; if the user
  /// tapped the currently-active option, this is called with `null` to indicate
  /// the RSVP should be cleared.
  final ValueChanged<String?> onChanged;

  /// Disables interaction while a request is in flight.
  final bool busy;

  const RsvpPicker({
    super.key,
    required this.status,
    required this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(
            label:  'Going',
            value:  kRsvpGoing,
            icon:   Icons.check_circle_rounded,
            accent: const Color(0xFF1D9E75),
          )),
          Expanded(child: _segment(
            label:  'Interested',
            value:  kRsvpInterested,
            icon:   Icons.star_rounded,
            accent: _kAmber,
          )),
          Expanded(child: _segment(
            label:  'Not going',
            value:  kRsvpNotGoing,
            icon:   Icons.cancel_rounded,
            accent: _kCoral,
          )),
        ],
      ),
    );
  }

  Widget _segment({
    required String   label,
    required String   value,
    required IconData icon,
    required Color    accent,
  }) {
    final active = status == value;
    return GestureDetector(
      onTap: busy ? null : () {
        HapticFeedback.lightImpact();
        // Tap the active segment again → clear.
        onChanged(active ? null : value);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          border: active
              ? Border.all(color: accent.withOpacity(0.35), width: 1.2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? accent : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: active ? accent : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
