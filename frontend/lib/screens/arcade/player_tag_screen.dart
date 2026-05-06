// lib/screens/arcade/player_tag_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import 'game_engine.dart';

class PlayerTagScreen extends StatefulWidget {
  const PlayerTagScreen({super.key});
  @override
  State<PlayerTagScreen> createState() => _PlayerTagScreenState();
}

class _PlayerTagScreenState extends State<PlayerTagScreen>
    with SingleTickerProviderStateMixin {
  final _api     = ApiService();
  final _ctrl    = TextEditingController();
  final _picker  = ImagePicker();
  late final AnimationController _pulse;

  int     _selectedColor = 0;
  bool    _checking      = false;
  bool    _uploadingImg  = false;
  String? _error;
  String? _preview;
  File?   _avatarFile;          // locally picked image
  String? _avatarUrl;           // uploaded URL from backend

  final _colorOptions = [
    [const Color(0xFF6DD5FA), const Color(0xFF2575FC)],
    [const Color(0xFF8E54E9), const Color(0xFF6B2FD9)],
    [const Color(0xFFF7971E), const Color(0xFFFF5858)],
    [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
    [const Color(0xFFFF5858), const Color(0xFFFF6B6B)],
    [const Color(0xFFCE93D8), const Color(0xFF7B1FA2)],
  ];

  final _suggestions = [
    'NeonRacer','QuantumX','BlazeFury','ShadowLynx',
    'CyberPunk','VoidKnight','NightOwl','ThunderBolt',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _ctrl.addListener(() =>
        setState(() { _preview = _ctrl.text.trim(); _error = null; }));
  }

  @override
  void dispose() { _pulse.dispose(); _ctrl.dispose(); super.dispose(); }

  // ── Pick avatar from camera or gallery ────────────────────

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kDarkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Choose Avatar', style: TextStyle(fontFamily: 'Alfa',
              fontSize: 18, color: Colors.white)),
          const SizedBox(height: 20),
          _sheetBtn(Icons.camera_alt_rounded, 'Take a Photo', () {
            Navigator.pop(context);
            _pickImage(ImageSource.camera);
          }),
          const SizedBox(height: 12),
          _sheetBtn(Icons.photo_library_rounded, 'Choose from Gallery', () {
            Navigator.pop(context);
            _pickImage(ImageSource.gallery);
          }),
          if (_avatarFile != null || _avatarUrl != null) ...[
            const SizedBox(height: 12),
            _sheetBtn(Icons.delete_outline_rounded, 'Remove Photo', () {
              Navigator.pop(context);
              setState(() { _avatarFile = null; _avatarUrl = null; });
            }, color: kNeonRed),
          ],
        ]),
      )),
    );
  }

  Widget _sheetBtn(IconData icon, String label, VoidCallback onTap,
      {Color color = kNeonBlue}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25))),
        child: Row(children: [
          const SizedBox(width: 16),
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (picked == null) return;
      setState(() { _avatarFile = File(picked.path); _uploadingImg = true; });
      await _uploadAvatar();
    } catch (e) {
      _snack('Could not pick image: $e');
    }
  }

  Future<void> _uploadAvatar() async {
    if (_avatarFile == null) return;
    try {
      // POST multipart to /api/arcade/gamer-tag/avatar/
      final res = await _api.uploadFile(
        '/arcade/gamer-tag/avatar/',
        filePath: _avatarFile!.path,
        field: 'avatar',
      ) as Map<String, dynamic>;
      setState(() {
        _avatarUrl   = res['avatar_url'] as String?;
        _uploadingImg = false;
      });
      _snack('Avatar uploaded! ✅', success: true);
    } catch (e) {
      setState(() => _uploadingImg = false);
      _snack('Upload failed: $e');
    }
  }

  // ── Save gamer tag ────────────────────────────────────────

  Future<void> _save() async {
    final tag = _ctrl.text.trim();
    if (tag.length < 3) {
      setState(() => _error = 'At least 3 characters required');
      return;
    }
    setState(() { _checking = true; _error = null; });
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

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: success ? Colors.green.shade700 : kDarkCard2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final grad = _colorOptions[_selectedColor];
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(children: [
              // Back
              Align(alignment: Alignment.centerLeft,
                child: GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: kDarkCard2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08))),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white60, size: 20)))),
              const SizedBox(height: 32),

              // Avatar preview — tappable to change photo
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(children: [
                  AnimatedBuilder(animation: _pulse, builder: (_, __) =>
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: (_avatarFile == null && _avatarUrl == null)
                            ? LinearGradient(colors: grad,
                                begin: Alignment.topLeft, end: Alignment.bottomRight)
                            : null,
                        color: (_avatarFile != null || _avatarUrl != null)
                            ? Colors.transparent : null,
                        image: _avatarFile != null
                            ? DecorationImage(image: FileImage(_avatarFile!),
                                fit: BoxFit.cover)
                            : _avatarUrl != null
                                ? DecorationImage(image: NetworkImage(_avatarUrl!),
                                    fit: BoxFit.cover)
                                : null,
                        boxShadow: [BoxShadow(
                          color: grad.first.withOpacity(0.4 + 0.2 * _pulse.value),
                          blurRadius: 30, spreadRadius: 4)]),
                      child: (_avatarFile == null && _avatarUrl == null)
                          ? Center(child: Text(
                              (_preview?.isNotEmpty == true)
                                  ? _preview![0].toUpperCase() : '?',
                              style: const TextStyle(fontFamily: 'Alfa',
                                  fontSize: 44, color: Colors.white)))
                          : null,
                    ),
                  ),

                  // Upload progress ring
                  if (_uploadingImg)
                    const SizedBox(width: 110, height: 110,
                      child: CircularProgressIndicator(
                          color: kNeonBlue, strokeWidth: 3)),

                  // Camera icon badge
                  Positioned(bottom: 4, right: 4,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: grad),
                        border: Border.all(color: kDarkBg, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16))),
                ],
              )),
              const SizedBox(height: 8),
              Text('Tap to add photo', style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: Colors.white.withOpacity(0.35))),
              const SizedBox(height: 14),

              // Tag preview
              if (_preview?.isNotEmpty == true)
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(colors: grad).createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: Text('#$_preview', style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 22, color: Colors.white)),
                ),
              const SizedBox(height: 4),
              Text('Create your gamer identity', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 13,
                  color: Colors.white.withOpacity(0.4))),

              const SizedBox(height: 28),

              // Tag input
              Container(
                decoration: BoxDecoration(
                  color: kDarkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _error != null
                      ? kNeonRed.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08))),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  maxLength: 20,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter your gamer tag...',
                    hintStyle: TextStyle(fontFamily: 'Arch', fontSize: 16,
                        color: Colors.white.withOpacity(0.25)),
                    counterStyle: TextStyle(color: Colors.white.withOpacity(0.3),
                        fontFamily: 'Momo'),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    prefixText: '#  ',
                    prefixStyle: TextStyle(fontFamily: 'Momo',
                        fontSize: 16, color: grad.first)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: kNeonRed)),
              ],

              const SizedBox(height: 20),

              // Suggestions
              Align(alignment: Alignment.centerLeft,
                child: Text('Suggestions', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.white.withOpacity(0.4)))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                children: _suggestions.map((s) => GestureDetector(
                  onTap: () {
                    _ctrl.text = s;
                    _ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: s.length));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: kDarkCard2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.07))),
                    child: Text(s, style: const TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: Colors.white60))),
                )).toList()),

              const SizedBox(height: 28),

              // Colour picker
              Align(alignment: Alignment.centerLeft,
                child: Text('Avatar Colour', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.white.withOpacity(0.4)))),
              const SizedBox(height: 12),
              Row(children: List.generate(_colorOptions.length, (i) {
                final g   = _colorOptions[i];
                final sel = i == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: sel ? 44 : 36, height: sel ? 44 : 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: g),
                      border: sel ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: sel ? [BoxShadow(color: g.first.withOpacity(0.6),
                          blurRadius: 14)] : null),
                    child: sel ? const Center(child: Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)) : null),
                );
              })),

              const SizedBox(height: 36),

              // Confirm button
              GestureDetector(
                onTap: (_checking || _uploadingImg) ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors:
                        (_checking || _uploadingImg)
                            ? [Colors.grey.shade700, Colors.grey.shade600]
                            : grad),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: (_checking || _uploadingImg) ? [] : [
                      BoxShadow(color: grad.first.withOpacity(0.4),
                          blurRadius: 20, offset: const Offset(0, 6))]),
                  child: Center(child: (_checking || _uploadingImg)
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Claim Tag ⚡', style: TextStyle(fontFamily: 'Alfa',
                          fontSize: 18, color: Colors.white))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}