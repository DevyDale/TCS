// lib/screens/studyhub/sessions_screen.dart
//
// Study sessions (spec §3E). Teachers schedule revision sessions (in-person or
// via a link) and can fan a reminder to attendees; students browse upcoming
// sessions and RSVP. `isTeacher` unlocks scheduling, remind and delete.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class SessionsScreen extends StatefulWidget {
  final bool isTeacher;
  const SessionsScreen({super.key, required this.isTeacher});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String _when = 'upcoming';
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.studySessions(
          when: _when, mine: widget.isTeacher && _when == 'mine') as Map;
      final list = (d['results'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rsvp(Map<String, dynamic> s) async {
    HapticFeedback.selectionClick();
    try {
      final d = await _api.rsvpSession(s['id'].toString()) as Map;
      setState(() {
        s['is_rsvped'] = d['is_rsvped'];
        s['rsvp_count'] = d['rsvp_count'];
      });
    } catch (_) {}
  }

  Future<void> _remind(Map<String, dynamic> s) async {
    try {
      final d = await _api.remindSession(s['id'].toString()) as Map;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reminder sent to ${d['reminded'] ?? 0} attendee(s).')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Cancel session?'),
      content: Text('“${s['title']}” will be removed.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel it', style: TextStyle(color: Color(0xFFDC2626)))),
      ]));
    if (ok != true) return;
    try { await _api.deleteSession(s['id'].toString()); _load(); } catch (_) {}
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              backgroundColor: kStaffG1,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Schedule',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      color: Colors.white)),
              onPressed: _showScheduleSheet)
          : null,
      body: RefreshIndicator(
        onRefresh: _load, color: kStaffG1,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: StaffHeader(
              horizontal: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 38, height: 38, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Study Sessions', style: TextStyle(fontFamily: 'Alfa',
                        fontSize: 22, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(widget.isTeacher
                        ? 'Schedule revision · remind attendees'
                        : 'Revision sessions from your teachers',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )),
                const Icon(Icons.event_available_rounded, color: Colors.white, size: 26),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(children: [
                _chip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                if (widget.isTeacher) _chip('Mine', 'mine'),
                if (widget.isTeacher) const SizedBox(width: 8),
                _chip('Past', 'past'),
              ]),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else if (_items.isEmpty)
              SliverFillRemaining(hasScrollBody: false,
                  child: staffNoResults(widget.isTeacher
                      ? 'No sessions — tap Schedule to add one.'
                      : 'No upcoming sessions yet.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _row(_items[i]),
                  childCount: _items.length,
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final on = _when == value;
    return GestureDetector(
      onTap: () { setState(() => _when = value); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? kStaffG1 : AppC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? kStaffG1 : AppC.border)),
        child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
            fontWeight: FontWeight.bold, color: on ? Colors.white : AppC.sub)),
      ),
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final when = DateTime.tryParse(s['when']?.toString() ?? '')?.toLocal();
    final online = (s['link'] ?? '').toString().isNotEmpty;
    final rsvped = s['is_rsvped'] == true;
    final mine = s['is_mine'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: staffCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: kStaffG1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Text(s['subject']?.toString() ?? '',
                style: const TextStyle(fontFamily: 'Arch', fontSize: 10,
                    fontWeight: FontWeight.bold, color: kStaffG1))),
          const Spacer(),
          if (when != null)
            Text(_fmtWhen(when), style: TextStyle(fontFamily: 'Arch', fontSize: 11,
                fontWeight: FontWeight.bold, color: AppC.text)),
        ]),
        const SizedBox(height: 8),
        Text(s['title']?.toString() ?? '',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 15, color: AppC.text)),
        if ((s['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(s['description'].toString(),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Icon(online ? Icons.videocam_rounded : Icons.place_rounded,
              size: 13, color: AppC.faint),
          const SizedBox(width: 4),
          Expanded(child: Text(
              online ? 'Online' : ((s['location'] ?? '').toString().isEmpty
                  ? 'Location TBA' : s['location'].toString()),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub))),
          Icon(Icons.people_rounded, size: 13, color: AppC.faint),
          const SizedBox(width: 4),
          Text('${s['rsvp_count'] ?? 0} going',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.faint)),
        ]),
        const Divider(height: 18),
        Row(children: [
          if (online)
            _act(Icons.open_in_new_rounded, 'Join', () => _openLink(s['link'].toString())),
          if (widget.isTeacher && (mine || true)) ...[
            _act(Icons.notifications_active_rounded, 'Remind', () => _remind(s)),
            const Spacer(),
            _act(Icons.delete_outline_rounded, 'Cancel', () => _delete(s),
                color: const Color(0xFFDC2626)),
          ] else ...[
            const Spacer(),
            GestureDetector(
              onTap: () => _rsvp(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: rsvped ? const Color(0xFF16A34A) : kStaffG1,
                  borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(rsvped ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text(rsvped ? "I'm going" : 'RSVP',
                      style: const TextStyle(fontFamily: 'Arch', fontSize: 12,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _act(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? kStaffG1;
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 11.5,
              fontWeight: FontWeight.bold, color: c)),
        ]),
      ),
    );
  }

  String _fmtWhen(DateTime t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep',
      'Oct', 'Nov', 'Dec'];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${days[t.weekday - 1]} ${t.day} ${months[t.month - 1]} · '
        '${two(t.hour)}:${two(t.minute)}';
  }

  // ── Schedule sheet (teacher) ──────────────────────────────────────────
  void _showScheduleSheet() {
    final titleC = TextEditingController();
    final subjC  = TextEditingController();
    final descC  = TextEditingController();
    final locC   = TextEditingController();
    final linkC  = TextEditingController();
    DateTime when = DateTime.now().add(const Duration(hours: 1));
    bool online = false, busy = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> pickWhen() async {
          final d = await showDatePicker(context: ctx, initialDate: when,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 120)));
          if (d == null) return;
          if (!ctx.mounted) return;
          final t = await showTimePicker(context: ctx,
              initialTime: TimeOfDay.fromDateTime(when));
          if (t == null) return;
          setSheet(() => when =
              DateTime(d.year, d.month, d.day, t.hour, t.minute));
        }

        Future<void> submit() async {
          if (titleC.text.trim().isEmpty || subjC.text.trim().isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Title and subject are required.')));
            return;
          }
          if (online && linkC.text.trim().isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Add the meeting link.')));
            return;
          }
          setSheet(() => busy = true);
          try {
            await _api.scheduleSession(
                title: titleC.text.trim(), subject: subjC.text.trim(),
                whenIso: when.toUtc().toIso8601String(),
                description: descC.text.trim(),
                location: online ? '' : locC.text.trim(),
                link: online ? linkC.text.trim() : '',
                notify: true);
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            setSheet(() => busy = false);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Could not schedule: $e')));
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppC.faint,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Text('Schedule a session',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
              const SizedBox(height: 14),
              _field(titleC, 'Title (e.g. Exam revision)', Icons.title_rounded),
              const SizedBox(height: 10),
              _field(subjC, 'Subject', Icons.school_rounded),
              const SizedBox(height: 10),
              _field(descC, 'What you’ll cover (optional)', Icons.notes_rounded, lines: 2),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: pickWhen,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppC.bg,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.event_rounded, color: kStaffG1, size: 20),
                    const SizedBox(width: 12),
                    Text(_fmtWhen(when), style: TextStyle(fontFamily: 'Arch',
                        fontSize: 13, fontWeight: FontWeight.bold, color: AppC.text)),
                    const Spacer(),
                    Icon(Icons.edit_rounded, size: 15, color: AppC.faint),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                ChoiceChip(label: const Text('In person'), selected: !online,
                    selectedColor: kStaffG1.withValues(alpha: 0.18),
                    onSelected: (_) => setSheet(() => online = false)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Online'), selected: online,
                    selectedColor: kStaffG1.withValues(alpha: 0.18),
                    onSelected: (_) => setSheet(() => online = true)),
              ]),
              const SizedBox(height: 12),
              if (online)
                _field(linkC, 'Meeting link (https://…)', Icons.link_rounded)
              else
                _field(locC, 'Location (e.g. Library B12)', Icons.place_rounded),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: busy ? null : submit,
                  style: ElevatedButton.styleFrom(backgroundColor: kStaffG1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: busy
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Schedule & notify students',
                          style: TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold, color: Colors.white)))),
            ]),
          ),
        );
      }),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {int lines = 1}) =>
      TextField(
        controller: c, maxLines: lines,
        style: TextStyle(fontFamily: 'Momo', color: AppC.text),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppC.faint, size: 20),
          filled: true, fillColor: AppC.bg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}
