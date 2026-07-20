// lib/screens/profile/share_profile_sheet.dart
//
// Bottom sheet shown when the user taps "Share profile" on either
// their own profile or someone else's. Lists recent chats; tapping
// "Send" on one shares the profile to that room.
//
// Two call patterns supported:
//
//   1. Function-based (preferred for new code) — the caller decides
//      what "share" actually does:
//
//      await showShareProfileSheet(
//        context,
//        profile: {'user_id': '…', 'name': '…', 'avatar_url': '…'},
//        onShareTo: (room) async {
//          await api.shareProfileToRoom(roomId: room['id'], …);
//        },
//      );
//
//   2. Widget-based (legacy / convenience) — does the standard
//      shareProfileToRoom() call automatically:
//
//      showModalBottomSheet(
//        context: context,
//        builder: (_) => ShareProfileSheet(
//          targetUserId:    'S2024001',
//          targetName:      'Matthew',
//          targetAvatarUrl: '…',
//        ),
//      );
//
// Both delegate to _ShareSheetView for the actual UI + chat loading.
//
// Loading strategy:
//  1. Try GET /api/chat/recent/?limit=8 — lightweight purpose-built
//     endpoint for surfaces like this.
//  2. If that 404s (not deployed yet), fall back to GET /api/chat/rooms/
//     and take the first 8 entries.
//  3. If both fail, show "No recent chats yet."

import 'package:cached_network_image/cached_network_image.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

const _kG1  = Color(0xFF6DD5FA);
const _kG2  = Color(0xFF8E54E9);
Color get _kInk => AppC.text;
const _kG4  = Color(0xFFFF5858);

// ─────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────

/// Show the share-profile bottom sheet using a callback for the
/// share action. Resolves when the sheet is dismissed (regardless
/// of whether anything was actually shared).
///
/// `profile` should contain at least 'name' and 'avatar_url'. Other
/// keys (user_id, role, …) are passed through to your callback via
/// the closure — they're not read by the sheet itself.
///
/// `onShareTo` is invoked with the chat room map when the user taps
/// "Send" on a row. The room map has at least `id` and `room_type`.
Future<void> showShareProfileSheet(
  BuildContext context, {
  required Map<String, dynamic> profile,
  required Future<void> Function(Map<String, dynamic> room) onShareTo,
}) async {
  await showModalBottomSheet<void>(
    context:            context,
    backgroundColor:    Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareSheetView(
      name:      ((profile['name'] as String?) ?? '').trim(),
      avatarUrl: (profile['avatar_url'] as String?) ?? '',
      onShareTo: onShareTo,
    ),
  );
}

/// Widget form of the share-profile sheet. Use this when you want
/// the standard `shareProfileToRoom()` API call to fire on send and
/// don't need a custom callback.
class ShareProfileSheet extends StatelessWidget {
  final String  targetUserId;
  final String  targetName;
  final String? targetAvatarUrl;

  const ShareProfileSheet({
    super.key,
    required this.targetUserId,
    required this.targetName,
    this.targetAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return _ShareSheetView(
      name:      targetName,
      avatarUrl: targetAvatarUrl ?? '',
      onShareTo: (room) async {
        final id = room['id']?.toString() ?? '';
        if (id.isEmpty) return;
        await ApiService().shareProfileToRoom(
          roomId:       id,
          targetUserId: targetUserId,
          targetName:   targetName,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INTERNAL VIEW
// ─────────────────────────────────────────────────────────────

class _ShareSheetView extends StatefulWidget {
  final String name;
  final String avatarUrl;
  final Future<void> Function(Map<String, dynamic> room) onShareTo;

  const _ShareSheetView({
    required this.name,
    required this.avatarUrl,
    required this.onShareTo,
  });

  @override
  State<_ShareSheetView> createState() => _ShareSheetViewState();
}

class _ShareSheetViewState extends State<_ShareSheetView> {
  final _api = ApiService();

  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  final Set<String> _shared = {};

  String get _displayName =>
      widget.name.isNotEmpty ? widget.name : 'this user';

  @override
  void initState() {
    super.initState();
    _loadRecentChats();
  }

  Future<void> _loadRecentChats() async {
    // Only people the user already chats with 1-on-1 (accepted chat
    // requests = direct rooms). Group/bubble & study-buddy rooms are
    // intentionally excluded — you share a profile *to a person*.
    try {
      final res   = await _api.getChatRooms();
      final rooms = _coerceRoomList(res)
          .where((r) => ((r['room_type'] as String?) ?? 'direct') == 'direct')
          .toList();
      if (!mounted) return;
      setState(() {
        _rooms   = rooms;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Both endpoints can return either a bare List or {results: [...]}
  /// depending on whether DRF pagination is enabled. Coerce to a list.
  List<Map<String, dynamic>> _coerceRoomList(dynamic res) {
    if (res is List) return res.cast<Map<String, dynamic>>();
    if (res is Map) {
      return ((res['results'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Future<void> _shareTo(Map<String, dynamic> room) async {
    final id = room['id']?.toString() ?? '';
    if (id.isEmpty || _shared.contains(id)) return;
    HapticFeedback.lightImpact();
    setState(() => _shared.add(id));
    try {
      // Delegate the actual share action to the caller — they decide
      // whether this means a chat message, a notification, a deep
      // link, etc.
      await widget.onShareTo(room);
      if (!mounted) return;
      _snack('Shared with ${_roomLabel(room)}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _shared.remove(id));
      _snack('Could not share. Try again.', isError: true);
    }
  }

  String _roomLabel(Map<String, dynamic> r) {
    final other = r['other_user'] as Map<String, dynamic>?;
    final n = (other?['name'] ??
            r['display_name'] ??
            r['other_user_name'] ??
            r['name'] ??
            '')
        .toString()
        .trim();
    return n.isNotEmpty ? n : 'them';
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: isError ? _kG4 : _kInk,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin:   const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

          // Header — who are we sharing
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T('Share profile',
                    style: TextStyle(
                      fontFamily: 'Arch', fontSize: 12,
                      color: AppC.sub, letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 17, color: _kInk,
                    ),
                  ),
                ],
              )),
            ]),
          ),

          Container(height: 1, color: AppC.divider),

          // Chats
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _kG2),
            )
          else if (_rooms.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: T('No chats yet — accept a chat request first.',
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 13,
                  color: AppC.sub,
                ),
              ),
            )
          else
            Flexible(child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _rooms.length,
              itemBuilder: (_, i) => _buildRoomTile(_rooms[i]),
            )),

          // Copy-link footer
          Container(height: 1, color: AppC.divider),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _snack('Profile link copied');
              // A real Clipboard.setData() call goes here once we
              // settle on a public profile URL scheme (deep link).
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(children: [
                Icon(Icons.link_rounded,
                    color: AppC.sub, size: 18),
                const SizedBox(width: 12),
                T('Copy profile link',
                  style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13, color: AppC.sub,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Subwidgets ───────────────────────────────────────────

  Widget _avatar() {
    if (widget.avatarUrl.isNotEmpty) {
      return ClipOval(child: CachedNetworkImage(
        imageUrl:    widget.avatarUrl,
        width:       44, height: 44,
        fit:         BoxFit.cover,
        placeholder: (_, __) => _avatarFallback(),
        errorWidget: (_, __, ___) => _avatarFallback(),
      ));
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    final initial = _displayName.isNotEmpty
        ? _displayName[0].toUpperCase()
        : '?';
    return Container(
      width: 44, height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_kG1, _kG2],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text(initial,
        style: const TextStyle(
          fontFamily: 'Alfa', fontSize: 18, color: Colors.white,
        ),
      )),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> r) {
    final id        = r['id']?.toString() ?? '';
    final shared    = _shared.contains(id);
    final label     = _roomLabel(r);
    final other     = r['other_user'] as Map<String, dynamic>?;
    final avatarUrl = (other?['avatar_url']    ??
                       r['display_avatar']     ??
                       r['other_user_avatar']  ?? '').toString();
    final initial   = label.isNotEmpty ? label[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: shared ? null : () => _shareTo(r),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          ClipOval(child: avatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl:    avatarUrl,
                  width:       40, height: 40,
                  fit:         BoxFit.cover,
                  errorWidget: (_, __, ___) => _initialCircle(initial),
                )
              : _initialCircle(initial)),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Arch', fontWeight: FontWeight.bold,
              fontSize: 14, color: _kInk,
            ),
          )),
          if (shared)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_rounded, size: 12,
                    color: Colors.green.shade700),
                const SizedBox(width: 4),
                T('Sent',
                  style: TextStyle(
                    fontFamily: 'Arch', fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const T('Send',
                style: TextStyle(
                  fontFamily: 'Arch', fontSize: 11,
                  fontWeight: FontWeight.bold, color: Colors.white,
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _initialCircle(String initial) => Container(
    width: 40, height: 40,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [_kG1, _kG2],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Text(initial,
      style: const TextStyle(
        fontFamily: 'Alfa', fontSize: 16, color: Colors.white,
      ),
    )),
  );
}
