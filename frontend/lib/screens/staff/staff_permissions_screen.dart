// lib/screens/staff/staff_permissions_screen.dart
//
// GOVERNANCE — Permission management (admin only). List staff and assign their
// tier (Staff / Teaching / Admin). Role changes are audit-logged server-side.
// Data: GET /api/moderation/staff/members/, POST .../<id>/role/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kIndigo = kStaffG1;
const _kDeep   = kStaffG2;

// role key -> (label, tier blurb, colour)
const _kRoles = <String, ({String label, String tier, Color color})>{
  'admin': (label: 'Admin', tier: 'Full control · permissions & config',
      color: Color(0xFFE11D48)),
  'teaching_staff': (label: 'Teaching staff', tier: 'Remove content · suspend',
      color: Color(0xFF8E54E9)),
  'non_teaching_staff': (label: 'Staff', tier: 'View · post · work flag queue',
      color: Color(0xFF0EA5A4)),
  'student': (label: 'Student', tier: 'No staff access',
      color: Color(0xFF64748B)),
};

class StaffPermissionsScreen extends StatefulWidget {
  const StaffPermissionsScreen({super.key});

  @override
  State<StaffPermissionsScreen> createState() => _StaffPermissionsScreenState();
}

class _StaffPermissionsScreenState extends State<StaffPermissionsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _canEdit = false;
  bool _busy = false;
  String _me = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.get('/moderation/staff/members/')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _members = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _canEdit = d['can_edit'] == true;
        _me = (d['me'] ?? '').toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRole(Map<String, dynamic> m, String role) async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/moderation/staff/members/${m['id']}/role/',
          body: {'role': role});
      if (mounted) {
        setState(() => m['role'] = role);
        _snack('${m['name']} → ${_kRoles[role]?.label ?? role}');
      }
    } catch (e) {
      _snack('Failed: ${e.toString().contains('403') ? 'admin only' : e}',
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: error ? const Color(0xFFE11D48) : _kDeep,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16)));
  }

  void _openRolePicker(Map<String, dynamic> m) {
    final isMe = (m['id'] ?? '').toString() == _me;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(top: false, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppC.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [
            Text('Set tier · ${m['name']}',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 16,
                    color: AppC.text)),
          ]),
        ),
        ..._kRoles.entries.map((e) {
          final disabled = isMe && e.key != 'admin';
          final current = (m['role'] ?? '') == e.key;
          return ListTile(
            enabled: !disabled,
            onTap: disabled ? null : () {
              Navigator.pop(context);
              if (!current) _setRole(m, e.key);
            },
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: e.value.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.shield_rounded, color: e.value.color, size: 19)),
            title: Text(e.value.label, style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 14,
                color: disabled ? AppC.faint : AppC.text)),
            subtitle: Text(e.value.tier, style: TextStyle(fontFamily: 'Momo',
                fontSize: 11, color: AppC.sub)),
            trailing: current
                ? const Icon(Icons.check_circle_rounded, color: _kDeep)
                : null,
          );
        }),
        const SizedBox(height: 12),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _header(),
        if (!_loading && !_canEdit)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25))),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('View only — only admins can change tiers.',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.text))),
            ]),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kDeep))
              : RefreshIndicator(
                  color: _kDeep,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _memberCard(_members[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _header() => StaffHeader(
    bottomPad: 12,
    horizontal: const EdgeInsets.only(left: 6, right: 14),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop()),
      const Text('🔑', style: TextStyle(fontSize: 20)),
      const SizedBox(width: 8),
      const Expanded(child: T('Permissions',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 19,
              color: Colors.white))),
    ]),
  );

  Widget _memberCard(Map<String, dynamic> m) {
    final role = (m['role'] ?? '').toString();
    final rs = _kRoles[role] ??
        (label: role, tier: '', color: const Color(0xFF64748B));
    final name = (m['name'] ?? 'Staff').toString();
    final avatar = (m['avatar_url'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: (_canEdit && !_busy) ? () => _openRolePicker(m) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppC.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppC.border)),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
              shape: BoxShape.circle,
              image: avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null),
            child: avatar.isEmpty
                ? Center(child: Text(initial, style: const TextStyle(
                    color: Colors.white, fontFamily: 'Arch',
                    fontWeight: FontWeight.bold)))
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14, color: AppC.text)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: rs.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(7)),
              child: Text(rs.label.toUpperCase(), style: TextStyle(
                  fontFamily: 'Arch', fontSize: 8.5, fontWeight: FontWeight.bold,
                  letterSpacing: 0.4, color: rs.color)),
            ),
          ])),
          if (_canEdit)
            Icon(Icons.edit_rounded, color: AppC.faint, size: 18),
        ]),
      ),
    );
  }
}
