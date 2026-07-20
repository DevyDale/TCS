// lib/screens/chat/add_members_bottom_sheet.dart
//
// Modal bottom sheet that lets the user search for people on the
// platform and multi-select them. Used by:
//   • CreateChatBubbleScreen — picking initial members for a new bubble
//   • (future) bubble settings — inviting more members later
//
// Returns the list of selected users via Navigator.pop, where each
// user is { user_id, name, avatar_url, role, is_online }.
//
// Usage:
//   final picked = await showAddMembersSheet(context,
//       alreadySelected: _selected);
//   if (picked != null) setState(() => _selected = picked);

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

const _kG1   = Color(0xFF6DD5FA);
const _kG2   = Color(0xFF8E54E9);
const _kG3   = Color(0xFFF7971E);
const _kG4   = Color(0xFFFF5858);
Color get _kInk => AppC.text;


/// Helper that shows the sheet and returns the picked users.
/// Returns null if the user cancels (taps outside or back).
Future<List<Map<String, dynamic>>?> showAddMembersSheet(
  BuildContext context, {
  List<Map<String, dynamic>> alreadySelected = const [],
  String title = 'Add Members',
}) {
  return showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMembersSheet(
        initiallySelected: alreadySelected,
        title:             title),
  );
}


class _AddMembersSheet extends StatefulWidget {
  final List<Map<String, dynamic>> initiallySelected;
  final String                     title;

  const _AddMembersSheet({
    required this.initiallySelected,
    required this.title,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}


class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _api    = ApiService();
  final _qCtrl  = TextEditingController();
  Timer? _debounce;

  /// user_id → user map for selection (preserves added order via _selectedOrder)
  final Map<String, Map<String, dynamic>> _selected = {};
  final List<String>                       _selectedOrder = [];

  List<Map<String, dynamic>> _results = [];
  bool   _searching = false;
  String _lastQuery = '';
  String? _lastError;

  @override
  void initState() {
    super.initState();
    for (final u in widget.initiallySelected) {
      final id = u['user_id'] as String? ?? '';
      if (id.isEmpty) continue;
      _selected[id] = u;
      _selectedOrder.add(id);
    }
    _qCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty) {
      setState(() { _results = []; _lastQuery = ''; _searching = false; });
      return;
    }
    setState(() { _searching = true; _lastError = null; });
    try {
      // Mirrors the working chat_search_screen.dart approach — same endpoint,
      // same parsing. /users/search/ was returning data but the wrapper was
      // shaped differently; /chat/dm/search/ is the proven path.
      final res = await _api.get('/chat/dm/search/', query: {'q': q})
          as Map<String, dynamic>;
      if (!mounted || _qCtrl.text.trim() != q) return;
      setState(() {
        _results = (res['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _searching = false;
        _lastQuery = q;
      });
    } catch (e) {
      if (mounted) setState(() {
        _searching = false;
        _lastError = e.toString();
        _results   = [];
      });
    }
  }

  void _toggle(Map<String, dynamic> u) {
    HapticFeedback.selectionClick();
    final id = u['user_id'] as String? ?? '';
    if (id.isEmpty) return;
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
        _selectedOrder.remove(id);
      } else {
        _selected[id] = u;
        _selectedOrder.add(id);
      }
    });
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    final out = _selectedOrder
        .map((id) => _selected[id]!)
        .toList(growable: false);
    Navigator.of(context).pop(out);
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: h * 0.88,
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          _buildHandle(),
          _buildHeader(),
          _buildSearchField(),
          if (_selectedOrder.isNotEmpty) _buildSelectedRow(),
          Divider(height: 1, color: AppC.divider),
          Expanded(child: _buildBody()),
          _buildConfirmBar(),
        ]),
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Center(child: Container(
        width: 42, height: 4,
        decoration: BoxDecoration(
            color: AppC.border,
            borderRadius: BorderRadius.circular(2)))),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Row(children: [
      Expanded(child: Text(widget.title, style: TextStyle(
          fontFamily: 'Alfa', fontSize: 20, color: _kInk))),
      GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: AppC.card2,
              shape: BoxShape.circle),
          child: Icon(Icons.close_rounded,
              size: 18, color: AppC.sub),
        ),
      ),
    ]),
  );

  Widget _buildSearchField() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Container(
      decoration: BoxDecoration(
        color: AppC.card2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _qCtrl, autofocus: true,
        style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
        decoration: InputDecoration(
          hintText: TranslationService.I.tr('Search by name or ID'),
          hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint),
          prefixIcon: Icon(Icons.search_rounded, color: AppC.sub),
          suffixIcon: _qCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, color: AppC.sub),
                  onPressed: () { _qCtrl.clear(); _runSearch(); }),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ),
  );

  Widget _buildSelectedRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final u    = _selected[_selectedOrder[i]]!;
          final name = u['name'] as String? ?? '';
          final init = name.isNotEmpty ? name[0].toUpperCase() : '?';
          final url  = u['avatar_url'] as String? ?? '';
          return GestureDetector(
            onTap: () => _toggle(u),
            child: Stack(clipBehavior: Clip.none, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_kG1, _kG2]),
                    image: url.isNotEmpty
                        ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                        : null),
                  child: url.isEmpty ? Center(child: Text(init,
                      style: const TextStyle(fontFamily: 'Arch', color: Colors.white,
                          fontWeight: FontWeight.bold))) : null,
                ),
                const SizedBox(height: 4),
                SizedBox(width: 56, child: Text(
                    name.split(' ').first,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Momo', fontSize: 10))),
              ]),
              Positioned(top: -2, right: -2, child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                      color: _kG4, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: Colors.white))),
            ]),
          );
        },
      ),
    ),
  );

  Widget _buildBody() {
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (_qCtrl.text.trim().isEmpty) {
      return _emptyHint(
        icon: Icons.search_rounded,
        title: 'Find people to add',
        body: 'Type a name, preferred name, or user ID',
      );
    }
    if (_results.isEmpty) {
      if (_lastError != null) {
        return _emptyHint(
          icon: Icons.error_outline_rounded,
          title: 'Search failed',
          body: _lastError!,
        );
      }
      return _emptyHint(
        icon: Icons.person_off_rounded,
        title: 'No matches',
        body: 'Try a different name or ID',
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemBuilder: (_, i) {
        final u        = _results[i];
        final id       = u['user_id']    as String? ?? '';
        final name     = u['name']       as String? ?? '';
        final role     = u['role']       as String? ?? '';
        final avatar   = u['avatar_url'] as String? ?? '';
        final selected = _selected.containsKey(id);
        final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';
        return InkWell(
          onTap: () => _toggle(u),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_kG1, _kG2]),
                  image: avatar.isNotEmpty
                      ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                      : null),
                child: avatar.isEmpty ? Center(child: Text(initial,
                    style: const TextStyle(fontFamily: 'Arch', color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16))) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
                const SizedBox(height: 2),
                Text(role, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11, color: AppC.sub)),
              ])),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? const LinearGradient(colors: [_kG1, _kG2])
                      : null,
                  border: selected
                      ? null
                      : Border.all(color: AppC.border, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _emptyHint({
    required IconData icon, required String title, required String body,
  }) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 44, color: AppC.border),
      const SizedBox(height: 14),
      Text(title, style: TextStyle(fontFamily: 'Alfa',
          fontSize: 16, color: _kInk)),
      const SizedBox(height: 6),
      Text(body, textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Momo',
              fontSize: 13, color: AppC.sub)),
    ]),
  ));

  Widget _buildConfirmBar() {
    final n = _selectedOrder.length;
    final disabled = n == 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: GestureDetector(
          onTap: disabled ? null : _confirm,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: disabled ? 0.4 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2, _kG3, _kG4],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: disabled ? [] : [BoxShadow(color: _kG2.withOpacity(0.35),
                    blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Center(
                child: Text(
                  n == 0 ? 'Select someone to add'
                         : n == 1 ? 'Add 1 member' : 'Add $n members',
                  style: const TextStyle(fontFamily: 'Arch',
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}