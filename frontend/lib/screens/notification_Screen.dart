// lib/screens/notifications/notifications_screen.dart
//
// Reads from NotificationService.instance — the screen is a thin view
// that re-renders when the service notifies listeners. Tapping an item
// marks it read and dispatches navigation by notif_type.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

const _kViolet = Color(0xFF8E54E9);
const _kBlue   = Color(0xFF6DD5FA);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF7A8294);
const _kBg     = Color(0xFFF7F8FA);
const _kCard   = Colors.white;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChange);
    _svc.refresh();
  }

  @override
  void dispose() {
    _svc.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() { if (mounted) setState(() {}); }

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

  @override
  Widget build(BuildContext context) {
    final items = _svc.notifications;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notifications',
          style: TextStyle(fontFamily: 'Alfa', color: _kInk, fontSize: 18)),
        iconTheme: const IconThemeData(color: _kInk),
        actions: [
          if (items.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: _kInk),
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                HapticFeedback.lightImpact();
                switch (value) {
                  case 'mark_all':
                    await _svc.markAllRead();
                    break;
                  case 'clear_all':
                    final ok = await _confirmClearAll();
                    if (ok == true) await _svc.clearAll();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'mark_all',
                  child: Row(children: [
                    Icon(Icons.done_all_rounded, size: 18, color: _kViolet),
                    SizedBox(width: 10),
                    Text('Mark all read',
                      style: TextStyle(fontFamily: 'Arch',
                        fontSize: 13, color: _kInk)),
                  ]),
                ),
                PopupMenuItem<String>(
                  value: 'clear_all',
                  child: Row(children: [
                    Icon(Icons.delete_sweep_rounded,
                      size: 18, color: Color(0xFFFF5858)),
                    SizedBox(width: 10),
                    Text('Clear all',
                      style: TextStyle(fontFamily: 'Arch', fontSize: 13,
                        color: Color(0xFFFF5858),
                        fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _kViolet,
        onRefresh: _svc.refresh,
        child: _svc.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator(color: _kViolet))
            : items.isEmpty
                ? _empty()
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _NotifTile(
                      n: items[i],
                      onTap:    () => _onTap(items[i]),
                      onDelete: () => _svc.delete(items[i].id),
                    ),
                  ),
      ),
    );
  }
  Future<bool?> _confirmClearAll() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear all notifications?',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
        content: const Text(
          'This will permanently remove every notification. This action cannot be undone.',
          style: TextStyle(fontFamily: 'Momo',
            fontSize: 13, color: _kSlate, height: 1.4),
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
              style: TextStyle(fontFamily: 'Arch',
                color: Color(0xFFFF5858), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 32),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_kViolet, _kBlue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
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

          const Text(
            "You're all caught up",
            style: TextStyle(
              fontFamily: 'Alfa',
              fontSize: 19,
              color: _kInk,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),

          const Text(
            'Game requests, chats, highlights and more will show here',
            style: TextStyle(
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

// ── Tile ──────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap, onDelete;
  const _NotifTile({required this.n, required this.onTap, required this.onDelete});

  ({String emoji, Color color}) get _glyph {
    switch (n.notifType) {
      case 'game_request':        return (emoji: '🎮', color: const Color(0xFFF7971E));
      case 'chat_request':        return (emoji: '💬', color: _kBlue);
      case 'chat_message':        return (emoji: '✉️', color: _kBlue);
      case 'highlight':           return (emoji: '✨', color: _kViolet);
      case 'study_buddy_request': return (emoji: '📚', color: const Color(0xFF4F46E5));
      case 'study_group_invite':  return (emoji: '👥', color: const Color(0xFF10B981));
      case 'follow':              return (emoji: '➕', color: const Color(0xFFEC4899));
      case 'like':                return (emoji: '❤️', color: const Color(0xFFFF5858));
      case 'comment':             return (emoji: '💭', color: const Color(0xFF6366F1));
      case 'event_reminder':      return (emoji: '📅', color: const Color(0xFFF59E0B));
      case 'achievement':         return (emoji: '🏆', color: const Color(0xFFFBBF24));
      default:                    return (emoji: '🔔', color: _kSlate);
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60)  return 'now';
    if (d.inMinutes < 60)  return '${d.inMinutes}m';
    if (d.inHours   < 24)  return '${d.inHours}h';
    if (d.inDays    < 7)   return '${d.inDays}d';
    return DateFormat('MMM d').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final g = _glyph;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(color: const Color(0xFFFF5858).withOpacity(0.12),
          borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5858)),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: n.isRead ? Colors.grey.shade200 : g.color.withOpacity(0.35),
                width: n.isRead ? 1 : 1.4),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: g.color.withOpacity(0.12),
                  shape: BoxShape.circle),
                child: Center(child: Text(g.emoji,
                  style: const TextStyle(fontSize: 19)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Arch',
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                      fontSize: 14, color: _kInk))),
                  const SizedBox(width: 8),
                  Text(_ago(n.createdAt),
                    style: TextStyle(fontFamily: 'Momo',
                      fontSize: 11, color: _kSlate.withOpacity(0.8))),
                ]),
                const SizedBox(height: 4),
                Text(n.body,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12.5, color: _kSlate, height: 1.35)),
              ])),
              if (!n.isRead)
                Container(margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: g.color, shape: BoxShape.circle)),
            ]),
          ),
        ),
      ),
    );
  }
}