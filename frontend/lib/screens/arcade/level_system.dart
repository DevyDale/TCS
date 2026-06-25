// lib/screens/arcade/level_system.dart
//
// Generic 10-level progression system that every game uses.
//
// Components:
//   • LevelConfig        — data describing a single level
//   • LevelProgress      — tracks unlocked levels + best scores per game
//   • LevelSelectScreen  — the "pick a level" UI before each game
//   • LevelCompleteScreen — score reveal with animated star rating
//
// Persistence: SharedPreferences. Each (game_slug → progress) blob is
// stored as JSON. If you want cross-device sync later, swap _saveProgress
// to call your backend; the rest stays the same.

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_engine.dart';

// ════════════════════════════════════════════════════════════
// LevelConfig — one level's data
// ════════════════════════════════════════════════════════════

class LevelConfig {
  final int    level;        // 1-10
  final String title;        // "Rookie Run"
  final String subtitle;     // "Get to know the basics"
  final int    targetScore;  // for star rating
  final int?   timeLimit;    // optional secs
  final IconData icon;
  final List<Color> gradient;

  /// Game-specific parameters. Each game knows what keys to look for:
  ///   • Snake:       'gridSize', 'speedMs', 'walls'
  ///   • Quiz Battle: 'questionCount', 'timePerQ', 'category'
  ///   • Spirit Racers: 'speed', 'spawnRate', 'lanes', 'powerups'
  final Map<String, dynamic> params;

  const LevelConfig({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.targetScore,
    required this.icon,
    required this.gradient,
    this.timeLimit,
    this.params = const {},
  });

  /// Star rating from a final score. 1 = completed, 2 = ≥75% target,
  /// 3 = ≥100% target.
  int starsForScore(int score) {
    if (score <= 0) return 0;
    if (score >= targetScore)              return 3;
    if (score >= (targetScore * 0.75))     return 2;
    return 1;
  }
}

// ════════════════════════════════════════════════════════════
// LevelProgress — per-game tracker
// ════════════════════════════════════════════════════════════

class LevelProgress {
  final String gameSlug;
  int                 highestUnlocked;   // 1-10; level 1 is always unlocked
  final Map<int, int> bestScores;        // level -> best
  final Map<int, int> stars;             // level -> 0-3

  LevelProgress({
    required this.gameSlug,
    this.highestUnlocked = 1,
    Map<int, int>? bestScores,
    Map<int, int>? stars,
  })  : bestScores = bestScores ?? {},
        stars      = stars      ?? {};

  bool isUnlocked(int level)   => level <= highestUnlocked;
  int  starsAt(int level)      => stars[level] ?? 0;
  int  bestAt(int level)       => bestScores[level] ?? 0;
  int  totalStars()            => stars.values.fold(0, (a, b) => a + b);

  /// Record a play. Returns true if anything changed (best score / stars
  /// improved, OR a new level got unlocked).
  bool recordRun({required int level, required int score, required int starsEarned}) {
    var changed = false;

    if (score > bestAt(level)) {
      bestScores[level] = score;
      changed = true;
    }
    if (starsEarned > starsAt(level)) {
      stars[level] = starsEarned;
      changed = true;
    }
    // Unlock next level once you complete this one with at least 1 star
    if (starsEarned >= 1 && level >= highestUnlocked && level < 10) {
      highestUnlocked = level + 1;
      changed = true;
    }
    return changed;
  }

  Map<String, dynamic> toJson() => {
    'highestUnlocked': highestUnlocked,
    'bestScores': bestScores.map((k, v) => MapEntry(k.toString(), v)),
    'stars':      stars.map((k, v) => MapEntry(k.toString(), v)),
  };

  static LevelProgress fromJson(String slug, Map<String, dynamic> j) {
    final bs = (j['bestScores'] as Map?) ?? {};
    final st = (j['stars']      as Map?) ?? {};
    return LevelProgress(
      gameSlug: slug,
      highestUnlocked: (j['highestUnlocked'] as int?) ?? 1,
      bestScores: bs.map((k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v as int)),
      stars:      st.map((k, v) => MapEntry(int.tryParse(k.toString()) ?? 0, v as int)),
    );
  }
}

// ════════════════════════════════════════════════════════════
// LevelStore — persistence
// ════════════════════════════════════════════════════════════

class LevelStore {
  static String _key(String slug) => 'level_progress_$slug';

  static Future<LevelProgress> load(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(slug));
    if (raw == null) return LevelProgress(gameSlug: slug);
    try {
      return LevelProgress.fromJson(slug, jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return LevelProgress(gameSlug: slug);
    }
  }

  static Future<void> save(LevelProgress p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(p.gameSlug), jsonEncode(p.toJson()));
  }
}

// ════════════════════════════════════════════════════════════
// LevelSelectScreen — pick a level UI
// ════════════════════════════════════════════════════════════
//
// USAGE:
//   final picked = await Navigator.push<int>(context, MaterialPageRoute(
//     builder: (_) => LevelSelectScreen(
//       gameSlug: 'snake',
//       gameName: 'Snake',
//       gameEmoji: '🐍',
//       gradient: [kNeonBlue, kNeonPurple],
//       levels: kSnakeLevels,
//     ),
//   ));
//   if (picked != null) {
//     // start game at that level
//   }

class LevelSelectScreen extends StatefulWidget {
  final String gameSlug;
  final String gameName;
  final String gameEmoji;
  final List<Color> gradient;
  final List<LevelConfig> levels;

  const LevelSelectScreen({
    super.key,
    required this.gameSlug,
    required this.gameName,
    required this.gameEmoji,
    required this.gradient,
    required this.levels,
  });

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  LevelProgress? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LevelStore.load(widget.gameSlug);
    if (!mounted) return;
    setState(() => _progress = p);
  }

  void _pick(int level) {
    if (_progress == null || !_progress!.isUnlocked(level)) return;
    HapticFeedback.heavyImpact();
    Navigator.pop(context, level);
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: p == null
          ? const Center(child: CircularProgressIndicator(color: kNeonPurple))
          : Column(children: [
              _buildHeader(p),
              Expanded(child: _buildLevelGrid(p)),
            ])),
    );
  }

  Widget _buildHeader(LevelProgress p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: kDarkCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white60, size: 20),
            ),
          ),
          const Spacer(),
          // Total stars indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kNeonOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kNeonOrange.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const T('⭐', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text('${p.totalStars()} / 30',
                  style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 14, color: kNeonOrange)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(widget.gameEmoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: widget.gradient).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(widget.gameName,
                  style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 26, color: Colors.white)),
            ),
            const SizedBox(height: 2),
            T('Choose your challenge',
                style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5))),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildLevelGrid(LevelProgress p) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: widget.levels.length,
      itemBuilder: (_, i) {
        final lvl     = widget.levels[i];
        final unlocked = p.isUnlocked(lvl.level);
        final stars   = p.starsAt(lvl.level);
        final best    = p.bestAt(lvl.level);
        return _LevelTile(
          config:    lvl,
          unlocked:  unlocked,
          stars:     stars,
          bestScore: best,
          onTap:     () => _pick(lvl.level),
        );
      },
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelConfig config;
  final bool        unlocked;
  final int         stars;
  final int         bestScore;
  final VoidCallback onTap;

  const _LevelTile({
    required this.config,
    required this.unlocked,
    required this.stars,
    required this.bestScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: unlocked ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kDarkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unlocked
                  ? config.gradient.first.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Row(children: [
            // Number badge / lock
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: unlocked ? LinearGradient(colors: config.gradient) : null,
                color: unlocked ? null : kDarkCard2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: unlocked
                    ? Text('${config.level}',
                        style: const TextStyle(
                            fontFamily: 'Alfa', fontSize: 22, color: Colors.white))
                    : const Icon(Icons.lock_rounded,
                        color: Colors.white38, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            // Title + subtitle + stars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(config.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(config.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.45))),
                  const SizedBox(height: 6),
                  // Stars row
                  Row(children: [
                    for (int i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: i < stars
                              ? const Color(0xFFFFD700)
                              : Colors.white.withOpacity(0.10),
                        ),
                      ),
                    if (bestScore > 0) ...[
                      const SizedBox(width: 8),
                      Text('Best: $bestScore',
                          style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.4))),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              unlocked ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
              color: unlocked ? Colors.white60 : Colors.white24,
              size: 22,
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// LevelCompleteScreen — animated star reveal post-game
// ════════════════════════════════════════════════════════════
//
// USAGE: push this AFTER the game ends, instead of GameOverScreen,
// when playing in level mode. It records progress and shows stars.
//
//   Navigator.pushReplacement(context, MaterialPageRoute(
//     builder: (_) => LevelCompleteScreen(
//       gameSlug: 'snake',
//       gameName: 'Snake',
//       config:   kSnakeLevels[level - 1],
//       score:    finalScore,
//       outcome:  'win',
//     ),
//   ));

class LevelCompleteScreen extends StatefulWidget {
  final String gameSlug, gameName, outcome;
  final LevelConfig config;
  final int score;

  const LevelCompleteScreen({
    super.key,
    required this.gameSlug,
    required this.gameName,
    required this.config,
    required this.score,
    this.outcome = 'win',
  });

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen>
    with TickerProviderStateMixin {
  late final AnimationController _starsCtrl;
  int   _earnedStars  = 0;
  int   _shownStars   = 0;
  bool  _newRecord    = false;
  int   _previousBest = 0;
  Timer? _starTimer;

  @override
  void initState() {
    super.initState();
    _starsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _earnedStars = widget.config.starsForScore(widget.score);
    _record();
  }

  Future<void> _record() async {
    final p = await LevelStore.load(widget.gameSlug);
    _previousBest = p.bestAt(widget.config.level);
    final changed = p.recordRun(
      level: widget.config.level,
      score: widget.score,
      starsEarned: _earnedStars,
    );
    if (changed) {
      _newRecord = widget.score > _previousBest;
      await LevelStore.save(p);
    }
    if (!mounted) return;
    // Reveal stars one at a time
    int idx = 0;
    _starTimer = Timer.periodic(const Duration(milliseconds: 450), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx >= _earnedStars) { t.cancel(); return; }
      idx += 1;
      HapticFeedback.heavyImpact();
      setState(() => _shownStars = idx);
      _starsCtrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _starTimer?.cancel();
    _starsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Spacer(),
          ShaderMask(
            shaderCallback: (b) =>
                LinearGradient(colors: cfg.gradient).createShader(b),
            blendMode: BlendMode.srcIn,
            child: Text('LEVEL ${cfg.level}',
                style: const TextStyle(
                    fontFamily: 'Alfa', fontSize: 18,
                    color: Colors.white, letterSpacing: 4)),
          ),
          const SizedBox(height: 6),
          Text(cfg.title,
              style: const TextStyle(
                  fontFamily: 'Alfa', fontSize: 28, color: Colors.white)),
          const SizedBox(height: 24),
          // Stars row
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
            final filled = i < _shownStars;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedBuilder(
                animation: _starsCtrl,
                builder: (_, __) {
                  // The most-recently-revealed star pops with elastic scale.
                  final isLatest = i == _shownStars - 1;
                  final scale = isLatest
                      ? 1.0 + (_starsCtrl.value * 0.5)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.star_rounded,
                      size: 56,
                      color: filled
                          ? const Color(0xFFFFD700)
                          : Colors.white.withOpacity(0.08),
                    ),
                  );
                },
              ),
            );
          })),
          const SizedBox(height: 28),
          // Score card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kDarkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cfg.gradient.first.withOpacity(0.3)),
            ),
            child: Column(children: [
              Text(_earnedStars >= 1 ? 'YOUR SCORE' : 'GAME OVER',
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('${widget.score}',
                  style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 44, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Target: ${cfg.targetScore}',
                  style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.45))),
              if (_newRecord) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kNeonOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kNeonOrange.withOpacity(0.3)),
                  ),
                  child: const T('🏆 NEW RECORD!',
                      style: TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: kNeonOrange)),
                ),
              ],
            ]),
          ),
          const Spacer(),
          // Action buttons
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: kDarkCard2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Center(
                    child: T('← Levels',
                        style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white60)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context, 'replay');
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: cfg.gradient),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _earnedStars >= 1 && cfg.level < 10
                          ? 'Next ▶'
                          : 'Retry ▶',
                      style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ))),
    );
  }
}
