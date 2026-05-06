// lib/screens/groups/study_hub_search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _indigo = Color(0xFF3F51B5);
const _deep   = Color(0xFF512DA8);

class StudyHubSearchScreen extends StatefulWidget {
  const StudyHubSearchScreen({super.key});
  @override
  State<StudyHubSearchScreen> createState() => _StudyHubSearchScreenState();
}

class _StudyHubSearchScreenState extends State<StudyHubSearchScreen> {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;

  List<Map<String, dynamic>> _groups    = [];
  List<Map<String, dynamic>> _buddies   = [];

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _groups = []; _buddies = []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final groupsRes = await _api.getGroups(q: q) as List;
      final buddyRes  = await _api.get('/groups/buddies/', query: {'subject': q}) as List;
      setState(() {
        _groups  = groupsRes.cast<Map<String, dynamic>>();
        _buddies = buddyRes.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        // Header + search
        Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 8, right: 16, bottom: 14),
          color: Colors.white,
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_rounded, size: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _ctrl, autofocus: true, enableSuggestions: false,
                onChanged: _onChanged,
                style: const TextStyle(fontFamily: 'Momo', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search groups, buddies, subjects...',
                  hintStyle: TextStyle(fontFamily: 'Momo', color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            )),
          ]),
        ),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _indigo)))
        else if (_ctrl.text.isEmpty)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.school_outlined, size: 52, color: _indigo.withOpacity(0.25)),
            const SizedBox(height: 14),
            Text('Search Study Hub', style: TextStyle(fontFamily: 'Alfa', fontSize: 17,
                color: _indigo.withOpacity(0.5))),
            const SizedBox(height: 6),
            Text('Find groups, study buddies, or subjects',
                style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: Colors.grey.shade400)),
          ])))
        else
          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_groups.isNotEmpty) ...[
                Text('Groups (${_groups.length})', style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 16, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 10),
                ..._groups.map((g) => _groupTile(g)),
                const SizedBox(height: 20),
              ],
              if (_buddies.isNotEmpty) ...[
                Text('Study Buddies (${_buddies.length})', style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 16, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 10),
                ..._buddies.map((b) => _buddyTile(b)),
              ],
              if (_groups.isEmpty && _buddies.isEmpty) ...[
                const SizedBox(height: 60),
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No results found', style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 16, color: Colors.grey.shade400)),
                ])),
              ],
            ],
          )),
      ]),
    );
  }

  Widget _groupTile(Map<String, dynamic> g) {
    final icon = g['theme_icon'] as String? ?? '👥';
    final isMember = g['is_joined'] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_indigo, _deep]),
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g['name'] as String? ?? '', style: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
          Text('${g['members_count'] ?? 0} members · ${g['category'] ?? ''}',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: Colors.grey.shade500)),
        ])),
        GestureDetector(
          onTap: () async {
            if (!isMember) { await _api.joinGroup(g['id']); _search(_ctrl.text); }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isMember ? Colors.green.shade50 : _indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isMember ? Colors.green.shade200 : _indigo.withOpacity(0.3))),
            child: Text(isMember ? 'Joined ✓' : 'Join', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12,
                color: isMember ? Colors.green.shade700 : _indigo)),
          ),
        ),
      ]),
    );
  }

  Widget _buddyTile(Map<String, dynamic> b) {
    final name    = b['name'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_kG2, _indigo])),
          child: Center(child: Text(initial, style: const TextStyle(color: Colors.white,
              fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
              fontSize: 14, color: Color(0xFF1A1A2E))),
          Text(b['subjects'] as String? ?? '', style: TextStyle(fontFamily: 'Momo',
              fontSize: 12, color: Colors.grey.shade500)),
        ])),
        Container(width: 10, height: 10,
          decoration: BoxDecoration(color: b['is_online'] == true
              ? Colors.green.shade500 : Colors.grey.shade400, shape: BoxShape.circle)),
      ]),
    );
  }
}