// lib/screens/feedback/suggestion_box_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

// ─── Category model ───────────────────────────────────────────
class _Cat {
  final String key, label, emoji;
  final List<Color> gradient;
  const _Cat(this.key, this.label, this.emoji, this.gradient);
}

const _categories = [
  _Cat('feature',   'Feature Request', '💡', [Color(0xFF6DD5FA), Color(0xFF8E54E9)]),
  _Cat('bug',       'Bug Report',      '🐛', [Color(0xFFFF5858), Color(0xFFFF9800)]),
  _Cat('content',   'Content',         '📚', [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
  _Cat('ui',        'Design & UI',     '🎨', [Color(0xFFCE93D8), Color(0xFF7B1FA2)]),
  _Cat('general',   'General',         '💬', [Color(0xFF8E54E9), Color(0xFF6DD5FA)]),
  _Cat('complaint', 'Complaint',       '⚠️', [Color(0xFFF7971E), Color(0xFFFF5858)]),
];

// ─────────────────────────────────────────────────────────────
class SuggestionBoxScreen extends StatefulWidget {
  const SuggestionBoxScreen({super.key});
  @override
  State<SuggestionBoxScreen> createState() => _SuggestionBoxScreenState();
}

class _SuggestionBoxScreenState extends State<SuggestionBoxScreen>
    with TickerProviderStateMixin {
  final _api         = ApiService();
  final _titleCtrl   = TextEditingController();
  final _msgCtrl     = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  String _selectedCat = 'general';
  bool   _submitting  = false;
  bool   _submitted   = false;

  late final AnimationController _successCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double>   _successScale;
  late final Animation<double>   _floatAnim;

  int get _msgLen => _msgCtrl.text.length;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _floatCtrl   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _floatAnim    = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _msgCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _floatCtrl.dispose();
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  _Cat get _currentCat =>
      _categories.firstWhere((c) => c.key == _selectedCat);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      await _api.post('/feedback/suggest/', body: {
        'title':    _titleCtrl.text.trim(),
        'message':  _msgCtrl.text.trim(),
        'category': _selectedCat,
      });
      setState(() { _submitting = false; _submitted = true; });
      _successCtrl.forward();
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(fontFamily: 'Momo')),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg   = isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF2F4F8);
    final card = isDark ? const Color(0xFF161628) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sub  = isDark ? Colors.white54 : Colors.grey.shade500;

    return Scaffold(
      backgroundColor: bg,
      body: _submitted ? _buildSuccess(isDark) : _buildForm(isDark, bg, card, text, sub),
    );
  }

  // ── Success state ─────────────────────────────────────────

  Widget _buildSuccess(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_currentCat.gradient.first.withOpacity(0.9),
            _currentCat.gradient.last],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(scale: _successScale, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(animation: _floatAnim, builder: (_, __) =>
              Transform.translate(offset: Offset(0, _floatAnim.value),
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
                  child: const Center(child: Text('🎉', style: TextStyle(fontSize: 54)))))),
            const SizedBox(height: 28),
            const Text('Sent! 🙏', style: TextStyle(fontFamily: 'Alfa',
                fontSize: 36, color: Colors.white)),
            const SizedBox(height: 12),
            Text('Your suggestion has been received.\nWe appreciate your feedback!',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 15,
                  color: Colors.white.withOpacity(0.85), height: 1.6)),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.4))),
                child: const Text('← Back', style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
            ),
          ],
        )),
      ))),
    );
  }

  // ── Form state ────────────────────────────────────────────

  Widget _buildForm(bool isDark, Color bg, Color card, Color text, Color sub) {
    final cat = _currentCat;
    return Column(children: [
      // ── Hero header
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: cat.gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(bottom: false, child: Column(children: [
          // Back row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3))),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25))),
                child: Text('${cat.emoji} ${cat.label}',
                  style: const TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: Colors.white))),
            ])),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(children: [
              AnimatedBuilder(animation: _floatAnim, builder: (_, __) =>
                Transform.translate(offset: Offset(0, _floatAnim.value * 0.4),
                  child: Text('📬', style: const TextStyle(fontSize: 52)))),
              const SizedBox(height: 12),
              const Text('Suggestion Box', style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 28, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Your name will be attached — speak freely!',
                style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                    color: Colors.white.withOpacity(0.8))),
            ])),
        ])),
      ),

      // ── Form body
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(key: _formKey, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Category picker
            _label('Category', sub),
            const SizedBox(height: 10),
            SizedBox(height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c   = _categories[i];
                  final sel = c.key == _selectedCat;
                  return GestureDetector(
                    onTap: () { HapticFeedback.lightImpact();
                      setState(() => _selectedCat = c.key); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: sel ? LinearGradient(colors: c.gradient) : null,
                        color: sel ? null : card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sel ? Colors.transparent
                              : isDark ? Colors.white12 : Colors.grey.shade200,
                          width: 1.5),
                        boxShadow: sel ? [BoxShadow(
                          color: c.gradient.first.withOpacity(0.35),
                          blurRadius: 12, offset: const Offset(0, 4))] : null),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 5),
                        Text(c.label, textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                            color: sel ? Colors.white : sub)),
                      ])),
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            // Title field
            _label('Title', sub),
            const SizedBox(height: 8),
            _field(
              controller: _titleCtrl,
              hint: 'Short summary of your suggestion...',
              card: card, text: text, sub: sub, isDark: isDark,
              maxLines: 1, maxLength: 120,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a title' : null,
            ),

            const SizedBox(height: 18),

            // Message field
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _label('Your Message', sub),
              Text('$_msgLen / 1000', style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11, color: _msgLen > 900 ? _kG4 : sub)),
            ]),
            const SizedBox(height: 8),
            _field(
              controller: _msgCtrl,
              hint: 'Describe your idea or issue in detail...',
              card: card, text: text, sub: sub, isDark: isDark,
              maxLines: 7, maxLength: 1000,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please write your message';
                if (v.trim().length < 10) return 'Message too short (min 10 characters)';
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Submit button
            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity, height: 58,
                decoration: BoxDecoration(
                  gradient: _submitting
                      ? LinearGradient(colors: [
                          Colors.grey.shade400, Colors.grey.shade500])
                      : LinearGradient(colors: _currentCat.gradient,
                          begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _submitting ? [] : [BoxShadow(
                    color: _currentCat.gradient.first.withOpacity(0.4),
                    blurRadius: 18, offset: const Offset(0, 6))]),
                child: Center(child: _submitting
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        const Text('Send Suggestion', style: TextStyle(
                          fontFamily: 'Arch', fontWeight: FontWeight.bold,
                          fontSize: 16, color: Colors.white)),
                      ])),
              ),
            ),

            const SizedBox(height: 16),
            Center(child: Text(
              'Submitted suggestions are reviewed by the TCS team.\nYou can view your past submissions in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 11, color: sub, height: 1.6))),
            const SizedBox(height: 24),
          ],
        )),
      )),
    ]);
  }

  Widget _label(String t, Color sub) => Text(t.toUpperCase(),
    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
        fontSize: 11, color: sub, letterSpacing: 0.8));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required Color card, required Color text, required Color sub,
    required bool isDark, required int maxLines, required int maxLength,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 13, color: sub),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: const TextStyle(fontSize: 0), // hide built-in counter
        ),
        validator: validator,
      ),
    );
  }
}