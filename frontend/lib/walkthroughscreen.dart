// lib/walkthroughscreen.dart
//
// Walkthrough / onboarding screen shown between the splash and role
// selection on first launch. Explains the app's value (campus social,
// share, clubs, events, arcade) across four animated pages, with a
// language picker supporting English, Chinese, Korean, Japanese, and
// Bahasa Melayu.
//
// Persistent state (SharedPreferences):
//   'app_lang'              → en | zh | ko | ja | ms
//   'walkthrough_completed' → bool, gates re-display of this screen
//
// On finish, navigates to RoleSelectionScreen with a fade transition.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth/role_selection_screen.dart';

// ── Palette ───────────────────────────────────────────────────────
const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kPink   = Color(0xFFEC4899);
const _kEmGrn  = Color(0xFF11998E);
const _kEmGrn2 = Color(0xFF38EF7D);
Color get _kInk => AppC.text;
Color get _kSlate => AppC.sub;
Color get _kBg => AppC.bg;

// ── Languages ─────────────────────────────────────────────────────
enum Lang { en, zh, ko, ja, ms }

class _LangInfo {
  final String name;
  final String code;
  final String flag;
  const _LangInfo(this.name, this.code, this.flag);
}

final Map<Lang, _LangInfo> _langInfo = {
  Lang.en: const _LangInfo('English',       'EN', '🇺🇸'),
  Lang.zh: const _LangInfo('中文',           'ZH', '🇨🇳'),
  Lang.ko: const _LangInfo('한국어',          'KO', '🇰🇷'),
  Lang.ja: const _LangInfo('日本語',          'JA', '🇯🇵'),
  Lang.ms: const _LangInfo('Bahasa Melayu', 'MS', '🇲🇾'),
};

// ── Page model ────────────────────────────────────────────────────
class _OnboardPage {
  final String titleKey;
  final String bodyKey;
  final String emoji;
  final List<Color> gradient;
  const _OnboardPage(this.titleKey, this.bodyKey, this.emoji, this.gradient);
}

const _pages = <_OnboardPage>[
  _OnboardPage('p1_title', 'p1_body', '🎓', [_kG2, _kG1]),
  _OnboardPage('p2_title', 'p2_body', '📸', [_kG3, _kG4]),
  _OnboardPage('p3_title', 'p3_body', '🎉', [_kEmGrn, _kEmGrn2]),
  _OnboardPage('p4_title', 'p4_body', '🚀', [_kG2, _kPink]),
];

// ── Translations ──────────────────────────────────────────────────
class _T {
  static const Map<Lang, Map<String, String>> _strings = {
    Lang.en: {
      'p1_title':    'Welcome to TCS',
      'p1_body':     'Your campus life, all in one place. Connect, share, and discover what\u2019s happening at Taylors.',
      'p2_title':    'Share & Connect',
      'p2_body':     'Post moments, browse your feed, message friends, and build your campus story.',
      'p3_title':    'Clubs & Events',
      'p3_body':     'Find your tribe in clubs, never miss an event, and play arcade games with friends.',
      'p4_title':    'Ready to Begin?',
      'p4_body':     'Choose your role and let\u2019s get you set up in seconds.',
      'skip':        'Skip',
      'next':        'Next',
      'get_started': 'Get Started',
      'choose_lang': 'Choose your language',
    },
    Lang.zh: {
      'p1_title':    '欢迎来到 TCS',
      'p1_body':     '您的校园生活，尽在掌握。连接、分享、发现 Taylors 的精彩。',
      'p2_title':    '分享与连接',
      'p2_body':     '发布动态，浏览信息流，与朋友聊天，记录你的校园故事。',
      'p3_title':    '社团与活动',
      'p3_body':     '在社团中找到你的圈子，不错过任何活动，和朋友玩游戏。',
      'p4_title':    '准备开始了吗？',
      'p4_body':     '选择您的角色，几秒钟即可设置完成。',
      'skip':        '跳过',
      'next':        '下一步',
      'get_started': '开始使用',
      'choose_lang': '选择语言',
    },
    Lang.ko: {
      'p1_title':    'TCS에 오신 것을\n환영합니다',
      'p1_body':     '캠퍼스 생활을 한곳에서. 연결하고, 공유하고, Taylors의 모든 것을 발견하세요.',
      'p2_title':    '공유하고 연결하세요',
      'p2_body':     '게시물 작성, 피드 확인, 친구와 채팅, 캠퍼스 스토리 만들기.',
      'p3_title':    '동아리와 행사',
      'p3_body':     '동아리에서 친구를 찾고, 행사를 놓치지 말고, 아케이드 게임을 즐겨보세요.',
      'p4_title':    '시작할 준비가 되셨나요?',
      'p4_body':     '역할을 선택하고 몇 초 안에 설정을 완료하세요.',
      'skip':        '건너뛰기',
      'next':        '다음',
      'get_started': '시작하기',
      'choose_lang': '언어 선택',
    },
    Lang.ja: {
      'p1_title':    'TCSへようこそ',
      'p1_body':     'キャンパスライフを一つに。Taylorsでの全てをつながり、共有、発見できます。',
      'p2_title':    'シェアとつながり',
      'p2_body':     '投稿、フィード閲覧、友達とチャット、あなたのキャンパスストーリーを作りましょう。',
      'p3_title':    'クラブとイベント',
      'p3_body':     'クラブで仲間を見つけて、イベントに参加、アーケードゲームを楽しもう。',
      'p4_title':    '始める準備はできましたか？',
      'p4_body':     '役割を選んで、数秒でセットアップ完了。',
      'skip':        'スキップ',
      'next':        '次へ',
      'get_started': '始める',
      'choose_lang': '言語を選ぶ',
    },
    Lang.ms: {
      'p1_title':    'Selamat Datang\nke TCS',
      'p1_body':     'Kehidupan kampus anda, semuanya di satu tempat. Hubung, kongsi, dan temui apa yang berlaku di Taylors.',
      'p2_title':    'Kongsi & Hubung',
      'p2_body':     'Hantar pos, lihat suapan anda, mesej kawan, dan bina cerita kampus anda.',
      'p3_title':    'Kelab & Acara',
      'p3_body':     'Cari kumpulan anda dalam kelab, jangan terlepas acara, dan main permainan dengan kawan.',
      'p4_title':    'Sedia untuk Mula?',
      'p4_body':     'Pilih peranan anda dan mari sediakan dalam beberapa saat.',
      'skip':        'Langkau',
      'next':        'Seterusnya',
      'get_started': 'Mula',
      'choose_lang': 'Pilih bahasa',
    },
  };

  static String t(Lang lang, String key) =>
      _strings[lang]?[key] ?? _strings[Lang.en]![key] ?? key;
}

// ── Screen ────────────────────────────────────────────────────────
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});
  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int  _index = 0;
  Lang _lang  = Lang.en;

  late final AnimationController _floatCtrl;
  late final Animation<double>   _float;
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _rotateCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 30))..repeat();
    _loadLang();
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_lang') ?? 'en';
    final lang = Lang.values.firstWhere(
      (l) => l.name == code, orElse: () => Lang.en);
    if (mounted) setState(() => _lang = lang);
  }

  Future<void> _setLang(Lang lang) async {
    setState(() => _lang = lang);
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang.name);
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('walkthrough_completed', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:        (_, __, ___) => const RoleSelectionScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _next() {
    if (_index < _pages.length - 1) {
      HapticFeedback.lightImpact();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve:    Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _floatCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(children: [
        // Decorative background blobs (outside SafeArea so they bleed to edges)
        Positioned(top: -100, left: -100, child: _blob(280, _kG2)),
        Positioned(bottom: -140, right: -140, child: _blob(340, _kG1)),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.40,
          right: -60,
          child: _blob(160, _kG3)),

        SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              physics:    const BouncingScrollPhysics(),
              onPageChanged: (i) {
                setState(() => _index = i);
                HapticFeedback.selectionClick();
              },
              itemCount:  _pages.length,
              itemBuilder: (_, i) => _buildPage(_pages[i]),
            ),
          ),
          _buildDots(),
          const SizedBox(height: 24),
          _buildCTA(),
          const SizedBox(height: 24),
        ])),
      ]),
    );
  }

  Widget _blob(double size, Color c) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c.withOpacity(0.20), c.withOpacity(0)],
      ),
    ),
  );

  Widget _buildTopBar() {
    final isLast = _index == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isLast ? 0.0 : 1.0,
            child: GestureDetector(
              onTap: isLast ? null : _finish,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
                child: Text(_T.t(_lang, 'skip'),
                  style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 14, color: _kSlate, letterSpacing: 0.5)),
              ),
            ),
          ),
          _buildLangPill(),
        ],
      ),
    );
  }

  Widget _buildLangPill() {
    final info = _langInfo[_lang]!;
    return GestureDetector(
      onTap: _showLangSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(info.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(info.code, style: TextStyle(
            fontFamily: 'Arch', fontWeight: FontWeight.bold,
            fontSize: 12, color: _kInk, letterSpacing: 0.6)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
            size: 18, color: _kSlate),
        ]),
      ),
    );
  }

  void _showLangSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppC.border,
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text(_T.t(_lang, 'choose_lang'),
                style: TextStyle(
                  fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
              const SizedBox(height: 16),
              for (final lang in Lang.values) ...[
                _buildLangRow(lang),
                if (lang != Lang.values.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangRow(Lang lang) {
    final info = _langInfo[lang]!;
    final selected = lang == _lang;
    return GestureDetector(
      onTap: () { _setLang(lang); Navigator.pop(context); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
            ? LinearGradient(colors: [
                _kG2.withOpacity(0.10), _kG1.withOpacity(0.10)])
            : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kG2.withOpacity(0.5) : AppC.border,
            width: selected ? 1.5 : 1.0),
        ),
        child: Row(children: [
          Text(info.flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.name, style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
                fontSize: 16,
                color: selected ? _kG2 : _kInk)),
              const SizedBox(height: 2),
              Text(info.code, style: TextStyle(
                fontFamily: 'Momo', fontSize: 11,
                color: AppC.sub, letterSpacing: 1.0)),
            ])),
          if (selected) const Icon(Icons.check_circle_rounded,
            color: _kG2, size: 24),
        ]),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 240, height: 240, child: Stack(
            alignment: Alignment.center,
            children: [
              // Slowly rotating sweep-gradient ring
              AnimatedBuilder(
                animation: _rotateCtrl,
                builder: (_, __) => Transform.rotate(
                  angle: _rotateCtrl.value * 6.28318,
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          page.gradient.first.withOpacity(0.15),
                          page.gradient.last.withOpacity(0.45),
                          page.gradient.first.withOpacity(0.15),
                        ],
                        stops: const [0.0, 0.5, 1.0]),
                    ),
                  ),
                ),
              ),
              // Inner solid gradient circle
              Container(
                width: 184, height: 184,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: page.gradient,
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                      color: page.gradient.first.withOpacity(0.40),
                      blurRadius: 36, offset: const Offset(0, 16)),
                  ],
                ),
              ),
              // Floating emoji
              AnimatedBuilder(
                animation: _float,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _float.value),
                  child: Text(page.emoji,
                    style: const TextStyle(fontSize: 90))),
              ),
            ],
          )),
          const SizedBox(height: 48),
          Text(_T.t(_lang, page.titleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Alfa', fontSize: 30,
              color: _kInk, height: 1.15)),
          const SizedBox(height: 16),
          Text(_T.t(_lang, page.bodyKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Momo', fontSize: 14,
              color: _kSlate, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 32 : 8, height: 8,
          decoration: BoxDecoration(
            gradient: active
              ? const LinearGradient(colors: [_kG2, _kG1]) : null,
            color: active ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4)),
        );
      }),
    );
  }

  Widget _buildCTA() {
    final isLast = _index == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: _next,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kG2, _kG1],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _kG2.withOpacity(0.40),
                blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_T.t(_lang, isLast ? 'get_started' : 'next'),
                style: const TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 16, color: Colors.white,
                  letterSpacing: 0.6)),
              const SizedBox(width: 10),
              Icon(isLast
                  ? Icons.rocket_launch_rounded
                  : Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
            ],
          )),
        ),
      ),
    );
  }
}
