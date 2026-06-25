// lib/screens/groups/create_group_page.dart
import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _indigo = Color(0xFF3F51B5);
const _deep   = Color(0xFF512DA8);

// Theme → emoji icon mapping (must match backend THEME_ICONS)
const _themeIcons = {
  'mathematics': '📐', 'science': '🔬', 'arts': '🎨',
  'technology': '💻', 'sports': '⚽', 'music': '🎵',
  'business': '💼', 'language': '🌍', 'gaming': '🎮', 'general': '👥',
};

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});
  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _api     = ApiService();
  final _namCtrl = TextEditingController();
  final _desCtrl = TextEditingController();
  final _purCtrl = TextEditingController();

  int _step = 0; // 0=basics 1=details 2=members 3=confirm
  bool _creating = false;

  // Step 0 – basics
  String _theme    = 'general';
  String _category = 'study';

  // Step 1 – details
  bool   _isAcademic = true;
  bool   _isPublic   = true;
  int?   _duration;  // days; null = no expiry

  // Step 2 – members (only relevant for private groups)
  final List<Map<String, dynamic>> _selectedMembers = [];
  List<Map<String, dynamic>> _searchResults = [];
  final _memCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  final _themes     = ['general','mathematics','science','arts','technology',
                       'sports','music','business','language','gaming'];
  final _categories = ['study','club','hobby','faculty','project','arcade','academic'];
  final _durations  = [null, 7, 14, 30, 60, 90];

  @override
  void dispose() {
    _namCtrl.dispose(); _desCtrl.dispose();
    _purCtrl.dispose(); _memCtrl.dispose();
    _debounce?.cancel(); super.dispose();
  }

  String get _icon => _themeIcons[_theme] ?? '👥';

  void _nextStep() {
    if (_step == 0 && _namCtrl.text.trim().isEmpty) {
      _snack('Please enter a group name'); return;
    }
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _createGroup();
    }
  }

  void _prevStep() { if (_step > 0) setState(() => _step--); }

  Future<void> _searchMembers(String q) async {
    if (q.trim().isEmpty) { setState(() { _searchResults = []; _searching = false; }); return; }
    setState(() => _searching = true);
    try {
      final res = await _api.get('/groups/user-search/', query: {'q': q.trim()})
          as Map<String, dynamic>;
      setState(() {
        _searchResults = (res['results'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .where((u) => !_selectedMembers.any((m) => m['user_id'] == u['user_id']))
            .toList();
        _searching = false;
      });
    } catch (_) { setState(() => _searching = false); }
  }

  Future<void> _createGroup() async {
    setState(() => _creating = true);
    try {
      final body = {
        'name':          _namCtrl.text.trim(),
        'description':   _desCtrl.text.trim(),
        'purpose':       _purCtrl.text.trim(),
        'theme':         _theme,
        'category':      _category,
        'is_academic':   _isAcademic,
        'is_public':     _isPublic,
        'initial_member_ids': _selectedMembers.map((m) => m['user_id']).toList(),
        if (_duration != null) 'duration_days': _duration,
      };
      final created = await _api.post('/groups/', body: body) as Map<String, dynamic>;
      if (mounted) {
        Navigator.pop(context, created);
        _snack('Group "${_namCtrl.text.trim()}" created! 🎉');
      }
    } catch (e) {
      setState(() => _creating = false);
      _snack('Failed to create: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kG2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        _buildHeader(),
        _buildStepper(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          physics: const BouncingScrollPhysics(),
          child: [
            _buildStep0(),
            _buildStep1(),
            _buildStep2(),
            _buildStep3(),
          ][_step],
        )),
        _buildBottomBar(),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 8, right: 16, bottom: 14),
      color: AppC.card,
      child: Row(children: [
        GestureDetector(
          onTap: () => _step == 0 ? Navigator.pop(context) : _prevStep(),
          child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: AppC.card2,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                  size: 20, color: AppC.text)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          T('Create Group', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 20, color: AppC.text)),
          Text(['Basics', 'Details', 'Members', 'Review'][_step],
              style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.faint)),
        ])),
        // Preview icon
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_indigo, _deep]),
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(_icon, style: const TextStyle(fontSize: 22))),
        ),
      ]),
    );
  }

  Widget _buildStepper() {
    return Container(
      color: AppC.card,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(children: List.generate(4, (i) {
        final active   = i == _step;
        final done     = i < _step;
        final stepColor = done || active ? _indigo : AppC.border;
        return Expanded(child: Row(children: [
          Expanded(child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 4,
            decoration: BoxDecoration(
              color: done ? _indigo : active ? _kG1 : AppC.border,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          if (i < 3) const SizedBox(width: 4),
        ]));
      })),
    );
  }

  // ── Step 0: Basics ────────────────────────────────────────

  Widget _buildStep0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      _sectionLabel('Group Name *'),
      const SizedBox(height: 8),
      _input(_namCtrl, 'e.g. Math Study Squad', maxLen: 60),
      const SizedBox(height: 20),
      _sectionLabel('Description'),
      const SizedBox(height: 8),
      _input(_desCtrl, 'What is this group about?', maxLines: 3),
      const SizedBox(height: 24),
      _sectionLabel('Theme'),
      const SizedBox(height: 8),
      T('The icon will be auto-assigned based on theme',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.faint)),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: _themes.map((t) {
        final selected = t == _theme;
        return GestureDetector(
          onTap: () => setState(() => _theme = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _indigo.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? _indigo : AppC.border,
                  width: selected ? 2 : 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_themeIcons[t] ?? '👥', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(t[0].toUpperCase() + t.substring(1),
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 12, color: selected ? _indigo : AppC.sub)),
            ]),
          ),
        );
      }).toList()),
    ]);
  }

  // ── Step 1: Details ───────────────────────────────────────

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      _sectionLabel('Purpose'),
      const SizedBox(height: 8),
      _input(_purCtrl, 'What is the goal of this group?', maxLines: 2),
      const SizedBox(height: 24),
      _sectionLabel('Category'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
        final sel = c == _category;
        return GestureDetector(
          onTap: () => setState(() => _category = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? _kG2.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? _kG2 : AppC.border, width: sel ? 2 : 1.5),
            ),
            child: Text(c[0].toUpperCase() + c.substring(1),
                style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 12, color: sel ? _kG2 : AppC.sub)),
          ),
        );
      }).toList()),
      const SizedBox(height: 24),
      _switchRow('Academic Group', _isAcademic, Icons.school_rounded,
          (v) => setState(() => _isAcademic = v)),
      const SizedBox(height: 14),
      _switchRow('Public Group', _isPublic, Icons.public_rounded,
          (v) => setState(() => _isPublic = v)),
      if (!_isPublic) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _kG3.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kG3.withOpacity(0.25))),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: _kG3, size: 16),
            const SizedBox(width: 8),
            Expanded(child: T('Private groups require you to manually add members.',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: _kG3))),
          ]),
        ),
      ],
      const SizedBox(height: 24),
      _sectionLabel('Group Duration'),
      const SizedBox(height: 8),
      T('The group will automatically close after this period.',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.faint)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: _durations.map((d) {
        final sel = d == _duration;
        final label = d == null ? 'No Expiry' : '${d}d';
        return GestureDetector(
          onTap: () => setState(() => _duration = d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? _indigo.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? _indigo : AppC.border, width: sel ? 2 : 1.5),
            ),
            child: Text(label, style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 13, color: sel ? _indigo : AppC.sub)),
          ),
        );
      }).toList()),
    ]);
  }

  // ── Step 2: Members ───────────────────────────────────────

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      if (_isPublic)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade200)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Expanded(child: T('Public group — anyone can join.\nYou can still add specific people below.',
                style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: AppC.text))),
          ]),
        ),
      const SizedBox(height: 20),
      _sectionLabel('Add Members'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppC.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppC.border)),
        child: TextField(
          controller: _memCtrl,
          enableSuggestions: false,
          onChanged: (q) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () => _searchMembers(q));
            setState(() {});
          },
          style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
          decoration: InputDecoration(
            hintText: TranslationService.I.tr('Search by name or ID...'),
            hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint),
            prefixIcon: _searching
                ? const Padding(padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kG2)))
                : Icon(Icons.person_search_rounded, color: AppC.faint),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
      if (_searchResults.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppC.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppC.border)),
          child: Column(children: _searchResults.map((u) {
            final name = u['name'] as String? ?? '';
            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
            return ListTile(
              leading: Container(width: 36, height: 36,
                decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_kG1, _kG2])),
                child: Center(child: Text(initial, style: TextStyle(
                    color: AppC.text, fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 15)))),
              title: Text(name, style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(u['role'] as String? ?? '',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.faint)),
              trailing: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMembers.add(u);
                    _searchResults.remove(u);
                    _memCtrl.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_indigo, _deep]),
                    borderRadius: BorderRadius.circular(8)),
                  child: T('Add', style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, color: AppC.text, fontSize: 12)),
                ),
              ),
            );
          }).toList()),
        ),
      ],
      if (_selectedMembers.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Added (${_selectedMembers.length})', style: TextStyle(
            fontFamily: 'Alfa', fontSize: 15, color: AppC.text)),
        const SizedBox(height: 10),
        ..._selectedMembers.map((m) {
          final name = m['name'] as String? ?? '';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppC.border)),
            child: Row(children: [
              Container(width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _indigo.withOpacity(0.1)),
                child: Center(child: Text(initial, style: const TextStyle(
                    color: _indigo, fontFamily: 'Arch', fontWeight: FontWeight.bold)))),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: AppC.text))),
              GestureDetector(
                onTap: () => setState(() => _selectedMembers.remove(m)),
                child: Icon(Icons.remove_circle_rounded, color: _kG4.withOpacity(0.7), size: 20)),
            ]),
          );
        }),
      ],
    ]);
  }

  // ── Step 3: Review ────────────────────────────────────────

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      // Preview card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_indigo, _deep],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _indigo.withOpacity(0.3),
              blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Text(_icon, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(_namCtrl.text.trim(), textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Alfa', fontSize: 22, color: AppC.text)),
          if (_desCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_desCtrl.text.trim(), textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                    color: AppC.text.withOpacity(0.75))),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pillWhite(_isPublic ? '🌍 Public' : '🔒 Private'),
            _pillWhite(_isAcademic ? '📚 Academic' : '🎮 Non-Academic'),
            _pillWhite(_theme[0].toUpperCase() + _theme.substring(1)),
            if (_duration != null) _pillWhite('⏰ ${_duration}d'),
          ]),
        ]),
      ),
      const SizedBox(height: 24),
      _reviewRow('Category', _category[0].toUpperCase() + _category.substring(1)),
      if (_purCtrl.text.isNotEmpty) _reviewRow('Purpose', _purCtrl.text.trim()),
      _reviewRow('Visibility', _isPublic ? 'Public — anyone can join' : 'Private — invite only'),
      _reviewRow('Duration', _duration == null ? 'No expiry' : '$_duration days'),
      _reviewRow('Members', '${_selectedMembers.length + 1} (including you)'),
    ]);
  }

  Widget _pillWhite(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
        fontWeight: FontWeight.bold, color: AppC.text)),
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(fontFamily: 'Momo',
          fontSize: 13, color: AppC.faint))),
      Expanded(child: Text(value, style: TextStyle(fontFamily: 'Arch',
          fontWeight: FontWeight.bold, fontSize: 13, color: AppC.text))),
    ]),
  );

  Widget _buildBottomBar() {
    final isLast = _step == 3;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: AppC.card,
          border: Border(top: BorderSide(color: AppC.border))),
      child: GestureDetector(
        onTap: _creating ? null : _nextStep,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52, width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_indigo, _deep],
                begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _indigo.withOpacity(0.35),
                blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Center(child: _creating
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(isLast ? '🚀 Create Group' : 'Continue',
                      style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                          color: AppC.text, fontSize: 15)),
                  if (!isLast) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ])),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t, style: TextStyle(
      fontFamily: 'Arch', fontWeight: FontWeight.bold,
      fontSize: 14, color: AppC.text));

  Widget _input(TextEditingController c, String hint,
      {int maxLines = 1, int? maxLen}) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppC.border)),
    child: TextField(
      controller: c, maxLines: maxLines, maxLength: maxLen,
      style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: AppC.text),
      decoration: InputDecoration(
        hintText: hint, counterText: '',
        hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );

  Widget _switchRow(String label, bool value, IconData icon, ValueChanged<bool> onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppC.border)),
        child: Row(children: [
          Icon(icon, color: value ? _indigo : AppC.faint, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 14, color: AppC.text))),
          Switch(value: value, onChanged: onChanged,
              activeThumbColor: Colors.white, activeTrackColor: _indigo,
              inactiveThumbColor: Colors.white, inactiveTrackColor: AppC.border),
        ]),
      );
}