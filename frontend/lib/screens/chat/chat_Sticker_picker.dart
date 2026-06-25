// lib/screens/chat/chat_Sticker_picker.dart
//
// Sticker picker with two modes:
//   • My Stickers   — user adds images from their phone gallery,
//                     persisted locally via SharedPreferences.
//                     Long-press a tile to remove.
//   • Sticker packs — backend packs from GET /api/chat/stickers/
//
// The first tab (heart icon) is always "My Stickers". Backend packs
// follow.

import 'dart:io';
import 'package:tcs_app/widgets/t_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG4     = Color(0xFFFF5858);
Color get _kInk => AppC.text;
const _kSlate  = Color(0xFF64687A);

const _kMyStickersKey = 'my_stickers_v1';

Future<void> showStickerPicker(
  BuildContext context, {
  required void Function(Map<String, dynamic> sticker) onPicked,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      expand: false,
      builder: (_, scrollCtrl) =>
          _StickerPickerSheet(scrollCtrl: scrollCtrl, onPicked: onPicked),
    ),
  );
}

class _StickerPickerSheet extends StatefulWidget {
  final ScrollController scrollCtrl;
  final void Function(Map<String, dynamic>) onPicked;
  const _StickerPickerSheet({
    required this.scrollCtrl,
    required this.onPicked,
  });

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  final _api          = ApiService();
  final _imagePicker  = ImagePicker();

  bool _loadingPacks   = true;
  bool _addingSticker  = false;
  List<Map<String, dynamic>> _packs = [];
  List<String> _myStickerPaths = [];

  /// 0 = My Stickers, 1..N = backend pack at index (n-1)
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _loadMyStickers();
    _loadPacks();
  }

  Future<void> _loadMyStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList(_kMyStickersKey) ?? [];
      // Prune deleted files
      final valid = paths.where((p) => File(p).existsSync()).toList();
      if (valid.length != paths.length) {
        await prefs.setStringList(_kMyStickersKey, valid);
      }
      if (!mounted) return;
      setState(() => _myStickerPaths = valid);
    } catch (_) {}
  }

  Future<void> _loadPacks() async {
    try {
      final data = await _api.getStickerPacks();
      if (!mounted) return;
      final list = (data is List)
          ? data.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      setState(() {
        _packs = list;
        _loadingPacks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPacks = false);
    }
  }

  Future<void> _addFromGallery() async {
    if (_addingSticker) return;
    setState(() => _addingSticker = true);
    try {
      final picked = await _imagePicker.pickImage(
        source:       ImageSource.gallery,
        maxWidth:     512,
        imageQuality: 92,
      );
      if (picked == null) return;
      final docsDir = await getApplicationDocumentsDirectory();
      final stDir   = Directory('${docsDir.path}/my_stickers');
      if (!stDir.existsSync()) stDir.createSync(recursive: true);
      final ext = picked.path.split('.').last.toLowerCase();
      final dest = '${stDir.path}/sticker_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(picked.path).copy(dest);
      final updated = [..._myStickerPaths, dest];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kMyStickersKey, updated);
      if (!mounted) return;
      setState(() => _myStickerPaths = updated);
      HapticFeedback.lightImpact();
    } catch (_) {
      _snack('Could not add sticker.');
    } finally {
      if (mounted) setState(() => _addingSticker = false);
    }
  }

  Future<void> _removeAt(int index) async {
    final path = _myStickerPaths[index];
    try { File(path).deleteSync(); } catch (_) {}
    final updated = [..._myStickerPaths]..removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kMyStickersKey, updated);
    if (!mounted) return;
    setState(() => _myStickerPaths = updated);
    HapticFeedback.mediumImpact();
  }

  Future<void> _confirmRemove(int index) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: T('Remove sticker?',
            style: TextStyle(fontFamily: 'Alfa', color: _kInk)),
        content: const T(
            'This will permanently remove this sticker from your saved set.',
            style: TextStyle(fontFamily: 'Momo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const T('Cancel',
                style: TextStyle(fontFamily: 'Momo', color: _kSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const T('Remove',
                style: TextStyle(fontFamily: 'Momo', color: _kG4)),
          ),
        ],
      ),
    );
    if (go == true) await _removeAt(index);
  }

  void _pickBackend(Map<String, dynamic> sticker) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    widget.onPicked(sticker);
  }

  void _pickLocal(String path) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    widget.onPicked({
      'is_local':     true,
      'file_path':    path,
      'message_type': 'sticker',
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_emotions_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            T('Stickers',
                style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 17, color: _kInk)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  color: Colors.grey.shade400),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFEDEEF3)),
        Expanded(child: _buildBody()),
        _buildTabs(),
      ]),
    );
  }

  Widget _buildBody() {
    if (_activeTab == 0) return _buildMy();
    if (_loadingPacks) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_packs.isEmpty) {
      return _emptyState(
          Icons.collections_rounded,
          'No sticker packs available yet.',
          'Add packs from the Django admin panel.');
    }
    final pIdx = _activeTab - 1;
    if (pIdx >= _packs.length) return const SizedBox.shrink();
    final pack = _packs[pIdx];
    final stickers = (pack['stickers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (stickers.isEmpty) {
      return _emptyState(
          Icons.sentiment_dissatisfied_rounded,
          'No stickers in this pack',
          'Check back later.');
    }
    return GridView.builder(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing:  12,
        crossAxisSpacing: 12,
      ),
      itemCount: stickers.length,
      itemBuilder: (_, i) {
        final s   = stickers[i];
        final url = s['image_url'] as String? ?? '';
        return InkWell(
          onTap: () => _pickBackend(s),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: url.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image_rounded,
                          color: Color(0xFFB0B3BD)),
                      placeholder: (_, __) => const SizedBox.shrink(),
                    )
                  : const Icon(Icons.image_rounded,
                      color: Color(0xFFB0B3BD)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMy() {
    return GridView.builder(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   4,
        mainAxisSpacing:  12,
        crossAxisSpacing: 12,
      ),
      itemCount: _myStickerPaths.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          // "Add from gallery" tile
          return InkWell(
            onTap: _addingSticker ? null : _addFromGallery,
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _kG2.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kG2.withOpacity(0.4),
                  width: 1.4,
                ),
              ),
              child: Center(
                child: _addingSticker
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kG2))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [_kG1, _kG2]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(height: 6),
                          const T('Add',
                              style: TextStyle(
                                  fontFamily: 'Momo',
                                  fontSize: 11,
                                  color: _kG2)),
                        ],
                      ),
              ),
            ),
          );
        }
        final idx  = i - 1;
        final path = _myStickerPaths[idx];
        return GestureDetector(
          onTap: () => _pickLocal(path),
          onLongPress: () => _confirmRemove(idx),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.5,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _packs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final active = i == _activeTab;
            if (i == 0) {
              // My Stickers tab
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeTab = 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(colors: [_kG1, _kG2])
                        : null,
                    color: active ? null : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? _kG2 : Colors.grey.shade200,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(Icons.favorite_rounded,
                      color: active ? Colors.white : _kSlate, size: 18),
                ),
              );
            }
            final pack  = _packs[i - 1];
            final thumb = pack['thumbnail_url'] as String? ?? '';
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50, height: 50,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: active ? _kG2.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? _kG2 : Colors.grey.shade200,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.collections_rounded,
                                color: _kSlate, size: 18),
                        placeholder: (_, __) => const SizedBox.shrink(),
                      )
                    : const Icon(Icons.collections_rounded,
                        color: _kSlate, size: 18),
              ),
            );
          },
        ),
      ),
    );
  }
}
