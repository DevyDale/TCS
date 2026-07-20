// lib/widgets/chat/chat_sticker_picker.dart
//
// Sticker picker bottom sheet for chat.
//
// Fetches sticker packs from GET /api/chat/stickers/ (already wired in
// the backend at apps.chat.views.sticker_packs). Each pack returns:
//   { id, name, thumbnail_url, is_free, token_cost, stickers: [...] }
// and each sticker has { id, name, image_url, is_animated, sort_order }.
//
// Usage:
//   showStickerPicker(context, onPicked: (sticker) {
//     final stickerId = sticker['id'] as int;
//     final imageUrl  = sticker['image_url'] as String;
//     // Send via WebSocket: chatWs.sendSticker(stickerId)
//     // Or fall back to optimistic UI insert.
//   });

import 'package:cached_network_image/cached_network_image.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';

import '../../../services/api_service.dart';

const _kG1   = Color(0xFF6DD5FA);
const _kG2   = Color(0xFF8E54E9);
Color get _kInk => AppC.text;
Color get _kSlate => AppC.sub;

/// Public entry point — call this to show the picker.
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
  final _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _packs = [];
  int _activePack = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getStickerPacks();
      if (!mounted) return;
      final list = (data is List)
          ? data.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      setState(() {
        _packs = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _pick(Map<String, dynamic> sticker) {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    widget.onPicked(sticker);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
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
              icon: Icon(Icons.close_rounded, color: AppC.faint),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),

        Divider(height: 1, color: AppC.divider),

        // Body
        Expanded(child: _buildBody()),

        // Pack tabs at the bottom
        if (!_loading && _packs.isNotEmpty) _buildPackTabs(),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_packs.isEmpty) {
      return _empty();
    }
    final pack     = _packs[_activePack];
    final stickers = (pack['stickers'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    if (stickers.isEmpty) {
      return _empty(message: 'This pack has no stickers yet.');
    }

    return GridView.builder(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: stickers.length,
      itemBuilder: (_, i) {
        final s = stickers[i];
        final url = s['image_url'] as String? ?? '';
        return InkWell(
          onTap: () => _pick(s),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: AppC.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: url.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Icon(
                          Icons.broken_image_rounded,
                          color: AppC.faint),
                      placeholder: (_, __) => const SizedBox.shrink(),
                    )
                  : Icon(Icons.image_rounded, color: AppC.faint),
            ),
          ),
        );
      },
    );
  }

  Widget _empty({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied_rounded,
                size: 56, color: AppC.border),
            const SizedBox(height: 12),
            T('No stickers available yet',
                style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
            const SizedBox(height: 6),
            Text(
              message ??
                  'Add sticker packs from the Django admin panel to '
                  'get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 12,
                color: AppC.sub,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pack tabs ─────────────────────────────────────────────

  Widget _buildPackTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppC.bg,
        border: Border(top: BorderSide(color: AppC.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 50,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _packs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final pack   = _packs[i];
            final active = i == _activePack;
            final thumb  = pack['thumbnail_url'] as String? ?? '';
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activePack = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50, height: 50,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: active ? _kG2.withOpacity(0.12) : AppC.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? _kG2 : AppC.border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            Icon(Icons.collections_rounded,
                                color: _kSlate, size: 18),
                        placeholder: (_, __) => const SizedBox.shrink(),
                      )
                    : Icon(Icons.collections_rounded,
                        color: _kSlate, size: 18),
              ),
            );
          },
        ),
      ),
    );
  }
}
