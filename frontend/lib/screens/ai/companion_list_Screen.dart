// lib/screens/ai/companion_list_screen.dart
//
// Grid of AI companions students can chat with.
// Light gradient page + animated SweepGradient borders to match
// the AI Hub aesthetic. Each persona's own gradient is preserved
// on the avatar block so personalities still feel distinct.

import 'dart:math' as math;
import 'package:tcs_app/widgets/t_text.dart';

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/ai/companion_chat_screen.dart';
import '../../../../services/api_service.dart';

// ── Light palette (matches AI Hub) ───────────────────────────
const _kBg1     = Color(0xFFFAFAFC);
const _kBg2     = Color(0xFFE6E6EE);
const _kBg3     = Color(0xFFF2F2F6);

Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;

Color get _kBorder => AppC.border;

Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
const _kInkSoft = Color(0xFF374151);
Color get _kInk => AppC.text;

// Shared sweep-gradient palette for animated borders
const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

class Companion {
  final String id, name, description, category, avatarEmoji,
      gradientStart, gradientEnd;
  final bool isSeed;

  Companion.fromJson(Map j)
      : id            = j['id'],
        name          = j['name'],
        description   = j['description'],
        category      = j['category'],
        avatarEmoji   = j['avatar_emoji']   ?? '🤖',
        gradientStart = j['gradient_start'] ?? '#6A11CB',
        gradientEnd   = j['gradient_end']   ?? '#2575FC',
        isSeed        = j['is_seed']        ?? false;

  Color get gradStart => _hex(gradientStart);
  Color get gradEnd   => _hex(gradientEnd);

  Map<String, dynamic> toJsonMap() => {
        'id':             id,
        'name':           name,
        'description':    description,
        'category':       category,
        'avatar_emoji':   avatarEmoji,
        'gradient_start': gradientStart,
        'gradient_end':   gradientEnd,
        'is_seed':        isSeed,
      };

  static Color _hex(String s) {
    var h = s.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

// ═════════════════════════════════════════════════════════════

class CompanionListScreen extends StatefulWidget {
  const CompanionListScreen({super.key});
  @override
  State<CompanionListScreen> createState() => _CompanionListScreenState();
}

class _CompanionListScreenState extends State<CompanionListScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<Companion> _companions = [];
  List<String>    _categories = [];
  String?         _selectedCategory;
  bool _loading = true;
  String? _error;

  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final query = _selectedCategory != null
          ? '/ai/companions/?category=$_selectedCategory'
          : '/ai/companions/';
      final data = await _api.get(query);
      if (!mounted) return;
      setState(() {
        _companions = ((data['companions'] ?? []) as List)
            .map((j) => Companion.fromJson(j as Map))
            .toList();
        _categories = ((data['categories'] ?? []) as List).cast<String>();
        _loading    = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops:  [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildIntro(),
              _buildCategoryChips(),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: _kInkSoft, strokeWidth: 2),
                      )
                    : _error != null
                        ? _buildError()
                        : _buildGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _kInk, size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: T(
              'AI Companions',
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
            padding: const EdgeInsets.all(9),
            child: Icon(
              Icons.groups_rounded,
              color: _kInk, size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: T(
        'Pick a persona to chat with. They remember your conversation.',
        style: TextStyle(color: _kSlate, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _chip('All', null),
          ..._categories.map((c) => _chip(_titleCase(c), c)),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = value);
          _load();
        },
        child: selected
            // Selected → filled dark pill with white text
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        _kInk,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              )
            // Unselected → white pill, dark text
            : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(color: _kBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                      color: _kInkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_companions.isEmpty) {
      return Center(
        child: T('No companions yet.',
            style: TextStyle(color: _kSlate, fontSize: 13)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing:  12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemCount: _companions.length,
      itemBuilder: (ctx, i) {
        final c = _companions[i];
        return _CompanionCard(
          companion: c,
          shimmer:   _shimmerCtrl,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CompanionChatScreen(
                  companion: c.toJsonMap(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFFF4F6E), size: 36),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Error',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kSlate),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: T('Retry',
                  style: TextStyle(color: _kInk)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Companion card — gradient border (rotating, shared) +
// persona's own gradient on the avatar block
// ═════════════════════════════════════════════════════════════

class _CompanionCard extends StatelessWidget {
  final Companion         companion;
  final Animation<double> shimmer;
  final VoidCallback      onTap;

  const _CompanionCard({
    required this.companion,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GradientBorderCard(
        animation:   shimmer,
        radius:      20,
        borderWidth: 1.4,
        innerColor:  _kCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Persona's own gradient on the avatar block — keeps
            // each companion visually distinct from the rotating
            // border that surrounds the whole card.
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [companion.gradStart, companion.gradEnd],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18.6)),
              ),
              child: Center(
                child: Text(
                  companion.avatarEmoji,
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companion.name,
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                    style: TextStyle(
                      color:      _kInk,
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    companion.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:    _kSlate,
                      fontSize: 11,
                      height:   1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: companion.gradEnd.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      companion.category.toUpperCase(),
                      style: TextStyle(
                        color:      companion.gradEnd,
                        fontSize:   9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — same as in ai_hub_screen
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double>   animation;
  final Widget              child;
  final double              radius;
  final double              borderWidth;
  final Color?               innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color>         colors;

  _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor,
    this.padding,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          math.max(0.0, radius - borderWidth)),
        color: innerColor ?? _kCard,
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