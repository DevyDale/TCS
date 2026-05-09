// lib/services/notification_service.dart
//
// Global notification state. Bootstraps on login, holds:
//   - unreadCount   (drives the bell badge anywhere in the app)
//   - notifications (the in-memory list shown by NotificationsScreen)
//   - WS connection (auto-reconnect with backoff)
//
// Usage:
//   final svc = NotificationService.instance;
//   await svc.bootstrap();              // after successful login
//   svc.addListener(() { ... });        // listen for changes
//   svc.disposeAll();                   // on logout
//
// All UI just reads svc.unreadCount / svc.notifications and calls
// svc.markRead(id) / svc.markAllRead() / svc.refresh().

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AppNotification {
  final String id;
  final String notifType;
  final String title;
  final String body;
  final String? actorName;
  final String? actorAvatar;
  final String  targetType;
  final String  targetId;
  final bool    isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.notifType,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
    this.actorName,
    this.actorAvatar,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id:          j['id']?.toString() ?? '',
        notifType:   j['notif_type']?.toString() ?? 'system',
        title:       j['title']?.toString() ?? '',
        body:        j['body']?.toString() ?? '',
        actorName:   j['actor_name'] as String?,
        actorAvatar: j['actor_avatar'] as String?,
        targetType:  j['target_type']?.toString() ?? '',
        targetId:    j['target_id']?.toString() ?? '',
        isRead:      j['is_read'] as bool? ?? false,
        createdAt:   DateTime.tryParse(j['created_at']?.toString() ?? '')
                       ?? DateTime.now(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id, notifType: notifType, title: title, body: body,
        actorName: actorName, actorAvatar: actorAvatar,
        targetType: targetType, targetId: targetId,
        isRead: isRead ?? this.isRead, createdAt: createdAt,
      );
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _api = ApiService();
  final _ws  = NotificationWebSocketService();

  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  int _backoffMs = 1000;

  int _unreadCount = 0;
  final List<AppNotification> _items = [];
  bool _loading = false;

  int  get unreadCount => _unreadCount;
  bool get isLoading   => _loading;
  List<AppNotification> get notifications => List.unmodifiable(_items);

  // ── Lifecycle ──────────────────────────────────────────────

  Future<void> bootstrap() async {
    await refresh();
    _connectWS();
  }

  Future<void> disposeAll() async {
    _reconnectTimer?.cancel();
    await _wsSub?.cancel();
    await _ws.disconnect();
    _wsSub = null;
    _items.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  // ── REST ───────────────────────────────────────────────────

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getNotifications() as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      _items
        ..clear()
        ..addAll(results.map((e) =>
            AppNotification.fromJson(e as Map<String, dynamic>)));
      _unreadCount = (data['unread_count'] as int?) ?? 0;
    } catch (_) {
      // swallow — keep stale data, the UI shows what we had
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMore({required int page}) async {
    try {
      final data = await _api.getNotifications(page: page) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? const [];
      _items.addAll(results
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {/* ignore */}
  }

  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1 || _items[i].isRead) return;
    _items[i] = _items[i].copyWith(isRead: true);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    notifyListeners();
    try { await _api.markNotificationRead(id); } catch (_) {}
    _ws.markRead(id); // best-effort live ack
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) _items[i] = _items[i].copyWith(isRead: true);
    }
    _unreadCount = 0;
    notifyListeners();
    try { await _api.markAllNotificationsRead(); } catch (_) {}
    _ws.markAllRead();
  }

  Future<void> delete(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i == -1) return;
    final removed = _items.removeAt(i);
    if (!removed.isRead) {
      _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    }
    notifyListeners();
    try { await _api.deleteNotification(id); } catch (_) {}
  }

  Future<void> clearAll() async {
    _items.clear();
    _unreadCount = 0;
    notifyListeners();
    try { await _api.clearAllNotifications(); } catch (_) {}
  }

  // ── WebSocket ──────────────────────────────────────────────

  void _connectWS() async {
    await _wsSub?.cancel();
    await _ws.connect();
    _wsSub = _ws.stream.listen(
      _handleWsEvent,
      onError: (_) => _scheduleReconnect(),
      onDone:  ()  => _scheduleReconnect(),
    );
    _backoffMs = 1000;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), _connectWS);
    _backoffMs = (_backoffMs * 2).clamp(1000, 30000);
  }

  void _handleWsEvent(Map<String, dynamic> evt) {
    final event = evt['event']?.toString();

    if (event == 'connected') {
      // server tells us authoritative unread count on connect
      final c = evt['unread_count'];
      if (c is int) {
        _unreadCount = c;
        notifyListeners();
      }
      return;
    }

    if (event == 'notification') {
      // Drop duplicates (REST may have already loaded it)
      final id = evt['id']?.toString() ?? '';
      if (id.isEmpty || _items.any((n) => n.id == id)) return;
      final n = AppNotification.fromJson({...evt, 'is_read': false});
      _items.insert(0, n);
      _unreadCount += 1;
      notifyListeners();
    }
  }
}