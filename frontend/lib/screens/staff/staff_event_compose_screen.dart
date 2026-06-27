// lib/screens/staff/staff_event_compose_screen.dart
//
// Staff create an event: title, description, category, audience (students/staff/
// everyone), date-time, location/online, and an AI-generated poster (Dale).
// POST /events/ with poster_url. Notifies the audience on create.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:lottie/lottie.dart';

const _kAmber = Color(0xFFF59E0B);

class StaffEventComposeScreen extends StatefulWidget {
  const StaffEventComposeScreen({super.key});

  @override
  State<StaffEventComposeScreen> createState() => _StaffEventComposeScreenState();
}

class _StaffEventComposeScreenState extends State<StaffEventComposeScreen> {
  final _api = ApiService();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  String _category = 'social';
  String _audience = 'everyone';
  bool _online = false;
  DateTime? _start, _end;
  String _posterUrl = '';
  bool _genPoster = false;
  bool _submitting = false;

  static const _cats = <String, String>{
    'academic': 'Academic', 'sports': 'Sports', 'social': 'Social',
    'club': 'Club', 'arcade': 'Arcade', 'other': 'Other',
  };

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _location.dispose(); super.dispose();
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : _kAmber,
      content: Text(m, style: const TextStyle(fontFamily: 'Momo', color: Colors.white))));
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context,
        initialDate: now, firstDate: now,
        lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context,
        initialTime: TimeOfDay.now());
    if (t == null) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (isStart) {
        _start = dt;
        _end ??= dt.add(const Duration(hours: 1));
      } else { _end = dt; }
    });
  }

  Future<void> _generatePoster() async {
    final title = _title.text.trim();
    if (title.isEmpty) { _snack('Add a title first.', error: true); return; }
    setState(() => _genPoster = true);
    HapticFeedback.mediumImpact();
    try {
      final res = (await _api.generateEventPoster(
          prompt: '$title. ${_desc.text.trim()}',
          title: title, clubId: '') as Map).cast<String, dynamic>();
      final url = (res['poster_url'] ?? '').toString();
      if (url.isEmpty) {
        _snack('Could not generate a poster — try again.', error: true);
      } else if (mounted) {
        setState(() => _posterUrl = url);
      }
    } catch (_) {
      _snack('Could not generate a poster — try again.', error: true);
    } finally { if (mounted) setState(() => _genPoster = false); }
  }

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty || _desc.text.trim().isEmpty) {
      _snack('Title and description are required.', error: true); return;
    }
    if (_posterUrl.isEmpty) { _snack('Generate a poster first.', error: true); return; }
    if (_start == null) { _snack('Pick a start date & time.', error: true); return; }
    if (!_online && _location.text.trim().isEmpty) {
      _snack('Add a location (or mark it online).', error: true); return;
    }
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.createEvent({
        'title': title, 'description': _desc.text.trim(),
        'category': _category, 'audience': _audience,
        'poster_url': _posterUrl,
        'location': _online ? 'Online' : _location.text.trim(),
        'is_online': _online,
        'start_time': _iso(_start!),
        'end_time': _iso(_end ?? _start!.add(const Duration(hours: 1))),
      });
      if (mounted) { _snack('Event created ✓'); Navigator.of(context).pop(true); }
    } catch (e) {
      _snack('Could not create: $e', error: true);
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  String _fmt(DateTime? d) => d == null ? 'Pick'
      : '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        _header(),
        Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            _posterArea(),
            const SizedBox(height: 16),
            _field(_title, 'Event title'),
            const SizedBox(height: 12),
            _field(_desc, 'Description', lines: 3),
            const SizedBox(height: 16),
            _label('Category'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _cats.entries) _chip(e.value, _category == e.key,
                  () => setState(() => _category = e.key)),
            ]),
            const SizedBox(height: 16),
            _label('Who is it for?'),
            const SizedBox(height: 8),
            Row(children: [
              for (final a in const [['everyone', 'Everyone'], ['students', 'Students'],
                  ['staff', 'Staff']])
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: a[0] == 'staff' ? 0 : 9),
                  child: _chip(a[1], _audience == a[0],
                      () => setState(() => _audience = a[0]), fill: true)),
                ),
            ]),
            const SizedBox(height: 16),
            _label('When'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _dtBtn('Starts', _start, () => _pickDateTime(true))),
              const SizedBox(width: 10),
              Expanded(child: _dtBtn('Ends', _end, () => _pickDateTime(false))),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _online = !_online),
              child: Row(children: [
                Icon(_online ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: _online ? _kAmber : AppC.sub, size: 22),
                const SizedBox(width: 8),
                Text('Online event', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 13, color: AppC.text)),
              ]),
            ),
            if (!_online) ...[
              const SizedBox(height: 12),
              _field(_location, 'Location'),
            ],
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: _kAmber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create event', style: TextStyle(fontFamily: 'Arch',
                      fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
            )),
            const SizedBox(height: 40),
          ])),
      ]),
    );
  }

  Widget _header() => StaffHeader(
        bottomPad: 20,
        horizontal: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          GestureDetector(onTap: () => Navigator.of(context).maybePop(),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
          const SizedBox(width: 14),
          const Text('New event', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 22, color: Colors.white)),
        ]),
      );

  Widget _posterArea() {
    if (_posterUrl.isNotEmpty) {
      return Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16),
          child: Image.network(_posterUrl, height: 200, width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 200, color: AppC.card2,
                  child: Icon(Icons.broken_image_rounded, color: AppC.faint)))),
        Positioned(top: 8, right: 8, child: GestureDetector(
          onTap: () => setState(() => _posterUrl = ''),
          child: Container(padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)))),
      ]);
    }
    return GestureDetector(
      onTap: _genPoster ? null : _generatePoster,
      child: Container(height: 130, alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFA78BFA), Color(0xFF8E54E9)]),
          borderRadius: BorderRadius.circular(16)),
        child: _genPoster
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 56, height: 56, child: Lottie.asset(
                    'assets/images/robot.json', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 26, height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white)))),
                const SizedBox(height: 6),
                const Text('Dale is designing your poster…',
                    style: TextStyle(fontFamily: 'Arch', fontSize: 12.5,
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 44, height: 44, child: Lottie.asset(
                    'assets/images/robot.json', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_awesome_rounded, color: Colors.white, size: 28))),
                const SizedBox(height: 6),
                const Text('Generate poster with Dale', style: TextStyle(fontFamily: 'Arch',
                    fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: TextStyle(fontFamily: 'Arch',
      fontSize: 11, fontWeight: FontWeight.bold, color: AppC.sub));

  Widget _chip(String label, bool sel, VoidCallback onTap, {bool fill = false}) =>
      GestureDetector(onTap: onTap, child: Container(
        padding: EdgeInsets.symmetric(horizontal: fill ? 0 : 13, vertical: 9),
        alignment: fill ? Alignment.center : null,
        decoration: BoxDecoration(color: sel ? _kAmber : AppC.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? _kAmber : AppC.border)),
        child: Text(label, style: TextStyle(fontFamily: 'Arch', fontSize: 12,
            fontWeight: FontWeight.bold, color: sel ? Colors.white : AppC.sub)),
      ));

  Widget _dtBtn(String label, DateTime? v, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: AppC.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppC.border)),
        child: Row(children: [
          Icon(Icons.schedule_rounded, size: 16, color: AppC.sub),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: ${_fmt(v)}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                  color: v == null ? AppC.faint : AppC.text))),
        ]),
      ));

  Widget _field(TextEditingController c, String hint, {int lines = 1}) =>
      TextField(controller: c, maxLines: lines,
        style: TextStyle(color: AppC.text, fontFamily: 'Momo', fontSize: 14),
        decoration: InputDecoration(hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 13.5),
            filled: true, fillColor: AppC.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none)));
}
