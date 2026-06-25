// lib/screens/staff/staff_moderation_screen.dart
//
// Staff Moderation: the reports queue. Lists flagged content/users and lets
// staff triage each — dismiss, mark reviewed, remove content (hard delete),
// or suspend the offending user. Backed by /moderation/staff/reports/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kRed = Color(0xFFFF5858);
const _bg = Color(0xFF0B0B16);
const _card = Color(0xFF15152A);
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

  @override
  void initState() { super.initState(); _load(); }

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
          const Text('Moderation',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: Colors.white)),
          if (_pending > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _kRed,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$_pending',
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
            ),
          ],
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kG2))
          : _reports.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: _kG2,
                  onRefresh: () async {
                    await CacheStore.I.invalidate(_kCacheKey);
                    _load();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _reportCard(_reports[i]),
                  ),
                ),
    );
  }

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.verified_user_rounded, size: 52, color: _kG1),
      const SizedBox(height: 12),
      const Text('Queue clear',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: Colors.white)),
      const SizedBox(height: 6),
      Text('No pending reports to review',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: Colors.white.withOpacity(.5))),
    ]),
  );

  Widget _reportCard(Map<String, dynamic> r) {
    final isUser    = r['is_user_report'] == true;
    final suspended = r['owner_suspended'] == true;
    final gone      = r['content_exists'] != true;
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
                    fontWeight: FontWeight.bold, color: Colors.white.withOpacity(.4))),
            const Spacer(),
            if (suspended)
              const Text('SUSPENDED', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFFAB91))),
          ]),
          const SizedBox(height: 10),
          Text(gone ? '(content already removed)' : (r['preview'] ?? '').toString(),
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  fontStyle: gone ? FontStyle.italic : FontStyle.normal,
                  color: Colors.white.withOpacity(gone ? .4 : .85))),
          if ((r['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('“${r['description']}”',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: Colors.white.withOpacity(.5))),
          ],
          const SizedBox(height: 10),
          Text('by ${r['owner_name'] ?? '—'}  ·  reported by ${r['reporter_name'] ?? '—'}',
              style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                  color: Colors.white.withOpacity(.4))),
        ]),
      ),
    );
  }

  void _openActions(Map<String, dynamic> r) {
    final isUser    = r['is_user_report'] == true;
    final gone      = r['content_exists'] != true;
    final suspended = r['owner_suspended'] == true;
    final hasOwner  = (r['owner_id'] ?? '').toString().isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: _card,
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
          style: const TextStyle(fontFamily: 'Arch', fontSize: 14, color: Colors.white)),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }

  void _confirm(String message, VoidCallback onYes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Confirm',
            style: TextStyle(fontFamily: 'Alfa', color: Colors.white, fontSize: 18)),
        content: Text(message,
            style: TextStyle(fontFamily: 'Momo', color: Colors.white.withOpacity(.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () { Navigator.pop(ctx); onYes(); },
              child: const Text('Confirm', style: TextStyle(color: _kRed))),
        ],
      ),
    );
  }
}
