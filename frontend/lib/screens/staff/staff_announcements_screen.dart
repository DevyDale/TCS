// lib/screens/staff/staff_announcements_screen.dart
//
// Staff Announcements module: lists all announcements and opens a composer
// that posts to /announcements/create/ (which fans out push notifications).

import 'dart:io';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _bg = Color(0xFF0B0B16);
const _card = Color(0xFF15152A);
const _kCacheKey = '/announcements/';

class StaffAnnouncementsScreen extends StatefulWidget {
  const StaffAnnouncementsScreen({super.key});
  @override
  State<StaffAnnouncementsScreen> createState() => _StaffAnnouncementsScreenState();
}

class _StaffAnnouncementsScreenState extends State<StaffAnnouncementsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        title: const T('Announcements',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kG2,
        onPressed: _compose,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const T('New notice',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kG2))
          : _items.isEmpty
              ? Center(child: T('No announcements yet.\nTap New notice to post one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                      color: Colors.white.withOpacity(.5))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final a = _items[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kG2.withOpacity(.18)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          if (a['is_pinned'] == true)
                            const Padding(padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.star_rounded, size: 16, color: _kG1)),
                          Expanded(child: Text((a['title'] ?? '').toString(),
                              style: const TextStyle(fontFamily: 'Alfa', fontSize: 15,
                                  color: Colors.white))),
                          Text((a['category_label'] ?? '').toString(),
                              style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(.5))),
                        ]),
                        const SizedBox(height: 6),
                        Text((a['body'] ?? '').toString(), maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                                color: Colors.white.withOpacity(.7))),
                        const SizedBox(height: 8),
                        Text('${a['view_count'] ?? 0} views  ·  ${a['audience'] ?? 'all'}',
                            style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                                color: Colors.white.withOpacity(.4))),
                      ]),
                    );
                  },
                ),
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
    if (x != null) setState(() => _image = File(x.path));
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
      final fields = <String, String>{
        'title': title,
        'body': body,
        'category': _category,
        'audience': _audience,
        'year_group': _audience == 'year_group' ? _year.text.trim() : '',
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
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: error ? const Color(0xFFFF5858) : _kG2,
      behavior: SnackBarBehavior.floating));
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontFamily: 'Momo', color: Colors.white.withOpacity(.6)),
    filled: true, fillColor: _card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        title: const T('New notice',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _title, style: const TextStyle(color: Colors.white),
            decoration: _dec('Title')),
        const SizedBox(height: 12),
        TextField(controller: _body, maxLines: 6,
            style: const TextStyle(color: Colors.white), decoration: _dec('Body')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category, dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontFamily: 'Momo'),
          decoration: _dec('Category'),
          items: _categories.map((c) =>
              DropdownMenuItem(value: c[0], child: Text(c[1]))).toList(),
          onChanged: (v) => setState(() => _category = v ?? 'general'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _audience, dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontFamily: 'Momo'),
          decoration: _dec('Audience'),
          items: _audiences.map((c) =>
              DropdownMenuItem(value: c[0], child: Text(c[1]))).toList(),
          onChanged: (v) => setState(() => _audience = v ?? 'all'),
        ),
        if (_audience == 'year_group') ...[
          const SizedBox(height: 12),
          TextField(controller: _year, style: const TextStyle(color: Colors.white),
              decoration: _dec('Year group (e.g. Y12)')),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: _image == null ? 60 : 160,
            decoration: BoxDecoration(color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kG2.withOpacity(.3))),
            child: _image == null
                ? Center(child: T('+ Add image (optional)',
                    style: TextStyle(fontFamily: 'Momo',
                        color: Colors.white.withOpacity(.6))))
                : ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: Image.file(_image!, fit: BoxFit.cover, width: double.infinity)),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _pinned, activeColor: _kG1,
          title: const T('Pin to top',
              style: TextStyle(fontFamily: 'Arch', color: Colors.white)),
          onChanged: (v) => setState(() => _pinned = v),
        ),
        SwitchListTile(
          value: _publishNow, activeColor: _kG1,
          title: const T('Publish now (push to students)',
              style: TextStyle(fontFamily: 'Arch', color: Colors.white)),
          subtitle: Text(_publishNow ? 'Sends a notification immediately' : 'Saves as draft',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: Colors.white.withOpacity(.5))),
          onChanged: (v) => setState(() => _publishNow = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _kG2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _submitting
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const T('Post announcement',
                    style: TextStyle(fontFamily: 'Alfa', fontSize: 15, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
