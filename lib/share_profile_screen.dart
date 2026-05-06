// lib/widgets/share_profile_sheet.dart
//
// Phase 3 spec 3.4 — bottom sheet that opens when a viewer taps "Share"
// on someone's profile.
//
// Contents:
//   - Search bar (filters the user's own contacts/recent chats)
//   - List of MAX 5 recent chats (one tap → shares profile to that chat)
//
// Data source: tries `/api/chat/recent/?limit=5` first; if that
// endpoint isn't available (404), falls back to `/api/chat/rooms/` and
// takes the first 5 results client-side. Either path works, so the
// optional backend endpoint in Phase 3's RECENT_CHATS_PATCH.md is just
// an optimisation.
//
// Usage:
//   showShareProfileSheet(
//     context,
//     profile: {
//       'user_id': 'STU12345',
//       'name': 'Matthew',
//       'avatar_url': '...',
//       'role': 'student',
//     },
//     onShareTo: (roomId) async => await api.shareProfile(roomId, ...),
//   );

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);

/// Convenience entry point — call this instead of constructing the
/// widget directly.
Future<void> showShareProfileSheet(
  BuildContext context, {
  required Map<String, dynamic> profile,
  Future<void> Function(Map<String, dynamic> room)? onShareTo,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShareProfileSheet(
      profile:   profile,
      onShareTo: onShareTo,
    ),
  );
}

class ShareProfileSheet extends StatefulWidget {
  /// The profile being shared. Expected keys:
  ///   user_id, name, role, avatar_url
  final Map<String, dynamic> profile;

  /// Called when the user picks a chat to share to. Receives the full
  /// room map so the caller can extract whatever they need (id, name).
  /// If not provided, the sheet just closes after selection.
  final Future<void> Function(Map<String, dynamic> room)? onShareTo;

  const ShareProfileSheet({
    super.key,
    required this.profile,
    this.onShareTo,
  });

  @override
  State<ShareProfileSheet> createState() => _ShareProfileSheetState();
}

class _ShareProfileSheetState extends State<ShareProfileSheet> {
  final _api      = ApiService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _recent  = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _sending = false;

  static const _maxRecent = 5;

  @override
  void initState() {
    super.initState();
    _loadRecentChats();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentChats() async {
    // Try the optimised endpoint first; fall back to the full list.
    try {
      final data = await _api.getRecentChats(limit: _maxRecent);
      final list = (data is List)
          ? data.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _recent   = list;
        _filtered = list;
        _loading  = false;
      });
    } catch (_) {
      // Fallback: full chat list, take first 5.
      try {
        final data = await _api.getChatRooms();
        final list = (data is List)
            ? data.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
        final capped = list.take(_maxRecent).toList();
        if (!mounted) return;
        setState(() {
          _recent   = capped;
          _filtered = capped;
          _loading  = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = _recent);
      return;
    }
    setState(() {
      _filtered = _recent.where((r) {
        final name = _roomName(r).toLowerCase();
        return name.contains(q);
      }).toList();
    });
  }

  String _roomName(Map<String, dynamic> r) {
    final type = r['room_type'] as String? ?? 'direct';
    if (type == 'group') return (r['name'] as String?) ?? 'Group';
    final other = r['other_user'] as Map<String, dynamic>?;
    return (other?['name'] as String?) ?? 'Unknown';
  }

  String? _roomAvatar(Map<String, dynamic> r) {
    final type = r['room_type'] as String? ?? 'direct';
    if (type == 'group') return r['avatar_url'] as String?;
    final other = r['other_user'] as Map<String, dynamic>?;
    return other?['avatar_url'] as String?;
  }

  Future<void> _shareTo(Map<String, dynamic> room) async {
    if (_sending) return;
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);

    try {
      if (widget.onShareTo != null) {
        await widget.onShareTo!(room);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profile shared to ${_roomName(room)} ✓',
            style: const TextStyle(fontFamily: 'Momo')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1D9E75),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Share failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: const TextStyle(fontFamily: 'Momo')),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.3,
      maxChildSize:     0.85,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          _buildHandle(),
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildList(scrollCtrl)),
        ]),
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildHeader() {
    final name = widget.profile['name'] as String? ?? 'this profile';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const Text(
            'Share Profile',
            style: TextStyle(
              fontFamily: 'Alfa',
              fontSize: 20,
              color: _kInk,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '· $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Momo',
                fontSize: 13,
                color: _kSlate,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _kSlate),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search recent chats...',
            hintStyle: TextStyle(
              fontFamily: 'Momo',
              fontSize: 13,
              color: _kSlate.withOpacity(0.5),
            ),
            prefixIcon: Icon(Icons.search_rounded,
                color: _kSlate.withOpacity(0.5), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ScrollController scrollCtrl) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                _recent.isEmpty
                    ? 'No recent chats yet'
                    : 'No matches',
                style: const TextStyle(
                  fontFamily: 'Alfa',
                  fontSize: 16,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _recent.isEmpty
                    ? 'Start a conversation first to share profiles.'
                    : 'Try a different search term.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _ChatRow(
        room:    _filtered[i],
        name:    _roomName(_filtered[i]),
        avatar:  _roomAvatar(_filtered[i]),
        sending: _sending,
        onTap:   () => _shareTo(_filtered[i]),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final Map<String, dynamic> room;
  final String   name;
  final String?  avatar;
  final bool     sending;
  final VoidCallback onTap;
  const _ChatRow({
    required this.room,
    required this.name,
    required this.avatar,
    required this.sending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type     = room['room_type'] as String? ?? 'direct';
    final isGroup  = type == 'group';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: sending ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGroup ? BorderRadius.circular(14) : null,
              ),
              child: ClipRRect(
                borderRadius: isGroup
                    ? BorderRadius.circular(14)
                    : BorderRadius.circular(24),
                child: avatar != null && avatar!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar!,
                        width: 48, height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _initialFallback(initial),
                      )
                    : _initialFallback(initial),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _kInk,
                    ),
                  ),
                  Text(
                    isGroup ? 'Group chat' : 'Direct message',
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            sending
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kG2),
                  )
                : const Icon(Icons.send_rounded, color: _kG2, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _initialFallback(String initial) => Center(
    child: Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Arch',
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}
