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
import 'package:tcs_app/widgets/dale_loader.dart';

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
  bool _tick = false; // brief green-tick flash after loading

  void _flashTick() {
    setState(() => _tick = true);
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _tick = false);
    });
  }
  bool _busy = false;

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _activeOnly = false;

  Map<String, dynamic>? _analytics;

  @override
  void initState() { super.initState(); _load(); _loadAnalytics(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _load() {
    CacheStore.I.swr(
      _kCacheKey,
      fetch: () => _api.get('/ai/knowledge/'),
      onData: (data, fresh) {
        if (!mounted) return;
        final wasLoading = _loading;
        final m = (data as Map?) ?? const {};
        setState(() {
          _docs = ((m['results'] as List?) ?? []).cast<Map<String, dynamic>>();
          _activeChunks = (m['active_chunks'] as int?) ?? 0;
          _loading = false;
        });
        if (wasLoading) _flashTick();
      },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  Future<void> _loadAnalytics() async {
    try {
      final d = (await _api.get('/ai/knowledge/analytics/')
          .catchError((_) => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();
      if (mounted) setState(() => _analytics = d);
    } catch (_) {/* analytics is best-effort */}
  }

  Future<void> _refresh() async {
    await CacheStore.I.invalidate(_kCacheKey);
    _load();
    _loadAnalytics();
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
              child: T('Cancel', style: TextStyle(color: AppC.sub))),
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
              child: T('Cancel', style: TextStyle(color: AppC.sub))),
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
        iconTheme: IconThemeData(color: AppC.text),
        title: T('Dale Knowledge',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kG2,
        onPressed: _busy ? null : _upload,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: const T('Upload material',
            style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: (_loading || _tick)
          ? DaleLoader(done: _tick, doneLabel: 'Dale is ready')
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
                      _analyticsSection(),
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

  // ── Training activity & analytics ─────────────────────────
  Widget _analyticsSection() {
    final a = _analytics;
    if (a == null) return const SizedBox.shrink();
    final totals = (a['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final last = (a['last_trained'] as Map?)?.cast<String, dynamic>();
    final recent = ((a['recent'] as List?) ?? []).cast<Map<String, dynamic>>();
    final mostUsed = ((a['most_used'] as List?) ?? []).cast<Map<String, dynamic>>();
    final contributors = (totals['contributors'] as int?) ?? 0;
    final retrievals = (totals['retrievals'] as int?) ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.insights_rounded, size: 16, color: _kG2),
        const SizedBox(width: 6),
        Text('Training activity',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 15, color: AppC.text)),
      ]),
      const SizedBox(height: 10),

      // How Dale uses it: contributors + times drawn on.
      Row(children: [
        _miniStat(Icons.people_alt_rounded, '$contributors',
            contributors == 1 ? 'contributor' : 'contributors',
            const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        _miniStat(Icons.auto_awesome_rounded, _comma(retrievals),
            'times Dale used it', const Color(0xFF0EA5A4)),
      ]),
      const SizedBox(height: 10),

      // Who last trained it + what they added + when.
      if (last != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kG2.withOpacity(.25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.history_rounded, size: 13, color: _kG1),
              const SizedBox(width: 5),
              Text('LAST TRAINED', style: TextStyle(fontFamily: 'Arch',
                  fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 1,
                  color: AppC.text.withOpacity(.45))),
              const Spacer(),
              Text(_ago((last['created_at'] ?? '').toString()),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 10.5,
                      color: AppC.text.withOpacity(.5))),
            ]),
            const SizedBox(height: 7),
            Text(last['title']?.toString() ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13.5, color: AppC.text)),
            const SizedBox(height: 2),
            Text('by ${last['by'] ?? 'Staff'}  ·  '
                '${last['chunk_count'] ?? 0} passages',
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: AppC.text.withOpacity(.5))),
          ]),
        ),

      // Recent activity feed.
      if (recent.length > 1) ...[
        const SizedBox(height: 12),
        Text('RECENT', style: TextStyle(fontFamily: 'Arch', fontSize: 8.5,
            fontWeight: FontWeight.bold, letterSpacing: 1,
            color: AppC.text.withOpacity(.4))),
        const SizedBox(height: 6),
        for (final r in recent.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: r['is_active'] == true ? _kG1 : AppC.text.withOpacity(.25),
                      shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Expanded(child: Text.rich(TextSpan(children: [
                TextSpan(text: '${r['by'] ?? 'Staff'} ',
                    style: TextStyle(fontFamily: 'Arch', fontSize: 11.5,
                        fontWeight: FontWeight.bold, color: AppC.text)),
                TextSpan(text: 'added ',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        color: AppC.text.withOpacity(.5))),
                TextSpan(text: (r['title'] ?? '').toString(),
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        color: AppC.text.withOpacity(.8))),
              ]), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Text(_ago((r['created_at'] ?? '').toString()),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 9.5,
                      color: AppC.text.withOpacity(.4))),
            ]),
          ),
      ],

      // How Dale responded — most-used materials.
      if (mostUsed.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('DALE LEANS ON', style: TextStyle(fontFamily: 'Arch', fontSize: 8.5,
            fontWeight: FontWeight.bold, letterSpacing: 1,
            color: AppC.text.withOpacity(.4))),
        const SizedBox(height: 6),
        for (final m in mostUsed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF0EA5A4)),
              const SizedBox(width: 8),
              Expanded(child: Text((m['title'] ?? '').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                      color: AppC.text.withOpacity(.8)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5A4).withOpacity(.12),
                  borderRadius: BorderRadius.circular(7)),
                child: Text('${m['retrieval_count'] ?? 0}×',
                    style: const TextStyle(fontFamily: 'Arch', fontSize: 10,
                        fontWeight: FontWeight.bold, color: Color(0xFF0EA5A4))),
              ),
            ]),
          ),
      ],
      const SizedBox(height: 16),
    ]);
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppC.border)),
        child: Row(children: [
          Container(
            width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
              Text(value, style: TextStyle(fontFamily: 'Alfa', fontSize: 16,
                  color: AppC.text, height: 1)),
              const SizedBox(height: 1),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 9.5,
                      color: AppC.text.withOpacity(.5))),
            ])),
        ]),
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
          border: Border.all(color: AppC.border)),
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
            border: Border.all(color: _activeOnly ? _kG2 : AppC.border)),
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
          border: Border.all(color: active ? _kG1.withOpacity(.25) : AppC.border),
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
              decoration: BoxDecoration(color: AppC.border,
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
          Divider(height: 1, color: AppC.divider),
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
                      border: Border.all(color: AppC.border)),
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
