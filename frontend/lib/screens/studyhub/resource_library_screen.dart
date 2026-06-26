// lib/screens/studyhub/resource_library_screen.dart
//
// Shared Study-Hub surface (spec §3B): teachers upload notes / past papers /
// guides / links per subject; everyone browses and downloads by subject.
// `isTeacher` unlocks the upload FAB, the verify toggle and delete. Students
// see the same library read-only, with a teacher-verified trust badge.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';

class ResourceLibraryScreen extends StatefulWidget {
  final bool isTeacher;
  const ResourceLibraryScreen({super.key, required this.isTeacher});

  @override
  State<ResourceLibraryScreen> createState() => _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends State<ResourceLibraryScreen> {
  final _api = ApiService();
  final _searchC = TextEditingController();
  bool _loading = true;
  String _subject = '';
  List<Map<String, dynamic>> _all = [];

  List<Map<String, dynamic>> get _items {
    final q = _subject.toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((r) =>
        (r['subject'] ?? '').toString().toLowerCase().contains(q) ||
        (r['title'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  static const _kinds = {
    'note': ('Note', Icons.sticky_note_2_rounded),
    'paper': ('Past paper', Icons.description_rounded),
    'guide': ('Guide', Icons.menu_book_rounded),
    'link': ('Link', Icons.link_rounded),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await _api.studyResources(subject: _subject) as Map;
      final list = (d['results'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() { _all = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> r) async {
    final url = (r['url'] ?? '').toString();
    if (url.isEmpty) return;
    try { await _api.downloadStudyResource(r['id'].toString()); } catch (_) {}
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this resource.')));
    }
  }

  Future<void> _verify(Map<String, dynamic> r) async {
    HapticFeedback.selectionClick();
    try {
      await _api.verifyStudyResource(r['id'].toString());
      _load();
    } catch (_) {}
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove resource?'),
        content: Text('“${r['title']}” will be removed from the library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (ok != true) return;
    try { await _api.deleteStudyResource(r['id'].toString()); _load(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              backgroundColor: kStaffG1,
              icon: const Icon(Icons.upload_rounded, color: Colors.white),
              label: const Text('Share',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      color: Colors.white)),
              onPressed: _showUploadSheet)
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        color: kStaffG1,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: StaffHeader(
              horizontal: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _back(),
                const SizedBox(width: 6),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Resource Library',
                        style: TextStyle(fontFamily: 'Alfa', fontSize: 23,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(widget.isTeacher
                        ? 'Share notes, papers & guides with your students'
                        : 'Teacher-curated notes, papers & guides',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                )),
                const Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: StaffSearchBar(
                controller: _searchC,
                hint: 'Filter by subject or title…',
                onChanged: (v) => setState(() => _subject = v.trim()),
              ),
            )),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: kStaffG1)))
            else if (_items.isEmpty)
              SliverFillRemaining(hasScrollBody: false,
                  child: staffNoResults(widget.isTeacher
                      ? 'No resources yet — tap Share to add the first.'
                      : 'No resources yet. Check back soon.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
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

  Widget _back() => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      );

  Widget _row(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? 'note').toString();
    final meta = _kinds[kind] ?? _kinds['note']!;
    final verified = r['verified'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: staffCard(),
      child: Row(children: [
        Container(
          width: 46, height: 46, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kStaffG1.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13)),
          child: Icon(meta.$2, color: kStaffG1, size: 23)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(child: Text(r['title']?.toString() ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 14, color: AppC.text))),
              if (verified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 15),
              ],
            ]),
            const SizedBox(height: 2),
            Text('${r['subject']}  ·  ${meta.$1}  ·  ${r['owner']}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: AppC.sub)),
          ],
        )),
        IconButton(
          icon: Icon(kind == 'link' ? Icons.open_in_new_rounded
              : Icons.download_rounded, color: kStaffG1, size: 22),
          onPressed: () => _open(r)),
        if (widget.isTeacher)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppC.faint, size: 20),
            onSelected: (v) {
              if (v == 'verify') _verify(r);
              if (v == 'delete') _delete(r);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'verify',
                  child: Text(verified ? 'Remove verified mark' : 'Mark verified')),
              const PopupMenuItem(value: 'delete', child: Text('Remove')),
            ],
          ),
      ]),
    );
  }

  // ── Upload sheet (teacher) ────────────────────────────────────────────
  void _showUploadSheet() {
    final titleC = TextEditingController();
    final subjC  = TextEditingController(text: _subject);
    final linkC  = TextEditingController();
    String kind = 'note';
    String? pickedPath, pickedName;
    bool busy = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> pick() async {
          final res = await FilePicker.platform.pickFiles(withData: false);
          if (res != null && res.files.single.path != null) {
            setSheet(() {
              pickedPath = res.files.single.path;
              pickedName = res.files.single.name;
              if (kind == 'link') kind = 'note';
            });
          }
        }

        Future<void> submit() async {
          final title = titleC.text.trim();
          final subj  = subjC.text.trim();
          final link  = linkC.text.trim();
          if (title.isEmpty || subj.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Title and subject are required.')));
            return;
          }
          if (pickedPath == null && link.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Attach a file or paste a link.')));
            return;
          }
          setSheet(() => busy = true);
          try {
            if (pickedPath != null) {
              await _api.uploadStudyResource(
                  filePath: pickedPath!, title: title, subject: subj, kind: kind);
            } else {
              await _api.addStudyLink(title: title, subject: subj, linkUrl: link);
            }
            if (ctx.mounted) Navigator.pop(ctx);
            _load();
          } catch (e) {
            setSheet(() => busy = false);
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Upload failed: $e')));
            }
          }
        }

        return Padding(
          padding: EdgeInsets.only(
              left: 18, right: 18, top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppC.faint,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text('Share a resource',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: AppC.text)),
            const SizedBox(height: 14),
            _field(titleC, 'Title', Icons.title_rounded),
            const SizedBox(height: 10),
            _field(subjC, 'Subject (e.g. Year 12 Chemistry)', Icons.school_rounded),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: _kinds.entries
                .where((e) => e.key != 'link' || pickedPath == null)
                .map((e) => ChoiceChip(
                    label: Text(e.value.$1),
                    selected: kind == e.key,
                    selectedColor: kStaffG1.withValues(alpha: 0.18),
                    onSelected: (_) => setSheet(() => kind = e.key)))
                .toList()),
            const SizedBox(height: 12),
            if (kind == 'link')
              _field(linkC, 'https://…', Icons.link_rounded)
            else
              OutlinedButton.icon(
                onPressed: pick,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                    foregroundColor: kStaffG1,
                    minimumSize: const Size.fromHeight(46)),
                label: Text(pickedName ?? 'Choose a file',
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: busy ? null : submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: kStaffG1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Share to library',
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold, color: Colors.white)),
              )),
          ]),
        );
      }),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) => TextField(
        controller: c,
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
