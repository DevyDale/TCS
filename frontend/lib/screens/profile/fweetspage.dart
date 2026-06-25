// lib/screens/fweetspage.dart
//
// §5 Fweets restyle + feeling backend tie-in + §4 location picker tie-in.
//
// Visible changes from the previous version:
//   • The cramped icon-button toolbar is replaced with three chunky
//     gradient pill buttons (Style / Place / Feeling) that show the
//     selected value at a glance — fixes user feedback that the old
//     buttons "weren't visible to the human eye."
//   • Feelings are now fetched from the backend (/api/feelings/) so
//     admins can manage the list from Django admin instead of editing
//     a hardcoded list in Dart.
//   • Backend `feeling` slug is sent on the createPost call.
//   • Place pill now opens the OpenStreetMap-backed LocationPicker.
//     The pill spins while the picker is open and updates with the
//     picked label when it closes.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../services/api_service.dart';
import '../../widgets/location_picker.dart';


const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

/// Picks black or white text for maximum contrast against [bg], so the
/// fweet text never clashes with the chosen background colour.
Color _fweetTextColor(Color bg) =>
    bg.computeLuminance() > 0.179 ? const Color(0xFF1A1A2E) : Colors.white;


// ─── Backend feeling model ───────────────────────────────────
class _Feeling {
  final String slug;
  final String label;
  final String emoji;
  const _Feeling({
    required this.slug,
    required this.label,
    required this.emoji,
  });
  factory _Feeling.fromJson(Map<String, dynamic> j) => _Feeling(
        slug:  (j['slug']  ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        emoji: (j['emoji'] ?? '').toString(),
      );
  String get display =>
      emoji.isNotEmpty ? '$emoji $label' : label;
}

// Built-in feelings shown when the backend list is empty or unreachable,
// so the picker is never blank. If /api/feelings/ returns its own list,
// that takes priority.
const List<_Feeling> _defaultFeelings = [
  _Feeling(slug: 'happy',       label: 'Happy',       emoji: '😊'),
  _Feeling(slug: 'excited',     label: 'Excited',     emoji: '🤩'),
  _Feeling(slug: 'grateful',    label: 'Grateful',    emoji: '🙏'),
  _Feeling(slug: 'loved',       label: 'Loved',       emoji: '🥰'),
  _Feeling(slug: 'chill',       label: 'Chill',       emoji: '😎'),
  _Feeling(slug: 'motivated',   label: 'Motivated',   emoji: '💪'),
  _Feeling(slug: 'focused',     label: 'Focused',     emoji: '🎯'),
  _Feeling(slug: 'tired',       label: 'Tired',       emoji: '😴'),
  _Feeling(slug: 'stressed',    label: 'Stressed',    emoji: '😰'),
  _Feeling(slug: 'sad',         label: 'Sad',         emoji: '😢'),
  _Feeling(slug: 'angry',       label: 'Angry',       emoji: '😠'),
  _Feeling(slug: 'bored',       label: 'Bored',       emoji: '🥱'),
  _Feeling(slug: 'sick',        label: 'Sick',        emoji: '🤒'),
  _Feeling(slug: 'celebrating', label: 'Celebrating', emoji: '🎉'),
];


class CreateFweetPage extends StatefulWidget {
  const CreateFweetPage({super.key});
  @override
  State<CreateFweetPage> createState() => _CreateFweetPageState();
}

class _CreateFweetPageState extends State<CreateFweetPage>
    with TickerProviderStateMixin {
  final _api          = ApiService();
  final _ctrl         = TextEditingController();
  final _locationCtrl = TextEditingController();
  static const int _maxChars = 240;

  Color?  _selectedBg;
  bool    _isPosting       = false;
  bool    _pickingLocation = false;          // NEW — drives Place pill loader
  String  _visibility      = 'Public';
  String? _feelingSlug;          // backend slug, not display text

  // Backend-driven feelings.
  List<_Feeling> _backendFeelings = [];
  bool           _feelingsLoading = true;
  // True only when feelings came from the backend, so their slugs are
  // valid to send. When the built-in fallback is used we don't send a
  // feeling — the backend has no matching Feeling row for those slugs.
  bool           _feelingsFromBackend = false;

  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;

  // Background-style choices (visual only — sent as the
  // `background_color` hex on the post).
  final List<Map<String, dynamic>> _bgOptions = const [
    {'name': 'Purple Dream', 'color': Color(0xFF8E54E9)},
    {'name': 'Ocean Blue',   'color': Color(0xFF4FC3F7)},
    {'name': 'Rose Gold',    'color': Color(0xFFFA709A)},
    {'name': 'Mint Fresh',   'color': Color(0xFF30CFD0)},
    {'name': 'Orange Glow',  'color': Color(0xFFFF9A56)},
    {'name': 'Midnight',     'color': Color(0xFF1A1A2E)},
    {'name': 'Emerald',      'color': Color(0xFF27AE60)},
    {'name': 'Crimson',      'color': Color(0xFFE74C3C)},
  ];

  // Campus quick-pick locations passed to the LocationPicker.
  final _campusLocations = const [
    'Taylors College', 'Library', 'Cafeteria', 'Sports Hall',
    'Lecture Hall A', 'Lecture Hall B', 'Study Hub', 'Auditorium',
    'Student Lounge', 'Science Lab',
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _ctrl.addListener(() => setState(() {}));
    _locationCtrl.addListener(() => setState(() {}));
    _fetchFeelings();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _ctrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Getters ──────────────────────────────────────────────

  bool  get _hasContent  => _ctrl.text.trim().isNotEmpty;
  int   get _remaining   => _maxChars - _ctrl.text.length;
  bool  get _hasBg       => _selectedBg != null;
  bool  get _hasLocation => _locationCtrl.text.trim().isNotEmpty;
  bool  get _hasFeeling  => _feelingSlug != null && _feelingSlug!.isNotEmpty;
  Color get _textColor   =>
      _hasBg ? _fweetTextColor(_selectedBg!) : const Color(0xFF1A1A2E);

  Color get _counterColor {
    if (_remaining < 0)  return _kG4;
    if (_remaining < 20) return _kG3;
    return _hasBg ? Colors.white54 : AppC.faint;
  }

  /// The full _Feeling object for the currently selected slug, or
  /// null if nothing is picked / the slug doesn't match anything in
  /// the backend list (e.g. a deactivated feeling).
  _Feeling? get _selectedFeeling {
    if (_feelingSlug == null) return null;
    for (final f in _backendFeelings) {
      if (f.slug == _feelingSlug) return f;
    }
    return null;
  }

  /// The currently selected background-style display name, looked up
  /// from `_bgOptions` so we can show "Purple Dream" on the toolbar
  /// pill instead of just "Style ✓".
  String? get _selectedBgName {
    if (_selectedBg == null) return null;
    for (final opt in _bgOptions) {
      if (opt['color'] == _selectedBg) return opt['name'] as String;
    }
    return null;
  }

  IconData get _visibilityIcon => _visibility == 'Public'
      ? Icons.public_rounded
      : _visibility == 'Followers'
          ? Icons.people_rounded
          : Icons.lock_rounded;

  // ── Backend ──────────────────────────────────────────────

  Future<void> _fetchFeelings() async {
    setState(() => _feelingsLoading = true);
    try {
      final raw = await _api.getFeelings();
      final list = (raw as List? ?? [])
          .whereType<Map>()
          .map((m) => _Feeling.fromJson(m.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _backendFeelings = list.isNotEmpty ? list : _defaultFeelings;
        _feelingsFromBackend = list.isNotEmpty;
        _feelingsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backendFeelings = _defaultFeelings;
        _feelingsFromBackend = false;
        _feelingsLoading = false;
      });
    }
  }

  // ── Location picker entry point ──────────────────────────

  Future<void> _openLocationPicker() async {
    if (_pickingLocation) return;
    HapticFeedback.lightImpact();
    setState(() => _pickingLocation = true);

    final result = await LocationPicker.show(
      context,
      quickPicks:   _campusLocations,
      initialQuery: _locationCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _pickingLocation = false;
      if (result != null) _locationCtrl.text = result.name;
    });
  }

  // ── POST TO BACKEND ──────────────────────────────────────

  Future<void> _post() async {
    if (!_hasContent || _remaining < 0) return;
    HapticFeedback.heavyImpact();
    setState(() => _isPosting = true);

    try {
      final bgHex = _selectedBg != null
          ? '#${_selectedBg!.value.toRadixString(16).substring(2).toUpperCase()}'
          : '';

      await _api.createPost(
        content:         _ctrl.text.trim(),
        postType:        'fweet',
        visibility:      _visibility.toLowerCase(),
        location:        _locationCtrl.text.trim(),
        backgroundColor: bgHex,
        // Only send a feeling the backend actually knows about. Built-in
        // fallback feelings have no Feeling row, so sending their slug
        // 400s with "Object with slug=… does not exist."
        feeling:         _feelingsFromBackend ? _feelingSlug : null,
      );

      if (!mounted) return;
      Navigator.pop(context, _ctrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to fweet: $e',
            style: const TextStyle(fontFamily: 'Momo')),
        behavior: SnackBarBehavior.floating, backgroundColor: _kG4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  // ═════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: _hasBg ? LinearGradient(
              colors: [_selectedBg!, _selectedBg!.withOpacity(0.75)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ) : null,
            color: _hasBg ? null : Colors.white,
          ),
          child: SafeArea(
            child: Column(children: [
              _buildAppBar(),
              Expanded(child: _buildComposer()),
              _buildActiveChips(),
              _buildToolbar(),
            ]),
          ),
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────

  Widget _buildAppBar() {
    final onBg  = _hasBg ? Colors.white : const Color(0xFF1A1A2E);
    final dimBg = _hasBg ? Colors.white.withOpacity(0.18) : AppC.card2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 38, height: 38,
            decoration: BoxDecoration(
                color: dimBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.close_rounded,
                color: onBg.withOpacity(0.7), size: 20)),
        ),
const SizedBox(width: 12),
        Flexible(
          child: T(
            'Create Fweet',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: onBg),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        const Spacer(),
        // Character ring
        SizedBox(width: 34, height: 34,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: (_ctrl.text.length / _maxChars).clamp(0.0, 1.0),
              strokeWidth: 3,
              backgroundColor: (_hasBg ? Colors.white : AppC.border)
                  .withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(
                  _remaining < 0 ? _kG4
                      : _remaining < 20 ? _kG3 : _kG2),
            ),
            if (_remaining <= 30)
              Text('$_remaining',
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 9, fontWeight: FontWeight.bold,
                      color: _counterColor)),
          ]),
        ),
        const SizedBox(width: 10),

        // Visibility pill
        GestureDetector(
          onTap: _pickVisibility,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hasBg
                  ? Colors.white.withOpacity(0.2)
                  : _kG2.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _hasBg
                  ? Colors.white.withOpacity(0.3)
                  : _kG2.withOpacity(0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_visibilityIcon,
                  color: _hasBg ? Colors.white : _kG2, size: 13),
              const SizedBox(width: 4),
              Text(_visibility,
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _hasBg ? Colors.white : _kG2)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: _hasBg ? Colors.white : _kG2, size: 16),
            ]),
          ),
        ),
        const SizedBox(width: 8),

        // Send button
        GestureDetector(
          onTap: (_hasContent && !_isPosting) ? _post : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _hasContent
                  ? (_hasBg ? Colors.white : _kG2)
                  : (_hasBg
                      ? Colors.white.withOpacity(0.3)
                      : AppC.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isPosting
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: _hasBg ? _selectedBg : Colors.white,
                        strokeWidth: 2))
                : Icon(Icons.send_rounded,
                    color: _hasBg ? _selectedBg : Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Composer (text field + optional avatar) ──────────────

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: _hasBg
          // Coloured "fweet card" — a live preview of how the post will
          // look in the feed. The card fill is the chosen colour; the
          // text uses a contrasting colour so it never clashes.
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 220),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _selectedBg!,
                      _selectedBg!.withOpacity(0.78),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: Center(child: _textField(centered: true)),
              ),
            )
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 44, height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_kG1, _kG2],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Icon(Icons.person_rounded,
                    color: Colors.white, size: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(child: _textField()),
            ]),
    );
  }

  Widget _textField({bool centered = false}) {
    return TextField(
      controller:        _ctrl,
      maxLines:          null,
      minLines:          centered ? 3 : 5,
      maxLength:         _maxChars,
      textAlign:         centered ? TextAlign.center : TextAlign.start,
      enableSuggestions: false,
      autocorrect:       false,
      style: TextStyle(
        fontFamily: 'Momo', fontSize: centered ? 22 : 16,
        color:      _textColor,
        fontWeight: centered ? FontWeight.bold : FontWeight.normal,
        height:     1.55,
      ),
      decoration: InputDecoration(
        hintText: TranslationService.I.tr('Share a quick thought with the campus...'),
        hintStyle: TextStyle(fontFamily: 'Momo',
          color:      _hasBg
              ? _textColor.withOpacity(0.55)
              : AppC.border,
          fontSize:   centered ? 20 : 16,
          fontWeight: centered ? FontWeight.bold : FontWeight.normal,
        ),
        border: InputBorder.none, counterText: '',
      ),
    );
  }

  // ── Active chips (location + feeling badges above toolbar) ──

  Widget _buildActiveChips() {
    final chips = <Widget>[];
    if (_hasLocation) {
      chips.add(_chip(Icons.location_on_rounded,
        _locationCtrl.text.trim(), _hasBg ? Colors.white : _kG4,
        () => setState(() => _locationCtrl.clear())));
    }
    if (_selectedFeeling != null) {
      chips.add(_chip(Icons.emoji_emotions_rounded,
        _selectedFeeling!.display,
        _hasBg ? Colors.white : _kG3,
        () => setState(() => _feelingSlug = null)));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(IconData icon, String label, Color color,
      VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _hasBg
            ? Colors.white.withOpacity(0.18)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hasBg
            ? Colors.white.withOpacity(0.3)
            : color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
            fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 5),
        GestureDetector(onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 13, color: color)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────
  // RESTYLED TOOLBAR — three eye-catching pill buttons.
  // ─────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _hasBg
            ? Colors.black.withOpacity(0.18)
            : Colors.grey.shade50,
        border: Border(top: BorderSide(
            color: _hasBg
                ? Colors.white.withOpacity(0.15)
                : AppC.border)),
      ),
      child: SafeArea(top: false,
        child: Row(children: [
          Expanded(child: _ToolPill(
            icon:        Icons.color_lens_rounded,
            label:       'Style',
            valueLabel:  _selectedBgName,
            gradient:    const [_kG2, _kG1],
            active:      _hasBg,
            onTab:       _showBgPicker,
            onClear:     _hasBg
                ? () => setState(() => _selectedBg = null)
                : null,
            invertedTheme: _hasBg,
          )),
          const SizedBox(width: 8),
          Expanded(child: _ToolPill(
            icon:        Icons.location_on_rounded,
            label:       'Place',
            valueLabel:  _hasLocation ? _locationCtrl.text.trim() : null,
            gradient:    const [_kG4, Color(0xFFFF8A65)],
            active:      _hasLocation || _pickingLocation,
            loading:     _pickingLocation,
            onTab:       _openLocationPicker,
            onClear:     _hasLocation && !_pickingLocation
                ? () => setState(() => _locationCtrl.clear())
                : null,
            invertedTheme: _hasBg,
          )),
          const SizedBox(width: 8),
          Expanded(child: _ToolPill(
            icon:        Icons.emoji_emotions_rounded,
            label:       'Feeling',
            valueLabel:  _selectedFeeling?.display,
            gradient:    const [_kG3, _kG4],
            active:      _hasFeeling,
            onTab:       _pickFeeling,
            onClear:     _hasFeeling
                ? () => setState(() => _feelingSlug = null)
                : null,
            invertedTheme: _hasBg,
          )),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Pickers
  // ─────────────────────────────────────────────────────────

  void _pickVisibility() {
    showModalBottomSheet(
      context: context, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppC.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const T('Who can see this Fweet?',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 18, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          ...[
            ('Public',    Icons.public_rounded,  'Everyone on TCS'),
            ('Followers', Icons.people_rounded,  'Only your followers'),
            ('Private',   Icons.lock_rounded,    'Only you'),
          ].map((opt) => GestureDetector(
            onTap: () {
              setState(() => _visibility = opt.$1);
              Navigator.pop(context);
            },
            child: Container(
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _visibility == opt.$1
                    ? _kG2.withOpacity(0.08) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _visibility == opt.$1
                      ? _kG2.withOpacity(0.3) : AppC.border,
                  width: _visibility == opt.$1 ? 1.5 : 1),
              ),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_visibility == opt.$1 ? _kG2 : AppC.border)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(opt.$2,
                      color: _visibility == opt.$1
                          ? _kG2 : AppC.faint, size: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(opt.$1, style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: _visibility == opt.$1
                          ? _kG2 : const Color(0xFF1A1A2E))),
                  Text(opt.$3, style: TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: AppC.faint)),
                ]),
                const Spacer(),
                if (_visibility == opt.$1)
                  Icon(Icons.check_circle_rounded, color: _kG2, size: 20),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  void _pickFeeling() {
    showModalBottomSheet(
      context: context, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppC.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const T('How are you feeling?',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 18, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          if (_feelingsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(
                    color: _kG3, strokeWidth: 2.5)))
          else if (_backendFeelings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                Icon(Icons.cloud_off_rounded,
                    color: AppC.faint, size: 28),
                const SizedBox(height: 8),
                Text("Couldn't load feelings.",
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 13, color: AppC.faint)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () { Navigator.pop(context); _fetchFeelings(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kG3.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: T('Try again',
                        style: TextStyle(fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 12, color: _kG3)),
                  ),
                ),
              ]),
            )
          else
            Wrap(spacing: 10, runSpacing: 10,
              children: _backendFeelings.map((f) => GestureDetector(
                onTap: () {
                  setState(() => _feelingSlug = f.slug);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _feelingSlug == f.slug
                        ? _kG3.withOpacity(0.12) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _feelingSlug == f.slug
                          ? _kG3.withOpacity(0.35) : AppC.border)),
                  child: Text(f.display,
                      style: TextStyle(fontFamily: 'Momo',
                          fontWeight: FontWeight.w600, fontSize: 14,
                          color: _feelingSlug == f.slug
                              ? _kG3 : const Color(0xFF1A1A2E))),
                ),
              )).toList()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showBgPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppC.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            const T('Choose Background',
                style: TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: Color(0xFF1A1A2E))),
            const Spacer(),
            if (_selectedBg != null)
              GestureDetector(
                onTap: () {
                  setState(() => _selectedBg = null);
                  Navigator.pop(context);
                },
                child: const T('Clear',
                    style: TextStyle(fontFamily: 'Momo',
                        color: _kG4, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true, crossAxisCount: 4,
            mainAxisSpacing: 12, crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: _bgOptions.map((opt) {
              final color = opt['color'] as Color;
              final sel   = _selectedBg == color;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedBg = color);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: sel ? Colors.black : Colors.transparent,
                        width: sel ? 3 : 0),
                    boxShadow: sel ? [BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 14, offset: const Offset(0, 4))] : null),
                  child: sel
                      ? const Center(child: Icon(Icons.check_rounded,
                          color: Colors.white, size: 28))
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8,
            children: _bgOptions.map((opt) {
              final sel = _selectedBg == (opt['color'] as Color);
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel
                      ? (opt['color'] as Color).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel
                          ? (opt['color'] as Color).withOpacity(0.3)
                          : AppC.border)),
                child: Text(opt['name'] as String,
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: sel
                            ? opt['color'] as Color
                            : AppC.faint)),
              );
            }).toList()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// Eye-catching tool pill — replaces the cramped icon button in
// the previous toolbar.
//
// Three visual states:
//   • Inactive (default theme): outlined card, coloured icon + label.
//   • Active   (default theme): gradient fill, white icon + label,
//                                value text shown below.
//   • Inverted theme (when a background colour is applied to the
//     fweet, so the page is colourful): outlined card with
//     translucent-white surface so it stays readable.
//
// Plus a `loading` flag — when true, the icon is replaced with a
// SpinKitFadingCircle. Used by the Place pill while the LocationPicker
// modal is open so the user gets a clear "in progress" signal.
// ─────────────────────────────────────────────────────────────

class _ToolPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  valueLabel;
  final List<Color> gradient;
  final bool     active;
  final bool     loading;
  final bool     invertedTheme;
  final VoidCallback onTab;
  final VoidCallback? onClear;

  const _ToolPill({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.gradient,
    required this.active,
    required this.onTab,
    required this.invertedTheme,
    this.loading = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // Colour resolution differs per theme.
    final Color fg;
    final BoxDecoration deco;

    if (invertedTheme) {
      // Page already has a colourful background — keep pills neutral.
      fg = Colors.white;
      deco = BoxDecoration(
        color: active
            ? Colors.white.withOpacity(0.25)
            : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(
            active ? 0.55 : 0.25), width: 1.5),
      );
    } else if (active) {
      // White page, active state — full gradient fill.
      fg = Colors.white;
      deco = BoxDecoration(
        gradient: LinearGradient(colors: gradient,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 12, offset: const Offset(0, 4))],
      );
    } else {
      // White page, inactive — outlined with a hint of category colour.
      fg = gradient.first;
      deco = BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: gradient.first.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      );
    }

    final hasValue = active && valueLabel != null && valueLabel!.isNotEmpty;
    final showSpinner = loading;

    return GestureDetector(
      onTap: onTab,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: deco,
        child: Stack(children: [
          // Main label/icon column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon OR loading spinner
                  SizedBox(
                    width: 18, height: 18,
                    child: showSpinner
                        ? SpinKitFadingCircle(color: fg, size: 18)
                        : Icon(icon, size: 18, color: fg),
                  ),
                  const SizedBox(width: 6),
                  Text(label,
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 13, color: fg)),
                ]),
              if (hasValue) ...[
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    valueLabel!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Momo', fontSize: 10,
                        color: fg.withOpacity(invertedTheme ? 0.85 : 0.92),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),

          // Tiny "x" in the top-right when the value can be cleared.
          // Hidden during a loading state to avoid visual noise.
          if (active && !loading && onClear != null)
            Positioned(top: -2, right: -2,
              child: GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                      color: invertedTheme
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: invertedTheme
                              ? Colors.white.withOpacity(0.4)
                              : gradient.first.withOpacity(0.3),
                          width: 1)),
                  child: Icon(Icons.close_rounded, size: 11, color: fg),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}