import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/avator/avator_picker.dart';
import 'package:tcs_app/avator/avator_view.dart';
import 'package:tcs_app/data/avators.dart';
import '../../services/api_service.dart';
import '../../utils/responsive_helper.dart';   // ← Add this
import 'game_engine.dart';

const _kPrefAvatar = 'arcade_avatar_id_v2';

class PlayerTagScreen extends StatefulWidget {
  const PlayerTagScreen({super.key});

  @override
  State<PlayerTagScreen> createState() => _PlayerTagScreenState();
}

class _PlayerTagScreenState extends State<PlayerTagScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  late final AnimationController _pulse;

  int _selectedColor = 0;
  bool _checking = false;
  String? _error;
  String? _preview;
  int? _avatarId;

  final _colorOptions = [
    [const Color(0xFF6DD5FA), const Color(0xFF2575FC)],
    [const Color(0xFF8E54E9), const Color(0xFF6B2FD9)],
    [const Color(0xFFF7971E), const Color(0xFFFF5858)],
    [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
    [const Color(0xFFFF5858), const Color(0xFFFF6B6B)],
    [const Color(0xFFCE93D8), const Color(0xFF7B1FA2)],
  ];

  final _suggestions = [
    'NeonRacer', 'QuantumX', 'BlazeFury', 'ShadowLynx',
    'CyberPunk', 'VoidKnight', 'NightOwl', 'ThunderBolt',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _ctrl.addListener(() => setState(() {
          _preview = _ctrl.text.trim();
          _error = null;
        }));

    _loadAvatar();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _avatarId = prefs.getInt(_kPrefAvatar));
    } catch (_) {}
  }

  Future<void> _saveAvatarPref(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefAvatar, id);
    } catch (_) {}
  }
Future<void> _pickAvatar() async {
  HapticFeedback.lightImpact();

  final newId = await Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => AvatarPickerScreen(
        initialAvatarId: _avatarId,
      ),
    ),
  );

  if (newId != null && newId != _avatarId) {
    setState(() => _avatarId = newId);
    await _saveAvatarPref(newId);
  }
}
  Future<void> _save() async {
    final tag = _ctrl.text.trim();
    if (tag.length < 3) {
      setState(() => _error = 'At least 3 characters required');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    HapticFeedback.heavyImpact();

    try {
      await _api.patch('/arcade/gamer-tag/', body: {'gamer_tag': tag});
      if (mounted) Navigator.pop(context, tag);
    } catch (e) {
      setState(() {
        _error = e.toString().contains('taken')
            ? 'That tag is taken! Try another 👀'
            : 'Something went wrong';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = R(context); // Responsive helper
    final grad = _colorOptions[_selectedColor];

    return Scaffold(
      backgroundColor: AppC.bg,
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560, // Nice max width on tablets/desktops
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: r.pagePad.copyWith(top: 20, bottom: 40),
              child: Column(children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppC.card2,
                        borderRadius: BorderRadius.circular(r.radiusMd),
                        border: Border.all(color: AppC.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: AppC.sub, size: 22),
                    ),
                  ),
                ),

                SizedBox(height: r.lg),

                // Avatar
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: r.avatarSize * 2.4,   // ~110 on phone, larger on tablet
                        height: r.avatarSize * 2.4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _avatarId == null
                              ? LinearGradient(
                                  colors: grad,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: grad.first.withOpacity(0.4 + 0.2 * _pulse.value),
                              blurRadius: 30,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        child: _avatarId != null
                            ? ClipOval(
                                child: AvatarView.preset(_avatarId!, size: r.avatarSize * 2.4))
                            : Center(
                                child: Text(
                                  (_preview?.isNotEmpty == true)
                                      ? _preview![0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontFamily: 'Alfa',
                                    fontSize: r.avatarSize * 0.85,
                                    color: AppC.text,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // Edit badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: grad),
                          border: Border.all(color: kDarkBg, width: 2.5),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 10),
                T('Tap to choose avatar',
                    style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: r.caption,
                        color: AppC.text.withOpacity(0.35))),

                SizedBox(height: r.md),

                // Tag preview
                if (_preview?.isNotEmpty == true)
                  ShaderMask(
                    shaderCallback: (b) =>
                        LinearGradient(colors: grad).createShader(b),
                    blendMode: BlendMode.srcIn,
                    child: Text('#$_preview',
                        style: TextStyle(
                            fontFamily: 'Alfa',
                            fontSize: r.heading,
                            color: AppC.text)),
                  ),

                SizedBox(height: 6),
                T('Create your gamer identity',
                    style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: r.subheading - 2,
                        color: AppC.text.withOpacity(0.4))),

                SizedBox(height: r.xl),

                // Input Field — explicit dark fill + high-contrast text so
                // the typed gamer tag never clashes with the surrounding card.
                Container(
                  decoration: BoxDecoration(
                    color: AppC.text,
                    borderRadius: BorderRadius.circular(r.radiusLg),
                    border: Border.all(
                        color: _error != null
                            ? kNeonRed.withOpacity(0.5)
                            : Colors.white.withOpacity(0.12)),
                  ),
                  child: Theme(
                    // Force the text-selection handle/highlight to use the
                    // accent grad so it doesn't fall back to the system blue.
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor:        grad.first,
                        selectionColor:     grad.first.withOpacity(0.35),
                        selectionHandleColor: grad.first,
                      ),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      maxLength: 20,
                      enableSuggestions: false,
                      autocorrect: false,
                      cursorColor: grad.first,
                      cursorWidth: 2,
                      keyboardAppearance: Brightness.dark,
                      style: TextStyle(
                        fontFamily:   'Arch',
                        fontWeight:   FontWeight.bold,
                        fontSize:     r.body + 3,
                        color:        Colors.white,
                        letterSpacing: 0.3,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: TranslationService.I.tr('Enter your gamer tag...'),
                        hintStyle: TextStyle(
                            fontFamily: 'Arch',
                            fontSize:   r.body + 1,
                            color:      Colors.white.withOpacity(0.30)),
                        counterStyle: TextStyle(
                            color: AppC.text.withOpacity(0.35),
                            fontFamily: 'Momo'),
                        border:        InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: r.inputPad,
                        prefixText: '# ',
                        prefixStyle: TextStyle(
                            fontFamily: 'Momo',
                            fontSize:   r.body + 1,
                            color:      grad.first),
                      ),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: r.caption,
                          color: kNeonRed)),
                ],

                SizedBox(height: r.lg),

                // Suggestions
                Align(
                  alignment: Alignment.centerLeft,
                  child: T('Suggestions',
                      style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: r.caption,
                          color: AppC.text.withOpacity(0.4))),
                ),
                SizedBox(height: r.sm),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((s) => GestureDetector(
                    onTap: () {
                      _ctrl.text = s;
                      _ctrl.selection =
                          TextSelection.fromPosition(TextPosition(offset: s.length));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: kDarkCard2,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Text(s,
                          style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: r.caption + 1,
                              color: Colors.white60)),
                    ),
                  )).toList(),
                ),

                SizedBox(height: r.xl),

                // Accent Colour
                Align(
                  alignment: Alignment.centerLeft,
                  child: T('Accent Colour',
                      style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: r.caption,
                          color: AppC.text.withOpacity(0.4))),
                ),
                SizedBox(height: r.sm),

                Row(
                  children: List.generate(_colorOptions.length, (i) {
                    final g = _colorOptions[i];
                    final sel = i == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: sel ? r.iconLg + 8 : r.iconLg - 4,
                        height: sel ? r.iconLg + 8 : r.iconLg - 4,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: g),
                          border: sel
                              ? Border.all(color: Colors.white, width: 3.5)
                              : null,
                          boxShadow: sel
                              ? [BoxShadow(color: g.first.withOpacity(0.6), blurRadius: 16)]
                              : null,
                        ),
                        child: sel
                            ? const Center(
                                child: Icon(Icons.check_rounded,
                                    color: Colors.white, size: 20))
                            : null,
                      ),
                    );
                  }),
                ),

                SizedBox(height: r.xl + 8),

                // Confirm Button
                GestureDetector(
                  onTap: _checking ? null : _save,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: r.btnH,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: _checking
                              ? [AppC.sub, AppC.sub]
                              : grad),
                      borderRadius: BorderRadius.circular(r.radiusLg),
                      boxShadow: _checking
                          ? []
                          : [
                              BoxShadow(
                                  color: grad.first.withOpacity(0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8))
                            ],
                    ),
                    child: Center(
                      child: _checking
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3))
                          : T('Claim Tag ⚡',
                              style: TextStyle(
                                  fontFamily: 'Alfa',
                                  fontSize: r.heading - 4,
                                  color: AppC.text)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}