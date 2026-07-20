// lib/screens/staff/staff_announcements_screen.dart
//
// Staff Announcements: a staff-kit landing that lists notices (with search)
// and a composer that posts to /announcements/create/ (fans out push
// notifications). Restyled with StaffHeader / staffCard.

import 'dart:io';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/services/cache_store.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

const _kAmber = Color(0xFFD97706);
const _kCacheKey = '/announcements/';

Color _catColor(String c) {
  switch (c) {
    case 'urgent': return const Color(0xFFDC2626);
    case 'academic': return const Color(0xFF2563EB);
    case 'event': return const Color(0xFF7C3AED);
    case 'job': return const Color(0xFF059669);
    case 'community': return const Color(0xFFDB2777);
    default: return _kAmber;
  }
}

class StaffAnnouncementsScreen extends StatefulWidget {
  const StaffAnnouncementsScreen({super.key});
  @override
  State<StaffAnnouncementsScreen> createState() => _StaffAnnouncementsScreenState();
}

class _StaffAnnouncementsScreenState extends State<StaffAnnouncementsScreen> {
  final _api = ApiService();
  final _search = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _load() {
    CacheStore.I.swr(
      _kCacheKey,
      fetch: () => _api.get(_kCacheKey),
      onData: (data, fresh) {
        if (!mounted) return;
        setState(() {
          _items = (data as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loading = false;
        });
      },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((a) =>
        '${a['title']} ${a['body']}'.toLowerCase().contains(q)).toList();
  }

  Future<void> _compose() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const StaffAnnouncementComposeScreen()));
    if (created == true) {
      await CacheStore.I.invalidate(_kCacheKey);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAmber,
        onPressed: _compose,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New notice',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: _kAmber,
        onRefresh: () async { await CacheStore.I.invalidate(_kCacheKey); _load(); },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator(color: _kAmber)))
            else ...[
              StaffSearchBar(
                  controller: _search,
                  hint: 'Search notices…',
                  onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                _empty()
              else if (_filtered.isEmpty)
                staffNoResults('No notices match.')
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  child: Column(children: [
                    for (final a in _filtered) ...[
                      _card(a),
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
          const Icon(Icons.campaign_rounded, color: Colors.white70, size: 22),
        ]),
        const SizedBox(height: 14),
        const Text('Announcements',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
                color: Colors.white, height: 1.05,
                shadows: [Shadow(color: Colors.black26, blurRadius: 8,
                    offset: Offset(0, 3))])),
        const SizedBox(height: 6),
        Text('Notices you push to students',
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.85))),
      ]),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.campaign_rounded, size: 52, color: AppC.faint),
          const SizedBox(height: 12),
          Text('No announcements yet',
              style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
          const SizedBox(height: 6),
          Text('Tap "New notice" to post one.',
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
        ])),
      );

  Widget _card(Map<String, dynamic> a) {
    final pinned = a['is_pinned'] == true;
    final cat = (a['category'] ?? 'general').toString();
    final catLabel = (a['category_label'] ?? cat).toString();
    final color = _catColor(cat);
    final published = a['is_published'] != false;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: staffCard(border: pinned ? _kAmber.withValues(alpha: 0.4) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (pinned) ...[
            const Icon(Icons.push_pin_rounded, size: 14, color: _kAmber),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text((a['title'] ?? '').toString(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Alfa', fontSize: 15, color: AppC.text))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7)),
            child: Text(catLabel.toUpperCase(),
                style: TextStyle(fontFamily: 'Arch', fontSize: 8.5,
                    fontWeight: FontWeight.bold, letterSpacing: 0.3, color: color)),
          ),
        ]),
        const SizedBox(height: 7),
        Text((a['body'] ?? '').toString(), maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Momo', fontSize: 12, height: 1.35,
                color: AppC.sub)),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.visibility_rounded, size: 13, color: AppC.faint),
          const SizedBox(width: 4),
          Text('${a['view_count'] ?? 0}', style: TextStyle(fontFamily: 'Momo',
              fontSize: 10.5, color: AppC.faint)),
          const SizedBox(width: 12),
          Icon(Icons.group_rounded, size: 13, color: AppC.faint),
          const SizedBox(width: 4),
          Text('${a['audience'] ?? 'all'}', style: TextStyle(fontFamily: 'Momo',
              fontSize: 10.5, color: AppC.faint)),
          const Spacer(),
          if (!published)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppC.faint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6)),
              child: Text('DRAFT', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 8, fontWeight: FontWeight.bold, color: AppC.sub)),
            ),
        ]),
      ]),
    );
  }
}

// ── Composer ─────────────────────────────────────────────────
class StaffAnnouncementComposeScreen extends StatefulWidget {
  const StaffAnnouncementComposeScreen({super.key});
  @override
  State<StaffAnnouncementComposeScreen> createState() =>
      _StaffAnnouncementComposeScreenState();
}

class _StaffAnnouncementComposeScreenState
    extends State<StaffAnnouncementComposeScreen> {
  final _api = ApiService();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _year = TextEditingController();
  String _category = 'general';
  String _audience = 'all';
  bool _pinned = false;
  bool _publishNow = true;
  File? _image;
  bool _submitting = false;

  // Plain text vs a designed panel (accent colour + banner).
  String _style = 'plain';
  String _accent = '';
  String _bannerUrl = '';
  bool _genBanner = false;
  bool _assisting = false;
  bool _daleOpen = false;

  static const _accents = [
    '#8E54E9', '#2563EB', '#0EA5A4', '#059669',
    '#F59E0B', '#DC2626', '#DB2777', '#475569',
  ];

  static const _categories = [
    ['general', 'General'], ['academic', 'Academic'], ['event', 'Event'],
    ['job', 'Job / Opportunity'], ['community', 'Community'], ['urgent', 'Urgent'],
  ];
  static const _audiences = [
    ['all', 'Everyone'], ['students', 'Students only'],
    ['staff', 'Staff only'], ['year_group', 'Specific year group'],
  ];

  @override
  void dispose() { _title.dispose(); _body.dispose(); _year.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() { _image = File(x.path); _bannerUrl = ''; });
  }

  static Color _hex(String h) {
    final s = h.replaceAll('#', '');
    return Color(int.parse('FF$s', radix: 16));
  }

  // Dale rewrites the draft (one-shot, non-streaming).
  Future<void> _improveWithDale() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) {
      _snack('Write a rough draft first, then Dale will polish it.', error: true);
      return;
    }
    setState(() => _assisting = true);
    HapticFeedback.selectionClick();
    try {
      final res = (await _api.post('/ai/announce-assist/',
          body: {'title': title, 'body': body, 'mode': 'improve'}) as Map)
          .cast<String, dynamic>();
      final nt = (res['title'] ?? title).toString();
      final nb = (res['body'] ?? body).toString();
      if (mounted) {
        setState(() {
          _title.text = nt;
          _body.text = nb;
        });
        _snack('Dale polished your notice ✨');
      }
    } catch (_) {
      _snack('Dale is busy — try again.', error: true);
    } finally {
      if (mounted) setState(() => _assisting = false);
    }
  }

  // Dale generates a banner image for the designed panel.
  Future<void> _generateBanner() async {
    final promptCtrl = TextEditingController(
        text: _title.text.trim().isEmpty ? '' : _title.text.trim());
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Generate a banner',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: TextField(controller: promptCtrl, maxLines: 2,
            style: TextStyle(color: AppC.text),
            decoration: _dec('Describe the poster')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppC.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate',
                  style: TextStyle(color: _kAmber, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (go != true) return;
    final prompt = promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    setState(() => _genBanner = true);
    HapticFeedback.mediumImpact();
    try {
      final res = (await _api.post('/ai/image/', body: {
        'prompt': 'School announcement banner: $prompt. Clean, vibrant, '
            'modern flat illustration, wide composition, no text.',
        'model': 'flux',
        'aspect': 'landscape',
      }) as Map).cast<String, dynamic>();
      final url = (res['image_url'] ?? '').toString();
      if (url.isEmpty) {
        _snack('Could not generate a banner — try again.', error: true);
      } else if (mounted) {
        setState(() { _bannerUrl = url; _image = null; });
      }
    } catch (_) {
      _snack('Could not generate a banner — try again.', error: true);
    } finally {
      if (mounted) setState(() => _genBanner = false);
    }
  }

  Widget _bannerArea() {
    final hasBanner = _bannerUrl.isNotEmpty;
    final hasFile = _image != null;
    if (hasBanner || hasFile) {
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: hasBanner
              ? Image.network(_bannerUrl, height: 150, width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 150,
                      color: AppC.card2,
                      child: Icon(Icons.broken_image_rounded, color: AppC.faint)))
              : Image.file(_image!, height: 150, width: double.infinity,
                  fit: BoxFit.cover),
        ),
        Positioned(top: 8, right: 8, child: GestureDetector(
          onTap: () => setState(() { _bannerUrl = ''; _image = null; }),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
        )),
        if (_genBanner)
          const Positioned.fill(child: Center(
              child: CircularProgressIndicator(color: Colors.white))),
      ]);
    }
    return Row(children: [
      Expanded(child: GestureDetector(
        onTap: _genBanner ? null : _generateBanner,
        child: Container(
          height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFA78BFA), Color(0xFF8E54E9)]),
            borderRadius: BorderRadius.circular(13)),
          child: _genBanner
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 7),
                  Text('Generate with Dale', style: TextStyle(fontFamily: 'Arch',
                      fontSize: 12.5, fontWeight: FontWeight.bold,
                      color: Colors.white)),
                ]),
        ),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 52, height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppC.border)),
          child: Icon(Icons.upload_rounded, color: AppC.sub, size: 22)),
      ),
    ]);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Title and body are required', error: true);
      return;
    }
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      final designed = _style == 'designed';
      final fields = <String, String>{
        'title': title,
        'body': body,
        'category': _category,
        'audience': _audience,
        'year_group': _audience == 'year_group' ? _year.text.trim() : '',
        'accent': designed ? _accent : '',
        'image_url': designed ? _bannerUrl : '',
        'is_pinned': _pinned ? 'true' : 'false',
        'is_published': _publishNow ? 'true' : 'false',
      };
      if (_image != null) {
        await _api.uploadFile('/announcements/create/',
            filePath: _image!.path, field: 'image', extraFields: fields);
      } else {
        await _api.post('/announcements/create/', body: fields);
      }
      await CacheStore.I.invalidate('/announcements/');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Could not post: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo',
          color: Colors.white)),
      backgroundColor: error ? const Color(0xFFB3261E) : _kAmber,
      behavior: SnackBarBehavior.floating));
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontFamily: 'Momo', color: AppC.sub),
    filled: true, fillColor: AppC.card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: GestureDetector(
        onTap: () { HapticFeedback.selectionClick();
          setState(() => _daleOpen = !_daleOpen); },
        child: Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFA78BFA), Color(0xFF8E54E9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: const Color(0xFF8E54E9).withValues(alpha: 0.45),
                blurRadius: 16, offset: const Offset(0, 7))]),
          padding: const EdgeInsets.all(8),
          child: Lottie.asset('assets/images/robot.json', fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_awesome_rounded, color: Colors.white, size: 28)),
        ),
      ),
      body: Stack(children: [
        ListView(padding: EdgeInsets.zero, children: [
        StaffHeader(
          bottomPad: 20,
          horizontal: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25))),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20)),
            ),
            const SizedBox(width: 14),
            const Text('New notice',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 22,
                    color: Colors.white)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: _title, style: TextStyle(color: AppC.text),
              decoration: _dec('Title')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 6,
              style: TextStyle(color: AppC.text), decoration: _dec('Body')),
          const SizedBox(height: 14),

          // Plain vs Designed
          Row(children: [
            for (final s in const [['plain', 'Plain', Icons.notes_rounded],
                ['designed', 'Designed', Icons.dashboard_customize_rounded]])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _style = s[0] as String),
                child: Container(
                  margin: EdgeInsets.only(right: s[0] == 'plain' ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _style == s[0] ? _kAmber : AppC.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _style == s[0] ? _kAmber : AppC.border)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(s[2] as IconData, size: 16,
                          color: _style == s[0] ? Colors.white : AppC.sub),
                      const SizedBox(width: 7),
                      Text(s[1] as String, style: TextStyle(fontFamily: 'Arch',
                          fontSize: 12.5, fontWeight: FontWeight.bold,
                          color: _style == s[0] ? Colors.white : AppC.sub)),
                    ]),
                ),
              )),
          ]),

          if (_style == 'designed') ...[
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: Text('Accent',
                style: TextStyle(fontFamily: 'Arch', fontSize: 11,
                    fontWeight: FontWeight.bold, color: AppC.sub))),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final hex in _accents)
                GestureDetector(
                  onTap: () => setState(() => _accent = hex),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _hex(hex), shape: BoxShape.circle,
                      border: Border.all(
                          color: _accent == hex ? AppC.text : Colors.transparent,
                          width: 2.5)),
                    child: _accent == hex
                        ? const Icon(Icons.check_rounded, color: Colors.white,
                            size: 17)
                        : null),
                ),
            ]),
            const SizedBox(height: 14),
            _bannerArea(),
          ],

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category, dropdownColor: AppC.card,
            style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
            decoration: _dec('Category'),
            items: _categories.map((c) =>
                DropdownMenuItem(value: c[0], child: Text(c[1]))).toList(),
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _audience, dropdownColor: AppC.card,
            style: TextStyle(color: AppC.text, fontFamily: 'Momo'),
            decoration: _dec('Audience'),
            items: _audiences.map((c) =>
                DropdownMenuItem(value: c[0], child: Text(c[1]))).toList(),
            onChanged: (v) => setState(() => _audience = v ?? 'all'),
          ),
          if (_audience == 'year_group') ...[
            const SizedBox(height: 12),
            TextField(controller: _year, style: TextStyle(color: AppC.text),
                decoration: _dec('Year group (e.g. Y12)')),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            value: _pinned, activeThumbColor: _kAmber,
            contentPadding: EdgeInsets.zero,
            title: T('Pin to top',
                style: TextStyle(fontFamily: 'Arch', color: AppC.text)),
            onChanged: (v) => setState(() => _pinned = v),
          ),
          SwitchListTile(
            value: _publishNow, activeThumbColor: _kAmber,
            contentPadding: EdgeInsets.zero,
            title: T('Publish now (push to students)',
                style: TextStyle(fontFamily: 'Arch', color: AppC.text)),
            subtitle: Text(_publishNow
                ? 'Sends a notification immediately' : 'Saves as draft',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
            onChanged: (v) => setState(() => _publishNow = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52, width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: _kAmber,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Post announcement',
                      style: TextStyle(fontFamily: 'Arch', fontSize: 15,
                          fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 30),
        ])),
        ]),
        // Dale chat cloud — drafts a notice you can drop into the form.
        if (_daleOpen) ...[
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _daleOpen = false),
            child: Container(color: Colors.black.withValues(alpha: 0.35)))),
          Positioned(
            left: 14, right: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom + 12
                : MediaQuery.of(context).padding.bottom + 92,
            child: _AnnounceDaleCloud(
              onClose: () => setState(() => _daleOpen = false),
              onApply: (t, b) {
                setState(() { _title.text = t; _body.text = b; _daleOpen = false; });
                _snack('Dale\'s draft added — tweak it and post ✨');
              },
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Ask-Dale chat cloud for drafting a notice ────────────────────────────
class _AnnounceDaleCloud extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(String title, String body) onApply;
  const _AnnounceDaleCloud({required this.onClose, required this.onApply});
  @override
  State<_AnnounceDaleCloud> createState() => _AnnounceDaleCloudState();
}

class _AnnounceDaleCloudState extends State<_AnnounceDaleCloud>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  final _msgs = <Map<String, String>>[]; // {role, content, title?, body?}
  bool _busy = false;

  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320))..forward();

  static const _chips = [
    'Draft a notice about exam timetable changes',
    'Remind students about library opening hours',
    'Announce a club fair this Friday',
  ];

  @override
  void dispose() { _ctrl.dispose(); _pop.dispose(); super.dispose(); }

  Future<void> _send(String text) async {
    final m = text.trim();
    if (m.isEmpty || _busy) return;
    setState(() { _msgs.add({'role': 'user', 'content': m}); _busy = true; });
    _ctrl.clear();
    try {
      final res = (await _api.post('/ai/announce-assist/',
          body: {'title': '', 'body': m, 'mode': 'draft'}) as Map)
          .cast<String, dynamic>();
      final t = (res['title'] ?? '').toString();
      final b = (res['body'] ?? '').toString();
      if (mounted) {
        setState(() => _msgs.add({
          'role': 'dale',
          'content': (t.isNotEmpty ? '$t\n\n' : '') + (b.isEmpty ? 'Here you go.' : b),
          'title': t, 'body': b,
        }));
      }
    } catch (_) {
      if (mounted) setState(() => _msgs.add({'role': 'dale',
          'content': "I'm having trouble right now — try again in a moment."}));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
      alignment: Alignment.bottomRight,
      child: FadeTransition(opacity: _pop, child: Material(
        color: Colors.transparent,
        child: Container(
          height: (kb > 0 ? (h - kb - 120) : h * 0.52).clamp(300.0, 520.0),
          decoration: BoxDecoration(
            color: AppC.card, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppC.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 26, offset: const Offset(0, 12))]),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [Color(0xFFA78BFA), Color(0xFF8E54E9)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Row(children: [
                SizedBox(width: 30, height: 30, child: Lottie.asset(
                    'assets/images/robot.json', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.smart_toy_rounded, color: Colors.white, size: 22))),
                const SizedBox(width: 10),
                const Expanded(child: Text('Ask Dale',
                    style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: Colors.white))),
                Text('drafts a notice', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(width: 6),
                GestureDetector(onTap: widget.onClose,
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
              ]),
            ),
            Expanded(child: _msgs.isEmpty
                ? _starters()
                : ListView.builder(
                    padding: const EdgeInsets.all(14), itemCount: _msgs.length,
                    itemBuilder: (_, i) => _bubble(_msgs[i]))),
            _inputBar(),
          ]),
        ),
      )),
    );
  }

  Widget _starters() => Padding(padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tell me what to announce…', style: TextStyle(fontFamily: 'Arch',
          fontSize: 12, fontWeight: FontWeight.bold, color: AppC.sub)),
      const SizedBox(height: 10),
      for (final c in _chips)
        GestureDetector(onTap: () => _send(c), child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: AppC.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppC.border)),
          child: Text(c, style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: AppC.text)))),
    ]));

  Widget _bubble(Map<String, String> m) {
    final isUser = m['role'] == 'user';
    final hasDraft = (m['body'] ?? '').isNotEmpty;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF8E54E9) : AppC.bg,
              borderRadius: BorderRadius.circular(14),
              border: isUser ? null : Border.all(color: AppC.border)),
            child: Text(m['content'] ?? '', style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, height: 1.4, color: isUser ? Colors.white : AppC.text)),
          ),
          if (!isUser && hasDraft)
            Padding(padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => widget.onApply(m['title'] ?? '', m['body'] ?? ''),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFF8E54E9),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 15),
                    SizedBox(width: 5),
                    Text('Use this notice', style: TextStyle(fontFamily: 'Arch',
                        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                ),
              )),
        ],
      ),
    );
  }

  Widget _inputBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: AppC.card,
        border: Border(top: BorderSide(color: AppC.border))),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppC.bg, borderRadius: BorderRadius.circular(22)),
        child: TextField(controller: _ctrl, minLines: 1, maxLines: 3,
          style: TextStyle(fontFamily: 'Momo', fontSize: 13.5, color: AppC.text),
          decoration: InputDecoration(border: InputBorder.none, isDense: true,
              hintText: 'Describe the announcement…',
              hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 12)),
          onSubmitted: _send),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _busy ? null : () => _send(_ctrl.text),
        child: Container(width: 46, height: 46,
          decoration: const BoxDecoration(color: Color(0xFF8E54E9), shape: BoxShape.circle),
          child: _busy
              ? const Padding(padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22)),
      ),
    ]),
  );
}
