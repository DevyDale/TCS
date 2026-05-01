// lib/screens/create_fweet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

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
  bool    _showingLocation = false;
  bool    _isPosting       = false;
  String  _visibility      = 'Public';
  String? _feeling;

  late final AnimationController _entryCtrl;
  late final Animation<double>   _fadeAnim;

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

  final _feelings = [
    '😊 Happy', '📚 Studying', '🎮 Gaming', '🏃 Active',
    '😴 Tired', '🎉 Excited', '🤔 Thinking', '💪 Motivated',
    '😎 Cool', '🥳 Celebrating',
  ];

  final _campusLocations = [
    'Taylors College', 'Library', 'Cafeteria', 'Sports Hall',
    'Lecture Hall A', 'Lecture Hall B', 'Study Hub', 'Auditorium',
    'Student Lounge', 'Science Lab',
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400))..forward();
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _ctrl.addListener(() => setState(() {}));
    _locationCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _entryCtrl.dispose(); _ctrl.dispose(); _locationCtrl.dispose();
    super.dispose();
  }

  bool  get _hasContent  => _ctrl.text.trim().isNotEmpty;
  int   get _remaining   => _maxChars - _ctrl.text.length;
  bool  get _hasBg       => _selectedBg != null;
  bool  get _hasLocation => _locationCtrl.text.trim().isNotEmpty;
  Color get _textColor   => _hasBg ? Colors.white : const Color(0xFF1A1A2E);

  Color get _counterColor {
    if (_remaining < 0)  return _kG4;
    if (_remaining < 20) return _kG3;
    return _hasBg ? Colors.white54 : Colors.grey.shade400;
  }

  // ── POST TO BACKEND ───────────────────────────────────────

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
      );

      if (!mounted) return;
      // Return the fweet text to the profile screen
      Navigator.pop(context, _ctrl.text.trim());
    } catch (e) {
      setState(() => _isPosting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to fweet: $e', style: const TextStyle(fontFamily: 'Momo')),
        behavior: SnackBarBehavior.floating, backgroundColor: _kG4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

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
              if (_showingLocation) _buildLocationBar(),
              _buildActiveChips(),
              _buildToolbar(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final onBg  = _hasBg ? Colors.white : const Color(0xFF1A1A2E);
    final dimBg = _hasBg ? Colors.white.withOpacity(0.18) : Colors.grey.shade100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: dimBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.close_rounded, color: onBg.withOpacity(0.7), size: 20)),
        ),
        const SizedBox(width: 12),
        Text('Create Fweet', style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: onBg)),
        const Spacer(),

        // Character ring
        SizedBox(width: 34, height: 34,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: (_ctrl.text.length / _maxChars).clamp(0.0, 1.0),
              strokeWidth: 3,
              backgroundColor: (_hasBg ? Colors.white : Colors.grey.shade200).withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(
                  _remaining < 0 ? _kG4 : _remaining < 20 ? _kG3 : _kG2),
            ),
            if (_remaining <= 30)
              Text('$_remaining', style: TextStyle(fontFamily: 'Momo',
                  fontSize: 9, fontWeight: FontWeight.bold, color: _counterColor)),
          ]),
        ),
        const SizedBox(width: 10),

        // Visibility pill
        GestureDetector(
          onTap: _pickVisibility,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hasBg ? Colors.white.withOpacity(0.2) : _kG2.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _hasBg
                  ? Colors.white.withOpacity(0.3) : _kG2.withOpacity(0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_visibilityIcon, color: _hasBg ? Colors.white : _kG2, size: 13),
              const SizedBox(width: 4),
              Text(_visibility, style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                  fontWeight: FontWeight.bold, color: _hasBg ? Colors.white : _kG2)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: _hasBg ? Colors.white : _kG2, size: 14),
            ]),
          ),
        ),
        const SizedBox(width: 10),

        // Send button
        GestureDetector(
          onTap: _isPosting || !_hasContent || _remaining < 0 ? null : _post,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _hasBg
                  ? Colors.white.withOpacity(_hasContent ? 0.25 : 0.12) : null,
              gradient: !_hasBg
                  ? (_hasContent && !_isPosting && _remaining >= 0
                      ? const LinearGradient(colors: [_kG1, _kG2, _kG3, _kG4],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : const LinearGradient(
                          colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)]))
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isPosting
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: _hasBg ? _selectedBg : Colors.white, strokeWidth: 2))
                  : Icon(Icons.send_rounded,
                      color: _hasBg ? _selectedBg : Colors.white, size: 18),
            ),
          ),
        ),
      ]),
    );
  }

  IconData get _visibilityIcon => _visibility == 'Public'
      ? Icons.public_rounded
      : _visibility == 'Followers' ? Icons.people_rounded : Icons.lock_rounded;

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: _hasBg
          ? _textField(centered: true)
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
      minLines:          centered ? 7 : 5,
      maxLength:         _maxChars,
      textAlign:         centered ? TextAlign.center : TextAlign.start,
      enableSuggestions: false,
      autocorrect:       false,
      style: TextStyle(
        fontFamily: 'Momo', fontSize: centered ? 22 : 16,
        color: _textColor,
        fontWeight: centered ? FontWeight.bold : FontWeight.normal,
        height: 1.55,
      ),
      decoration: InputDecoration(
        hintText: 'Share a quick thought with the campus...',
        hintStyle: TextStyle(fontFamily: 'Momo',
          color: _hasBg ? Colors.white38 : Colors.grey.shade300,
          fontSize: centered ? 20 : 16,
          fontWeight: centered ? FontWeight.bold : FontWeight.normal,
        ),
        border: InputBorder.none, counterText: '',
      ),
    );
  }

  Widget _buildLocationBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _hasBg ? Colors.white.withOpacity(0.15) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasBg ? Colors.white.withOpacity(0.2) : Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.location_on_rounded, color: _hasBg ? Colors.white : _kG4, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _locationCtrl, autofocus: true,
              style: TextStyle(fontFamily: 'Momo', fontSize: 14, color: _textColor),
              decoration: InputDecoration(
                hintText: 'Where are you?',
                hintStyle: TextStyle(fontFamily: 'Momo', fontSize: 14,
                    color: _hasBg ? Colors.white38 : Colors.grey.shade400),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_hasLocation)
            GestureDetector(
              onTap: () => setState(() { _locationCtrl.clear(); _showingLocation = false; }),
              child: Icon(Icons.close_rounded,
                  color: _hasBg ? Colors.white54 : Colors.grey.shade400, size: 16)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _campusLocations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () {
                _locationCtrl.text = _campusLocations[i];
                setState(() => _showingLocation = false);
                FocusScope.of(context).unfocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _hasBg ? Colors.white.withOpacity(0.15) : _kG4.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasBg ? Colors.white.withOpacity(0.2) : _kG4.withOpacity(0.2)),
                ),
                child: Text(_campusLocations[i], style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _hasBg ? Colors.white : _kG4)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildActiveChips() {
    final chips = <Widget>[];
    if (_hasLocation) {
      chips.add(_chip(Icons.location_on_rounded,
        _locationCtrl.text.trim(), _hasBg ? Colors.white : _kG4,
        () => setState(() { _locationCtrl.clear(); _showingLocation = false; })));
    }
    if (_feeling != null) {
      chips.add(_chip(Icons.emoji_emotions_rounded, _feeling!,
        _hasBg ? Colors.white : _kG3, () => setState(() => _feeling = null)));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Wrap(spacing: 8, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(IconData icon, String label, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _hasBg ? Colors.white.withOpacity(0.18) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hasBg ? Colors.white.withOpacity(0.3) : color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color), const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
            fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 5),
        GestureDetector(onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 13, color: color)),
      ]),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: _hasBg ? Colors.black.withOpacity(0.15) : Colors.grey.shade50,
        border: Border(top: BorderSide(
          color: _hasBg ? Colors.white.withOpacity(0.15) : Colors.grey.shade200)),
      ),
      child: SafeArea(top: false,
        child: Row(children: [
          _tool(Icons.color_lens_outlined, 'Style',
              _hasBg ? Colors.white : _kG2, _showBgPicker, badge: _hasBg),
          _tool(Icons.location_on_outlined, 'Place',
              _hasBg ? Colors.white : _kG4,
              () => setState(() => _showingLocation = !_showingLocation),
              badge: _hasLocation),
          _tool(Icons.emoji_emotions_outlined, 'Feeling',
              _hasBg ? Colors.white : _kG3, _pickFeeling, badge: _feeling != null),
          const Spacer(),
          if (_hasBg)
            GestureDetector(
              onTap: () => setState(() => _selectedBg = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Clear Style', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _tool(IconData icon, String label, Color color, VoidCallback onTap,
      {bool badge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, color: color, size: 22),
            if (badge) Positioned(right: -3, top: -3,
              child: Container(width: 8, height: 8,
                decoration: BoxDecoration(color: Colors.green.shade500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)),
              ),
            ),
          ]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 10,
              color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _pickVisibility() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Who can see this Fweet?', style: TextStyle(
              fontFamily: 'Alfa', fontSize: 18, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          ...[
            ('Public',    Icons.public_rounded,  'Everyone on TCS'),
            ('Followers', Icons.people_rounded,  'Only your followers'),
            ('Private',   Icons.lock_rounded,    'Only you'),
          ].map((opt) => GestureDetector(
            onTap: () { setState(() => _visibility = opt.$1); Navigator.pop(context); },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _visibility == opt.$1 ? _kG2.withOpacity(0.08) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _visibility == opt.$1 ? _kG2.withOpacity(0.3) : Colors.grey.shade200,
                  width: _visibility == opt.$1 ? 1.5 : 1),
              ),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_visibility == opt.$1 ? _kG2 : Colors.grey.shade300).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(opt.$2,
                      color: _visibility == opt.$1 ? _kG2 : Colors.grey.shade500, size: 20)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(opt.$1, style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 15, color: _visibility == opt.$1 ? _kG2 : const Color(0xFF1A1A2E))),
                  Text(opt.$3, style: TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: Colors.grey.shade500)),
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
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('How are you feeling?', style: TextStyle(
              fontFamily: 'Alfa', fontSize: 18, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: _feelings.map((f) => GestureDetector(
            onTap: () { setState(() => _feeling = f); Navigator.pop(context); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _feeling == f ? _kG3.withOpacity(0.12) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _feeling == f ? _kG3.withOpacity(0.35) : Colors.grey.shade200)),
              child: Text(f, style: TextStyle(fontFamily: 'Momo', fontWeight: FontWeight.w600,
                  fontSize: 14, color: _feeling == f ? _kG3 : const Color(0xFF1A1A2E))),
            ),
          )).toList()),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showBgPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Choose Background', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 18, color: Color(0xFF1A1A2E))),
            const Spacer(),
            if (_selectedBg != null)
              GestureDetector(
                onTap: () { setState(() => _selectedBg = null); Navigator.pop(context); },
                child: const Text('Clear', style: TextStyle(fontFamily: 'Momo',
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
                onTap: () { setState(() => _selectedBg = color); Navigator.pop(context); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: sel ? Colors.white : Colors.transparent, width: 3),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.4),
                        blurRadius: sel ? 14 : 4, offset: const Offset(0, 3))],
                  ),
                  child: sel
                      ? const Center(child: Icon(Icons.check_rounded,
                          color: Colors.white, size: 24))
                      : Center(child: Text(opt['name'], textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Momo', fontSize: 9,
                              color: Colors.white70, fontWeight: FontWeight.w600))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}