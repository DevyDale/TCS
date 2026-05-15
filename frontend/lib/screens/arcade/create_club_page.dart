// lib/screens/clubs/create_club_page.dart
//
// Phase 5 Slice 2 — Create-club form.
//
// Posts to /api/clubs/. Backend auto-promotes the creator to PRESIDENT
// in the same transaction. On success this page pops with the new
// Club map (the caller in ClubsListScreen pushes ClubScreen with it).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';

import '../../services/api_service.dart';


const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);
const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

const _kCats = <Map<String, String>>[
  {'value': 'academic',       'label': 'Academic'},
  {'value': 'sports',         'label': 'Sports'},
  {'value': 'arts',           'label': 'Arts'},
  {'value': 'cultural',       'label': 'Cultural'},
  {'value': 'technology',     'label': 'Technology'},
  {'value': 'social_service', 'label': 'Social Service'},
  {'value': 'business',       'label': 'Business'},
  {'value': 'gaming',         'label': 'Gaming'},
  {'value': 'other',          'label': 'Other'},
];

class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key});
  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _api  = ApiService();
  final _form = GlobalKey<FormState>();

  final _picker = ImagePicker();

  // Image files
  XFile? _logoFile;
  XFile? _coverFile;

  final _name        = TextEditingController();
  final _tagline     = TextEditingController();
  final _description = TextEditingController();

  String _category         = 'other';
  bool   _isPublic         = true;
  bool   _requiresApproval = false;
  bool   _busy             = false;

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _busy = true);

    try {
      final res = await _api.createClub({
        'name': _name.text.trim(),
        'tagline': _tagline.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'is_public': _isPublic,
        'requires_approval': _requiresApproval,
      }, logoPath: _logoFile?.path, coverPath: _coverFile?.path) as Map<String, dynamic>;

      if (!mounted) return;
      Navigator.pop(context, res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(),
            style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAiLogoSheet() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<XFile>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AiLogoSheet(
        api: _api,
        clubName: _name.text.trim(),
      ),
    );
    if (result != null && mounted) {
      setState(() => _logoFile = result);
    }
  }

  Future<void> _pickLogo() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file != null) setState(() => _logoFile = file);
  }

  Future<void> _pickCover() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file != null) setState(() => _coverFile = file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // === Club Logo & Cover Photo ===
                  Row(
                    children: [
                      // Logo
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickLogo,
                          child: Column(
                            children: [
                              const Text('Club Logo', 
                                style: TextStyle(fontFamily: 'Arch', fontSize: 12.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _kG2.withOpacity(0.4), width: 3),
                                  image: _logoFile != null 
                                      ? DecorationImage(image: FileImage(File(_logoFile!.path)), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: _logoFile == null
                                    ? const Icon(Icons.camera_alt_rounded, size: 34, color: _kG2)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Cover Photo
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickCover,
                          child: Column(
                            children: [
                              const Text('Cover Photo', 
                                style: TextStyle(fontFamily: 'Arch', fontSize: 12.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _kG2.withOpacity(0.4), width: 3),
                                  image: _coverFile != null 
                                      ? DecorationImage(image: FileImage(File(_coverFile!.path)), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: _coverFile == null
                                    ? const Center(
                                        child: Icon(Icons.photo_library_rounded, size: 34, color: _kG2),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // AI logo generator pill
                  GestureDetector(
                    onTap: _openAiLogoSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _kG2.withOpacity(0.92),
                            _kG1.withOpacity(0.92),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _kG2.withOpacity(0.25),
                            blurRadius: 12, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Generate Logo with AI',
                              style: TextStyle(
                                fontFamily: 'Arch',
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  _label('Club Name *'),
                  _textField(
                    controller: _name,
                    hint:        'e.g. Photography Society',
                    maxLength:   120,
                    validator:   (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 18),

                  _label('Tagline'),
                  _textField(
                    controller: _tagline,
                    hint:        'A short hook — e.g. "Capture campus life."',
                    maxLength:   160,
                  ),
                  const SizedBox(height: 18),

                  _label('Description'),
                  _textField(
                    controller: _description,
                    hint:        'Tell people what your club is about.',
                    maxLines:    5,
                  ),
                  const SizedBox(height: 22),

                  _label('Category *'),
                  _buildCategoryPicker(),
                  const SizedBox(height: 22),

                  _buildToggleCard(
                    icon:    Icons.public_rounded,
                    title:   'Public club',
                    body:    'Anyone can find this club in the discover list.',
                    value:   _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                  ),
                  const SizedBox(height: 10),

                  _buildToggleCard(
                    icon:    Icons.shield_rounded,
                    title:   'Require approval to join',
                    body:    'Members go to "pending" until you approve them.',
                    value:   _requiresApproval,
                    onChanged: (v) => setState(() => _requiresApproval = v),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kG2.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kG2.withOpacity(0.18)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_rounded, color: _kG2, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You\'ll become President of the club. You can '
                          'add a cover, logo, mission, and rules from the '
                          'Django admin panel afterwards.',
                          style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 11.5,
                            color: _kInk.withOpacity(0.75),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            width: 38, height: 38,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const Text('NEW CLUB',
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: _kIndigo,
                      letterSpacing: 1.4,
                    )),
                const SizedBox(height: 2),
                const Text('Start a Club',
                    style: TextStyle(
                      fontFamily: 'Alfa',
                      fontSize: 22,
                      color: _kInk,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer (save button) ──────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        12 + MediaQuery.of(context).viewInsets.bottom * 0.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, -3),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _busy ? null : _submit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kIndigo.withOpacity(0.30),
                blurRadius: 12, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Create Club',
                          style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          )),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  Widget _label(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(label,
            style: const TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _kInk,
              letterSpacing: 0.3,
            )),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int  maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        validator:  validator,
        maxLength:  maxLength,
        maxLines:   maxLines,
        style: const TextStyle(
            fontFamily: 'Momo', fontSize: 14, color: _kInk),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kCats.map((c) {
        final value  = c['value']!;
        final label  = c['label']!;
        final active = _category == value;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _category = value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active ? _kG2 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? _kG2 : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Text(label,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: active ? Colors.white : _kInk,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToggleCard({
    required IconData       icon,
    required String         title,
    required String         body,
    required bool           value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? _kIndigo.withOpacity(0.4) : Colors.grey.shade200,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kIndigo.withOpacity(value ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _kIndigo, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _kInk,
                    )),
                const SizedBox(height: 2),
                Text(body,
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: _kIndigo,
            onChanged: onChanged,
          ),
        ]),
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════
// AI LOGO SHEET — Flux-powered club logo generator
// ═════════════════════════════════════════════════════════════

class _AiLogoSheet extends StatefulWidget {
  final ApiService api;
  final String clubName;
  const _AiLogoSheet({required this.api, required this.clubName});

  @override
  State<_AiLogoSheet> createState() => _AiLogoSheetState();
}

class _AiLogoSheetState extends State<_AiLogoSheet> {
  final _promptCtrl = TextEditingController();
  String? _logoUrl;
  Uint8List? _logoBytes;   // cached bytes — preview + save both reuse this
  bool _generating = false;
  bool _saving = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
      backgroundColor: _kG4,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      _err('Describe the logo you want');
      return;
    }
    setState(() {
      _generating = true;
      _logoBytes = null;
      _logoUrl = null;
    });
    try {
      // Step 1 — FLUX generation (slow: 5-30s, server-side)
      final res = await widget.api.generateClubLogo(
        prompt: prompt,
        name: widget.clubName,
      ) as Map<String, dynamic>;
      final url = (res['image_url'] ?? res['logo_url'] ?? res['url']) as String?;
      if (url == null || url.isEmpty) {
        throw Exception('No image URL in response');
      }

      // Step 2 — download bytes ONCE; both preview and save reuse them
      final dl = await http.get(Uri.parse(url));
      if (dl.statusCode < 200 || dl.statusCode >= 300) {
        throw Exception('Download failed (' + dl.statusCode.toString() + ')');
      }

      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _logoBytes = dl.bodyBytes;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _err('Generation failed: ' + e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _useThisLogo() async {
    if (_logoBytes == null) return;
    setState(() => _saving = true);
    try {
      // Bytes already in RAM — just persist to a temp file (near-instant)
      final lower = (_logoUrl ?? '').toLowerCase();
      final ext = lower.contains('.png')  ? 'png'
                : lower.contains('.webp') ? 'webp'
                : 'jpg';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File(Directory.systemTemp.path + '/ai_logo_' + ts.toString() + '.' + ext);
      await file.writeAsBytes(_logoBytes!);
      if (!mounted) return;
      Navigator.pop(context, XFile(file.path));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _err('Could not use this logo: ' + e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Expanded(
                child: Text('AI Logo Generator',
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 22, color: _kInk,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _kSlate),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Text(
                  'Describe the vibe, mascot, or imagery and Flux will '
                  'generate a logo you can drop straight into your club. '
                  'Generation takes 5-30 seconds.',
                  style: TextStyle(
                    fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.grey.shade600, height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _promptCtrl,
                    maxLines: 3,
                    style: const TextStyle(
                        fontFamily: 'Momo', fontSize: 14, color: _kInk),
                    decoration: InputDecoration(
                      hintText: 'e.g. minimalist owl mascot, navy blue and '
                          'gold, modern flat illustration',
                      hintStyle: TextStyle(
                          fontFamily: 'Momo', fontSize: 13,
                          color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_logoBytes != null) ...[
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        _logoBytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: _kSlate, size: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                GestureDetector(
                  onTap: _generating ? null : _generate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kG2, _kG1]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _generating
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                                SizedBox(width: 10),
                                Text('Flux is painting...',
                                    style: TextStyle(
                                      fontFamily: 'Arch', fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    )),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                    _logoBytes == null
                                        ? 'Generate Logo'
                                        : 'Regenerate',
                                    style: const TextStyle(
                                      fontFamily: 'Arch', fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    )),
                              ],
                            ),
                    ),
                  ),
                ),
                if (_logoBytes != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _saving ? null : _useThisLogo,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kIndigo, _kDeep]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Use this logo',
                                      style: TextStyle(
                                        fontFamily: 'Arch', fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
