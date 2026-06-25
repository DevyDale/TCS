// lib/widgets/avatar/avatar_view.dart
//
// Universal avatar widget — handles all three rendering paths in one place:
//   1. Uploaded avatar (CloudinaryField on User model) → CachedNetworkImage
//   2. Preset avatar (avatar_id 0-99) → procedural render from kAvatars
//   3. Neither → letter initial on a deterministic gradient
//
// The widget accepts EITHER explicit fields or a User-shaped Map. Most of
// the existing app passes around Map<String, dynamic> from API responses,
// so the Map path is the common one.
//
// USAGE:
//
//   // From a user map (most common in this app)
//   AvatarView.user(user, size: 48)
//
//   // Explicit fields
//   AvatarView(
//     avatarUrl: '...',          // Cloudinary URL or null
//     avatarId:  42,             // 0-99 or null
//     fallbackName: 'Alice',
//     size: 56,
//   )
//
//   // Just a preset avatar (e.g. picker preview)
//   AvatarView.preset(42, size: 80)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

import '../data/avators.dart';


class AvatarView extends StatelessWidget {
  final String? avatarUrl;
  final int?    avatarId;
  final String  fallbackName;
  final double  size;
  final bool    showBorder;
  final Color   borderColor;
  final double  borderWidth;
  final bool    isOnline;

  const AvatarView({
    super.key,
    this.avatarUrl,
    this.avatarId,
    this.fallbackName = '?',
    this.size = 48,
    this.showBorder = false,
    this.borderColor = Colors.white,
    this.borderWidth = 2,
    this.isOnline = false,
  });

  /// Build from a user-shaped map (e.g. API response). Looks at:
  ///   • user['avatar_url']  / user['avatar']
  ///   • user['avatar_id']
  ///   • user['name'] / user['display_name'] / user['preferred_name']
  ///   • user['is_online']
  factory AvatarView.user(
    Map<String, dynamic>? user, {
    double size = 48,
    bool showBorder = false,
    Color borderColor = Colors.white,
    double borderWidth = 2,
  }) {
    if (user == null) {
      return AvatarView(
        size: size,
        showBorder: showBorder,
        borderColor: borderColor,
        borderWidth: borderWidth,
      );
    }
    return AvatarView(
      avatarUrl: (user['avatar_url'] ?? user['avatar']) as String?,
      avatarId:  user['avatar_id'] as int?,
      fallbackName: (user['display_name']
              ?? user['name']
              ?? user['preferred_name']
              ?? user['username']
              ?? '?') as String,
      size: size,
      showBorder: showBorder,
      borderColor: borderColor,
      borderWidth: borderWidth,
      isOnline: user['is_online'] as bool? ?? false,
    );
  }

  /// Convenience: render a preset avatar with no upload/letter fallback logic.
  factory AvatarView.preset(int id, {double size = 48, bool showBorder = false, Key? key}) {
    return AvatarView(
      key: key,
      avatarId: id,
      size: size,
      showBorder: showBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget core;

    final hasUpload = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasPreset = avatarId != null && avatarId! >= 0 && avatarId! < kAvatars.length;

    if (hasUpload) {
      core = _CircularNetworkImage(url: avatarUrl!, size: size);
    } else if (hasPreset) {
      core = _PresetAvatarView(def: kAvatars[avatarId!], size: size);
    } else {
      core = _InitialAvatar(name: fallbackName, size: size);
    }

    if (showBorder) {
      core = Container(
        width: size + (borderWidth * 2),
        height: size + (borderWidth * 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: borderColor,
        ),
        child: Center(child: core),
      );
    }

    if (!isOnline) return core;

    final dotSize = (size * 0.27).clamp(8.0, 16.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        core,
        Positioned(
          right: 0, bottom: 0,
          child: Container(
            width: dotSize, height: dotSize,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Preset rendering ────────────────────────────────────────

class _PresetAvatarView extends StatelessWidget {
  final AvatarDef def;
  final double    size;
  const _PresetAvatarView({required this.def, required this.size});

  @override
  Widget build(BuildContext context) {
    // Emoji size scales with avatar size — empirically tuned.
    final emojiSize = size * 0.55;

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: def.gradient,
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: def.gradient.last.withOpacity(0.20),
            blurRadius: size * 0.10,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: Center(
        child: Text(
          def.emoji,
          style: TextStyle(
            fontSize: emojiSize,
            // Drop shadow so the emoji pops against bright gradients
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Network upload rendering ────────────────────────────────

class _CircularNetworkImage extends StatelessWidget {
  final String url;
  final double size;
  const _CircularNetworkImage({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppC.border,
            child: const Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8E54E9),
                ),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _InitialAvatar(
            name: '?',
            size: size,
          ),
        ),
      ),
    );
  }
}

// ── Initial fallback ────────────────────────────────────────

class _InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _InitialAvatar({required this.name, required this.size});

  /// Deterministic gradient from the name's hashCode so each user
  /// gets a stable colour without us tracking it.
  List<Color> _gradientFor(String name) {
    const palettes = [
      [Color(0xFF6DD5FA), Color(0xFF8E54E9)],
      [Color(0xFFF7971E), Color(0xFFFF5858)],
      [Color(0xFF11998E), Color(0xFF38EF7D)],
      [Color(0xFFFC466B), Color(0xFF3F5EFB)],
      [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      [Color(0xFFFF512F), Color(0xFFF09819)],
      [Color(0xFF00B4DB), Color(0xFF0083B0)],
      [Color(0xFFEE0979), Color(0xFFFF6A00)],
    ];
    return palettes[name.hashCode.abs() % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final colors  = _gradientFor(name);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
            color: AppC.text,
            fontFamily: 'Arch',
          ),
        ),
      ),
    );
  }
}
