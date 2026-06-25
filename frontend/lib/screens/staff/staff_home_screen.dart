// lib/screens/staff/staff_home_screen.dart
//
// HOME tab — the staff Cohort Command Center. Answers "what needs me today?"
// the instant it opens: greeting + live pulse strip, quick actions, and the
// control cards (moderation, suggestions, announcements, train Dale).
// Pulse data: GET /api/moderation/staff/overview/.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_announcements_screen.dart';
import 'package:tcs_app/screens/staff/staff_moderation_screen.dart';
import 'package:tcs_app/screens/staff/staff_suggestions_screen.dart';
import 'package:tcs_app/screens/staff/staff_knowledge_screen.dart';
import 'package:tcs_app/screens/dashboard/events_screen.dart';
import 'package:tcs_app/screens/staff/staff_oversight_screen.dart';
import 'package:tcs_app/screens/staff/staff_wellbeing_screen.dart';

const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

class StaffHomeScreen extends StatefulWidget {
  final String fullName;
  final String preferredName;
  final String role;
  const StaffHomeScreen({
    super.key,
    required this.fullName,
    required this.preferredName,
    required this.role,
  });

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _api = ApiService();
  int? _activeToday, _flagsPending, _upcomingEvents;
  List<Map<String, dynamic>> _needs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.get('/moderation/staff/overview/'),
        _api.get('/moderation/staff/needs-attention/')
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final d = (results[0] as Map).cast<String, dynamic>();
      final n = (results[1] as Map).cast<String, dynamic>();
      setState(() {
        _activeToday    = (d['active_today'] as num?)?.toInt();
        _flagsPending   = (d['flags_pending'] as num?)?.toInt();
        _upcomingEvents = (d['upcoming_events'] as num?)?.toInt();
        _needs = ((n['results'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTarget(String target) {
    if (target == 'moderation') {
      _push(const StaffModerationScreen());
    } else if (target == 'wellbeing') {
      _push(const StaffWellbeingScreen());
    }
  }

  String get _firstName {
    final p = widget.preferredName.trim();
    final f = p.isNotEmpty ? p : widget.fullName.trim();
    return f.isEmpty ? 'there' : f.split(' ').first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _push(Widget s) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: RefreshIndicator(
        color: _kDeep,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            const SizedBox(height: 16),
            _pulseStrip(),
            const SizedBox(height: 22),
            _sectionLabel('Needs attention'),
            _needsAttention(),
            const SizedBox(height: 22),
            _sectionLabel('Quick actions'),
            _quickActions(),
            const SizedBox(height: 22),
            _sectionLabel('Run your cohort'),
            _controls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 18,
          left: 20, right: 20, bottom: 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kIndigo, _kDeep],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20)),
            child: const Text('STAFF',
                style: TextStyle(fontFamily: 'Arch', fontSize: 9,
                    fontWeight: FontWeight.bold, letterSpacing: 1.5,
                    color: Colors.white)),
          ),
          const Spacer(),
          const Text('🎓', style: TextStyle(fontSize: 22)),
        ]),
        const SizedBox(height: 14),
        Text('$_greeting,',
            style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                color: Colors.white.withOpacity(0.85))),
        Text(_firstName,
            style: const TextStyle(fontFamily: 'Alfa', fontSize: 28,
                color: Colors.white, height: 1.1)),
        const SizedBox(height: 6),
        Text("Here's what needs you today.",
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: Colors.white.withOpacity(0.8))),
      ]),
    );
  }

  Widget _pulseStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _pulseTile('Active today', _activeToday, Icons.bolt_rounded,
            const Color(0xFF22C55E),
            onTap: () => _push(const StaffOversightScreen(initialFilter: 'active'))),
        const SizedBox(width: 10),
        _pulseTile('Flags pending', _flagsPending, Icons.flag_rounded,
            const Color(0xFFE11D48),
            onTap: () => _push(const StaffModerationScreen())),
        const SizedBox(width: 10),
        _pulseTile('Upcoming', _upcomingEvents, Icons.event_rounded,
            const Color(0xFFF59E0B),
            onTap: () => _push(const EventsScreen())),
      ]),
    );
  }

  Widget _pulseTile(String label, int? value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: AppC.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppC.border)),
          child: Column(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(_loading ? '—' : '${value ?? 0}',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 22,
                    color: AppC.text)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Arch', fontSize: 9.5,
                    fontWeight: FontWeight.bold, letterSpacing: 0.3,
                    color: AppC.sub)),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(t, style: TextStyle(fontFamily: 'Alfa',
            fontSize: 16, color: AppC.text)),
      );

  ({IconData icon, Color color}) _needStyle(String type) {
    switch (type) {
      case 'escalation':
        return (icon: Icons.priority_high_rounded, color: const Color(0xFFE11D48));
      case 'flag':
        return (icon: Icons.flag_rounded, color: const Color(0xFFF59E0B));
      case 'wellbeing':
        return (icon: Icons.favorite_rounded, color: const Color(0xFF0EA5A4));
      default:
        return (icon: Icons.notifications_rounded, color: _kIndigo);
    }
  }

  Widget _needsAttention() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppC.border)),
          child: const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kDeep))),
        ),
      );
    }
    if (_needs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppC.border)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text("You're all caught up — nothing needs you right now.",
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: AppC.sub))),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: _needs.map((it) {
        final st = _needStyle((it['type'] ?? '').toString());
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _openTarget((it['target'] ?? '').toString());
            },
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppC.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: st.color.withOpacity(0.30))),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: st.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11)),
                  child: Icon(st.icon, color: st.color, size: 19)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((it['title'] ?? '').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, fontSize: 13.5,
                            color: AppC.text)),
                    const SizedBox(height: 2),
                    Text((it['subtitle'] ?? '').toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: AppC.sub)),
                  ],
                )),
                Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 20),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _quickActions() {
    final actions = [
      (Icons.campaign_rounded, 'Post\nannouncement', const Color(0xFF8E54E9),
          () => _push(const StaffAnnouncementsScreen())),
      (Icons.warning_amber_rounded, 'Send scam\nalert', const Color(0xFFE11D48),
          () => _push(const StaffAnnouncementsScreen())),
      (Icons.event_available_rounded, 'Create\nevent', const Color(0xFFF59E0B),
          () => _push(const EventsScreen())),
      (Icons.school_rounded, 'Train\nDale', const Color(0xFF0EA5A4),
          () => _push(const StaffKnowledgeScreen())),
    ];
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); a.$4(); },
            child: Container(
              width: 96,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppC.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppC.border)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: a.$3.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(a.$1, color: a.$3, size: 19)),
                  const Spacer(),
                  Text(a.$2, style: TextStyle(fontFamily: 'Arch',
                      fontSize: 11, fontWeight: FontWeight.bold, height: 1.2,
                      color: AppC.text)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _controls() {
    final items = [
      (Icons.shield_rounded, 'Moderation', 'Flags, hide & remove',
          const Color(0xFFE11D48), () => _push(const StaffModerationScreen())),
      (Icons.lightbulb_rounded, 'Suggestions', 'Student ideas to the school',
          const Color(0xFF4F46E5), () => _push(const StaffSuggestionsScreen())),
      (Icons.campaign_rounded, 'Announcements', 'Official posts & push',
          const Color(0xFF8E54E9), () => _push(const StaffAnnouncementsScreen())),
      (Icons.school_rounded, 'Train Dale', 'Tutor from your notes',
          const Color(0xFF0EA5A4), () => _push(const StaffKnowledgeScreen())),
      (Icons.insights_rounded, 'Oversight', 'Student roster & engagement',
          const Color(0xFF2575FC), () => _push(const StaffOversightScreen())),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: items.map((it) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); it.$5(); },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppC.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppC.border)),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: it.$4.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13)),
                child: Icon(it.$1, color: it.$4, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.$2, style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 14.5,
                    color: AppC.text)),
                const SizedBox(height: 2),
                Text(it.$3, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11.5, color: AppC.sub)),
              ])),
              Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 22),
            ]),
          ),
        ),
      )).toList()),
    );
  }
}
