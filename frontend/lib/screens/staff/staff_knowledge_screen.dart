// lib/screens/staff/staff_knowledge_screen.dart
//
// Staff "Dale AI" knowledge base. Upload PDFs/DOCXs of course material; the
// backend extracts + chunks them, and active docs feed Dale's answers (RAG).
// Staff can toggle a doc active/inactive or delete it.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kRed = Color(0xFFFF5858);
Color get _bg => AppC.bg;
Color get _card => AppC.card;
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

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _activeOnly = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

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
        title: T('Add to Dale\'s knowledge',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, style: TextStyle(color: AppC.text),
              decoration: _dec('Title')),
          const SizedBox(height: 10),
          TextField(controller: subjectCtrl, style: TextStyle(color: AppC.text),
              decoration: _dec('Subject (optional)')),
          const SizedBox(height: 8),
          Text(pf.name, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
              color: AppC.text.withOpacity(.5))),
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
        title: T('Delete document?',
            style: TextStyle(fontFamily: 'Alfa', color: AppC.text, fontSize: 17)),
        content: Text('"${d['title']}" will be removed from Dale\'s knowledge.',
            style: TextStyle(fontFamily: 'Momo', color: AppC.text.withOpacity(.8))),
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
    labelStyle: TextStyle(fontFamily: 'Momo', color: AppC.text.withOpacity(.6)),
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

  // ── helpers ───────────────────────────────────────────────
  String _comma(int n) => n.toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  String _ago(String iso) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
    return '${(d.inDays / 365).floor()}y ago';
  }

  // Docs after search + active-only filter, grouped by subject.
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final q = _query.trim().toLowerCase();
    final filtered = _docs.where((d) {
      if (_activeOnly && d['is_active'] != true) return false;
      if (q.isEmpty) return true;
      final hay = '${d['title']} ${d['subject']} ${d['uploaded_by']}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final d in filtered) {
      final s = (d['subject'] ?? '').toString().trim();
      groups.putIfAbsent(s.isEmpty ? 'General' : s, () => []).add(d);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped();
    final subjects = groups.keys.toList()..sort();
    final totalActive = _docs.where((d) => d['is_active'] == true).length;
    String lastTrained = '';
    if (_docs.isNotEmpty) {
      final newest = _docs
          .map((d) => (d['created_at'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .fold<String>('', (a, b) => b.compareTo(a) > 0 ? b : a);
      lastTrained = newest.isEmpty ? '' : _ago(newest);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: T('Dale Knowledge',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kG2,
        onPressed: _busy ? null : _upload,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: T('Upload material',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold, color: AppC.text)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kG2))
          : _docs.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: _kG2,
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    children: [
                      _statsHeader(totalActive, lastTrained),
                      const SizedBox(height: 14),
                      _searchBar(),
                      const SizedBox(height: 12),
                      if (subjects.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(child: Text('No materials match.',
                              style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                                  color: AppC.text.withOpacity(.5)))),
                        )
                      else
                        for (final s in subjects) ...[
                          _subjectHeader(s, groups[s]!.length),
                          const SizedBox(height: 8),
                          for (final d in groups[s]!) ...[
                            _docCard(d),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 6),
                        ],
                    ],
                  ),
                ),
    );
  }

  // ── Stats header (training overview) ──────────────────────
  Widget _statsHeader(int activeDocs, String lastTrained) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6DD5FA), Color(0xFF8E54E9)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text("Dale's training",
              style: TextStyle(fontFamily: 'Alfa', fontSize: 16,
                  color: Colors.white)),
          const Spacer(),
          if (lastTrained.isNotEmpty)
            Text('Last: $lastTrained',
                style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                    color: Colors.white.withOpacity(.9))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _stat('${_docs.length}', 'materials'),
          _statDivider(),
          _stat('$activeDocs', 'active'),
          _statDivider(),
          _stat(_comma(_activeChunks), 'passages'),
        ]),
      ]),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(fontFamily: 'Alfa', fontSize: 20,
              color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
              color: Colors.white.withOpacity(.9))),
        ]),
      );

  Widget _statDivider() => Container(
      width: 1, height: 30, color: Colors.white.withOpacity(.25));

  // ── Search + active-only filter ───────────────────────────
  Widget _searchBar() {
    return Row(children: [
      Expanded(child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 18, color: AppC.text.withOpacity(.4)),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.text),
            decoration: InputDecoration(
              isDense: true, border: InputBorder.none,
              hintText: 'Search materials…',
              hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  color: AppC.text.withOpacity(.35))),
          )),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
              child: Icon(Icons.close_rounded, size: 16,
                  color: AppC.text.withOpacity(.4))),
        ]),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () => setState(() => _activeOnly = !_activeOnly),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _activeOnly ? _kG2 : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _activeOnly ? _kG2 : Colors.white12)),
          child: Row(children: [
            Icon(Icons.bolt_rounded, size: 16,
                color: _activeOnly ? Colors.white : AppC.text.withOpacity(.5)),
            const SizedBox(width: 5),
            Text('Active',
                style: TextStyle(fontFamily: 'Arch', fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _activeOnly ? Colors.white : AppC.text.withOpacity(.6))),
          ]),
        ),
      ),
    ]);
  }

  Widget _subjectHeader(String subject, int count) => Row(children: [
        Container(width: 4, height: 14,
            decoration: BoxDecoration(color: _kG1,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(subject.toUpperCase(),
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 12, letterSpacing: 0.5, color: AppC.text)),
        const SizedBox(width: 6),
        Text('($count)', style: TextStyle(fontFamily: 'Momo', fontSize: 11,
            color: AppC.text.withOpacity(.4))),
      ]);

  Widget _empty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.menu_book_rounded, size: 52, color: _kG1),
      const SizedBox(height: 12),
      T('No material yet',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
      const SizedBox(height: 6),
      T('Upload notes so Dale tutors from your course content',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: AppC.text.withOpacity(.5))),
    ]),
  );

  Widget _docCard(Map<String, dynamic> d) {
    final active = d['is_active'] == true;
    final meta = [
      '${d['chunk_count'] ?? 0} passages',
      if ((d['char_count'] ?? 0) is int && (d['char_count'] ?? 0) > 0)
        '${_comma(d['char_count'])} chars',
      if (_ago((d['created_at'] ?? '').toString()).isNotEmpty)
        'Trained ${_ago((d['created_at'] ?? '').toString())}',
      if ((d['uploaded_by'] ?? '').toString().isNotEmpty) 'by ${d['uploaded_by']}',
    ].join('  ·  ');

    return GestureDetector(
      onTap: () => _preview(d),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (active ? _kG1 : Colors.white24).withOpacity(.25)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text((d['title'] ?? '').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 14, color: AppC.text))),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 16,
                  color: AppC.text.withOpacity(.3)),
            ]),
            const SizedBox(height: 4),
            Text(meta,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                    color: AppC.text.withOpacity(.45))),
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
      ),
    );
  }

  // ── Preview: the passages Dale learned from this doc ──────
  void _preview(Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4,
        builder: (ctx, scroll) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 38, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, color: _kG1, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text((d['title'] ?? '').toString(),
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: AppC.text))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('What Dale learned from this material',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.text.withOpacity(.5))),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: FutureBuilder(
            future: _api.get('/ai/knowledge/${d['id']}/chunks/')
                .catchError((_) => <String, dynamic>{}),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: _kG2));
              }
              final m = (snap.data as Map?) ?? const {};
              final chunks = ((m['chunks'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>();
              if (chunks.isEmpty) {
                return Center(child: Text('No passages to preview.',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                        color: AppC.text.withOpacity(.5))));
              }
              return ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                itemCount: chunks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final c = chunks[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bg, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Passage ${(c['ordinal'] ?? i) + 1}',
                            style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                                fontWeight: FontWeight.bold, letterSpacing: 0.5,
                                color: _kG1)),
                        const SizedBox(height: 6),
                        Text((c['content'] ?? '').toString(),
                            style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                                height: 1.45, color: AppC.text.withOpacity(.85))),
                      ]),
                  );
                },
              );
            },
          )),
        ]),
      ),
    );
  }
}
