// lib/screens/staff/staff_clubs_screen.dart
//
// Staff oversight of campus clubs & societies. A read-only monitor (not the
// student arcade clubs UI): club name, category, tagline and member count.
//   GET /clubs/

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class StaffClubsScreen extends StatefulWidget {
  const StaffClubsScreen({super.key});

  @override
  State<StaffClubsScreen> createState() => _StaffClubsScreenState();
}

class _StaffClubsScreenState extends State<StaffClubsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _clubs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getClubs();
      final list = (res is Map ? (res['results'] as List?) : (res as List?)) ?? [];
      if (!mounted) return;
      setState(() {
        _clubs = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _members =>
      _clubs.fold(0, (s, c) => s + ((c['members_count'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: const Color(0xFFEA580C),
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
                      color: Color(0xFFEA580C))))
            else if (_clubs.isEmpty)
              _empty()
            else ...[
              _stats(),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(children: [
                  for (final c in _clubs) ...[
                    _clubCard(c),
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
          const Icon(Icons.local_activity_rounded,
              color: Colors.white70, size: 22),
        ]),
        const SizedBox(height: 14),
        const Text('Clubs',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 6),
        Text('Clubs & societies on campus',
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
          _stat('${_clubs.length}', 'clubs'),
          Container(width: 1, height: 26, color: AppC.border),
          _stat('$_members', 'total members'),
        ]),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontFamily: 'Alfa', fontSize: 19,
              color: Color(0xFFEA580C))),
          const SizedBox(height: 2),
          Text(l, style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
              color: AppC.sub)),
        ]),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_activity_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 12),
          Text('No clubs yet',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
        ])),
      );

  Widget _clubCard(Map<String, dynamic> c) {
    final name = (c['name'] ?? 'Club').toString();
    final category = (c['category'] ?? '').toString();
    final tagline = (c['tagline'] ?? '').toString();
    final logo = (c['logo_url'] ?? '').toString();
    final members = (c['members_count'] as int?) ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: staffCard(),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
            image: logo.isNotEmpty
                ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                : null),
          alignment: Alignment.center,
          child: logo.isNotEmpty ? null : Text(initial,
              style: const TextStyle(fontFamily: 'Alfa', fontSize: 18,
                  color: Color(0xFFEA580C))),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                      fontWeight: FontWeight.bold, color: AppC.text))),
              if (category.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(category,
                      style: const TextStyle(fontFamily: 'Arch', fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC2410C))),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(
                tagline.isNotEmpty
                    ? tagline
                    : '$members ${members == 1 ? 'member' : 'members'}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: AppC.sub)),
          ],
        )),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$members', style: TextStyle(fontFamily: 'Alfa', fontSize: 15,
              color: AppC.text)),
          Text('members', style: TextStyle(fontFamily: 'Momo', fontSize: 9,
              color: AppC.faint)),
        ]),
      ]),
    );
  }
}
