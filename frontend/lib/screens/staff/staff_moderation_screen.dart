// lib/screens/staff/staff_moderation_screen.dart
//
// Staff Moderation: the reports queue. Lists flagged content/users and lets
// staff triage each — dismiss, mark reviewed, remove content (hard delete),
// or suspend the offending user. Backed by /moderation/staff/reports/.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kRed = Color(0xFFFF5858);
const _kAmber = Color(0xFFF59E0B);
Color get _bg => AppC.bg;
Color get _card => AppC.card;
const _kCacheKey = 'moderation:queue';

class StaffModerationScreen extends StatefulWidget {
  const StaffModerationScreen({super.key});
  @override
  State<StaffModerationScreen> createState() => _StaffModerationScreenState();
}

class _StaffModerationScreenState extends State<StaffModerationScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _reports = [];
  int _pending = 0;
  bool _loading = true;
  bool _busy = false;

  String _tab = 'reports'; // 'reports' | 'suspended'
  List<Map<String, dynamic>> _suspended = [];
  bool _loadingSusp = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _loadSuspended() async {
    setState(() => _loadingSusp = true);
    try {
      final d = await _api.get('/moderation/staff/suspended/') as List;
      if (mounted) setState(() {
        _suspended = d.cast<Map<String, dynamic>>();
        _loadingSusp = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSusp = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> u) async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/moderation/staff/suspended/${u['id']}/restore/');
      _snack('${u['name'] ?? 'User'} restored');
      _loadSuspended();
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _load() {
    CacheStore.I.swr(
      _kCacheKey,
      fetch: () => _api.get('/moderation/staff/reports/'),
      onData: (data, fresh) {
        if (!mounted) return;
        final m = (data as Map?) ?? const {};
        setState(() {
          _reports = ((m['results'] as List?) ?? []).cast<Map<String, dynamic>>();
          _pending = ((m['counts'] as Map?)?['pending'] as int?) ?? _reports.length;
          _loading = false;
        });
      },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  Future<void> _act(Map<String, dynamic> report, String action,
      {String? reason}) async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/moderation/staff/reports/${report['id']}/action/',
          body: {'action': action, if (reason != null) 'reason': reason});
      await CacheStore.I.invalidate(_kCacheKey);
      _load();
      _snack(_actionLabel(action));
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _actionLabel(String a) => switch (a) {
        'dismiss'        => 'Report dismissed',
        'review'         => 'Marked reviewed',
        'hide_content'   => 'Content hidden',
        'unhide_content' => 'Content unhidden',
        'remove_content' => 'Content removed',
        'suspend_user'   => 'User suspended',
        'unsuspend_user' => 'User unsuspended',
        _                => 'Done',
      };

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: error ? _kRed : _kG2,
      behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          T('Moderation',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
          if (_pending > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _kRed,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$_pending',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 12, color: AppC.text)),
            ),
          ],
        ]),
      ),
      body: Column(children: [
        _toggle(),
        Expanded(child: _tab == 'reports' ? _reportsBody() : _suspendedBody()),
      ]),
    );
  }

  Widget _toggle() {
    Widget pill(String key, String label, {int? badge}) {
      final sel = _tab == key;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_tab == key) return;
            HapticFeedback.selectionClick();
            setState(() => _tab = key);
            if (key == 'suspended' && _suspended.isEmpty) _loadSuspended();
          },
          child: Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: sel
                ? BoxDecoration(
                    gradient: const LinearGradient(colors: [_kG1, _kG2]),
                    borderRadius: BorderRadius.circular(10))
                : null,
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: sel ? Colors.white : AppC.sub)),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: sel ? Colors.white24 : _kRed,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$badge', style: const TextStyle(fontFamily: 'Arch',
                      fontSize: 10, fontWeight: FontWeight.bold,
                      color: Colors.white)),
                ),
              ],
            ])),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppC.border)),
      child: Row(children: [
        pill('reports', 'Reports', badge: _pending),
        pill('suspended', 'Suspended'),
      ]),
    );
  }

  Widget _reportsBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_reports.isEmpty) return _empty();
    return RefreshIndicator(
      color: _kG2,
      onRefresh: () async {
        await CacheStore.I.invalidate(_kCacheKey);
        _load();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _reportCard(_reports[i]),
      ),
    );
  }

  Widget _suspendedBody() {
    if (_loadingSusp) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_suspended.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_open_rounded, size: 52, color: _kG1),
        const SizedBox(height: 12),
        T('No suspended students',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
      ]));
    }
    return RefreshIndicator(
      color: _kG2,
      onRefresh: _loadSuspended,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        itemCount: _suspended.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _suspendedCard(_suspended[i]),
      ),
    );
  }

  Widget _suspendedCard(Map<String, dynamic> u) {
    final name = (u['name'] ?? 'User').toString();
    final reason = (u['reason'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppC.border)),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: const BoxDecoration(
              color: Color(0xFFB23A48), shape: BoxShape.circle),
          child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontFamily: 'Arch',
                  fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14, color: AppC.text)),
          if (reason.isNotEmpty)
            Text(reason, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: AppC.sub)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _busy ? null : () => _restore(u),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                borderRadius: BorderRadius.circular(11)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_open_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              T('Restore', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.verified_user_rounded, size: 52, color: _kG1),
      const SizedBox(height: 12),
      T('Queue clear',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
      const SizedBox(height: 6),
      T('No pending reports to review',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: AppC.text.withOpacity(.5))),
    ]),
  );

  Widget _reportCard(Map<String, dynamic> r) {
    final isUser    = r['is_user_report'] == true;
    final suspended = r['owner_suspended'] == true;
    final gone      = r['content_exists'] != true;
    final flags     = (r['flag_count'] as num?)?.toInt() ?? 0;
    final hidden    = r['content_hidden'] == true;
    return GestureDetector(
      onTap: _busy ? null : () => _openActions(r),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kRed.withOpacity(.22)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _kRed.withOpacity(.18),
                  borderRadius: BorderRadius.circular(8)),
              child: Text((r['reason_label'] ?? '').toString().toUpperCase(),
                  style: const TextStyle(fontFamily: 'Arch', fontSize: 9,
                      fontWeight: FontWeight.bold, color: _kRed)),
            ),
            const SizedBox(width: 8),
            Text((isUser ? 'USER' : (r['content_type'] ?? '').toString()).toUpperCase(),
                style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                    fontWeight: FontWeight.bold, color: AppC.text.withOpacity(.4))),
            if (flags > 1) ...[
              const SizedBox(width: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.flag_rounded, size: 11, color: _kRed),
                const SizedBox(width: 2),
                Text('$flags', style: const TextStyle(fontFamily: 'Arch',
                    fontSize: 10, fontWeight: FontWeight.bold, color: _kRed)),
              ]),
            ],
            const Spacer(),
            if (hidden) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: _kAmber.withOpacity(.18),
                    borderRadius: BorderRadius.circular(7)),
                child: const Text('HIDDEN', style: TextStyle(fontFamily: 'Arch',
                    fontSize: 8.5, fontWeight: FontWeight.bold, color: _kAmber)),
              ),
              const SizedBox(width: 6),
            ],
            if (suspended)
              const T('SUSPENDED', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFFAB91))),
          ]),
          const SizedBox(height: 10),
          Text(gone ? '(content already removed)' : (r['preview'] ?? '').toString(),
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  fontStyle: gone ? FontStyle.italic : FontStyle.normal,
                  color: AppC.text.withOpacity(gone ? .4 : .85))),
          if ((r['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('“${r['description']}”',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: AppC.text.withOpacity(.5))),
          ],
          const SizedBox(height: 10),
          Text('by ${r['owner_name'] ?? '—'}  ·  reported by ${r['reporter_name'] ?? '—'}',
              style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                  color: AppC.text.withOpacity(.4))),
        ]),
      ),
    );
  }

  void _openActions(Map<String, dynamic> r) {
    final isUser    = r['is_user_report'] == true;
    final gone      = r['content_exists'] != true;
    final hidden    = r['content_hidden'] == true;
    final suspended = r['owner_suspended'] == true;
    final hasOwner  = (r['owner_id'] ?? '').toString().isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(3))),
            _sheetAction(Icons.close_rounded, 'Dismiss report', Colors.white70,
                () => _act(r, 'dismiss')),
            _sheetAction(Icons.check_rounded, 'Mark reviewed (no action)', _kG1,
                () => _act(r, 'review')),
            if (!isUser && !gone && !hidden)
              _sheetAction(Icons.visibility_off_rounded, 'Hide content (reversible)',
                  _kAmber, () => _act(r, 'hide_content')),
            if (!isUser && !gone && hidden)
              _sheetAction(Icons.visibility_rounded, 'Unhide content', _kG1,
                  () => _act(r, 'unhide_content')),
            if (!isUser && !gone)
              _sheetAction(Icons.delete_forever_rounded, 'Remove content (permanent)',
                  _kRed, () => _confirm(
                      'Permanently delete this content?', () => _act(r, 'remove_content'))),
            if (hasOwner && !suspended)
              _sheetAction(Icons.gavel_rounded, 'Suspend user', _kRed,
                  () => _confirm('Suspend ${r['owner_name'] ?? 'this user'}? They will be '
                      'unable to log in.', () => _act(r, 'suspend_user'))),
            if (hasOwner && suspended)
              _sheetAction(Icons.lock_open_rounded, 'Unsuspend user', _kG1,
                  () => _act(r, 'unsuspend_user')),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  Widget _sheetAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(fontFamily: 'Arch', fontSize: 14, color: AppC.text)),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }

  void _confirm(String message, VoidCallback onYes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: T('Confirm',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 18)),
        content: Text(message,
            style: TextStyle(fontFamily: 'Momo', color: AppC.text.withOpacity(.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const T('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () { Navigator.pop(ctx); onYes(); },
              child: const T('Confirm', style: TextStyle(color: _kRed))),
        ],
      ),
    );
  }
}
