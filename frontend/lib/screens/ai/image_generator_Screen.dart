// lib/screens/ai/image_generator_screen.dart
//
// TCS Image Generator — free image generation via Pollinations (FLUX).
// Light theme + animated SweepGradient borders to match the AI Hub.
// Image-Gen identity preserved through the orange/red gradient on
// selection states + the Generate button.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/api_service.dart';

// ── Light palette ────────────────────────────────────────────
const _kBg1 = Color(0xFFFAFAFC);
const _kBg2 = Color(0xFFE6E6EE);
const _kBg3 = Color(0xFFF2F2F6);

const _kCard = Color(0xFFFFFFFF);
const _kCardLo = Color(0xFFF5F5F8);

const _kBorder = Color(0xFFE5E7EB);

const _kSlate2 = Color(0xFF9CA3AF);
const _kSlate = Color(0xFF6B7280);
const _kInkSoft = Color(0xFF374151);
const _kInk = Color(0xFF0D0D1A);

// Image-Gen identity (orange → red) for filled buttons & selected chips
const _kImg1 = Color(0xFFFF5858);
const _kImg2 = Color(0xFFF09819);

// Shared sweep-gradient palette for animated borders
const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

// ── Models ─────────────────────────────────────────────────

class GeneratedImage {
  final String id, prompt, model, imageUrl;
  final int width, height, seed;
  final DateTime createdAt;

  GeneratedImage.fromJson(Map j)
    : id = j['id'],
      prompt = j['prompt'],
      model = j['model'],
      imageUrl = j['image_url'],
      width = j['width'],
      height = j['height'],
      seed = j['seed'],
      createdAt = DateTime.parse(j['created_at']);
}

const _modelOptions = [
  ('flux', 'FLUX', '🎨'),
  ('turbo', 'Turbo', '⚡'),
  ('flux-realism', 'Realism', '📷'),
  ('flux-anime', 'Anime', '🌸'),
];

const _aspectOptions = [
  ('square', '1:1', Icons.crop_square_rounded),
  ('portrait', '9:16', Icons.crop_portrait_rounded),
  ('landscape', '16:9', Icons.crop_landscape_rounded),
  ('tall', '4:5', Icons.crop_7_5_rounded),
];

const _suggestionPrompts = [
  '🌌 a glowing cosmic library, oil painting',
  '🐉 cyberpunk dragon coiled around a Tokyo skyscraper',
  '🌊 a giant whale flying through clouds, watercolor',
  '🎓 cute corgi wearing graduation cap, 3D render',
  '🍜 ramen bowl on a rainy Kyoto street, cinematic',
  '🚀 retro 1960s rocket ship launch poster',
];

const Map<String, (int, int)> ALLOWED_DIMENSIONS_CLIENT = {
  'square': (1024, 1024),
  'portrait': (768, 1344),
  'landscape': (1344, 768),
  'tall': (832, 1216),
};

// ═════════════════════════════════════════════════════════════

class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});
  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _api = ApiService();
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _model = 'flux';
  String _aspect = 'square';

  bool _isGenerating = false;
  GeneratedImage? _current;
  List<GeneratedImage> _history = [];
  String? _error;

  late final AnimationController _shimmerCtrl;
  late final AnimationController _loadingCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _loadingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _promptCtrl.addListener(() => setState(() {}));
    _loadHistory();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _loadingCtrl.dispose();
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _api.get('/ai/images/?limit=30');
      if (!mounted) return;
      setState(() {
        _history = ((data['images'] ?? []) as List)
            .map((j) => GeneratedImage.fromJson(j as Map))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty || _isGenerating) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isGenerating = true;
      _current = null;
      _error = null;
    });

    try {
      final data = await _api.post(
        '/ai/image/',
        body: {'prompt': prompt, 'model': _model, 'aspect': _aspect},
      );
      if (!mounted) return;

      final gen = GeneratedImage.fromJson(data as Map);
      setState(() {
        _current = gen;
        _isGenerating = false;
        _history = [gen, ..._history];
      });

      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _error = e.toString();
      });
    }
  }

  void _useSuggestion(String suggestion) {
    final clean = suggestion.replaceFirst(RegExp(r'^[^\s]+\s'), '');
    setState(() => _promptCtrl.text = clean);
  }

  Future<void> _deleteImage(GeneratedImage g) async {
    HapticFeedback.lightImpact();
    setState(() => _history.removeWhere((h) => h.id == g.id));
    try {
      await _api.delete('/ai/images/${g.id}/');
    } catch (_) {
      if (mounted) _loadHistory();
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  children: [
                    _buildPromptCard(),
                    const SizedBox(height: 16),
                    _buildLabel('Style'),
                    const SizedBox(height: 8),
                    _buildModelChips(),
                    const SizedBox(height: 16),
                    _buildLabel('Aspect ratio'),
                    const SizedBox(height: 8),
                    _buildAspectChips(),
                    const SizedBox(height: 18),
                    _buildGenerateButton(),
                    const SizedBox(height: 22),
                    if (_isGenerating) _buildLoadingFrame(),
                    if (_current != null) _buildCurrentImage(),
                    if (_error != null) _buildErrorBanner(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drawer (image history) ────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _kBg1,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kImg2, _kImg1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Your images',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 20,
                        color: _kInk,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _kInkSoft,
                      size: 20,
                    ),
                    tooltip: 'Refresh',
                    onPressed: _loadHistory,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "No images yet.\nGenerate one and it'll show up here.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 13,
                            color: _kSlate2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: _buildHistorySection(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: _GradientBorderCard(
                animation: _shimmerCtrl,
                radius: 14,
                borderWidth: 1.2,
                innerColor: _kCard,
                padding: const EdgeInsets.all(11),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _kInk,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          // Menu → opens the image-history drawer
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openDrawer();
            },
            child: _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 14,
              borderWidth: 1.2,
              innerColor: _kCard,
              padding: const EdgeInsets.all(11),
              child: const Icon(Icons.menu_rounded, color: _kInk, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Image Generator',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _kInk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          _GradientBorderCard(
            animation: _shimmerCtrl,
            radius: 12,
            borderWidth: 1.2,
            innerColor: _kCard,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: _kInkSoft, size: 12),
                SizedBox(width: 4),
                Text(
                  'FLUX',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _kSlate,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Prompt card ───────────────────────────────────────────

  Widget _buildPromptCard() {
    return _GradientBorderCard(
      animation: _shimmerCtrl,
      radius: 18,
      borderWidth: 1.4,
      innerColor: _kCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _promptCtrl,
            minLines: 3,
            maxLines: 6,
            cursorColor: _kImg1,
            style: const TextStyle(color: _kInk, fontSize: 14, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'Describe the image you want…',
              hintStyle: TextStyle(color: _kSlate2),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'TRY ONE',
            style: TextStyle(
              color: _kSlate,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestionPrompts.map((s) {
              return GestureDetector(
                onTap: () => _useSuggestion(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kCardLo,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(color: _kInkSoft, fontSize: 11),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Style chips ───────────────────────────────────────────

  Widget _buildModelChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _modelOptions.map((m) {
          final selected = _model == m.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _model = m.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [_kImg2, _kImg1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? Colors.transparent : _kBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.$3, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      m.$2,
                      style: TextStyle(
                        color: selected ? Colors.white : _kInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Aspect ratio chips ────────────────────────────────────

  Widget _buildAspectChips() {
    return Row(
      children: _aspectOptions.map((a) {
        final selected = _aspect == a.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _aspect = a.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 56,
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [_kImg2, _kImg1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? Colors.transparent : _kBorder,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      a.$3,
                      color: selected ? Colors.white : _kInk,
                      size: 18,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.$2,
                      style: TextStyle(
                        color: selected ? Colors.white : _kInk,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Generate button ───────────────────────────────────────

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _isGenerating ? null : _generate,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: _isGenerating
              ? null
              : const LinearGradient(
                  colors: [_kImg2, _kImg1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isGenerating ? _kCardLo : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isGenerating ? _kBorder : Colors.transparent,
          ),
          boxShadow: _isGenerating
              ? null
              : [
                  BoxShadow(
                    color: _kImg1.withOpacity(0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isGenerating
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kInkSoft,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Generating…',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'Generate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Loading frame ─────────────────────────────────────────

  Widget _buildLoadingFrame() {
    final dim = ALLOWED_DIMENSIONS_CLIENT[_aspect]!;
    final aspectRatio = dim.$1 / dim.$2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 18,
        borderWidth: 1.4,
        innerColor: _kCardLo,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Light shimmer band sliding across
              ClipRRect(
                borderRadius: BorderRadius.circular(16.6),
                child: AnimatedBuilder(
                  animation: _loadingCtrl,
                  builder: (_, __) {
                    return ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: const [_kCardLo, Color(0xFFE8E8EE), _kCardLo],
                        stops: [
                          (_loadingCtrl.value - 0.3).clamp(0.0, 1.0),
                          _loadingCtrl.value,
                          (_loadingCtrl.value + 0.3).clamp(0.0, 1.0),
                        ],
                      ).createShader(rect),
                      child: Container(color: _kCardLo),
                    );
                  },
                ),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _kImg1, size: 30),
                    SizedBox(height: 8),
                    Text(
                      'FLUX is painting…',
                      style: TextStyle(
                        color: _kInkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '5–30 seconds',
                      style: TextStyle(color: _kSlate, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Current image card ────────────────────────────────────

  Widget _buildCurrentImage() {
    final g = _current!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 18,
        borderWidth: 1.4,
        innerColor: _kCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16.6),
              ),
              child: GestureDetector(
                onTap: () => _showFullScreen(g),
                child: Image.network(
                  g.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, prog) {
                    if (prog == null) return child;
                    return AspectRatio(
                      aspectRatio: g.width / g.height,
                      child: const Center(
                        child: CircularProgressIndicator(color: _kImg1),
                      ),
                    );
                  },
                  errorBuilder: (ctx, _, __) => Container(
                    height: 200,
                    alignment: Alignment.center,
                    color: _kCardLo,
                    child: const Text(
                      'Failed to load image',
                      style: TextStyle(color: _kSlate),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.prompt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _smallBadge(g.model.toUpperCase()),
                      const SizedBox(width: 6),
                      _smallBadge('${g.width}×${g.height}'),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: _kImg1,
                          size: 22,
                        ),
                        tooltip: 'Generate variation',
                        onPressed: () {
                          _promptCtrl.text = g.prompt;
                          _generate();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _kCardLo,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBorder),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: _kInkSoft,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kImg1.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kImg1.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kImg1, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? 'Error',
              style: const TextStyle(color: _kInk, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            'RECENT',
            style: TextStyle(
              color: _kSlate,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: _history.length,
          itemBuilder: (ctx, i) {
            final g = _history[i];
            return GestureDetector(
              onTap: () => _showFullScreen(g),
              onLongPress: () => _confirmDelete(g),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  g.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: _kCardLo),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _confirmDelete(GeneratedImage g) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete this image?',
          style: TextStyle(color: _kInk, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Removes it from your history.',
          style: TextStyle(color: _kSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _kSlate)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteImage(g);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: _kImg1, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(GeneratedImage g) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _FullScreenImage(image: g)),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Full-screen viewer — kept dark for proper image presentation
// ═════════════════════════════════════════════════════════════

class _FullScreenImage extends StatelessWidget {
  final GeneratedImage image;
  const _FullScreenImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy prompt',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: image.prompt));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Prompt copied')));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(image.imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.6),
              child: Text(
                image.prompt,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — same widget pattern as everywhere else
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double radius;
  final double borderWidth;
  final Color innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color> colors;

  const _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor = _kCard,
    this.padding,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          math.max(0.0, radius - borderWidth),
        ),
        color: innerColor,
      ),
      padding: padding,
      child: child,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final t = animation.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
              colors: colors,
              startAngle: t,
              endAngle: t + 2 * math.pi,
            ),
          ),
          padding: EdgeInsets.all(borderWidth),
          child: c,
        );
      },
      child: inner,
    );
  }
}
