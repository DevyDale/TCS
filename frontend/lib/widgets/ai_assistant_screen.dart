// lib/screens/ai/ai_assistant_screen.dart
//
// TCS AI Assistant — full animated chat screen
// Streams responses from Django → Groq → back to UI
// Matches the TCS dark aesthetic exactly

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _dark  = Color(0xFF0D0D1A);
const _card  = Color(0xFF141428);
const _card2 = Color(0xFF1C1C38);

// ── Message model ─────────────────────────────────────────────

class AiMessage {
  final String  role;      // "user" | "assistant"
  final String  content;
  final bool    isStreaming;
  final DateTime createdAt;

  AiMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AiMessage copyWith({String? content, bool? isStreaming}) => AiMessage(
    role:        role,
    content:     content ?? this.content,
    isStreaming: isStreaming ?? this.isStreaming,
    createdAt:   createdAt,
  );

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ── Quick suggestion prompts ──────────────────────────────────

const _suggestions = [
  ('📅', 'When is my next exam?'),
  ('📖', 'Help me study Physics'),
  ('🎉', 'What events are this week?'),
  ('🕹', 'How do I earn more XP?'),
  ('📚', 'Find me a study group'),
  ('💡', 'Give me study tips'),
];

// ═════════════════════════════════════════════════════════════
// AI ASSISTANT SCREEN
// ═════════════════════════════════════════════════════════════

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _inputFocus  = FocusNode();
  final _api         = ApiService();

  final List<AiMessage> _messages  = [];
  bool  _isLoading                 = false;
  bool  _showSuggestions           = true;
  int   _rateLimitUsed             = 0;
  int   _rateLimitMax              = 30;

  late final AnimationController _headerCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _headerFade;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _pulseAnim  = CurvedAnimation(parent: _pulseCtrl,  curve: Curves.easeInOut);

    _addGreeting();
    _fetchStatus();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _pulseCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Greeting ──────────────────────────────────────────────

  void _addGreeting() {
    _messages.add(AiMessage(
      role:    'assistant',
      content: "Hey! 👋 I'm your TCS campus assistant, powered by Llama 3.\n\n"
               "I can help with study tips, explain concepts, tell you about campus events, "
               "arcade games, and anything about the TCS app. What's on your mind?",
    ));
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await _api.get('/ai/status/');
      if (mounted && data is Map) {
        setState(() {
          _rateLimitUsed = data['messages_used'] as int? ?? 0;
          _rateLimitMax  = data['limit']         as int? ?? 30;
        });
      }
    } catch (_) {}
  }

  // ── Send message ──────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    _inputCtrl.clear();
    _inputFocus.unfocus();

    setState(() {
      _messages.add(AiMessage(role: 'user', content: msg));
      _showSuggestions = false;
      _isLoading       = true;
    });

    _scrollToBottom();

    // Add streaming placeholder
    final aiMsgIndex = _messages.length;
    setState(() {
      _messages.add(AiMessage(role: 'assistant', content: '', isStreaming: true));
    });

    try {
      final token     = await _api.accessToken;
      final baseUrl   = ApiConfig.baseUrl;
      final history   = _messages
          .sublist(0, aiMsgIndex - 1)
          .where((m) => !m.isStreaming)
          .map((m) => m.toJson())
          .toList();

      final request = http.Request('POST', Uri.parse('$baseUrl/api/ai/chat/'))
        ..headers.addAll({
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode({
          'message': msg,
          'history': history,
          'stream':  true,
        });

      final streamed  = await request.send();
      final streamSub = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (!line.startsWith('data:')) return;
          final data = line.substring(5).trim();
          if (data == '[DONE]') {
            if (mounted) {
              setState(() {
              _messages[aiMsgIndex] =
                  _messages[aiMsgIndex].copyWith(isStreaming: false);
              _isLoading = false;
              _rateLimitUsed++;
            });
            }
            _scrollToBottom();
            return;
          }
          try {
            final chunk = jsonDecode(data);
            if (chunk['error'] != null) {
              _handleError(aiMsgIndex, chunk['error']);
              return;
            }
            final token = chunk['token'] as String? ?? '';
            if (token.isNotEmpty && mounted) {
              setState(() {
                _messages[aiMsgIndex] = _messages[aiMsgIndex]
                    .copyWith(content: _messages[aiMsgIndex].content + token);
              });
              _scrollToBottom();
            }
          } catch (_) {}
        },
        onError: (e) => _handleError(aiMsgIndex, 'Connection error. Try again.'),
        onDone: () {
          if (mounted && _isLoading) {
            setState(() {
              _messages[aiMsgIndex] =
                  _messages[aiMsgIndex].copyWith(isStreaming: false);
              _isLoading = false;
            });
          }
        },
      );
    } on Exception {
      _handleError(aiMsgIndex, 'Something went wrong. Try again.');
    }
  }

  void _handleError(int index, String error) {
    if (!mounted) return;
    setState(() {
      _messages[index] = AiMessage(role: 'assistant', content: '⚠️ $error');
      _isLoading       = false;
    });
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

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _headerFade,
              child: ListView.builder(
                controller:  _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount:   _messages.length + (_showSuggestions ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_showSuggestions && i == _messages.length) {
                    return _buildSuggestions();
                  }
                  return _buildMessage(_messages[i], i);
                },
              ),
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8, right: 16, bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: Color(0x10FFFFFF))),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white60, size: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar with pulse
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_kG1, _kG2],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(
                  color: _kG2.withOpacity(0.3 + 0.2 * _pulseAnim.value),
                  blurRadius: 12 + 8 * _pulseAnim.value,
                  spreadRadius: 1,
                )],
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TCS Assistant',
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 17, color: Colors.white,
                    )),
                Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D9E75), shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('Online · Llama 3.3 · Free',
                      style: TextStyle(
                        fontFamily: 'Momo', fontSize: 11,
                        color: Colors.white.withOpacity(0.45),
                      )),
                ]),
              ],
            ),
          ),

          // Rate limit pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              '${_rateLimitMax - _rateLimitUsed} left',
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 11, fontWeight: FontWeight.bold,
                color: (_rateLimitMax - _rateLimitUsed) < 5
                    ? _kG4
                    : Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────

  Widget _buildMessage(AiMessage msg, int index) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _AiAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0x226DD5FA), Color(0x228E54E9)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : _card2,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? _kG2.withOpacity(0.3)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.isStreaming && msg.content.isEmpty)
                    _TypingDots()
                  else
                    Text(
                      msg.content,
                      style: const TextStyle(
                        fontFamily: 'Momo', fontSize: 13,
                        color: Colors.white, height: 1.5,
                      ),
                    ),
                  if (msg.isStreaming && msg.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _CursorBlink(),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _UserAvatar(size: 28),
          ],
        ],
      ),
    );
  }

  // ── Suggestion chips ──────────────────────────────────────

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 10),
            child: Text('Try asking:',
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11,
                  color: Colors.white.withOpacity(0.35),
                )),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => _sendMessage(s.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kG2.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kG2.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(s.$2,
                          style: const TextStyle(
                            fontFamily: 'Momo', fontSize: 12,
                            color: Colors.white70, fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: Color(0x10FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _card2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _inputFocus,
                      enabled: !_isLoading,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(
                        fontFamily: 'Momo', fontSize: 14, color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'TCS AI is thinking...'
                            : 'Ask anything...',
                        hintStyle: TextStyle(
                          fontFamily: 'Momo', fontSize: 14,
                          color: Colors.white.withOpacity(0.25),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          AnimatedBuilder(
            animation: _inputCtrl,
            builder: (_, __) {
              final hasText = _inputCtrl.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText && !_isLoading
                    ? () => _sendMessage(_inputCtrl.text)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasText && !_isLoading
                        ? const LinearGradient(
                            colors: [_kG1, _kG2],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          )
                        : null,
                    color: hasText && !_isLoading ? null : _card2,
                    boxShadow: hasText && !_isLoading
                        ? [BoxShadow(
                            color: _kG2.withOpacity(0.4),
                            blurRadius: 12, offset: const Offset(0, 4),
                          )]
                        : null,
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: hasText ? Colors.white : Colors.white24,
                          size: 20,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════

class _AiAvatar extends StatelessWidget {
  final double size;
  const _AiAvatar({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [_kG1, _kG2],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Center(child: Text('🤖',
        style: TextStyle(fontSize: size * 0.5))),
  );
}

class _UserAvatar extends StatelessWidget {
  final double size;
  const _UserAvatar({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [_kG2, _kG3],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Center(
      child: Text('AL',
          style: TextStyle(
            fontFamily: 'Arch', fontWeight: FontWeight.bold,
            fontSize: size * 0.35, color: Colors.white,
          )),
    ),
  );
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i / 3;
          final t = (_ctrl.value - delay).clamp(0.0, 1.0);
          final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Container(
            width: 7, height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kG1.withOpacity(opacity),
            ),
          );
        }),
      ),
    );
  }
}

class _CursorBlink extends StatefulWidget {
  @override
  State<_CursorBlink> createState() => _CursorBlinkState();
}

class _CursorBlinkState extends State<_CursorBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: 2, height: 14,
      decoration: BoxDecoration(
        color: _kG1.withOpacity(_ctrl.value),
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}
