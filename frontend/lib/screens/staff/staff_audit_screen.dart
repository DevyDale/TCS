// lib/screens/staff/staff_audit_screen.dart
//
// GOVERNANCE — Audit log. An append-only, searchable record of every staff
// action (moderation, wellbeing, restores…). The accountability layer.
// Data: GET /api/moderation/staff/audit/?q=.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';
import 'package:tcs_app/services/csv_export.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kIndigo = kStaffG1;
const _kDeep   = kStaffG2;

class StaffAuditScreen extends StatefulWidget {
  const StaffAuditScreen({super.key});

  @override
  State<StaffAuditScreen> createState() => _StaffAuditScreenState();
}

class _StaffAuditScreenState extends State<StaffAuditScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final q = _searchCtrl.text.trim();
    // Searching → live fetch. Default view → stale-while-revalidate: paints
    // instantly from cache on re-open, then refreshes in the background.
    if (q.isNotEmpty) {
      setState(() => _loading = true);
      try {
        final d = await _api.get('/moderation/staff/audit/',
            query: {'q': q}) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _events = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    CacheStore.I.swr(
      'audit:log',
      fetch: () => _api.get('/moderation/staff/audit/'),
      onData: (data, _) {
        if (!mounted) return;
        final d = (data as Map).cast<String, dynamic>();
        setState(() {
          _events = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _export() async {
    final rows = <List<String>>[
      ['Time', 'Staff', 'Action', 'Detail', 'Target type', 'Target id'],
      ..._events.map((e) => [
            (e['created_at'] ?? '').toString(),
            (e['actor_name'] ?? '').toString(),
            (e['action'] ?? '').toString(),
            (e['summary'] ?? '').toString(),
            (e['target_type'] ?? '').toString(),
            (e['target_id'] ?? '').toString(),
          ]),
    ];
    try {
      await exportCsv(filename: 'tcs_audit_log.csv', rows: rows);
    } catch (_) {}
  }

  // Group actions for a friendly icon + colour.
  ({IconData icon, Color color}) _style(String action) {
    if (action.startsWith('wellbeing')) {
      return (icon: Icons.favorite_rounded, color: const Color(0xFF0EA5A4));
    }
    if (action.contains('remove') || action.contains('suspend')) {
      return (icon: Icons.gavel_rounded, color: const Color(0xFFE11D48));
    }
    if (action.contains('hide')) {
      return (icon: Icons.visibility_off_rounded, color: const Color(0xFFF59E0B));
    }
    if (action.contains('restore') || action.contains('unsuspend')) {
      return (icon: Icons.lock_open_rounded, color: const Color(0xFF22C55E));
    }
    return (icon: Icons.shield_rounded, color: _kIndigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _header(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kDeep))
              : _events.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      color: _kDeep,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _eventCard(_events[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 12,
      horizontal: const EdgeInsets.only(left: 6, right: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop()),
          const Text('🧾', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Expanded(child: T('Audit Log',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 19,
                  color: Colors.white))),
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white,
                  size: 20),
              tooltip: 'Export CSV',
              onPressed: _export),
        ]),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                color: AppC.text),
            cursorColor: const Color(0xFF7C3AED),
            decoration: InputDecoration(
              hintText: 'Search by staff, action or detail…',
              hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  color: AppC.faint),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF7C3AED), size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () { _searchCtrl.clear(); _onSearch(''); },
                      child: Icon(Icons.close_rounded,
                          color: AppC.sub, size: 18))
                  : null,
              filled: true,
              fillColor: AppC.card,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
    Icon(Icons.history_rounded, size: 52, color: AppC.border),
    const SizedBox(height: 14),
    Text('No actions logged yet', style: TextStyle(fontFamily: 'Momo',
        fontSize: 13.5, color: AppC.sub)),
  ]));

  Widget _eventCard(Map<String, dynamic> e) {
    final st = _style((e['action'] ?? '').toString());
    final actor = (e['actor_name'] ?? 'System').toString();
    final summary = (e['summary'] ?? '').toString();
    final action = (e['action'] ?? '').toString().replaceAll('.', ' · ');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppC.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppC.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: st.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(st.icon, color: st.color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Flexible(child: Text(actor, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13, color: AppC.text))),
            const SizedBox(width: 8),
            Text(_ago(e['created_at'] as String?),
                style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                    color: AppC.faint)),
          ]),
          const SizedBox(height: 2),
          Text(action.toUpperCase(),
              style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                  fontWeight: FontWeight.bold, letterSpacing: 0.5,
                  color: st.color)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(summary, style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                height: 1.35, color: AppC.sub)),
          ],
        ])),
      ]),
    );
  }

  String _ago(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}
