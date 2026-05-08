// lib/screens/saved_materials/saved_materials_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

// ── Library palette ───────────────────────────────────────────
const _kShelf    = Color(0xFF2C1810);   // dark mahogany
const _kWood     = Color(0xFF5C3317);   // mid wood
const _kWoodLight= Color(0xFF8B5E3C);   // light wood
const _kCream    = Color(0xFFFDF6EC);   // aged paper
const _kPaper    = Color(0xFFF5ECD7);   // paper card
const _kGold     = Color(0xFFD4A017);   // gold accent
const _kInk      = Color(0xFF1A1209);   // ink text
const _kInkLight = Color(0xFF4A3728);   // subtitle text

// File type → colour + icon
const _kTypeColors = {
  'pdf':   Color(0xFFE53935),
  'doc':   Color(0xFF1E88E5),
  'audio': Color(0xFF8E24AA),
  'image': Color(0xFF43A047),
  'video': Color(0xFFE91E63),
  'other': Color(0xFF546E7A),
};

// ─────────────────────────────────────────────────────────────
class SavedMaterialsScreen extends StatefulWidget {
  const SavedMaterialsScreen({super.key});
  @override
  State<SavedMaterialsScreen> createState() => _SavedMaterialsScreenState();
}

class _SavedMaterialsScreenState extends State<SavedMaterialsScreen>
    with SingleTickerProviderStateMixin {
  final _api     = ApiService();
  final _search  = TextEditingController();
  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;

  List<Map<String, dynamic>> _all       = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool   _loading      = true;
  String _activeFilter = 'All';
  bool   _searching    = false;

  final _filters = ['All', 'PDF', 'Doc', 'Audio', 'Image', 'Video', 'Other'];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500))..forward();
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/chat/saved/') as List;
      setState(() {
        _all     = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
      _filter();
    } catch (_) { setState(() => _loading = false); }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((m) {
        final title    = (m['title']     as String? ?? '').toLowerCase();
        final fileName = (m['file_name'] as String? ?? '').toLowerCase();
        final type     = _resolveType(m['file_type'] as String? ?? '');
        final matchQ   = q.isEmpty || title.contains(q) || fileName.contains(q);
        final matchF   = _activeFilter == 'All' ||
            type.toLowerCase() == _activeFilter.toLowerCase();
        return matchQ && matchF;
      }).toList();
    });
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove from Library?',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 17, color: _kInk)),
        content: Text('This material will be removed from your saved collection.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: _kInkLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Momo'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(
                fontFamily: 'Momo', color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await _api.delete('/chat/saved/$id/');
      setState(() {
        _all.removeWhere((m) => m['id'] == id);
      });
      _filter();
      _snack('Removed from library');
    } catch (e) { _snack('Could not remove: $e'); }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating, backgroundColor: _kWood,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _resolveType(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('pdf'))            return 'PDF';
    if (t.contains('word') ||
        t.contains('doc') ||
        t.contains('text')) {
      return 'Doc';
    }
    if (t.contains('audio') ||
        t.contains('mp3') ||
        t.contains('ogg') ||
        t.contains('wav')) {
      return 'Audio';
    }
    if (t.contains('image') ||
        t.contains('jpg') ||
        t.contains('jpeg') ||
        t.contains('png')) {
      return 'Image';
    }
    if (t.contains('video') ||
        t.contains('mp4')) {
      return 'Video';
    }
    return 'Other';
  }

  // ── Counts for each filter ────────────────────────────────

  Map<String, int> get _counts {
    final m = <String, int>{'All': _all.length};
    for (final item in _all) {
      final t = _resolveType(item['file_type'] as String? ?? '');
      m[t] = (m[t] ?? 0) + 1;
    }
    return m;
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kShelf,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kGold))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildGrid(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0E09), _kShelf, _kWood],
          begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top bar
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12))),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white70, size: 20)),
              ),
              const Spacer(),
              // Total count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kGold.withOpacity(0.4))),
                child: Text('${_all.length} items', style: const TextStyle(
                    fontFamily: 'Momo', fontSize: 12,
                    color: _kGold, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 16),

            // Title
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Library', style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 30,
                    color: Colors.white, letterSpacing: 0.5)),
                Text('Saved study materials', style: TextStyle(
                    fontFamily: 'Momo', fontSize: 13,
                    color: Colors.white54)),
              ]),
              const Spacer(),
              // Bookshelf icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGold.withOpacity(0.3))),
                child: const Center(child: Text('📚',
                    style: TextStyle(fontSize: 26)))),
            ]),
            const SizedBox(height: 16),

            // Search bar
            GestureDetector(
              onTap: () => setState(() => _searching = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _searching
                      ? Colors.white
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searching
                        ? _kGold
                        : Colors.white.withOpacity(0.15))),
                child: TextField(
                  controller: _search,
                  autofocus: false,
                  onTap:  () => setState(() => _searching = true),
                  onEditingComplete: () => setState(() => _searching = false),
                  style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                      color: _searching ? _kInk : Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search your materials...',
                    hintStyle: TextStyle(fontFamily: 'Momo',
                        color: _searching
                            ? Colors.grey.shade400
                            : Colors.white38),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _searching ? _kGold : Colors.white38),
                    suffixIcon: _search.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _search.clear();
                              setState(() {});
                            },
                            child: const Icon(Icons.clear_rounded,
                                color: Colors.grey, size: 18))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Filter chips ──────────────────────────────────────────

  Widget _buildFilterRow() {
    final counts = _counts;
    return Container(
      height: 52,
      color: _kWood,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f   = _filters[i];
          final sel = f == _activeFilter;
          final cnt = counts[f] ?? 0;
          if (cnt == 0 && f != 'All') return const SizedBox.shrink();
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _activeFilter = f);
              _filter();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? _kGold : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? _kGold : Colors.white.withOpacity(0.15))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_filterEmoji(f), style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(f, style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 12,
                    color: sel ? _kShelf : Colors.white70)),
                if (cnt > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: sel ? _kShelf.withOpacity(0.2) : Colors.white12,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$cnt', style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, fontWeight: FontWeight.bold,
                        color: sel ? _kShelf : Colors.white60))),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  String _filterEmoji(String f) {
    switch (f) {
      case 'PDF':   return '📄';
      case 'Doc':   return '📝';
      case 'Audio': return '🎵';
      case 'Image': return '🖼️';
      case 'Video': return '🎬';
      case 'Other': return '📎';
      default:      return '📚';
    }
  }

  // ── Empty state ───────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: _kWoodLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kWoodLight.withOpacity(0.2))),
          child: const Center(child: Text('📭',
              style: TextStyle(fontSize: 44)))),
        const SizedBox(height: 20),
        Text(_search.text.isNotEmpty || _activeFilter != 'All'
            ? 'No matches found'
            : 'Your library is empty',
            style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 18, color: _kInk)),
        const SizedBox(height: 8),
        Text(_search.text.isNotEmpty || _activeFilter != 'All'
            ? 'Try a different search or filter'
            : 'Save materials from chats and groups\nto find them all here',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: _kInkLight, height: 1.5)),
        if (_activeFilter != 'All' || _search.text.isNotEmpty) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              _search.clear();
              setState(() => _activeFilter = 'All');
              _filter();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _kWood.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kWood.withOpacity(0.2))),
              child: const Text('Clear filters', style: TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  color: _kWood, fontSize: 13)))),
        ],
      ]),
    ));
  }

  // ── Materials grid ────────────────────────────────────────

  Widget _buildGrid() {
    return RefreshIndicator(
      color: _kGold,
      backgroundColor: _kCream,
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Stats bar
            SliverToBoxAdapter(child: _buildStatsBar()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Grid
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _MaterialCard(
                  material: _filtered[i],
                  onDelete: () => _delete(_filtered[i]['id'] as String? ?? ''),
                  resolveType: _resolveType,
                ),
                childCount: _filtered.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final counts = _counts;
    final typeEntries = counts.entries
        .where((e) => e.key != 'All' && e.value > 0)
        .toList();

    if (typeEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kWoodLight.withOpacity(0.2))),
      child: Row(children: [
        const Text('📊', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 12, runSpacing: 4, children: typeEntries.map((e) {
            final color = _kTypeColors[e.key.toLowerCase()] ??
                _kTypeColors['other']!;
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color,
                      shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${e.key} (${e.value})', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11, color: _kInkLight)),
            ]);
          }).toList()),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MATERIAL CARD — looks like a book / file card
// ─────────────────────────────────────────────────────────────

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic>   material;
  final VoidCallback           onDelete;
  final String Function(String) resolveType;

  const _MaterialCard({
    required this.material,
    required this.onDelete,
    required this.resolveType,
  });

  Color _typeColor(String type) =>
      _kTypeColors[type.toLowerCase()] ?? _kTypeColors['other']!;

  String _typeEmoji(String type) {
    switch (type) {
      case 'PDF':   return '📄';
      case 'Doc':   return '📝';
      case 'Audio': return '🎵';
      case 'Image': return '🖼️';
      case 'Video': return '🎬';
      default:      return '📎';
    }
  }

  String _ago(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (d.inSeconds < 60) return 'Just now';
      if (d.inMinutes < 60) return '${d.inMinutes}m ago';
      if (d.inHours   < 24) return '${d.inHours}h ago';
      if (d.inDays    <  7) return '${d.inDays}d ago';
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final title    = material['title']     as String? ?? 'Untitled';
    final fileName = material['file_name'] as String? ?? '';
    final fileType = resolveType(material['file_type'] as String? ?? '');
    final savedAt  = _ago(material['created_at'] as String? ?? '');
    final fileUrl  = material['file_url']  as String? ?? '';
    final color    = _typeColor(fileType);
    final emoji    = _typeEmoji(fileType);

    return GestureDetector(
      onLongPress: onDelete,
      onTap: () {
        if (fileUrl.isNotEmpty) {
          // TODO: open file viewer
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Opening: $title',
                style: const TextStyle(fontFamily: 'Momo')),
            behavior: SnackBarBehavior.floating, backgroundColor: _kWood,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12),
                blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Book spine top — coloured header ──────────────
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)),
            ),
            child: Stack(children: [
              // Texture lines (book page effect)
              ...List.generate(5, (i) => Positioned(
                bottom: 8 + i * 6, left: 0, right: 0,
                child: Container(height: 0.5,
                    color: Colors.white.withOpacity(0.1)))),

              // File type emoji
              Center(child: Text(emoji,
                  style: const TextStyle(fontSize: 40))),

              // Type badge top-right
              Positioned(top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(fileType, style: const TextStyle(
                      fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 9, color: Colors.white)))),

              // Delete hint bottom-left
              Positioned(bottom: 8, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6)),
                  child: const Text('Hold to remove',
                      style: TextStyle(fontFamily: 'Momo',
                          fontSize: 8, color: Colors.white60)))),
            ]),
          ),

          // ── Card body ─────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 13, color: _kInk, height: 1.3)),
                  const SizedBox(height: 4),

                  // File name
                  if (fileName.isNotEmpty && fileName != title)
                    Text(fileName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Momo',
                            fontSize: 10, color: _kInkLight)),

                  const Spacer(),

                  // Saved time
                  Row(children: [
                    Icon(Icons.bookmark_rounded, size: 10, color: color),
                    const SizedBox(width: 4),
                    Text(savedAt, style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ),

          // ── Bottom action bar ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18)),
              border: Border(top: BorderSide(
                  color: color.withOpacity(0.1)))),
            child: Row(children: [
              // Open
              Expanded(child: GestureDetector(
                onTap: () {}, // TODO: open file
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.open_in_new_rounded, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text('Open', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: color)),
                ]),
              )),
              Container(width: 1, height: 14,
                  color: color.withOpacity(0.2)),
              // Share
              Expanded(child: GestureDetector(
                onTap: () {},
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.ios_share_rounded, size: 13,
                      color: _kInkLight),
                  const SizedBox(width: 4),
                  const Text('Share', style: TextStyle(fontFamily: 'Momo',
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: _kInkLight)),
                ]),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}