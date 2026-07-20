// lib/screens/profile/privacy_toggle_sheet.dart
//
// Reusable bottom sheet for choosing a privacy / visibility level.
// Two factory constructors cover the two current uses:
//
//   PrivacyToggleSheet.bio(currentPublic: true)
//     → Public | Private
//
//   PrivacyToggleSheet.interests(currentVisibility: 'followers')
//     → Public | Followers only | Private
//
// On selection, pops with the chosen value as a String. The caller
// is responsible for converting to its API contract:
//   bio:        'public' / 'private'  →  setBioPublic(true | false)
//   interests:  'public' / 'followers' / 'private'  →  setInterestsVisibility(value)
//
// Returns null if the user dismisses the sheet without selecting.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';

const _kG2  = Color(0xFF8E54E9);
Color get _kInk => AppC.text;

class PrivacyOption {
  final String   value;
  final String   label;
  final String   description;
  final IconData icon;

  const PrivacyOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class PrivacyToggleSheet extends StatelessWidget {
  final String              title;
  final String              subtitle;
  final List<PrivacyOption> options;
  final String              currentValue;

  const PrivacyToggleSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.currentValue,
  });

  /// Bio visibility — public or private.
  /// Selected value pops back as 'public' or 'private'.
  factory PrivacyToggleSheet.bio({
    Key? key,
    required bool currentPublic,
  }) =>
      PrivacyToggleSheet(
        key:          key,
        title:        'Bio visibility',
        subtitle:     'Choose who can see your bio.',
        currentValue: currentPublic ? 'public' : 'private',
        options: const [
          PrivacyOption(
            value:       'public',
            label:       'Public',
            description: 'Anyone on TCS can see your bio.',
            icon:        Icons.public_rounded,
          ),
          PrivacyOption(
            value:       'private',
            label:       'Private',
            description: 'Only you can see your bio.',
            icon:        Icons.lock_rounded,
          ),
        ],
      );

  /// Interests visibility — public, followers-only, or private.
  /// Selected value pops back as 'public', 'followers', or 'private'.
  factory PrivacyToggleSheet.interests({
    Key? key,
    required String currentVisibility,
  }) =>
      PrivacyToggleSheet(
        key:          key,
        title:        'Interests visibility',
        subtitle:     'Choose who can see your interests.',
        currentValue: currentVisibility,
        options: const [
          PrivacyOption(
            value:       'public',
            label:       'Public',
            description: 'Anyone on TCS can see your interests.',
            icon:        Icons.public_rounded,
          ),
          PrivacyOption(
            value:       'followers',
            label:       'Followers only',
            description: 'Only people who follow you can see them.',
            icon:        Icons.people_alt_rounded,
          ),
          PrivacyOption(
            value:       'private',
            label:       'Private',
            description: 'Only you can see your interests.',
            icon:        Icons.lock_rounded,
          ),
        ],
      );

  // ── Convenience helpers ──────────────────────────────────

  /// Pretty label for a stored bio_public value, e.g. for showing in
  /// an overflow-menu subtitle ("Bio visibility · Public").
  static String bioLabel(bool isPublic) =>
      isPublic ? 'Public' : 'Private';

  /// Pretty label for a stored interests_visibility value.
  static String interestsLabel(String visibility) {
    switch (visibility) {
      case 'private':   return 'Private';
      case 'followers': return 'Followers only';
      default:          return 'Public';
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          // Drag handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 18, color: _kInk,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 12,
                  color: AppC.sub,
                ),
              ),
            ),
          ),
          ...options.map((o) => _buildOption(context, o)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildOption(BuildContext context, PrivacyOption o) {
    final selected = o.value == currentValue;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context, o.value);
      },
      child: Container(
        margin:  const EdgeInsets.fromLTRB(20, 4, 20, 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? _kG2.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kG2.withOpacity(0.5) : AppC.border,
            width: 1.5,
          ),
        ),
        child: Row(children: [
          // Icon swatch
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: selected ? _kG2 : AppC.card2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              o.icon,
              color: selected ? Colors.white : AppC.sub,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Label + description
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.label,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: selected ? _kG2 : _kInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(o.description,
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11,
                  color: AppC.sub,
                ),
              ),
            ],
          )),
          // Selected check
          if (selected)
            const Icon(Icons.check_circle_rounded, color: _kG2, size: 22),
        ]),
      ),
    );
  }
}