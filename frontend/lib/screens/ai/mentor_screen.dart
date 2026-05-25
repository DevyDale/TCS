// lib/screens/ai/mentor_screen.dart
//
// Sage — every student's private, personal mentor & wellbeing companion.
//
//   • One continuous thread per user, persisted server-side
//     (GET /api/ai/mentor/history/, POST /api/ai/mentor/chat/,
//      DELETE /api/ai/mentor/clear/).
//   • Sage is warm and emotionally understanding, but is explicitly an
//     AI companion — not a counsellor. A standing footer points to real
//     crisis support so the boundary is always visible.
//   • Sage replies render through AiMarkdown so lists / emphasis look tidy.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/widgets/ai_markdown.dart';

// ── Sage palette (matches the chat room) ─────────────────────
const _kSage   = Color(0xFFA9BC95);
const _kSageDk = Color(0xFF6E8159);
const _kSageLt = Color(0xFFEFF2E8);
const _kInk    = Color(0xFF2E3A24);
const _kSlate  = Color(0xFF6B7280);
const _kBg     = Color(0xFFF6F8F2);
const _kHair   = Color(0xFFE3E7DA);

class MentorScreen extends StatefulWidget {
  const MentorScreen({super.key});

  @override
  State<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends State<MentorScreen> {
  final _api    = ApiService.instance;
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  // Each entry: {'role': 'user' | 'mentor', 'content': '...'}
  final List<Map<String, String>> _messages = [];

  bool _loading = true;   // initial history load
  bool _sending = false;  // awaiting a reply

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _api.get('/ai/mentor/history/');
      final list = (res is Map && res['messages'] is List)
          ? res['messages'] as List
          : const [];
      _messages
        ..clear()
        ..addAll(list.map((m) => {
              'role': (m['role'] ?? 'mentor').toString(),
              'content': (m['content'] ?? '').toString(),
            }));
    } catch (_) {
      // Leave the thread empty — the welcome state will show.
    }
    if (mounted) {
      setState(() => _loading = false);
      _scrollToEnd(delay: true);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _ctrl.clear();
    });
    _scrollToEnd();

    try {
      final res = await _api.post('/ai/mentor/chat/', body: {'message': text});
      final reply = (res is Map && res['response'] != null)
          ? res['response'].toString()
          : "I'm here with you. I had trouble responding just then — could you say that again?";
      if (mounted) {
        setState(() => _messages.add({'role': 'mentor', 'content': reply}));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add({
              'role': 'mentor',
              'content':
                  "I'm having a little trouble connecting right now. Give me a moment and try again — I'm still here. 🌿",
            }));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd(delay: true);
    }
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
                fontWeight: FontWeight.w800, fontSize: 16, color: _kInk)),
        content: const Text(
          'This clears your conversation history so far. Sage will start with a clean slate.',
          style: TextStyle(fontSize: 13, color: _kSlate, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: _kSlate)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(
                    color: Color(0xFFC0563B), fontWeight: FontWeight.w700)),
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

  void _scrollToEnd({bool delay = false}) {
    void jump() {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }

    if (delay) {
      Future.delayed(const Duration(milliseconds: 120), jump);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: _kSageDk, strokeWidth: 2.4))
                  : _buildThread(),
            ),
            _buildDisclaimer(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kHair)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kInk, size: 18),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_kSage, _kSageDk],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipOval(
              child: Lottie.asset(
                'assets/images/robot.json',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.spa_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sage',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: _kInk,
                        letterSpacing: -0.2)),
                Text('Your personal mentor',
                    style: TextStyle(fontSize: 12, color: _kSlate)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Start fresh',
            onPressed: _messages.isEmpty ? null : _confirmClear,
            icon: Icon(Icons.refresh_rounded,
                color: _messages.isEmpty ? _kHair : _kSageDk, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildThread() {
    final showWelcome = _messages.isEmpty;
    final itemCount =
        (showWelcome ? 1 : _messages.length) + (_sending ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        if (showWelcome && i == 0) return _welcomeCard();
        if (_sending && i == itemCount - 1) return _typingBubble();
        final m = _messages[i];
        return _bubble(m['role'] == 'user', m['content'] ?? '');
      },
    );
  }

  Widget _welcomeCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sageAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kSageLt,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: _kHair),
              ),
              child: const Text(
                "Hi, I'm Sage — your personal mentor here at TCS. 🌿\n\n"
                "This is a private space to talk through anything: study stress, "
                "settling in, friendships, motivation, or just how your day's "
                "going. I'm here to listen, no judgement.\n\n"
                "What's on your mind?",
                style: TextStyle(fontSize: 14.5, color: _kInk, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(bool isUser, String content) {
    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _kSage,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(content,
                style: const TextStyle(
                    fontSize: 14.5, color: Colors.white, height: 1.4)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sageAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _kSageLt,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: _kHair),
              ),
              child: AiMarkdown(data: content, accent: _kSageDk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sageAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kSageLt,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: _kHair),
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: _kSageDk, strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sageAvatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_kSage, _kSageDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: Lottie.asset(
          'assets/images/robot.json',
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.spa_rounded, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: _kBg,
      child: const Text(
        'Sage is an AI companion for support, not a substitute for professional care. '
        'In a crisis call 000 or Lifeline 13 11 14.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5, color: _kSlate, height: 1.3),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kHair)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kHair),
              ),
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 5,
                cursorColor: _kSageDk,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14.5, color: _kInk),
                decoration: const InputDecoration(
                  hintText: 'Tell Sage what\'s on your mind…',
                  hintStyle: TextStyle(color: _kSlate, fontSize: 13.5),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_kSage, _kSageDk],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _kSageDk.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
