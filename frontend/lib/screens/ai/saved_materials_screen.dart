// lib/screens/saved_materials_screen.dart
//
// "My Library" — saved study materials, AI-quizzable.
//
// Theme matches ai_hub_screen.dart: LIGHT gradient page background
// (white → soft grey → white) with animated SweepGradient borders
// on every card surface. ONE shared AnimationController drives every
// border via AnimatedBuilder + child param.
//
// The All / Subject / Group / Date tab row has been removed — the page
// now shows a single flat grid of everything, still filterable by the
// file-type chips and the search bar.
//
// Upload button (in the FAB stack) lets the user pick a document
// straight from their phone and push it into the library (and quiz on
// it). It posts a multipart file to /chat/saved/upload/ — that backend
// endpoint must store the file (Cloudinary) and create a SavedMaterial
// so the quiz engine can read it.

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:lottie/lottie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tcs_app/screens/ai/quiz_generator_Screen.dart';
import 'package:tcs_app/screens/ai/saved_quizzes_screen.dart';
import 'package:tcs_app/widgets/uploading_delay.dart';
import '../../../services/api_service.dart';


// ── Light palette (matches ai_hub_screen.dart) ────────────────
Color get _kBg1 => AppC.bg;
Color get _kBg2 => AppC.bg;
Color get _kBg3 => AppC.bg;

Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;

Color get _kBorder => AppC.border;

Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
Color get _kInkSoft => AppC.sub;
Color get _kInk => AppC.text;

const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

const _kTypeColors = {
  'pdf':   Color(0xFFEF4444),
  'doc':   Color(0xFF3B82F6),
  'audio': Color(0xFF8B5CF6),
  'image': Color(0xFF10B981),
  'video': Color(0xFFF59E0B),
  'other': Color(0xFF64748B),
};

// ─────────────────────────────────────────────────────────────
class SavedMaterialsScreen extends StatefulWidget {
  const SavedMaterialsScreen({super.key});

  @override
  State<SavedMaterialsScreen> createState() => _SavedMaterialsScreenState();
}

class _SavedMaterialsScreenState extends State<SavedMaterialsScreen>
    with TickerProviderStateMixin {
  final _api    = ApiService();
  final _search = TextEditingController();

  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl;
  late final Animation<double>   _fadeAnim;

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];

  bool     _loading      = true;
  String   _typeFilter   = 'All';

  static const _typeFilters = ['All', 'PDF', 'Doc', 'Audio', 'Image', 'Video', 'Other'];

  // ─── Lifecycle ───────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500))..forward();
    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 6))..repeat();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

  // ─── Data ────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/chat/saved/') as List;
      setState(() {
        _all     = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
      _filter();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((m) {
        final title    = (m['title']     as String? ?? '').toLowerCase();
        final fileName = (m['file_name'] as String? ?? '').toLowerCase();
        final subject  = (m['subject']   as String? ?? '').toLowerCase();
        final source   = (m['source_group_name'] as String? ?? '').toLowerCase();
        final type     = _resolveType(m['file_type'] as String? ?? '');

        final matchesType = _typeFilter == 'All' ||
            type.toLowerCase() == _typeFilter.toLowerCase();
        final matchesSearch = q.isEmpty ||
            title.contains(q) || fileName.contains(q) ||
            subject.contains(q) || source.contains(q);
        return matchesType && matchesSearch;
      }).toList();
    });
  }

  String _resolveType(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('pdf'))                              return 'pdf';
    if (r.contains('doc') || r.contains('word'))        return 'doc';
    if (r.contains('audio') || r.contains('voice'))     return 'audio';
    if (r.contains('image') || r.contains('photo'))     return 'image';
    if (r.contains('video'))                            return 'video';
    return 'other';
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: T('Remove from library?',
            style: TextStyle(color: _kInk, fontSize: 17,
                fontWeight: FontWeight.w800)),
        content: Text(
            "This won't delete the original file — just take it out of your library.",
            style: TextStyle(color: _kSlate, fontSize: 13, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: T('Cancel',
                  style: TextStyle(color: _kSlate, fontSize: 13))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const T('Remove',
                  style: TextStyle(color: Color(0xFFFF4F6E), fontSize: 13))),
        ],
      ),
    ) ?? false;

    if (!ok) return;
    try { await _api.delete('/chat/saved/$id/'); } catch (_) {}
    setState(() {
      _all.removeWhere((m) => m['id'] == id);
    });
    _filter();
  }

  void _openQuizWizard({Map<String, dynamic>? prefilledMaterial}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizGeneratorScreen(
        materials: _all,
        initialMaterial: prefilledMaterial,
      ),
    )).then((_) => _load());
  }

  // ─── Upload a document straight from the phone into the library ──
  //
  // Posts a multipart file to /chat/saved/upload/. That endpoint must
  // store the file (Cloudinary) and create a SavedMaterial so it shows
  // up here and can be quizzed. Until the endpoint exists this will
  // surface "Upload failed".
  Future<void> _uploadToLibrary() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv',
      ],
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.first;
    if (pf.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: T('Could not read that file.')));
      }
      return;
    }

    final ext = (pf.extension ?? '').toLowerCase();
    String mime = 'application/octet-stream';
    if (ext == 'pdf')                       mime = 'application/pdf';
    else if (ext == 'doc' || ext == 'docx') mime = 'application/msword';
    else if (ext == 'ppt' || ext == 'pptx') mime = 'application/vnd.ms-powerpoint';
    else if (ext == 'xls' || ext == 'xlsx') mime = 'application/vnd.ms-excel';
    else if (ext == 'txt')                  mime = 'text/plain';
    else if (ext == 'csv')                  mime = 'text/csv';

    if (!mounted) return;
    showUploadingDialog(context, message: 'Uploading to your library…');
    try {
      final result = await _api.uploadFile(
        '/chat/saved/upload/',            // ← NEW backend endpoint (still to build)
        filePath:    pf.path!,
        field:       'file',
        mimeType:    mime,
        extraFields: {'title': pf.name, 'source_type': 'manual'},
      );
      if (result != null) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: T('Added to your library ✓')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) dismissUploadingDialog(context);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _buildFab(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops:  [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(children: [
              _buildHeader(),
              _buildTypeFilterRow(),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(
                        color: _kInkSoft, strokeWidth: 2.5))
                    : _filtered.isEmpty
                        ? _buildEmpty()
                        : _buildFlatGrid(),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─── FAB ─────────────────────────────────────────────────
  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Upload document — gradient-bordered icon button
        _GradientBorderCard(
          animation:   _shimmerCtrl,
          radius:      16,
          borderWidth: 1.4,
          innerColor:  _kCard,
          padding:     const EdgeInsets.all(12),
          child: Tooltip(
            message: 'Upload a document',
            child: GestureDetector(
              onTap: _uploadToLibrary,
              child: Icon(Icons.upload_file_rounded,
                  color: _kInkSoft, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // My quizzes — gradient-bordered icon button
        _GradientBorderCard(
          animation:   _shimmerCtrl,
          radius:      16,
          borderWidth: 1.4,
          innerColor:  _kCard,
          padding:     const EdgeInsets.all(12),
          child: Tooltip(
            message: 'My quizzes',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SavedQuizzesScreen())),
              child: Icon(Icons.quiz_outlined,
                  color: _kInkSoft, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quiz me — gradient-bordered pill with Lottie robot
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (_all.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: T('Save some materials first to quiz on them.')));
                return;
              }
              _openQuizWizard();
            },
            child: _GradientBorderCard(
              animation:   _shimmerCtrl,
              radius:      18,
              borderWidth: 1.6,
              innerColor:  _kCard,
              padding:     const EdgeInsets.fromLTRB(12, 10, 18, 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 28, height: 28,
                  child: _SafeRobotLottie(),
                ),
                const SizedBox(width: 10),
                T('Quiz me',
                    style: TextStyle(
                        color: _kInk, fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    final rounded = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _kBorder),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kInk, size: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Library icon chip — gradient border around 📚
          _GradientBorderCard(
            animation:   _shimmerCtrl,
            radius:      13,
            borderWidth: 1.4,
            innerColor:  _kCard,
            padding:     const EdgeInsets.all(9),
            child: const T('📚', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),

          // Title + tagline
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            T('My Digital Library',
                style: TextStyle(color: _kInk,
                    fontSize: 22, fontWeight: FontWeight.w800,
                    letterSpacing: -0.4, height: 1.1)),
            SizedBox(height: 2),
            T('AI-quizzable study materials',
                style: TextStyle(color: _kSlate, fontSize: 12.5)),
          ])),

          // Item count — gradient-bordered pill
          _GradientBorderCard(
            animation:   _shimmerCtrl,
            radius:      11,
            borderWidth: 1.2,
            innerColor:  _kCard,
            padding:     const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text('${_all.length}',
                style: TextStyle(color: _kInk,
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 14),

        // Search bar — gradient-bordered, with Material + Theme
        // override so the white fill stays rounded and the dark
        // global inputDecorationTheme can't leak in.
        _GradientBorderCard(
          animation:   _shimmerCtrl,
          radius:      13,
          borderWidth: 1.4,
          innerColor:  _kCard,
          padding:     EdgeInsets.zero,
          child: Material(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 46,
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: _kCard,
                    border:         rounded,
                    enabledBorder:  rounded,
                    focusedBorder:  rounded,
                    disabledBorder: rounded,
                  ),
                  textSelectionTheme: TextSelectionThemeData(
                    cursorColor: _kInk,
                    selectionColor: Color(0x33A78BFA),
                    selectionHandleColor: _kInk,
                  ),
                ),
                child: TextField(
                  controller: _search,
                  cursorColor: _kInk,
                  style: TextStyle(color: _kInk, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _kCard,
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _kSlate2, size: 19),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 42, minHeight: 42),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: _kSlate2, size: 16),
                            onPressed: () { _search.clear(); _filter(); }),
                    hintText: TranslationService.I.tr('Search title, subject, group…'),
                    hintStyle: TextStyle(color: _kSlate2, fontSize: 13),
                    border:         rounded,
                    enabledBorder:  rounded,
                    focusedBorder:  rounded,
                    disabledBorder: rounded,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 13),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── File-type filter chips ─────────────────────────────
  Widget _buildTypeFilterRow() {
    return SizedBox(
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        itemCount: _typeFilters.length,
        itemBuilder: (_, i) {
          final f = _typeFilters[i];
          final selected = f == _typeFilter;
          final inner = AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              border: selected ? null : Border.all(color: _kBorder),
            ),
            child: Center(child: Text(f,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    color: selected ? _kInk : _kSlate))),
          );
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () { setState(() => _typeFilter = f); _filter(); },
              child: selected
                  ? _GradientBorderCard(
                      animation:   _shimmerCtrl,
                      radius:      19,
                      borderWidth: 1.4,
                      innerColor:  _kCard,
                      child:       inner)
                  : inner,
            ),
          );
        },
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _GradientBorderCard(
            animation:   _shimmerCtrl,
            radius:      40,
            borderWidth: 1.6,
            innerColor:  _kCard,
            padding:     const EdgeInsets.all(22),
            child: const T('📖', style: TextStyle(fontSize: 38)),
          ),
          const SizedBox(height: 20),
          Text(
            _search.text.isNotEmpty || _typeFilter != 'All'
                ? 'No matches found'
                : 'Your library is empty',
            style: TextStyle(color: _kInk,
                fontSize: 18, fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(
            _search.text.isNotEmpty || _typeFilter != 'All'
                ? 'Try a different search or filter'
                : 'Save materials from chats and groups, or tap the\nupload button to add one from your phone',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSlate,
                fontSize: 13, height: 1.5)),
        ]),
      ),
    );
  }

  // ─── Flat grid ──────────────────────────────────────────
  Widget _buildFlatGrid() {
    return RefreshIndicator(
      color: _kInkSoft, backgroundColor: _kCard, onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 130),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12,
          mainAxisSpacing: 12, childAspectRatio: 0.74),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _MaterialCard(
          material:    _filtered[i],
          shimmerCtrl: _shimmerCtrl,
          resolveType: _resolveType,
          onDelete:    () => _delete(_filtered[i]['id'] as String),
          onQuiz:      () => _openQuizWizard(prefilledMaterial: _filtered[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Material card
// ─────────────────────────────────────────────────────────────
class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic>    material;
  final AnimationController     shimmerCtrl;
  final String Function(String) resolveType;
  final VoidCallback            onDelete;
  final VoidCallback            onQuiz;

  const _MaterialCard({
    required this.material,
    required this.shimmerCtrl,
    required this.resolveType,
    required this.onDelete,
    required this.onQuiz,
  });

  Color _typeColor(String t) =>
      _kTypeColors[t.toLowerCase()] ?? _kTypeColors['other']!;

  IconData _typeIcon(String t) {
    switch (t.toLowerCase()) {
      case 'pdf':   return Icons.picture_as_pdf_rounded;
      case 'doc':   return Icons.article_rounded;
      case 'audio': return Icons.audiotrack_rounded;
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.videocam_rounded;
      default:      return Icons.insert_drive_file_rounded;
    }
  }

  bool _isQuizable(String t) => t == 'pdf' || t == 'doc';

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7)    return '${dt.day}/${dt.month}/${dt.year % 100}';
    if (diff.inDays > 0)    return '${diff.inDays}d ago';
    if (diff.inHours > 0)   return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final type     = resolveType(material['file_type'] as String? ?? '');
    final color    = _typeColor(type);
    final title    = material['title']     as String? ?? 'Untitled';
    final fileName = material['file_name'] as String? ?? '';
    final subject  = material['subject']   as String? ?? '';
    final source   = material['source_group_name'] as String? ?? '';
    final savedAt  = _formatDate(material['created_at'] as String? ?? '');
    final canQuiz  = _isQuizable(type);

    return _GradientBorderCard(
      animation:   shimmerCtrl,
      radius:      18,
      borderWidth: 1.4,
      innerColor:  _kCard,
      padding:     EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Top row: type chip + badge + delete ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.22))),
              child: Icon(_typeIcon(type), color: color, size: 22),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.22))),
              child: Text(type.toUpperCase(),
                  style: TextStyle(color: color,
                      fontSize: 10, fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
            const Spacer(),
            // Delete X
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _kCardLo,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _kBorder)),
                child: Icon(Icons.close_rounded,
                    size: 16, color: _kSlate),
              ),
            ),
          ]),
        ),

        // ── Body ─────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _kInk,
                      fontSize: 14, fontWeight: FontWeight.w800,
                      height: 1.3, letterSpacing: -0.2)),
              const SizedBox(height: 3),
              if (fileName.isNotEmpty && fileName != title)
                Text(fileName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _kSlate2,
                        fontSize: 11, fontFamily: 'monospace')),
              const Spacer(),
              Wrap(spacing: 4, runSpacing: 4, children: [
                if (subject.isNotEmpty) _miniTag('📘', subject),
                if (source.isNotEmpty)  _miniTag('👥', source),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.schedule_rounded,
                    size: 11, color: _kSlate2),
                const SizedBox(width: 4),
                Text(savedAt,
                    style: TextStyle(color: _kSlate2,
                        fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
        ),

        // ── Bottom: Quiz me affordance ───────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16)),
          onTap: canQuiz ? onQuiz : () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: T('Quizzes can only be made from PDFs or DOCXs.')));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            decoration: BoxDecoration(
              color: _kCardLo,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 14, color: canQuiz ? _kInk : _kSlate2),
              const SizedBox(width: 6),
              T('Quiz me',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: canQuiz ? _kInk : _kSlate2)),
              const Spacer(),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: canQuiz ? _kInkSoft : _kSlate2),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _miniTag(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kCardLo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _kInkSoft,
                  fontSize: 10.5, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — copied from ai_hub_screen.dart
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double>   animation;
  final Widget              child;
  final double              radius;
  final double              borderWidth;
  final Color?               innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color>         colors;

  _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor,
    this.padding,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            math.max(0.0, radius - borderWidth)),
        color: innerColor ?? _kCard,
      ),
      padding: padding,
      child: child,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final t = animation.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
              colors: colors,
              startAngle: t,
              endAngle: t + 2 * math.pi,
            ),
          ),
          padding: EdgeInsets.all(borderWidth),
          child: c,
        );
      },
      child: inner,
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _SafeRobotLottie — copied from ai_hub_screen.dart
// ═════════════════════════════════════════════════════════════

class _SafeRobotLottie extends StatelessWidget {
  const _SafeRobotLottie();

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/images/robot.json',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kCardLo,
        ),
        child: Icon(
          Icons.smart_toy_rounded,
          color: _kInkSoft,
          size: 18,
        ),
      ),
    );
  }
}