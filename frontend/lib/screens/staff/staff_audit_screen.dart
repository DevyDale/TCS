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

const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

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
    setState(() => _loading = true);
    try {
      final d = await _api.get('/moderation/staff/audit/', query: {
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _events = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
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
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 6, right: 14, bottom: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kIndigo, _kDeep],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
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
        ]),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(0.18))),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: const TextStyle(fontFamily: 'Momo', fontSize: 14,
                color: Colors.white),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: 'Search by staff, action or detail…',
              hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  color: Colors.white60),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white70,
                  size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 12)),
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
