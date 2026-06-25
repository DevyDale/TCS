// lib/screens/staff/staff_knowledge_screen.dart
//
// Staff "Dale AI" knowledge base. Upload PDFs/DOCXs of course material; the
// backend extracts + chunks them, and active docs feed Dale's answers (RAG).
// Staff can toggle a doc active/inactive or delete it.

import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kRed = Color(0xFFFF5858);
const _bg = Color(0xFF0B0B16);
const _card = Color(0xFF15152A);
const _kCacheKey = 'ai:knowledge';

class StaffKnowledgeScreen extends StatefulWidget {
  const StaffKnowledgeScreen({super.key});
  @override
  State<StaffKnowledgeScreen> createState() => _StaffKnowledgeScreenState();
}

class _StaffKnowledgeScreenState extends State<StaffKnowledgeScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _docs = [];
  int _activeChunks = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  void _load() {
    CacheStore.I.swr(
      _kCacheKey,
      fetch: () => _api.get('/ai/knowledge/'),
      onData: (data, fresh) {
        if (!mounted) return;
        final m = (data as Map?) ?? const {};
        setState(() {
          _docs = ((m['results'] as List?) ?? []).cast<Map<String, dynamic>>();
          _activeChunks = (m['active_chunks'] as int?) ?? 0;
          _loading = false;
        });
      },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  Future<void> _refresh() async {
    await CacheStore.I.invalidate(_kCacheKey);
    _load();
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.first;
    if (pf.path == null) { _snack('Could not read that file.', error: true); return; }
    if (!mounted) return;

    final titleCtrl   = TextEditingController(text: pf.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
    final subjectCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const T('Add to Dale\'s knowledge',
            style: TextStyle(fontFamily: 'Alfa', color: Colors.white, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white),
              decoration: _dec('Title')),
          const SizedBox(height: 10),
          TextField(controller: subjectCtrl, style: const TextStyle(color: Colors.white),
              decoration: _dec('Subject (optional)')),
          const SizedBox(height: 8),
          Text(pf.name, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: Colors.white.withOpacity(.5))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const T('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const T('Upload', style: TextStyle(color: _kG1))),
        ],
      ),
    );
    if (ok != true) return;

    final ext  = (pf.extension ?? '').toLowerCase();
    final mime = ext == 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.uploadFile('/ai/knowledge/upload/',
          filePath: pf.path!, field: 'file', mimeType: mime,
          extraFields: {'title': titleCtrl.text.trim(), 'subject': subjectCtrl.text.trim()});
      await _refresh();
      _snack('Added to Dale\'s knowledge ✓');
    } catch (e) {
      _snack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> d) async {
    setState(() => _busy = true);
    try {
      await _api.post('/ai/knowledge/${d['id']}/toggle/');
      await _refresh();
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const T('Delete document?',
            style: TextStyle(fontFamily: 'Alfa', color: Colors.white, fontSize: 17)),
        content: Text('"${d['title']}" will be removed from Dale\'s knowledge.',
            style: TextStyle(fontFamily: 'Momo', color: Colors.white.withOpacity(.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const T('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const T('Delete', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.delete('/ai/knowledge/${d['id']}/');
      await _refresh();
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(fontFamily: 'Momo', color: Colors.white.withOpacity(.6)),
    filled: true, fillColor: _bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
  );

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: error ? _kRed : _kG2,
      behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const T('Dale Knowledge',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kG2,
        onPressed: _busy ? null : _upload,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: const T('Upload material',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kG2))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  const Icon(Icons.psychology_rounded, size: 16, color: _kG1),
                  const SizedBox(width: 6),
                  Text('Dale is tutoring from $_activeChunks active passages',
                      style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                          color: Colors.white.withOpacity(.55))),
                ]),
              ),
              Expanded(
                child: _docs.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        color: _kG2,
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: _docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _docCard(_docs[i]),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.menu_book_rounded, size: 52, color: _kG1),
      const SizedBox(height: 12),
      const T('No material yet',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: Colors.white)),
      const SizedBox(height: 6),
      T('Upload notes so Dale tutors from your course content',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: Colors.white.withOpacity(.5))),
    ]),
  );

  Widget _docCard(Map<String, dynamic> d) {
    final active = d['is_active'] == true;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (active ? _kG1 : Colors.white24).withOpacity(.25)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((d['title'] ?? '').toString(),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Alfa', fontSize: 14, color: Colors.white)),
          const SizedBox(height: 4),
          Text([
            if ((d['subject'] ?? '').toString().isNotEmpty) d['subject'],
            '${d['chunk_count'] ?? 0} passages',
            d['uploaded_by'] ?? '',
          ].where((e) => (e ?? '').toString().isNotEmpty).join('  ·  '),
              style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                  color: Colors.white.withOpacity(.45))),
        ])),
        Switch(
          value: active, activeThumbColor: _kG1,
          onChanged: _busy ? null : (_) => _toggle(d),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 20),
          onPressed: _busy ? null : () => _delete(d),
        ),
      ]),
    );
  }
}
