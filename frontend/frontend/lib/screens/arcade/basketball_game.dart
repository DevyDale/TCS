// lib/screens/arcade/game_engine.dart
// Shared game utilities — stories, pause, quit, multiplayer, score, leaderboard
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

// ─── Colours ──────────────────────────────────────────────────
const kTokenColor  = Color(0xFFF7971E);
const kXpColor     = Color(0xFF6DD5FA);
const kDarkBg      = Color(0xFF0D0D1A);
const kDarkCard    = Color(0xFF161628);
const kDarkCard2   = Color(0xFF1E1E38);
const kNeonBlue    = Color(0xFF6DD5FA);
const kNeonPurple  = Color(0xFF8E54E9);
const kNeonOrange  = Color(0xFFF7971E);
const kNeonRed     = Color(0xFFFF5858);

// ─── Track which game stories have been shown this session ─────
final _seenStories = <String>{};

// ─── Game stories ─────────────────────────────────────────────
class GameStory {
  final String slug, title, emoji, narrative;
  final List<String> tips;
  final LinearGradient gradient;
  const GameStory({
    required this.slug, required this.title,
    required this.emoji, required this.narrative,
    required this.tips, required this.gradient,
  });
}

const _kStories = {
  'spirit-racers': GameStory(
    slug:'spirit-racers', title:'Spirit Racers',
    emoji:'🏎️',
    narrative:'The annual Spirit Cup is here — TCS students race ghost cars '
      'powered by school spirit. You\'ve tuned your neon racer all semester. '
      'Hit the track, dodge rivals, collect fuel coins and prove you\'re the '
      'fastest spirit on campus.',
    tips:['Swipe L/R to switch lanes','Collect 🪙 coins for bonus points',
      'Speed increases as your score grows','Crash = race over'],
    gradient:LinearGradient(colors:[Color(0xFF6DD5FA),Color(0xFFF7971E)]),
  ),
  'ninja-tag': GameStory(
    slug:'ninja-tag', title:'Ninja Tag',
    emoji:'🥷',
    narrative:'A shadow clan has infiltrated the campus at night. As the '
      'student council\'s chosen ninja, slip through the grid, collect the '
      'sacred stars before sunrise, and evade the shadow phantoms hunting you.',
    tips:['D-pad to move','Collect all ⭐ to win','Walls block both you and enemies',
      'Timer runs out = game over'],
    gradient:LinearGradient(colors:[Color(0xFFFF5858),Color(0xFF8E54E9)]),
  ),
  'sushi-rush': GameStory(
    slug:'sushi-rush', title:'Sushi Rush',
    emoji:'🍣',
    narrative:'The campus sushi bar is overwhelmed — orders flying in from '
      'every faculty. As head chef, memorise each order flashing on the board '
      'and plate them correctly before the hungry professors riot.',
    tips:['Watch the order flash','Tap sushi in the EXACT same sequence',
      'Faster = time bonus points','Wrong tap = lose a life'],
    gradient:LinearGradient(colors:[Color(0xFFF7971E),Color(0xFFFF5858)]),
  ),
  'battle-bots': GameStory(
    slug:'battle-bots', title:'Battle Bots',
    emoji:'🤖',
    narrative:'The robotics club challenge is live. Two teams of battle bots '
      'face off on the engineering grid. You command the blue squad — each bot '
      'has unique HP, attack and range. Destroy all enemy units to claim the '
      'Engineering Cup.',
    tips:['Select your bot → tap to move or attack','Attack costs your turn',
      'Different bots have different attack ranges','End Turn when done'],
    gradient:LinearGradient(colors:[Color(0xFF6DD5FA),Color(0xFF8E54E9)]),
  ),
  'campus-craft': GameStory(
    slug:'campus-craft', title:'Campus Craft',
    emoji:'🏗️',
    narrative:'A freak storm scrambled the campus blueprint tiles overnight. '
      'The principal needs the map restored before parents arrive for open day. '
      'Slide the building tiles back into their correct positions!',
    tips:['Tap a tile next to the blank space to slide it',
      'Goal: tiles in order 1→N with blank at bottom-right',
      'Fewer moves = bigger bonus','Timer counts up — be fast!'],
    gradient:LinearGradient(colors:[Color(0xFFF7971E),Color(0xFF6DD5FA)]),
  ),
  'pool-royale': GameStory(
    slug:'pool-royale', title:'Pool Royale',
    emoji:'🎱',
    narrative:'The TCS recreational hall hosts the Midnight Pool Tournament. '
      'Your cue is chalk-tipped, the table is lit neon-green, and a semester\'s '
      'worth of bragging rights is on the line. Pocket every ball before your '
      'opponent does.',
    tips:['Drag FROM the white ball to aim','Release to shoot',
      'Power = drag distance','Cue ball pocketed = -30 pts penalty'],
    gradient:LinearGradient(colors:[Color(0xFF8E54E9),Color(0xFF6DD5FA)]),
  ),
  'quiz-battle': GameStory(
    slug:'quiz-battle', title:'Quiz Battle',
    emoji:'🧠',
    narrative:'The Academic League is live — students compete in rapid-fire '
      'trivia across science, history, pop culture and more. One wrong answer '
      'and your streak breaks. Outlast everyone to become the Quiz Champion.',
    tips:['4 choices per question','Speed bonus for fast answers',
      'Streak multiplier × consecutive correct','No time limit per question'],
    gradient:LinearGradient(colors:[Color(0xFF8E54E9),Color(0xFF6DD5FA)]),
  ),
  'tic-tac-toe': GameStory(
    slug:'tic-tac-toe', title:'Tic Tac Toe',
    emoji:'⭕',
    narrative:'The oldest rivalry on campus — X vs O. Challenge the AI or '
      'a fellow student to the classic battle of wits. Three in a row wins '
      'the match. Simple? The AI thinks three moves ahead.',
    tips:['First to 3-in-a-row wins','AI gets harder each level',
      'Draw = no points','Win streaks = token bonus'],
    gradient:LinearGradient(colors:[Color(0xFF6DD5FA),Color(0xFF8E54E9)]),
  ),
  'memory-match': GameStory(
    slug:'memory-match', title:'Memory Match',
    emoji:'🃏',
    narrative:'The psychology lab is running a memory experiment on students. '
      'Flip cards and match the pairs hidden beneath. The faster you match, '
      'the higher your memory score.',
    tips:['Flip 2 cards per turn','Match = cards stay revealed',
      'All pairs matched = victory','Fewer flips = bigger score'],
    gradient:LinearGradient(colors:[Color(0xFF6DD5FA),Color(0xFFF7971E)]),
  ),
  'snake': GameStory(
    slug:'snake', title:'Snake',
    emoji:'🐍',
    narrative:'Campus legend says a neon serpent haunts the server room, '
      'eating data packets to grow. Control the snake, consume all the power '
      'nodes before it crashes into itself.',
    tips:['Swipe to change direction','Eat 🍎 to grow and score',
      'Avoid walls and your own tail','Speed increases as you grow'],
    gradient:LinearGradient(colors:[Color(0xFF4CAF50),Color(0xFF6DD5FA)]),
  ),
  'number-guesser': GameStory(
    slug:'number-guesser', title:'Number Guesser',
    emoji:'🔢',
    narrative:'The maths department hid a secret number in their vault. '
      'You have a limited number of guesses and each attempt reveals whether '
      'the secret is higher or lower. Crack the code!',
    tips:['Higher/Lower hints after each guess',
      'Fewer guesses = more points','Range gets wider each level'],
    gradient:LinearGradient(colors:[Color(0xFFF7971E),Color(0xFFFF5858)]),
  ),
  'basketball': GameStory(
    slug:'basketball', title:'Stickman Hoops',
    emoji:'🏀',
    narrative:'The TCS gym echoes with sneaker squeaks. As the stickman '
      'shooter, launch the ball in a perfect arc through the hoop. The crowd '
      'goes wild for every nothing-but-net swish.',
    tips:['Hold & drag to set angle and power','Release to shoot',
      'Arc it — flat shots bounce off','Score 10 baskets per level'],
    gradient:LinearGradient(colors:[Color(0xFFFF9800),Color(0xFFE53935)]),
  ),
  'texas-poker': GameStory(
    slug:'texas-poker', title:"Texas Hold'em",
    emoji:'🃏',
    narrative:'The campus poker night is legendary. Chips stack high as '
      'students bluff, raise and fold. Survive three rounds of Texas Hold\'em '
      'against increasingly cunning AI opponents and walk away with the pot.',
    tips:["Fold/Call/Raise each betting round",
      "Best 5-card hand from 7 cards wins",
      "Bluff strategically — AI adapts","Go all-in to double up"],
    gradient:LinearGradient(colors:[Color(0xFF388E3C),Color(0xFF1B5E20)]),
  ),
};

// ─── Game story screen ────────────────────────────────────────
class GameStoryScreen extends StatefulWidget {
  final String gameSlug;
  final VoidCallback onPlay;
  const GameStoryScreen({super.key, required this.gameSlug, required this.onPlay});
  @override
  State<GameStoryScreen> createState() => _GameStoryScreenState();
}

class _GameStoryScreenState extends State<GameStoryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  int _tipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    final story = _kStories[widget.gameSlug];
    if (story != null && story.tips.isNotEmpty) {
      _tipTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) setState(() => _tipIndex = (_tipIndex + 1) % story.tips.length);
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); _tipTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final story = _kStories[widget.gameSlug];
    if (story == null) { widget.onPlay(); return const SizedBox.shrink(); }

    return Scaffold(
      backgroundColor: kDarkBg,
      body: FadeTransition(opacity: _fade, child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            // Close
            Align(alignment: Alignment.centerRight,
              child: GestureDetector(onTap: () { _seenStories.add(widget.gameSlug); widget.onPlay(); },
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: kDarkCard2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20)))),
            const Spacer(),

            // Emoji
            Text(story.emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 12),

            // Title
            ShaderMask(
              shaderCallback: (b) => story.gradient.createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(story.title, style: const TextStyle(
                  fontFamily: 'Alfa', fontSize: 32, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Container(width: 60, height: 3,
              decoration: BoxDecoration(gradient: story.gradient,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),

            // Story
            Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: kDarkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Text(story.narrative, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Momo', fontSize: 14,
                  color: Colors.white.withOpacity(0.8), height: 1.65))),
            const SizedBox(height: 16),

            // Animated tip
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Container(key: ValueKey(_tipIndex),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: story.gradient.colors.first.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: story.gradient.colors.first.withOpacity(0.25))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('💡 ', style: TextStyle(fontSize: 14)),
                  Flexible(child: Text(story.tips[_tipIndex],
                    style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                      color: story.gradient.colors.first))),
                ])),
            ),

            // Dots
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(story.tips.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _tipIndex ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                  color: i == _tipIndex
                      ? story.gradient.colors.first
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(3))))),

            const Spacer(),

            // Play button
            GestureDetector(
              onTap: () { HapticFeedback.heavyImpact();
                _seenStories.add(widget.gameSlug); widget.onPlay(); },
              child: Container(width: double.infinity, height: 56,
                decoration: BoxDecoration(gradient: story.gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: story.gradient.colors.first.withOpacity(0.4),
                    blurRadius: 20, offset: const Offset(0, 6))]),
                child: const Center(child: Text("Let's Play! ▶",
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 20,
                    color: Colors.white))))),
            const SizedBox(height: 8),
            GestureDetector(onTap: () { _seenStories.add(widget.gameSlug); widget.onPlay(); },
              child: Text('Skip story →', style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: Colors.white.withOpacity(0.3)))),
          ]),
        ),
      )),
    );
  }
}

// ─── Helper: should show story? ────────────────────────────────
bool shouldShowStory(String slug) => !_seenStories.contains(slug);

// ─── Pause overlay ────────────────────────────────────────────
class PauseOverlay extends StatelessWidget {
  final String gameName;
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final bool isMultiplayer;

  const PauseOverlay({super.key,
    required this.gameName, required this.onResume, required this.onQuit,
    this.isMultiplayer = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: kDarkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kNeonBlue.withOpacity(0.2))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⏸', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text('PAUSED', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 28, color: Colors.white, letterSpacing: 4)),
          Text(gameName, style: TextStyle(fontFamily: 'Momo',
            fontSize: 13, color: Colors.white.withOpacity(0.5))),
          if (isMultiplayer)
            Padding(padding: const EdgeInsets.only(top: 12),
              child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kNeonOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kNeonOrange.withOpacity(0.3))),
                child: Text('⚠️ Opponent notified of pause.\nAuto-quit in 5s if not resumed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Momo', fontSize: 12, color: kNeonOrange)))),
          const SizedBox(height: 24),
          // Resume
          GestureDetector(onTap: onResume,
            child: Container(width: double.infinity, height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kNeonBlue, kNeonPurple]),
                borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('▶  Resume', style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 16, color: Colors.white))))),
          const SizedBox(height: 12),
          // Quit
          GestureDetector(onTap: onQuit,
            child: Container(width: double.infinity, height: 50,
              decoration: BoxDecoration(color: kNeonRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kNeonRed.withOpacity(0.3))),
              child: const Center(child: Text('✕  Quit Game', style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 16, color: kNeonRed))))),
        ]),
      )),
    );
  }
}

// ─── Quit confirmation dialog ─────────────────────────────────
Future<bool> showQuitDialog(BuildContext ctx, {bool isMultiplayer = false}) async {
  return await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: kDarkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Quit Game?', style: TextStyle(fontFamily: 'Alfa',
        fontSize: 20, color: Colors.white)),
      content: Text(
        isMultiplayer
          ? '⚠️ Quitting forfeits the match.\nYour opponent wins the wagered tokens.\n\nAre you sure?'
          : 'Your current progress will be lost.\nYour score so far will be submitted.',
        style: TextStyle(fontFamily: 'Momo', fontSize: 13,
          color: Colors.white.withOpacity(0.7), height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep Playing', style: TextStyle(
            fontFamily: 'Arch', fontWeight: FontWeight.bold, color: kNeonBlue))),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Quit', style: TextStyle(
            fontFamily: 'Arch', fontWeight: FontWeight.bold, color: kNeonRed))),
      ],
    ),
  ) ?? false;
}

// ─── In-game HUD bar (reusable) ───────────────────────────────
class GameHUD extends StatelessWidget {
  final String score;
  final String level;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onQuit;
  final Widget? extra; // e.g. lives, timer

  const GameHUD({super.key,
    required this.score, required this.level,
    required this.paused, required this.onPause, required this.onQuit,
    this.extra});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      color: kDarkBg,
      child: Row(children: [
        // Quit
        GestureDetector(onTap: onQuit,
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: kNeonRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kNeonRed.withOpacity(0.3))),
            child: const Icon(Icons.exit_to_app_rounded, color: kNeonRed, size: 16))),
        const SizedBox(width: 8),
        // Level
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: kDarkCard2, borderRadius: BorderRadius.circular(8)),
          child: Text(level, style: const TextStyle(fontFamily: 'Momo',
            fontSize: 11, color: Colors.white60))),
        const Spacer(),
        // Extra (timer, lives, etc)
        if (extra != null) ...[extra!, const SizedBox(width: 8)],
        // Score
        Text(score, style: const TextStyle(fontFamily: 'Alfa',
          fontSize: 18, color: kNeonOrange)),
        const SizedBox(width: 8),
        // Pause
        GestureDetector(onTap: onPause,
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: kDarkCard2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white70, size: 18))),
      ]),
    );
  }
}

// ─── Multiplayer session model ────────────────────────────────
class MultiplayerSession {
  final String sessionId;
  final String opponentTag;
  final int wager;
  final String gameSlug;
  bool opponentPaused = false;
  bool opponentQuit   = false;
  Timer? _pauseAutoQuit;

  MultiplayerSession({
    required this.sessionId, required this.opponentTag,
    required this.wager, required this.gameSlug,
  });

  void dispose() { _pauseAutoQuit?.cancel(); }
}

// ─── Game result model ────────────────────────────────────────
class GameResult {
  final String gameSlug, gameName, outcome;
  final int score, bonusTokens;
  final Map<String, dynamic> extra;
  final MultiplayerSession? session;

  const GameResult({
    required this.gameSlug, required this.gameName,
    required this.score, this.bonusTokens = 0,
    this.outcome = 'complete', this.extra = const {},
    this.session,
  });
}

// ─── Game over screen ─────────────────────────────────────────
class GameOverScreen extends StatefulWidget {
  final GameResult result;
  const GameOverScreen({super.key, required this.result});
  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  Map<String, dynamic>? _reward;
  bool _submitting = true;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _submitScore();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submitScore() async {
    try {
      final res = await _api.submitScore(
          game: widget.result.gameSlug, score: widget.result.score)
          as Map<String, dynamic>;
      if (mounted) setState(() { _reward = res; _submitting = false; });
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color get _color {
    switch (widget.result.outcome) {
      case 'win': return Colors.green.shade400;
      case 'draw': return kNeonOrange;
      case 'lose': return kNeonRed;
      default: return kNeonBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emojis = {'win':'🏆','draw':'🤝','lose':'💀','complete':'✅'};
    final labels = {'win':'VICTORY!','draw':'DRAW!','lose':'GAME OVER','complete':'COMPLETE!'};
    final emoji = emojis[widget.result.outcome] ?? '✅';
    final label = labels[widget.result.outcome] ?? 'DONE';

    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(28),
        child: ScaleTransition(scale: _scale, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: [_color, _color.withOpacity(0.6)]).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text(label, style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 36, color: Colors.white))),
            const SizedBox(height: 6),
            Text(widget.result.gameName, style: TextStyle(fontFamily: 'Momo',
              fontSize: 14, color: Colors.white.withOpacity(0.5))),
            // Multiplayer wager result
            if (widget.result.session != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _color.withOpacity(0.2))),
                child: Text(
                  widget.result.outcome == 'win'
                    ? '🎉 You won ${widget.result.session!.wager * 2} tokens!'
                    : '😔 ${widget.result.session!.wager} tokens lost',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14, color: _color))),
            ],
            const SizedBox(height: 24),
            // Score card
            Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kDarkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _color.withOpacity(0.3), width: 1.5)),
              child: Column(children: [
                Text('SCORE', style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: Colors.white.withOpacity(0.4), letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('${widget.result.score}', style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 48, color: _color)),
                if (_submitting) ...[
                  const SizedBox(height: 12),
                  const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: kNeonBlue, strokeWidth: 2)),
                  const SizedBox(height: 6),
                  Text('Saving...', style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11, color: Colors.white.withOpacity(0.3))),
                ] else if (_reward != null) ...[
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _chip('⚡ ${_reward!['xp_earned'] ?? 0} XP', kXpColor),
                    const SizedBox(width: 10),
                    _chip('🪙 ${_reward!['tokens_earned'] ?? 0}', kTokenColor),
                  ]),
                  const SizedBox(height: 8),
                  if (_reward!['my_rank'] != null)
                    Text('Rank #${_reward!['my_rank']}', style: TextStyle(
                      fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 13, color: Colors.white.withOpacity(0.5))),
                ],
              ])),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                child: Container(height: 50,
                  decoration: BoxDecoration(color: kDarkCard2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08))),
                  child: const Center(child: Text('← Arcade', style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14, color: Colors.white60)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () { HapticFeedback.heavyImpact(); Navigator.pop(context, 'replay'); },
                child: Container(height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_color, _color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('▶ Play Again', style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14, color: Colors.white)))))),
            ]),
          ]),
        ),
      ))),
    );
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: c.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.3))),
    child: Text(t, style: TextStyle(fontFamily: 'Arch',
      fontWeight: FontWeight.bold, fontSize: 13, color: c)));
}

// ─── Mini leaderboard ─────────────────────────────────────────
class MiniLeaderboard extends StatefulWidget {
  final String gameSlug, gameName;
  const MiniLeaderboard({super.key, required this.gameSlug, required this.gameName});
  @override
  State<MiniLeaderboard> createState() => _MiniLeaderboardState();
}

class _MiniLeaderboardState extends State<MiniLeaderboard> {
  final _api = ApiService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await _api.getLeaderboard(gameSlug: widget.gameSlug, limit: 5);
      if (mounted) {
        setState(() {
        _rows = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kDarkCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('${widget.gameName} Top Scores',
            style: const TextStyle(fontFamily: 'Alfa', fontSize: 13, color: Colors.white)),
        ]),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(color: kNeonBlue, strokeWidth: 2)))
        else if (_rows.isEmpty)
          Text('No scores yet — be the first!', style: TextStyle(fontFamily: 'Momo',
            fontSize: 12, color: Colors.white.withOpacity(0.4)))
        else
          ..._rows.map((r) {
            final rank  = r['rank'] as int? ?? 0;
            final name  = r['gamer_tag']?.isNotEmpty == true
                ? r['gamer_tag'] : r['display_name'] ?? '?';
            final score = r['score'] ?? 0;
            final medals = ['🥇','🥈','🥉'];
            return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 28, child: Text(rank <= 3 ? medals[rank-1] : '#$rank',
                  style: TextStyle(fontFamily: 'Alfa', fontSize: 12,
                    color: rank <= 3 ? kNeonOrange : Colors.white38))),
                const SizedBox(width: 6),
                Expanded(child: Text(name.toString(),
                  style: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 12, color: Colors.white),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('$score', style: const TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: kNeonBlue, fontWeight: FontWeight.bold)),
              ]));
          }),
      ]));
  }
}

// ─── Game countdown ───────────────────────────────────────────
class GameCountdown extends StatefulWidget {
  final VoidCallback onComplete;
  const GameCountdown({super.key, required this.onComplete});
  @override
  State<GameCountdown> createState() => _GameCountdownState();
}

class _GameCountdownState extends State<GameCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _count = 3;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))..forward();
    _tick();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _tick() async {
    for (var i = 3; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _count = i);
      HapticFeedback.lightImpact();
      _ctrl.reset(); _ctrl.forward();
    }
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kDarkBg,
    body: Center(child: ScaleTransition(
      scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      child: Text(_count == 0 ? 'GO!' : '$_count',
        style: TextStyle(fontFamily: 'Alfa', fontSize: 96,
          color: _count == 0 ? Colors.green.shade400 : Colors.white)))));
}