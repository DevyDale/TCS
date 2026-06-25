// lib/screens/staff/staff_wellbeing_screen.dart
//
// WELLBEING queue — an early-support signal, NOT a clinical assessment.
// Lists "quiet" students (normally active, gone silent) so staff can reach
// out before a student crosses a help-seeking threshold. Actions: Reach out,
// Escalate to senior staff, Mark handled. Escalate is in-app routing, not a
// substitute for the college's formal welfare process.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/dashboard/other_user_profile_Screen.dart';

const _kTeal  = Color(0xFF0EA5A4);
const _kIndigo = Color(0xFF3F51B5);
const _kAmber = Color(0xFFF59E0B);
const _kRed   = Color(0xFFE11D48);

class StaffWellbeingScreen extends StatefulWidget {
  const StaffWellbeingScreen({super.key});

  @override
  State<StaffWellbeingScreen> createState() => _StaffWellbeingScreenState();
}

class _StaffWellbeingScreenState extends State<StaffWellbeingScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.get('/moderation/staff/wellbeing/')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(Map<String, dynamic> s, String action) async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.post('/moderation/staff/wellbeing/${s['id']}/action/',
          body: {'action': action});
      if (mounted) {
        setState(() => _items.removeWhere((x) => x['id'] == s['id']));
        _snack(switch (action) {
          'reach_out' => 'Logged — reaching out to ${s['name']}',
          'escalate'  => 'Escalated to senior staff',
          _           => 'Marked handled',
        });
      }
      if (action == 'reach_out' && mounted) {
        final uid = (s['user_id'] ?? '').toString();
        if (uid.isNotEmpty) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OtherUserProfileScreen(userId: uid)));
        }
      }
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: error ? _kRed : _kTeal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16)));
  }

  void _openActions(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(top: false, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppC.border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        _action(Icons.waving_hand_rounded, 'Reach out', _kTeal,
            'Open their profile to message them, and log it.',
            () { Navigator.pop(context); _act(s, 'reach_out'); }),
        _action(Icons.priority_high_rounded, 'Escalate to senior staff', _kAmber,
            'Notifies senior staff in-app. Follow your college welfare process.',
            () { Navigator.pop(context); _act(s, 'escalate'); }),
        _action(Icons.check_circle_rounded, 'Mark handled', _kIndigo,
            'Remove from the queue — already attended to.',
            () { Navigator.pop(context); _act(s, 'handled'); }),
        const SizedBox(height: 12),
      ])),
    );
  }

  Widget _action(IconData icon, String label, Color color, String sub,
      VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20)),
      title: Text(label, style: TextStyle(fontFamily: 'Arch',
          fontWeight: FontWeight.bold, fontSize: 14, color: AppC.text)),
      subtitle: Text(sub, style: TextStyle(fontFamily: 'Momo',
          fontSize: 11, color: AppC.sub)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _banner(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kTeal))
              : _items.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      color: _kTeal,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _card(_items[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _banner() => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kTeal.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kTeal.withOpacity(0.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.favorite_rounded, color: _kTeal, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(
        'Early-support signal — students who\'ve gone quiet. This is not a '
        'clinical assessment; escalation routes to senior staff in-app, not '
        'your college\'s formal welfare process.',
        style: TextStyle(fontFamily: 'Momo', fontSize: 11, height: 1.45,
            color: AppC.text))),
    ]),
  );

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min,
      children: [
    const Icon(Icons.sentiment_satisfied_alt_rounded, size: 52, color: _kTeal),
    const SizedBox(height: 12),
    T('Nobody flagged quiet', style: TextStyle(fontFamily: 'Alfa',
        fontSize: 18, color: AppC.text)),
    const SizedBox(height: 6),
    Text('Students who go silent after being active will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Momo', fontSize: 12.5, color: AppC.sub)),
  ]));

  Widget _card(Map<String, dynamic> s) {
    final name = (s['name'] ?? 'Student').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatar = (s['avatar_url'] ?? '').toString();
    final days = (s['days_quiet'] as num?)?.toInt();
    return GestureDetector(
      onTap: _busy ? null : () => _openActions(s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kAmber.withOpacity(0.30))),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kAmber, _kRed]),
              shape: BoxShape.circle,
              image: avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null),
            child: avatar.isEmpty
                ? Center(child: Text(initial,
                    style: const TextStyle(color: Colors.white,
                        fontFamily: 'Arch', fontWeight: FontWeight.bold)))
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14.5, color: AppC.text)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.nightlight_round, size: 12, color: _kAmber),
              const SizedBox(width: 5),
              Text(days != null ? 'Quiet for $days days' : 'Gone quiet',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.sub)),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _kTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11)),
            child: const T('Support', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12, color: _kTeal)),
          ),
        ]),
      ),
    );
  }
}
