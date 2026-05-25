// lib/screens/ai/mentor_screen.dart
//
// Sage — every student's private personal mentor & wellbeing companion.
//
// Built to mirror the AI Assistant screen's look (hero Lottie + gradient
// greeting, suggestion chips, themed bubbles, sticky input bar) — but in
// the sage palette and wired to Sage's SERVER-SIDE persistent thread:
//   GET    /api/ai/mentor/history/   load the ongoing conversation
//   POST   /api/ai/mentor/chat/      send a message, get Sage's reply
//   DELETE /api/ai/mentor/clear/     start fresh
//
// Unlike the AI Assistant (many local chats in a drawer), Sage is ONE
// continuous relationship per user — it remembers you across sessions
// and devices. So the drawer is replaced by a "start fresh" control.
//
// Sage is warm and emotionally understanding, but it is explicitly an AI
// companion, not a counsellor — a standing footer keeps real crisis
// support one glance away.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'package:tcs_app/services/api_service.dart';

// ── Light palette ─────────────────────────────────────────────
const _kBg = Color(0xFFFAFBF8);
const _kCard = Color(0xFFFFFFFF);
const _kInk = Color(0xFF26301C);
const _kInkSoft = Color(0xFF3C4A30);
const _kSlate = Color(0xFF6B7280);
const _kSlateLight = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE3E7DA);
const _kBorderSoft = Color(0xFFF1F3EC);
const _kInputBg = Color(0xFFF5F7F1);
const _kDanger = Color(0xFFC0563B);

// Sage accent gradient — used for the halo, user bubbles, send button,
// suggestion accents, and cursor (the only saturated colour on the page).
const _sage = <Color>[Color(0xFFA9BC95), Color(0xFF5E7049)];

// ── Greeting + wellbeing suggestions ──────────────────────────

String _greetingHeadline() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 21) return 'Good evening';
  return 'Still up';
}

const _suggestions = <(String, String)>[
  ('😮‍💨', "I'm feeling really stressed"),
  ('📚', "Exam pressure is getting to me"),
  ('🏠', "I've been feeling homesick"),
  ('💬', "I just need someone to talk to"),
  ('🎯', "Help me set a small goal"),
];

// ── Message model ─────────────────────────────────────────────

class _Msg {
  final String role; // 'user' | 'mentor'
  final String content;
  final bool isTyping;
  final bool isError;
  _Msg({
    required this.role,
    required this.content,
    this.isTyping = false,
    this.isError = false,
  });
}

// ═════════════════════════════════════════════════════════════
// SAGE SCREEN
// ═════════════════════════════════════════════════════════════

class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen>
    with TickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  final _api = ApiService.instance;

  final List<_Msg> _messages = [];
  String _userName = '';
  bool _loadingHistory = true;
  bool _sending = false;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _inputCtrl.addListener(() => setState(() {}));
    _inputFocus.addListener(() => setState(() {}));

    _fetchUserName();
    _loadHistory();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _fetchUserName() async {
    for (final path in const ['/users/me/', '/me/', '/auth/me/']) {
      try {
        final data = await _api.get(path);
        if (mounted && data is Map) {
          final name = (data['preferred_name'] ??
                  data['first_name'] ??
                  data['display_name'] ??
                  data['name'] ??
                  data['username'] ??
                  '')
              .toString()
              .trim();
          if (name.isNotEmpty) {
            setState(() => _userName = name.split(' ').first);
            return;
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _api.get('/ai/mentor/history/');
      final list = (res is Map && res['messages'] is List)
          ? res['messages'] as List
          : const [];
      _messages
        ..clear()
        ..addAll(list.map((m) => _Msg(
              role: (m['role'] ?? 'mentor').toString(),
              content: (m['content'] ?? '').toString(),
            )));
    } catch (_) {
      // empty thread → hero + suggestions show
    }
    if (mounted) {
      setState(() => _loadingHistory = false);
      _scrollToBottom();
    }
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _sending) return;

    HapticFeedback.lightImpact();
    _inputCtrl.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', content: msg));
      _sending = true;
    });
    _scrollToBottom();

    final aiIndex = _messages.length;
    setState(() =>
        _messages.add(_Msg(role: 'mentor', content: '', isTyping: true)));
    _scrollToBottom();

    try {
      final res = await _api.post('/ai/mentor/chat/', body: {'message': msg});
      final reply = (res is Map && res['response'] != null)
          ? res['response'].toString()
          : "I'm here with you. I had trouble responding just then — could you say that again?";
      if (mounted) {
        setState(() {
          _messages[aiIndex] = _Msg(role: 'mentor', content: reply);
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages[aiIndex] = _Msg(
            role: 'mentor',
            content:
                "I'm having a little trouble connecting right now. Give me a moment and try again — I'm still here. 🌿",
            isError: true,
          );
          _sending = false;
        });
      }
    }
    _scrollToBottom();
  }

  Future<void> _confirmClear() async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Start fresh with Sage?',
            style: TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _kInk)),
        content: const Text(
          'This clears your conversation so far. Sage will start with a clean slate.',
          style: TextStyle(
              fontFamily: 'Momo', fontSize: 13, color: _kSlate, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep',
                style: TextStyle(fontFamily: 'Momo', color: _kSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(
                    fontFamily: 'Momo',
                    color: _kDanger,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/ai/mentor/clear/');
    } catch (_) {}
    if (mounted) setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String get _greeting {
    final base = _greetingHeadline();
    return _userName.isNotEmpty ? '$base, $_userName' : base;
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF5E7049), strokeWidth: 2.4))
                  : FadeTransition(
                      opacity: _entryFade,
                      child: ListView(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        children: [
                          const SizedBox(height: 8),
                          _buildHero(),
                          const SizedBox(height: 28),
                          if (_messages.isEmpty) _buildSuggestions(),
                          ..._messages
                              .asMap()
                              .entries
                              .map((e) => _buildMessage(e.value)),
                        ],
                      ),
                    ),
            ),
            _buildDisclaimer(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: _iconChip(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _messages.isEmpty ? null : _confirmClear,
            child: Opacity(
              opacity: _messages.isEmpty ? 0.4 : 1.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: _kInkSoft, size: 15),
                    SizedBox(width: 5),
                    Text('Start fresh',
                        style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _kSlate)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconChip(IconData icon, {double size = 18}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: _kInkSoft, size: size),
    );
  }

  // ── Hero ──────────────────────────────────────────────────

  Widget _buildHero() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: _sage,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _sage.last.withOpacity(0.22 + 0.18 * _pulse.value),
                  blurRadius: 30 + 12 * _pulse.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCard,
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Lottie.asset(
                      'assets/images/robot.json',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.spa_rounded,
                            size: 56, color: Color(0xFF5E7049)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: _sage,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(rect),
          blendMode: BlendMode.srcIn,
          child: Text(
            _greeting,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 26,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "I'm Sage, your personal mentor.\nThis is your space — what's on your mind? 🌿",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            color: _kSlate,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Suggestions ───────────────────────────────────────────

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded,
                  size: 13, color: _sage.last.withOpacity(0.75)),
              const SizedBox(width: 6),
              Text(
                'YOU COULD START WITH',
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _kSlate.withOpacity(0.8),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => _SuggestionChip(
                      emoji: s.$1,
                      label: s.$2,
                      onTap: () => _send(s.$2),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────

  Widget _buildMessage(_Msg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _MiniSageAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: _sage,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? null
                    : (msg.isError ? _kDanger.withOpacity(0.06) : _kCard),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: msg.isError
                            ? _kDanger.withOpacity(0.25)
                            : _kBorder),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _sage.last.withOpacity(0.18)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: isUser ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: msg.isTyping
                  ? _TypingDots(color: _sage.last)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.isError) ...[
                          const Icon(Icons.error_outline_rounded,
                              size: 15, color: _kDanger),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            msg.content,
                            style: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 13.5,
                              color: isUser
                                  ? Colors.white
                                  : (msg.isError ? _kDanger : _kInk),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _MiniUserAvatar(name: _userName),
          ],
        ],
      ),
    );
  }

  // ── Disclaimer ────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: const Text(
        'Sage is an AI companion for support, not a substitute for professional care. '
        'In a crisis call 000 or Lifeline 13 11 14.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Momo', fontSize: 10, color: _kSlateLight, height: 1.3),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────

  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final canSend = hasText && !_sending;
    final focused = _inputFocus.hasFocus;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: focused ? _sage.last.withOpacity(0.5) : _kBorder,
                  width: focused ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                enabled: !_sending,
                maxLines: 4,
                minLines: 1,
                cursorColor: _sage.last,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(2),
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 14,
                  color: _kInk,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: _sending ? 'Sage is thinking…' : "Tell Sage what's on your mind…",
                  hintStyle: const TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 14,
                    color: _kSlateLight,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: canSend ? () => _send(_inputCtrl.text) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: canSend
                    ? const LinearGradient(
                        colors: _sage,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSend ? null : _kBorderSoft,
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: _sage.last.withOpacity(0.42),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          color: _kSlate, strokeWidth: 2),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: canSend ? Colors.white : _kSlateLight,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════

class _SuggestionChip extends StatefulWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kInkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSageAvatar extends StatelessWidget {
  const _MiniSageAvatar();
  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: _sage,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _sage.last.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Lottie.asset(
            'assets/images/robot.json',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.spa_rounded,
                color: Colors.white, size: 15),
          ),
        ),
      );
}

class _MiniUserAvatar extends StatelessWidget {
  final String name;
  const _MiniUserAvatar({required this.name});
  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kBorderSoft,
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: _kInkSoft,
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3;
          final t = (_ctrl.value - delay).clamp(0.0, 1.0);
          final op = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(op),
            ),
          );
        }),
      ),
    );
  }
}
