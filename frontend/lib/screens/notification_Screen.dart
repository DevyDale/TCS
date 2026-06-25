// lib/screens/notifications/notifications_screen.dart
//
// Reads from NotificationService.instance — the screen is a thin view
// that re-renders when the service notifies listeners. Tapping an item
// marks it read and dispatches navigation by notif_type.
//
// Notifications are split into Today / Yesterday / Earlier via a pill
// tab bar; the selected bucket is filtered from createdAt.
//
// Leaving the screen marks everything read, so the feed's bell drops
// its animated icon + unread badge — visiting counts as "attended to".
//
// VISUAL REVISION (match notification-feed reference):
//   • Tiles are now clean white rounded cards with a soft shadow (the
//     old 2px violet→cyan gradient border has been removed — that was
//     the main thing pulling the screen away from the reference's flat
//     look). Brand identity stays in the icon tints + selected pill.
//   • Unread items get a subtle violet-tinted background + hairline +
//     a colored status dot, instead of the heavy border.
//   • Per-type glyphs are Material line icons on a tinted circle
//     (was emoji), matching the reference's icon style.
//   • Swipe-to-delete reveals a red "Delete" affordance (icon + label),
//     rounded to match the card.
//   • Title is centered to match the reference; Clear All + the
//     Today/Yesterday/Earlier pills are unchanged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import 'noticeboard_screen.dart';

const _kViolet = Color(0xFF8E54E9);
const _kBlue   = Color(0xFF6DD5FA);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF7A8294);
const _kBg     = Color(0xFFF7F8FA);
const _kCard   = Colors.white;
const _kRed    = Color(0xFFFF5858);
const _kTabBg  = Color(0xFFF0F0F3); // unselected pill fill

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService.instance;

  // 'today' | 'yesterday' | 'earlier'
  String _bucket = 'today';

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChange);
    _svc.refresh();
  }

  @override
  void dispose() {
    _svc.removeListener(_onChange);
    // Visiting this screen counts as attending to notifications: mark
    // everything read on the way out so the feed bell clears its Lottie
    // animation and unread badge. Deferred so it never runs mid-teardown.
    Future.microtask(_svc.markAllRead);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _onTap(AppNotification n) async {
    HapticFeedback.selectionClick();
    if (!n.isRead) await _svc.markRead(n.id);
    _routeFor(n);
  }

  // Map notif_type → screen. Plug your existing routes in here.
  void _routeFor(AppNotification n) {
    // Safe defaults — replace with your real Navigator.push targets.
    switch (n.notifType) {
      case 'game_request':
        Navigator.of(context).pushNamed('/arcade/requests');
        break;
      case 'chat_request':
        Navigator.of(context).pushNamed('/chat/requests');
        break;
      case 'chat_message':
        Navigator.of(context).pushNamed('/chat/room',
            arguments: {'room_id': n.targetId});
        break;
      case 'highlight':
        if (n.targetType == 'event') {
          Navigator.of(context).pushNamed('/events/details',
              arguments: {'event_id': n.targetId});
        } else {
          Navigator.of(context).pushNamed('/feed');
        }
        break;
      case 'announcement':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NoticeboardScreen(highlightId: n.targetId),
        ));
        break;
      case 'study_buddy_request':
        Navigator.of(context).pushNamed('/groups/buddies');
        break;
      case 'study_group_invite':
        Navigator.of(context).pushNamed('/groups/detail',
            arguments: {'group_id': n.targetId});
        break;
      case 'follow':
        Navigator.of(context).pushNamed('/profile/other',
            arguments: {'user_id': n.targetId});
        break;
      case 'like':
      case 'comment':
      case 'mention':
        Navigator.of(context).pushNamed('/posts/detail',
            arguments: {'post_id': n.targetId});
        break;
    }
  }

  // Notifications belonging to the currently selected time bucket.
  List<AppNotification> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    return _svc.notifications.where((n) {
      final d = DateTime(
          n.createdAt.year, n.createdAt.month, n.createdAt.day);
      switch (_bucket) {
        case 'today':
          return d == today;
        case 'yesterday':
          return d == yesterday;
        case 'earlier':
          return d.isBefore(yesterday);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = _svc.notifications;
    final items = _filtered;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Notifications',
            style: TextStyle(fontFamily: 'Alfa', color: _kInk, fontSize: 18)),
        iconTheme: const IconThemeData(color: _kInk),
        actions: [
          // Top-right: a direct "Clear All" button (replaces the 3-dot menu).
          if (all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kRed.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final ok = await _confirmClearAll();
                    if (ok == true) await _svc.clearAll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: RefreshIndicator(
              color: _kViolet,
              onRefresh: _svc.refresh,
              child: _svc.isLoading && all.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _kViolet))
                  : items.isEmpty
                      ? _emptyScrollable(_bucket)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NotifTile(
                            n: items[i],
                            onTap: () => _onTap(items[i]),
                            onDelete: () => _svc.delete(items[i].id),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar : Today | Yesterday | Earlier ────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      child: Row(children: [
        _tab('Today', 'today'),
        const SizedBox(width: 8),
        _tab('Yesterday', 'yesterday'),
        const SizedBox(width: 8),
        _tab('Earlier', 'earlier'),
      ]),
    );
  }

  Widget _tab(String label, String value) {
    final sel = _bucket == value;
    return GestureDetector(
      onTap: () {
        if (_bucket == value) return;
        HapticFeedback.selectionClick();
        setState(() => _bucket = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _kInk : _kTabBg,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Arch',
            fontSize: 13,
            fontWeight: sel ? FontWeight.bold : FontWeight.w600,
            color: sel ? Colors.white : _kSlate,
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmClearAll() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear all notifications?',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
        content: const Text(
          'This will permanently remove every notification. This action cannot be undone.',
          style: TextStyle(
              fontFamily: 'Momo', fontSize: 13, color: _kSlate, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Arch', color: _kSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all',
                style: TextStyle(
                    fontFamily: 'Arch',
                    color: _kRed,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Scrollable wrapper so pull-to-refresh still works on an empty bucket.
  Widget _emptyScrollable(String bucket) => ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.08),
          _empty(bucket),
        ],
      );

  Widget _empty(String bucket) {
    String title, sub;
    switch (bucket) {
      case 'yesterday':
        title = 'Nothing from yesterday';
        sub = 'You had no notifications yesterday';
        break;
      case 'earlier':
        title = 'Nothing earlier';
        sub = 'Older notifications will show here';
        break;
      case 'today':
      default:
        title = "You're all caught up";
        sub = 'New notifications from today will show here';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kViolet, _kBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Container(
          margin: const EdgeInsets.all(3), // ← Controls border thickness
          decoration: BoxDecoration(
            color: _kCard, // White inner background
            borderRadius: BorderRadius.circular(17),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bell Icon
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: _kViolet.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔔', style: TextStyle(fontSize: 38)),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Alfa',
                  fontSize: 19,
                  color: _kInk,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                sub,
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 13.5,
                  color: _kSlate,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap, onDelete;
  const _NotifTile(
      {required this.n, required this.onTap, required this.onDelete});

  ({IconData icon, Color color}) get _glyph {
    switch (n.notifType) {
      case 'game_request':
        return (icon: Icons.sports_esports_rounded, color: const Color(0xFFF7971E));
      case 'chat_request':
        return (icon: Icons.forum_rounded, color: _kBlue);
      case 'chat_message':
        return (icon: Icons.chat_bubble_rounded, color: _kBlue);
      case 'highlight':
        return (icon: Icons.auto_awesome_rounded, color: _kViolet);
      case 'study_buddy_request':
        return (icon: Icons.menu_book_rounded, color: const Color(0xFF4F46E5));
      case 'study_group_invite':
        return (icon: Icons.groups_rounded, color: const Color(0xFF10B981));
      case 'follow':
        return (icon: Icons.person_add_rounded, color: const Color(0xFFEC4899));
      case 'like':
        return (icon: Icons.favorite_rounded, color: _kRed);
      case 'comment':
        return (icon: Icons.mode_comment_rounded, color: const Color(0xFF6366F1));
      case 'mention':
        return (icon: Icons.alternate_email_rounded, color: _kViolet);
      case 'announcement':
        return (icon: Icons.campaign_rounded, color: _kViolet);
      case 'event_reminder':
        return (icon: Icons.event_rounded, color: const Color(0xFFF59E0B));
      case 'achievement':
        return (icon: Icons.emoji_events_rounded, color: const Color(0xFFFBBF24));
      default:
        return (icon: Icons.notifications_rounded, color: _kSlate);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat('MMM d').format(t);
  }

  // Long-press → confirmation dialog → permanent delete.
  Future<void> _confirmDelete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete notification?',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
        content: const Text(
          'This notification will be permanently removed and will not appear again.',
          style: TextStyle(
              fontFamily: 'Momo', fontSize: 13, color: _kSlate, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Arch', color: _kSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    fontFamily: 'Arch',
                    color: _kRed,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  // Red "Delete" affordance revealed on swipe (matches the reference).
  Widget _swipeBackground() => Container(
        decoration: BoxDecoration(
          color: _kRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(width: 6),
            Text('Delete',
                style: TextStyle(
                    fontFamily: 'Arch',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final g = _glyph;
    final unread = !n.isRead;

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: _swipeBackground(),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: () => _confirmDelete(context),
          child: Container(
            decoration: BoxDecoration(
              // Clean white card when read; subtle violet wash when unread.
              color: unread ? _kViolet.withOpacity(0.06) : _kCard,
              borderRadius: BorderRadius.circular(16),
              border: unread
                  ? Border.all(color: _kViolet.withOpacity(0.18), width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type glyph on a tinted circle.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: g.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(g.icon, color: g.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Arch',
                                  fontWeight:
                                      unread ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14,
                                  color: _kInk)),
                        ),
                        const SizedBox(width: 8),
                        Text(_ago(n.createdAt),
                            style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 11,
                                color: _kSlate.withOpacity(0.8))),
                      ]),
                      const SizedBox(height: 4),
                      Text(n.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 12.5,
                              color: _kSlate,
                              height: 1.35)),
                    ],
                  ),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: g.color, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}