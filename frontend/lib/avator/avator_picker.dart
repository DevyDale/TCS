// lib/screens/avatar/avatar_picker_screen.dart
//
// Avatar picker — full-screen modal where the user browses and selects
// from 100 preset avatars. Supports:
//   • Category filter chips (All / Animals / Fantasy / Sci-Fi / etc)
//   • Search by name
//   • Live preview of the currently-selected avatar at the top
//   • One-tap save → returns the selected avatar id to the caller
//
// USAGE:
//   final newId = await Navigator.of(context).push<int>(
//     MaterialPageRoute(builder: (_) => AvatarPickerScreen(
//       initialAvatarId: user.avatarId,
//     )),
//   );
//   if (newId != null) {
//     await api.updateProfile({'avatar_id': newId});
//   }

import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';

import '../data/avators.dart';
import 'avator_view.dart';



const _kG1   = Color(0xFF6DD5FA);
const _kG2   = Color(0xFF8E54E9);
const _kInk  = Color(0xFF1A1A2E);

class AvatarPickerScreen extends StatefulWidget {
  final int? initialAvatarId;
  const AvatarPickerScreen({super.key, this.initialAvatarId});

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  String _category    = 'all';
  String _searchQuery = '';
  int?   _selectedId;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialAvatarId;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AvatarDef> get _filtered {
    Iterable<AvatarDef> list = kAvatars;
    if (_category != 'all') {
      list = list.where((a) => a.category == _category);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.category.toLowerCase().contains(q));
    }
    return list.toList();
  }

  void _select(int id) {
    HapticFeedback.lightImpact();
    setState(() => _selectedId = id);
  }

  void _save() {
    if (_selectedId == null) {
      Navigator.pop(context);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDef = _selectedId != null
        ? avatarById(_selectedId)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          _buildPreview(selectedDef),
          _buildSearchField(),
          _buildCategoryChips(),
          Expanded(child: _buildGrid()),
          _buildSaveBar(),
        ]),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEEF3))),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: T('Choose Avatar',
              style: TextStyle(
                fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
        ),
      ]),
    );
  }

  // ── Preview ───────────────────────────────────────────────

  Widget _buildPreview(AvatarDef? def) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: def != null
              ? [def.gradient.first.withOpacity(0.15),
                 def.gradient.last.withOpacity(0.05)]
              : [Colors.white, Colors.white],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: def != null
              ? AvatarView.preset(
                  def.id, size: 96, showBorder: true,
                  key: ValueKey('preview_${def.id}'))
              : Container(
                  key: const ValueKey('preview_none'),
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                  child: Icon(Icons.help_outline_rounded,
                      size: 36, color: Colors.grey.shade400),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          def?.name ?? 'Pick one below',
          style: const TextStyle(
              fontFamily: 'Alfa', fontSize: 16, color: _kInk),
        ),
        if (def != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              kAvatarCategoryLabels[def.category] ?? def.category,
              style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 11,
                  color: Colors.grey.shade600),
            ),
          ),
      ]),
    );
  }

  // ── Search ────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEEF3)),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon:
                Icon(Icons.search_rounded, color: Colors.grey.shade400),
            hintText: 'Search avatars by name...',
            hintStyle: TextStyle(
                fontFamily: 'Momo',
                color: Colors.grey.shade400, fontSize: 14),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.grey.shade400, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────

  Widget _buildCategoryChips() {
    final cats = kAvatarCategoryLabels.keys.toList();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c      = cats[i];
          final active = c == _category;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _category = c);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(colors: [_kG1, _kG2])
                    : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active
                        ? Colors.transparent
                        : const Color(0xFFEDEEF3)),
              ),
              child: Text(
                kAvatarCategoryLabels[c] ?? c,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────

  Widget _buildGrid() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.sentiment_dissatisfied_rounded,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No avatars matching "$_searchQuery"',
                style: TextStyle(
                    fontFamily: 'Momo',
                    color: Colors.grey.shade500, fontSize: 13)),
          ]),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final def    = items[i];
        final picked = def.id == _selectedId;
        return GestureDetector(
          onTap: () => _select(def.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: picked ? _kG2 : const Color(0xFFEDEEF3),
                width: picked ? 2 : 1,
              ),
              boxShadow: picked
                  ? [BoxShadow(
                      color: _kG2.withOpacity(0.20),
                      blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AvatarView.preset(def.id, size: 52),
                const SizedBox(height: 6),
                Text(
                  def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: picked ? _kG2 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Save bar ──────────────────────────────────────────────

  Widget _buildSaveBar() {
    final canSave = _selectedId != null
        && _selectedId != widget.initialAvatarId;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: canSave ? _save : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50,
            decoration: BoxDecoration(
              gradient: canSave
                  ? const LinearGradient(colors: [_kG1, _kG2])
                  : null,
              color: canSave ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: canSave
                  ? [BoxShadow(
                      color: _kG2.withOpacity(0.30),
                      blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Center(
              child: Text(
                canSave ? 'Save Avatar' : 'Pick an avatar to save',
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: canSave ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
