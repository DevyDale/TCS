// lib/screens/profile/create_highlight_page.dart
//
// Create a profile Highlight — Instagram/WhatsApp-style story
// collection. Pushed from the "+ New" circle in the highlights row
// on profile_screen.dart.
//
// Flow:
//   1. Name the highlight
//   2. (Optional) pick a cover image
//   3. Add one or more story items (images and/or videos)
//   4. Tap "Create Highlight":
//        a. POST /highlights/         → creates the row, returns id
//        b. POST /highlights/upload/  → cover (if picked), is_cover=true
//        c. POST /highlights/upload/  → each story item, in order
//      Pops with `true` on success so the profile can refetch.
//
// Self-contained: only depends on image_picker + ApiService.

import 'dart:io';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';

// ── Light palette (matches profile_screen.dart) ──────────────
const _kBg1    = Color(0xFFFAFAFC);
Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;
Color get _kBorder => AppC.border;
Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
Color get _kInk => AppC.text;
const _kPurple = Color(0xFF7C3AED);
const _kBlue   = Color(0xFF6DD5FA);
const _kCoral  = Color(0xFFFF4F6E);

class _StoryItem {
  final File file;
  final bool isVideo;
  const _StoryItem(this.file, this.isVideo);
}

class CreateHighlightPage extends StatefulWidget {
  const CreateHighlightPage({super.key});
  @override
  State<CreateHighlightPage> createState() => _CreateHighlightPageState();
}

class _CreateHighlightPageState extends State<CreateHighlightPage> {
  final _api       = ApiService();
  final _picker    = ImagePicker();
  final _titleCtrl = TextEditingController();

  File?                  _coverFile;
  final List<_StoryItem> _items = [];

  bool   _saving   = false;
  String _progress = '';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty && _items.isNotEmpty && !_saving;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? _kCoral : Colors.green.shade600,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Pickers ───────────────────────────────────────────────

  Future<void> _pickCover() async {
    if (_saving) return;
    final x = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 85,
      maxWidth: 1000, maxHeight: 1000);
    if (x == null) return;
    setState(() => _coverFile = File(x.path));
  }

  Future<void> _addImages() async {
    if (_saving) return;
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      for (final x in picked) {
        _items.add(_StoryItem(File(x.path), false));
      }
    });
  }

  Future<void> _addVideo() async {
    if (_saving) return;
    final x = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60));
    if (x == null) return;
    setState(() => _items.add(_StoryItem(File(x.path), true)));
  }

  void _removeItem(int i) {
    if (_saving) return;
    HapticFeedback.lightImpact();
    setState(() => _items.removeAt(i));
  }

  void _showAddSheet() {
    if (_saving) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(
            color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          _sheetTile(Icons.photo_library_rounded, 'Add photos', _kPurple, () {
            Navigator.pop(context);
            _addImages();
          }),
          _sheetTile(Icons.videocam_rounded, 'Add a video', _kBlue, () {
            Navigator.pop(context);
            _addVideo();
          }),
          const SizedBox(height: 8),
        ])),
    );
  }

  Widget _sheetTile(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        onTap: onTap,
        leading: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 19)),
        title: Text(label, style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 14, color: _kInk)),
      );

  // ── Save ──────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _saving   = true;
      _progress = 'Creating highlight...';
    });

    String? highlightId;
    try {
      final created = await _api.createHighlight(
          title: _titleCtrl.text.trim()) as Map<String, dynamic>;
      highlightId = created['id']?.toString();
    } catch (e) {
      setState(() { _saving = false; _progress = ''; });
      _snack('Could not create highlight: $e', error: true);
      return;
    }

    if (highlightId == null || highlightId.isEmpty) {
      setState(() { _saving = false; _progress = ''; });
      _snack('Server did not return a highlight id.', error: true);
      return;
    }

    int uploaded = 0;
    final total  = _items.length + (_coverFile != null ? 1 : 0);

    if (_coverFile != null) {
      try {
        setState(() => _progress = 'Uploading cover (1/$total)...');
        await _api.uploadHighlightMedia(
          highlightId, _coverFile!, mediaType: 'image', isCover: true);
        uploaded++;
      } catch (_) {
        // Non-fatal — a cover can be set later; keep going.
      }
    }

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      try {
        setState(() => _progress = 'Uploading ${uploaded + 1}/$total...');
        await _api.uploadHighlightMedia(
          highlightId, item.file,
          mediaType: item.isVideo ? 'video' : 'image');
        uploaded++;
      } catch (_) {
        // Skip the failed item, continue with the rest.
      }
    }

    if (!mounted) return;
    setState(() { _saving = false; _progress = ''; });

    if (uploaded == 0) {
      _snack('Highlight created but no media uploaded.', error: true);
    } else {
      _snack('Highlight created');
    }
    Navigator.of(context).pop(true);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _kBg1,
      appBar: AppBar(
        backgroundColor: _kBg1,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _kInk),
          onPressed: _saving ? null : () => Navigator.pop(context)),
        title: T('New Highlight', style: TextStyle(
          fontWeight: FontWeight.w900, color: _kInk,
          fontSize: 17, letterSpacing: -0.3)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: _pickCover,
                child: Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    color: _kCardLo,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBorder, width: 1.5),
                    image: _coverFile != null
                        ? DecorationImage(
                            image: FileImage(_coverFile!), fit: BoxFit.cover)
                        : null),
                  child: _coverFile == null
                      ? Icon(Icons.add_a_photo_rounded,
                          color: _kSlate2, size: 24)
                      : null),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  T('Cover & name', style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 12,
                    color: _kSlate, letterSpacing: 0.3)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder)),
                    child: TextField(
                      controller: _titleCtrl,
                      enabled: !_saving,
                      maxLength: 24,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14, color: _kInk),
                      decoration: InputDecoration(
                        hintText: TranslationService.I.tr('e.g. Orientation'),
                        hintStyle: TextStyle(color: _kSlate2,
                          fontWeight: FontWeight.w600),
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13)),
                    ),
                  ),
                ])),
            ]),
            const SizedBox(height: 8),
            Text(
              _coverFile == null
                  ? 'Tap the circle to set a cover (optional).'
                  : 'Tap the circle to change the cover.',
              style: TextStyle(fontSize: 11.5, color: _kSlate2)),
            const SizedBox(height: 24),

            Row(children: [
              T('Story items', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12,
                color: _kInk, letterSpacing: 0.3)),
              const SizedBox(width: 8),
              Text('${_items.length}', style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12, color: _kPurple)),
            ]),
            const SizedBox(height: 12),
            _buildItemsGrid(),
            const SizedBox(height: 28),

            GestureDetector(
              onTap: _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  gradient: _canSave
                      ? const LinearGradient(colors: [_kPurple, _kBlue],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight)
                      : const LinearGradient(
                          colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _canSave ? [BoxShadow(
                    color: _kPurple.withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 5))] : []),
                child: Center(child: _saving
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.2)),
                        const SizedBox(width: 12),
                        Text(_progress.isEmpty ? 'Working...' : _progress,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white, fontSize: 13)),
                      ])
                    : const T('Create Highlight', style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white, fontSize: 15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72),
      itemCount: _items.length + 1,
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return GestureDetector(
            onTap: _showAddSheet,
            child: Container(
              decoration: BoxDecoration(
                color: _kCardLo,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder, width: 1.5)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: _kSlate2, size: 26),
                  SizedBox(height: 4),
                  T('Add', style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11, color: _kSlate2)),
                ])),
          );
        }
        final item = _items[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            if (item.isVideo)
              Container(
                color: const Color(0xFF1A1A2E),
                child: const Center(child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white, size: 30)))
            else
              Image.file(item.file, fit: BoxFit.cover),
            if (item.isVideo)
              Positioned(left: 6, bottom: 6, child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6)),
                child: const T('VIDEO', style: TextStyle(
                  color: Colors.white, fontSize: 8,
                  fontWeight: FontWeight.w800)))),
            Positioned(top: 4, right: 4, child: GestureDetector(
              onTap: () => _removeItem(i),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14)))),
            Positioned(left: 4, top: 4, child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(
                color: _kPurple, shape: BoxShape.circle),
              child: Center(child: Text('${i + 1}', style: const TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800))))),
          ]),
        );
      },
    );
  }
}
