// lib/screens/suggestion_box_screen.dart
import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

// Neutral gradient used for the hero header BEFORE a category is
// chosen. Once the user picks one, the header switches to that
// category's own gradient.
const _kNeutralGrad = [Color(0xFF8E54E9), Color(0xFF6DD5FA)];


// ─── Backend-driven category model ───────────────────────────
//
// Replaces the old hardcoded `_categories` const list. The data is
// fetched from /api/feedback/categories/ on screen init — admins
// control what shows up in the picker.
class _Cat {
  final String     id;
  final String     key;
  final String     label;
  final String     emoji;
  final List<Color> gradient;
  final int        sortOrder;

  const _Cat({
    required this.id,
    required this.key,
    required this.label,
    required this.emoji,
    required this.gradient,
    required this.sortOrder,
  });

  factory _Cat.fromJson(Map<String, dynamic> j) {
    Color parseHex(String s, Color fallback) {
      try {
        var h = s.replaceFirst('#', '').trim();
        if (h.length == 6) h = 'FF$h';
        return Color(int.parse(h, radix: 16));
      } catch (_) { return fallback; }
    }
    return _Cat(
      id:        (j['id']    ?? '').toString(),
      key:       (j['key']   ?? '').toString(),
      label:     (j['label'] ?? '').toString(),
      emoji:     (j['emoji'] ?? '').toString(),
      gradient: [
        parseHex((j['gradient_from'] ?? '').toString(), _kG2),
        parseHex((j['gradient_to']   ?? '').toString(), _kG1),
      ],
      sortOrder: (j['sort_order'] is int)
          ? j['sort_order'] as int
          : int.tryParse('${j['sort_order']}') ?? 100,
    );
  }
}


// ─── Submission model (history list) ─────────────────────────
class _Submission {
  final String  id;
  final _Cat?   category;
  final String  title;
  final String  status;
  final String? adminNote;
  final DateTime createdAt;

  _Submission({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    required this.adminNote,
    required this.createdAt,
  });

  factory _Submission.fromJson(Map<String, dynamic> j) => _Submission(
        id:        (j['id']    ?? '').toString(),
        category:  j['category'] is Map
            ? _Cat.fromJson((j['category'] as Map).cast<String, dynamic>())
            : null,
        title:     (j['title']      ?? '').toString(),
        status:    (j['status']     ?? 'new').toString(),
        adminNote: (j['admin_note'] ?? '').toString().isEmpty
            ? null
            : (j['admin_note']).toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())
            ?? DateTime.now(),
      );
}


// ─────────────────────────────────────────────────────────────

class SuggestionBoxScreen extends StatefulWidget {
  const SuggestionBoxScreen({super.key});
  @override
  State<SuggestionBoxScreen> createState() => _SuggestionBoxScreenState();
}

class _SuggestionBoxScreenState extends State<SuggestionBoxScreen>
    with TickerProviderStateMixin {
  final _api       = ApiService();
  final _titleCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  // ── Categories (backend-driven) ──────────────────────────
  List<_Cat> _categories      = [];
  bool       _loadingCats     = true;
  String?    _categoriesError;

  // Null until the user explicitly picks one. The form is locked
  // until this is non-null.
  String? _selectedCatKey;

  // ── Submission history ───────────────────────────────────
  List<_Submission> _submissions      = [];
  bool              _historyExpanded  = false;
  bool              _historyLoading   = false;
  bool              _historyLoadedOnce = false;

  // ── Form state ───────────────────────────────────────────
  bool _submitting = false;
  bool _submitted  = false;

  late final AnimationController _successCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double>   _successScale;
  late final Animation<double>   _floatAnim;

  int get _msgLen => _msgCtrl.text.length;

  /// The category the user has selected, or null if none yet.
  _Cat? get _currentCat {
    if (_selectedCatKey == null) return null;
    for (final c in _categories) {
      if (c.key == _selectedCatKey) return c;
    }
    return null;
  }

  /// Gradient for the hero header — category's own if one is picked,
  /// neutral otherwise so the screen still looks finished on first open.
  List<Color> get _headerGradient => _currentCat?.gradient ?? _kNeutralGrad;

  bool get _formEnabled => _selectedCatKey != null;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _successScale = CurvedAnimation(
        parent: _successCtrl, curve: Curves.elasticOut);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _msgCtrl.addListener(() => setState(() {}));
    _fetchCategories();
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _floatCtrl.dispose();
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Data
  // ─────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    setState(() {
      _loadingCats     = true;
      _categoriesError = null;
    });
    try {
      final raw = await _api.getSuggestionCategories();
      final list = (raw as List? ?? [])
          .whereType<Map>()
          .map((m) => _Cat.fromJson(m.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() {
        _categories  = list;
        _loadingCats = false;
      });
    } catch (e) {
      setState(() {
        _loadingCats     = false;
        _categoriesError = 'Could not load categories. Pull to retry.';
      });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _historyLoading = true);
    try {
      final raw = await _api.getMySuggestions();
      final list = (raw as List? ?? [])
          .whereType<Map>()
          .map((m) => _Submission.fromJson(m.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _submissions       = list;
        _historyLoading    = false;
        _historyLoadedOnce = true;
      });
    } catch (_) {
      setState(() {
        _historyLoading    = false;
        _historyLoadedOnce = true;
      });
    }
  }

  Future<void> _toggleHistory() async {
    HapticFeedback.lightImpact();
    final wasExpanded = _historyExpanded;
    setState(() => _historyExpanded = !wasExpanded);
    if (!wasExpanded && !_historyLoadedOnce) {
      await _fetchHistory();
    }
  }

  // ─────────────────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selectedCatKey == null) {
      _toast('Please choose a category first.', isError: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      await _api.submitSuggestion(
        title:    _titleCtrl.text.trim(),
        message:  _msgCtrl.text.trim(),
        category: _selectedCatKey!,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted  = true;
      });
      _successCtrl.forward(from: 0);
      // Force a refresh on next history expand so the new entry appears.
      _historyLoadedOnce = false;
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(_extractErr(e), isError: true);
    }
  }

  String _extractErr(Object e) {
    final s = e.toString();
    final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(s);
    if (m != null) return m.group(1)!;
    return s.replaceAll('Exception: ', '').trim();
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? _kG4 : Colors.green.shade600,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF0F0F1F) : const Color(0xFFF7F7FB);
    final card   = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final text   = isDark ? Colors.white               : const Color(0xFF1A1A2E);
    final sub    = isDark ? Colors.white60             : AppC.faint;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: _submitted
            ? _buildSuccess(card, text, sub)
            : _buildForm(isDark, bg, card, text, sub),
      ),
    );
  }

  // ── Success state ────────────────────────────────────────

  Widget _buildSuccess(Color card, Color text, Color sub) {
    final grad = _currentCat?.gradient ?? _kNeutralGrad;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: grad,
            begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(scale: _successScale,
            child: Container(width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white.withOpacity(0.4),
                    width: 3)),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 60))),
          const SizedBox(height: 28),
          T('Thank you! 🙏',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 36, color: AppC.text)),
          const SizedBox(height: 12),
          T('Your suggestion has been received.\n'
              'We appreciate your feedback!',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Momo', fontSize: 15,
                color: AppC.text.withOpacity(0.85), height: 1.6)),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () {
              // Reset to a fresh form for another submission.
              setState(() {
                _submitted      = false;
                _selectedCatKey = null;
                _titleCtrl.clear();
                _msgCtrl.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.4))),
              child: T('Submit another',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 15, color: AppC.text)),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const T('← Back',
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 14, color: Colors.white70)),
          ),
        ]),
      )),
    );
  }

  // ── Form state ───────────────────────────────────────────

  Widget _buildForm(bool isDark, Color bg, Color card, Color text, Color sub) {
    return Column(children: [

      // ── Hero header (category-coloured gradient) ─────────
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _headerGradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(bottom: false, child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3))),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20))),
              const Spacer(),
              if (_currentCat != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25))),
                  child: Text(
                    '${_currentCat!.emoji} ${_currentCat!.label}',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: AppC.text))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(children: [
              AnimatedBuilder(animation: _floatAnim, builder: (_, __) =>
                Transform.translate(
                  offset: Offset(0, _floatAnim.value * 0.4),
                  child: const T('📬',
                      style: TextStyle(fontSize: 52)))),
              const SizedBox(height: 12),
              T('Suggestion Box', style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 28, color: AppC.text)),
              const SizedBox(height: 6),
              T('Your name will be attached — speak freely!',
                style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                    color: AppC.text.withOpacity(0.8))),
            ])),
        ])),
      ),

      // ── Form body ────────────────────────────────────────
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _label('Category', sub),
            const SizedBox(height: 10),
            _buildCategoryRow(isDark, card, sub),

            const SizedBox(height: 22),

            // Soft "pick a category to continue" hint, only while
            // the form is locked.
            if (!_formEnabled) _buildLockedHint(card, sub),

            // School suggestions go to every staff member and are NOT
            // anonymous — make that crystal clear before they send.
            if (_selectedCatKey == 'school') ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF4F46E5).withOpacity(0.25))),
                child: Row(children: [
                  const Text('🏫', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'This goes to every staff member and is NOT anonymous — '
                    'your name will be shown with it.',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                        height: 1.4, color: AppC.text))),
                ]),
              ),
            ],

            // Title
            _label('Title', sub),
            const SizedBox(height: 8),
            _field(
              controller: _titleCtrl,
              hint: _formEnabled
                  ? 'Short summary of your suggestion...'
                  : 'Pick a category to enable',
              card: card, text: text, sub: sub, isDark: isDark,
              maxLines: 1, maxLength: 120,
              enabled: _formEnabled,
              validator: (v) {
                if (!_formEnabled) return null;
                return (v == null || v.trim().isEmpty)
                    ? 'Please enter a title' : null;
              },
            ),

            const SizedBox(height: 18),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Your Message', sub),
                Text('$_msgLen / 1000',
                  style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11, color: _msgLen > 900 ? _kG4 : sub)),
              ]),
            const SizedBox(height: 8),
            _field(
              controller: _msgCtrl,
              hint: _formEnabled
                  ? 'Describe your idea or issue in detail...'
                  : 'Pick a category to enable',
              card: card, text: text, sub: sub, isDark: isDark,
              maxLines: 7, maxLength: 1000,
              enabled: _formEnabled,
              validator: (v) {
                if (!_formEnabled) return null;
                if (v == null || v.trim().isEmpty) {
                  return 'Please write your message';
                }
                if (v.trim().length < 10) {
                  return 'Message too short (min 10 characters)';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            _buildSubmitButton(),

            const SizedBox(height: 16),
            Center(child: T(
              'Submitted suggestions are reviewed by the TCS team.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: sub, height: 1.6))),

            const SizedBox(height: 28),

            // ── On-page submission history ─────────────────
            _buildHistorySection(isDark, card, text, sub),

            const SizedBox(height: 24),
          ],
        )),
      )),
    ]);
  }

  // ── Category picker row ──────────────────────────────────

  Widget _buildCategoryRow(bool isDark, Color card, Color sub) {
    if (_loadingCats) {
      return SizedBox(height: 80,
        child: Center(child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
              color: _kG2, strokeWidth: 2.5))));
    }

    if (_categoriesError != null || _categories.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white12 : AppC.border,
              width: 1.5)),
        child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 16, color: sub),
              const SizedBox(width: 8),
              Flexible(child: Text(
                _categoriesError ?? 'No categories available right now.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                    color: sub))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _fetchCategories,
                child: const Icon(Icons.refresh_rounded,
                    size: 18, color: _kG2)),
            ]))));
    }

    return SizedBox(height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c   = _categories[i];
          final sel = c.key == _selectedCatKey;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCatKey = c.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 100,
              decoration: BoxDecoration(
                gradient: sel ? LinearGradient(colors: c.gradient) : null,
                color: sel ? null : card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? Colors.transparent
                      : isDark ? Colors.white12 : AppC.border,
                  width: 1.5),
                boxShadow: sel ? [BoxShadow(
                  color: c.gradient.first.withOpacity(0.35),
                  blurRadius: 12, offset: const Offset(0, 4))] : null),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(c.label, textAlign: TextAlign.center,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                        color: sel ? Colors.white : sub)),
                  ),
                ])),
          );
        },
      ),
    );
  }

  // ── Locked-form hint banner ──────────────────────────────

  Widget _buildLockedHint(Color card, Color sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kG2.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kG2.withOpacity(0.18))),
      child: Row(children: [
        const Icon(Icons.arrow_upward_rounded, size: 16, color: _kG2),
        const SizedBox(width: 8),
        Expanded(child: T(
          'Pick a category above to start writing.',
          style: TextStyle(fontFamily: 'Momo', fontSize: 12,
              color: sub, height: 1.4))),
      ]),
    );
  }

  // ── Submit button ────────────────────────────────────────

  Widget _buildSubmitButton() {
    final canSubmit = _formEnabled && !_submitting;
    final grad = _currentCat?.gradient ?? _kNeutralGrad;

    return GestureDetector(
      onTap: canSubmit ? _submit : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity, height: 58,
        decoration: BoxDecoration(
          gradient: canSubmit
              ? LinearGradient(colors: grad,
                  begin: Alignment.centerLeft, end: Alignment.centerRight)
              : LinearGradient(colors: [
                  AppC.faint, AppC.faint]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: canSubmit ? [BoxShadow(
            color: grad.first.withOpacity(0.4),
            blurRadius: 18, offset: const Offset(0, 6))] : []),
        child: Center(child: _submitting
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_formEnabled
                        ? Icons.send_rounded
                        : Icons.lock_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(_formEnabled
                        ? 'Send Suggestion'
                        : 'Choose a category',
                  style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 16, color: AppC.text)),
              ])),
      ),
    );
  }

  // ── Submission history (collapsible) ─────────────────────

  Widget _buildHistorySection(
      bool isDark, Color card, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : AppC.border,
            width: 1.5)),
      child: Column(children: [

        // Header (tap to expand)
        InkWell(
          onTap: _toggleHistory,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG2, _kG1]),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.history_rounded,
                    color: Colors.white, size: 16)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T('Your submissions',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 13, color: text)),
                  const SizedBox(height: 2),
                  Text(_historyExpanded
                          ? 'Tap to hide'
                          : 'See past suggestions and their status',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 11, color: sub)),
                ])),
              AnimatedRotation(
                duration: const Duration(milliseconds: 220),
                turns: _historyExpanded ? 0.5 : 0,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: sub, size: 22)),
            ]),
          ),
        ),

        // Body
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: !_historyExpanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  child: _buildHistoryBody(isDark, text, sub),
                ),
        ),
      ]),
    );
  }

  Widget _buildHistoryBody(bool isDark, Color text, Color sub) {
    if (_historyLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
              color: _kG2, strokeWidth: 2.5))));
    }
    if (_submissions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: T(
            'No submissions yet — yours will appear here.',
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: sub))));
    }
    return Column(children: [
      for (final s in _submissions)
        _buildHistoryTile(s, isDark, text, sub),
    ]);
  }

  Widget _buildHistoryTile(_Submission s, bool isDark, Color text, Color sub) {
    final cat   = s.category;
    final grad  = cat?.gradient ?? _kNeutralGrad;
    final emoji = cat?.emoji ?? '📝';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : grad.first.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: grad.first.withOpacity(0.18))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13, color: text)),
            const SizedBox(height: 4),
            Row(children: [
              if (cat != null) Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(cat.label,
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 10, color: sub))),
              Text('· ${_relTime(s.createdAt)}',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 10, color: sub)),
            ]),
            if (s.adminNote != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kG2.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kG2.withOpacity(0.18))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.reply_rounded, size: 13, color: _kG2),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.adminNote!,
                      style: const TextStyle(fontFamily: 'Momo',
                          fontSize: 11, color: _kG2, height: 1.4))),
                  ])),
            ],
          ])),
        const SizedBox(width: 8),
        _statusPill(s.status),
      ]),
    );
  }

  Widget _statusPill(String status) {
    final spec = _statusSpec(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: spec.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: spec.color.withOpacity(0.3))),
      child: Text(spec.label,
        style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 9,
            color: spec.color, letterSpacing: 0.3)),
    );
  }

  _StatusSpec _statusSpec(String status) {
    switch (status) {
      case 'under_review': return const _StatusSpec('REVIEWING', _kG3);
      case 'planned':      return const _StatusSpec('PLANNED',   _kG2);
      case 'done':         return const _StatusSpec('DONE',      Color(0xFF4CAF50));
      case 'wont_do':      return const _StatusSpec("WON'T DO",  Color(0xFF9E9E9E));
      case 'new':
      default:             return const _StatusSpec('NEW',       _kG1);
    }
  }

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours   < 24) return '${d.inHours}h ago';
    if (d.inDays    <  7) return '${d.inDays}d ago';
    if (d.inDays    < 30) return '${(d.inDays / 7).floor()}w ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  // ── Small atoms ──────────────────────────────────────────

  Widget _label(String t, Color sub) => Text(t.toUpperCase(),
    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
        fontSize: 11, color: sub, letterSpacing: 0.8));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required Color card, required Color text, required Color sub,
    required bool isDark, required int maxLines, required int maxLength,
    required bool enabled,
    String? Function(String?)? validator,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : AppC.border,
            width: 1.5),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0 : 0.03),
            blurRadius: 6, offset: const Offset(0, 2))]),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Momo',
                fontSize: 14, color: sub),
            border: InputBorder.none,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14)),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
class _StatusSpec {
  final String label;
  final Color  color;
  const _StatusSpec(this.label, this.color);
}