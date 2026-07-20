import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class InterestsPage extends StatefulWidget {
  /// Interests the user has already saved — pre-selected so they can be
  /// reviewed, removed, or added to (rather than starting from scratch).
  final List<String> initial;
  const InterestsPage({super.key, this.initial = const []});

  @override
  State<InterestsPage> createState() => _InterestsPageState();
}

class _InterestsPageState extends State<InterestsPage>
    with TickerProviderStateMixin {
  static const _min = 5;
  static const _max = 8;

  final Set<String> _selected = {};

  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  final Map<String, _CategoryMeta> _categoryMeta = {
    'Academic & Learning': _CategoryMeta(
      icon: Icons.school_rounded,
      gradient: [_kG2, Color(0xFF6B2FD9)],
    ),
    'Creative & Digital': _CategoryMeta(
      icon: Icons.palette_rounded,
      gradient: [_kG1, Color(0xFF0288D1)],
    ),
    'Sports & Fitness': _CategoryMeta(
      icon: Icons.sports_soccer_rounded,
      gradient: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
    ),
    'Gaming & Chill': _CategoryMeta(
      icon: Icons.sports_esports_rounded,
      gradient: [_kG4, Color(0xFFB71C1C)],
    ),
    'Lifestyle & Growth': _CategoryMeta(
      icon: Icons.self_improvement_rounded,
      gradient: [_kG3, Color(0xFFE65100)],
    ),
  };

  final Map<String, List<String>> _categories = {
    'Academic & Learning': [
      'Mathematics', 'Physics', 'Chemistry', 'Biology',
      'Computer Science', 'Programming', 'Engineering',
      'Business Studies', 'Economics', 'Psychology',
      'History', 'Literature', 'Research', 'Public Speaking',
    ],
    'Creative & Digital': [
      'Web Development', 'App Development', 'Graphic Design',
      'UI/UX Design', 'Video Editing', 'Digital Art',
      'Photography', 'Filmmaking', 'Content Creation',
      'Music', 'Drawing', 'Writing', 'Game Development',
    ],
    'Sports & Fitness': [
      'Football', 'Basketball', 'Gym & Fitness', 'Running',
      'Swimming', 'Yoga', 'Martial Arts', 'Badminton', 'Tennis',
    ],
    'Gaming & Chill': [
      'Esports', 'Chess', 'Video Games', 'Board Games',
      'Anime', 'Manga', 'Movies', 'TV Series', 'Podcasts',
    ],
    'Lifestyle & Growth': [
      'Traveling', 'Cooking', 'Personal Development',
      'Mental Health', 'Productivity', 'Entrepreneurship',
      'Volunteering', 'Leadership', 'Career Planning',
    ],
  };

  @override
  void initState() {
    super.initState();
    // Pre-select the user's already-saved interests (respecting the max cap).
    _selected.addAll(widget.initial.take(_max));
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _selected.length >= _min && _selected.length <= _max;

  void _toggle(String interest) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(interest)) {
        _selected.remove(interest);
      } else if (_selected.length < _max) {
        _selected.add(interest);
      } else {
        // Already at max — shake or snack
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can select up to $_max interests',
              style: const TextStyle(fontFamily: 'Momo'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _kG4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _save() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;

    return Scaffold(
      backgroundColor: AppC.bg,
      body: Stack(
        children: [
          // ── Top gradient strip ──────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kG2, _kG1],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -40,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: 0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildHeader(count),
                  ),
                ),

                // ── Body ──────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      final key = _categories.keys.elementAt(i);
                      final meta = _categoryMeta[key]!;
                      return _CategorySection(
                        title: key,
                        meta: meta,
                        items: _categories[key]!,
                        selected: _selected,
                        onTap: _toggle,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Floating bottom bar ────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(count),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppC.card,
                      size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: T(
                  'Your Interests',
                  style: TextStyle(
                    fontFamily: 'Alfa',
                    fontSize: 22,
                    color: AppC.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tagline
          Text(
            '✨ Pick $_min–$_max topics that define you',
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 13,
              color: AppC.text.withOpacity(0.8),
            ),
          ),

          const SizedBox(height: 14),

          // Progress pill
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppC.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _kG2.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Counter circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _canSave
                        ? const LinearGradient(
                            colors: [_kG1, _kG2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(colors: [
                            AppC.border,
                            AppC.faint,
                          ]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 22,
                        color: AppC.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _canSave
                            ? 'Perfect selection! 🎉'
                            : count < _min
                                ? 'Select at least $_min interests'
                                : 'Maximum $_max reached',
                        style: TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _canSave
                              ? AppC.text
                              : AppC.sub,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: count / _max,
                          minHeight: 6,
                          backgroundColor: AppC.border,
                          valueColor: AlwaysStoppedAnimation(
                            _canSave ? _kG2 : _kG3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────

  Widget _buildBottomBar(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: AppC.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected chips preview
            if (_selected.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _selected
                      .map((s) => Container(
                            margin:
                                const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kG1, _kG2]),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s,
                                    style: TextStyle(
                                      fontFamily: 'Momo',
                                      fontSize: 12,
                                      color: AppC.text,
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _toggle(s),
                                  child: Icon(
                                      Icons.close_rounded,
                                      color: AppC.card,
                                      size: 14),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (_selected.isNotEmpty) const SizedBox(height: 10),

            // Save button
            GestureDetector(
              onTap: _canSave ? _save : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: _canSave
                      ? const LinearGradient(
                          colors: [_kG1, _kG2, _kG3, _kG4],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : const LinearGradient(colors: [
                          Color(0xFFE0E0E0),
                          Color(0xFFD0D0D0),
                        ]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _canSave
                      ? [
                          BoxShadow(
                            color: _kG2.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _canSave
                        ? 'Save Interests ($count/$_max)'
                        : count < _min
                            ? 'Select ${_min - count} more'
                            : 'Max reached',
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      color: AppC.text,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category section ──────────────────────────────────────────

class _CategoryMeta {
  final IconData icon;
  final List<Color> gradient;

  const _CategoryMeta({required this.icon, required this.gradient});
}

class _CategorySection extends StatefulWidget {
  final String title;
  final _CategoryMeta meta;
  final List<String> items;
  final Set<String> selected;
  final void Function(String) onTap;

  const _CategorySection({
    required this.title,
    required this.meta,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final selectedInCat =
        widget.items.where((i) => widget.selected.contains(i)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category header
          GestureDetector(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.meta.gradient
                      .map((c) => c.withOpacity(0.08))
                      .toList(),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(20),
                  bottom: _expanded
                      ? Radius.zero
                      : const Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: widget.meta.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.meta.icon,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 15,
                        color: widget.meta.gradient.first,
                      ),
                    ),
                  ),
                  if (selectedInCat > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: widget.meta.gradient),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$selectedInCat',
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppC.text,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: widget.meta.gradient.first
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chips
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.items.map((item) {
                  final sel = widget.selected.contains(item);
                  final g = widget.meta.gradient;
                  return GestureDetector(
                    onTap: () => widget.onTap(item),
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: sel
                            ? LinearGradient(
                                colors: g,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: sel
                            ? null
                            : AppC.bg,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? Colors.transparent
                              : AppC.border,
                          width: 1.5,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: g.first
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset:
                                      const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 13,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: sel
                              ? Colors.white
                              : AppC.sub,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}