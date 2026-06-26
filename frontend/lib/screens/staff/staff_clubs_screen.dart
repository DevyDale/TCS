// lib/screens/staff/staff_clubs_screen.dart
//
// Staff clubs hub — one screen consolidating the student club features:
//   • see every club on the platform (GET /clubs/) with search + stats
//   • create a club (POST /clubs/)
//   • join / leave a club (POST /clubs/<id>/join/, DELETE …/leave/)
//   • remove (dissolve) a club as staff (DELETE /clubs/<id>/)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kOrange = Color(0xFFEA580C);

const _kClubCategories = <List<String>>[
  ['academic', 'Academic'], ['sports', 'Sports'], ['arts', 'Arts'],
  ['cultural', 'Cultural'], ['technology', 'Technology'],
  ['social_service', 'Social Service'], ['business', 'Business'],
  ['gaming', 'Gaming'], ['other', 'Other'],
];

class StaffClubsScreen extends StatefulWidget {
  const StaffClubsScreen({super.key});

  @override
  State<StaffClubsScreen> createState() => _StaffClubsScreenState();
}

class _StaffClubsScreenState extends State<StaffClubsScreen> {
  final _api = ApiService();
  final _search = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _clubs = [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _clubs;
    return _clubs.where((c) {
      final hay = '${c['name']} ${c['category']} ${c['tagline']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  int get _members =>
      _clubs.fold(0, (s, c) => s + ((c['members_count'] as int?) ?? 0));

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : _kOrange,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo',
          color: Colors.white))));
  }

  Future<void> _toggleJoin(Map<String, dynamic> c) async {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty || _busy.contains(id)) return;
    final joined = c['is_member'] == true;
    setState(() => _busy.add(id));
    HapticFeedback.selectionClick();
    try {
      if (joined) {
        await _api.leaveClub(id);
      } else {
        await _api.joinClub(id);
      }
      await _load();
    } catch (_) {
      _snack('Could not ${joined ? 'leave' : 'join'} the club.', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final id = (c['id'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Remove this club?',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Text('"${c['name']}" will be dissolved and removed from the '
            'platform for everyone.',
            style: TextStyle(fontFamily: 'Momo', color: AppC.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFB3261E),
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy.add(id));
    try {
      await _api.dissolveClub(id);
      _snack('Club removed.');
      await _load();
    } catch (_) {
      _snack('Could not remove the club.', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kOrange,
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New club',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: _kOrange,
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
                  child: Center(child: CircularProgressIndicator(color: _kOrange)))
            else ...[
              if (_clubs.isNotEmpty) ...[
                _stats(),
                const SizedBox(height: 14),
              ],
              StaffSearchBar(
                  controller: _search,
                  hint: 'Search clubs…',
                  onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 12),
              if (_clubs.isEmpty)
                _empty()
              else if (_filtered.isEmpty)
                staffNoResults('No clubs match.')
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  child: Column(children: [
                    for (final c in _filtered) ...[
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
        Text('Create, join & manage clubs on campus',
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
              color: _kOrange)),
          const SizedBox(height: 2),
          Text(l, style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
              color: AppC.sub)),
        ]),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_activity_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 12),
          Text('No clubs yet',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
          const SizedBox(height: 6),
          Text('Tap "New club" to start one.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
        ])),
      );

  Widget _clubCard(Map<String, dynamic> c) {
    final id = (c['id'] ?? '').toString();
    final name = (c['name'] ?? 'Club').toString();
    final category = (c['category'] ?? '').toString();
    final tagline = (c['tagline'] ?? '').toString();
    final logo = (c['logo_url'] ?? '').toString();
    final members = (c['members_count'] as int?) ?? 0;
    final joined = c['is_member'] == true;
    final busy = _busy.contains(id);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: staffCard(),
      child: Column(children: [
        Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _kOrange.withValues(alpha: 0.12),
              image: logo.isNotEmpty
                  ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                  : null),
            alignment: Alignment.center,
            child: logo.isNotEmpty ? null : Text(initial,
                style: const TextStyle(fontFamily: 'Alfa', fontSize: 18,
                    color: _kOrange)),
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
                      color: _kOrange.withValues(alpha: 0.14),
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
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.people_alt_rounded, size: 14, color: AppC.faint),
          const SizedBox(width: 5),
          Text('$members', style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
              color: AppC.sub)),
          const Spacer(),
          // Join / leave
          GestureDetector(
            onTap: busy ? null : () => _toggleJoin(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: joined ? AppC.bg : _kOrange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: joined ? AppC.border : _kOrange)),
              child: busy
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(joined ? 'Joined' : 'Join',
                      style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: joined ? AppC.sub : Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // Staff remove
          GestureDetector(
            onTap: busy ? null : () => _delete(c),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFB3261E).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFB3261E), size: 18)),
          ),
        ]),
      ]),
    );
  }

  // ── Create club sheet ─────────────────────────────────────
  void _openCreate() {
    final nameCtrl = TextEditingController();
    final taglineCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'other';
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          InputDecoration dec(String h) => InputDecoration(
                hintText: h,
                hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                    color: AppC.faint),
                filled: true, fillColor: AppC.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none));

          Future<void> submit() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) { _snack('Give the club a name.', error: true); return; }
            setSheet(() => submitting = true);
            try {
              await _api.createClub({
                'name': name,
                'tagline': taglineCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'category': category,
              });
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              _snack('Club created ✓');
              await _load();
            } catch (_) {
              setSheet(() => submitting = false);
              _snack('Could not create the club.', error: true);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.local_activity_rounded, color: _kOrange, size: 20),
                const SizedBox(width: 10),
                Text('New club', style: TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: AppC.text)),
              ]),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl,
                  style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
                  decoration: dec('Club name')),
              const SizedBox(height: 10),
              TextField(controller: taglineCtrl,
                  style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
                  decoration: dec('Short tagline (optional)')),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, maxLines: 3,
                  style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
                  decoration: dec('What is this club about? (optional)')),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Category', style: TextStyle(fontFamily: 'Arch',
                    fontSize: 12, fontWeight: FontWeight.bold, color: AppC.sub)),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final cat in _kClubCategories)
                  GestureDetector(
                    onTap: () => setSheet(() => category = cat[0]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: category == cat[0] ? _kOrange : AppC.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: category == cat[0]
                            ? _kOrange : AppC.border)),
                      child: Text(cat[1], style: TextStyle(fontFamily: 'Arch',
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: category == cat[0] ? Colors.white : AppC.sub)),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: submitting ? null : submit,
                  style: ElevatedButton.styleFrom(backgroundColor: _kOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create club',
                          style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
