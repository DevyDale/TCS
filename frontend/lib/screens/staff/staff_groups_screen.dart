// lib/screens/staff/staff_groups_screen.dart
//
// Staff oversight of student study groups. A read-only monitor (not the
// student study-hub UI): who's studying together, what subject, how many
// members, and which are active now.  GET /groups/

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class StaffGroupsScreen extends StatefulWidget {
  const StaffGroupsScreen({super.key});

  @override
  State<StaffGroupsScreen> createState() => _StaffGroupsScreenState();
}

class _StaffGroupsScreenState extends State<StaffGroupsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getGroups();
      final list = (res is Map ? (res['results'] as List?) : (res as List?)) ?? [];
      if (!mounted) return;
      setState(() {
        _groups = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _activeCount =>
      _groups.where((g) => g['active_now'] == true).length;
  int get _members =>
      _groups.fold(0, (s, g) => s + ((g['members_count'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: const Color(0xFF059669),
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator(
                      color: Color(0xFF059669))))
            else if (_groups.isEmpty)
              _empty()
            else ...[
              _stats(),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(children: [
                  for (final g in _groups) ...[
                    _groupCard(g),
                    const SizedBox(height: 10),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return StaffHeader(
      bottomPad: 22,
      horizontal: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20)),
          ),
          const Spacer(),
          const Icon(Icons.groups_rounded, color: Colors.white70, size: 22),
        ]),
        const SizedBox(height: 14),
        const Text('Study groups',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 6),
        Text('What students are studying together',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.85))),
      ]),
    );
  }

  Widget _stats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: staffCard(),
        child: Row(children: [
          _stat('${_groups.length}', 'groups'),
          _divider(),
          _stat('$_activeCount', 'active now'),
          _divider(),
          _stat('$_members', 'members'),
        ]),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontFamily: 'Alfa', fontSize: 19,
              color: Color(0xFF059669))),
          const SizedBox(height: 2),
          Text(l, style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
              color: AppC.sub)),
        ]),
      );

  Widget _divider() =>
      Container(width: 1, height: 26, color: AppC.border);

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.groups_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 12),
          Text('No study groups yet',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
        ])),
      );

  Widget _groupCard(Map<String, dynamic> g) {
    final emoji = (g['display_emoji'] ?? g['theme_icon'] ?? '📚').toString();
    final name = (g['name'] ?? 'Study group').toString();
    final subject = (g['display_subject'] ?? g['subject'] ?? '').toString();
    final members = (g['members_count'] as int?) ?? 0;
    final active = g['active_now'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: staffCard(),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14)),
          child: Text(emoji, style: const TextStyle(fontSize: 22))),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                    fontWeight: FontWeight.bold, color: AppC.text)),
            const SizedBox(height: 3),
            Text([
              if (subject.isNotEmpty) subject,
              '$members ${members == 1 ? 'member' : 'members'}',
            ].join('  ·  '),
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: AppC.sub)),
          ],
        )),
        if (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
              SizedBox(width: 4),
              Text('Active', style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                  fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
            ]),
          ),
      ]),
    );
  }
}
