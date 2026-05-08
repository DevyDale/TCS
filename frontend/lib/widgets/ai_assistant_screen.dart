// lib/screens/ai/ai_assistant_screen.dart
//
// Dale — TCS Campus Assistant.
// Light gradient page + rotating SweepGradient borders on chrome.
// Period gradient is preserved on the Lottie halo, gradient-text
// greeting, mini AI avatar, user-message bubble fill, and send
// button — so dawn still looks peachy, night still looks deep
// purple, etc.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

import '../../services/api_service.dart';

// ── Light palette ─────────────────────────────────────────────
const _kBg1         = Color(0xFFFAFAFC);
const _kBg2         = Color(0xFFE6E6EE);
const _kBg3         = Color(0xFFF2F2F6);

const _kCard        = Color(0xFFFFFFFF);
const _kCardLo      = Color(0xFFF5F5F8);

const _kInk         = Color(0xFF0D0D1A);
const _kInkSoft     = Color(0xFF374151);
const _kSlate       = Color(0xFF6B7280);
const _kSlateLight  = Color(0xFF9CA3AF);
const _kBorder      = Color(0xFFE5E7EB);
const _kBorderSoft  = Color(0xFFF1F2F5);
const _kInputBg     = Color(0xFFF7F8FB);
const _kDanger      = Color(0xFFFF5858);
const _kOnline      = Color(0xFF10B981);

const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

// ─────────────────────────────────────────────────────────────
// TIME-OF-DAY THEME
// ─────────────────────────────────────────────────────────────

enum _DayPeriod { dawn, morning, afternoon, evening, night }

class _PeriodTheme {
  final String       label;
  final String       emoji;
  final IconData     icon;
  final List<Color>  gradient;
  final String       greetingHeadline;
  final String       greetingTagline;
  final List<(String, String)> suggestions;

  const _PeriodTheme({
    required this.label,
    required this.emoji,
    required this.icon,
    required this.gradient,
    required this.greetingHeadline,
    required this.greetingTagline,
    required this.suggestions,
  });

  static _PeriodTheme of(_DayPeriod p) {
    switch (p) {
      case _DayPeriod.dawn:
        return const _PeriodTheme(
          label: 'Early',
          emoji: '🌅',
          icon:  Icons.wb_twilight_rounded,
          gradient: [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
          greetingHeadline: 'Up early',
          greetingTagline:  "I'm Dale · here for the quiet hours ✨",
          suggestions: [
            ('📅', "What's on my schedule today?"),
            ('📖', 'Help me prep for class'),
            ('☕', 'Best early-open spots on campus'),
            ('💡', 'Quick wins to start the day'),
            ('🧠', "Review yesterday's notes"),
          ],
        );
      case _DayPeriod.morning:
        return const _PeriodTheme(
          label: 'Morning',
          emoji: '☀️',
          icon:  Icons.wb_sunny_rounded,
          gradient: [Color(0xFFFFB75E), Color(0xFFED8F03)],
          greetingHeadline: 'Good morning',
          greetingTagline:  "I'm Dale · ready when you are ☀️",
          suggestions: [
            ('📅', "What's on my schedule today?"),
            ('📖', 'Help me study for an exam'),
            ('🎉', "What's happening on campus today?"),
            ('💡', 'Boost my productivity'),
            ('📚', 'Find me a study group'),
          ],
        );
      case _DayPeriod.afternoon:
        return const _PeriodTheme(
          label: 'Afternoon',
          emoji: '🌤️',
          icon:  Icons.wb_sunny_outlined,
          gradient: [Color(0xFF6DD5FA), Color(0xFF8E54E9)],
          greetingHeadline: 'Good afternoon',
          greetingTagline:  "I'm Dale · what can I help with? 🌤️",
          suggestions: [
            ('📚', 'Find me a study group'),
            ('💡', 'Beat the afternoon slump'),
            ('🎉', "What's happening tonight?"),
            ('📖', 'Explain a concept to me'),
            ('🍱', 'Lunch spots near me'),
          ],
        );
      case _DayPeriod.evening:
        return const _PeriodTheme(
          label: 'Evening',
          emoji: '🌆',
          icon:  Icons.brightness_4_rounded,
          gradient: [Color(0xFFFF6B6B), Color(0xFFFFA07A)],
          greetingHeadline: 'Good evening',
          greetingTagline:  "I'm Dale · wind down or gear up 🌆",
          suggestions: [
            ('📋', "Plan tomorrow's tasks"),
            ('📖', 'Review what I learned today'),
            ('🍕', 'Dinner spots on campus'),
            ('🎉', "Tonight's events"),
            ('🧠', 'Quick concept refresher'),
          ],
        );
      case _DayPeriod.night:
        return const _PeriodTheme(
          label: 'Late night',
          emoji: '🌙',
          icon:  Icons.bedtime_rounded,
          gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          greetingHeadline: 'Burning the midnight oil',
          greetingTagline:  "I'm Dale · here for the late shift 🌙",
          suggestions: [
            ('🧠', 'Quick concept review'),
            ('📖', "Help with a problem I'm stuck on"),
            ('☕', 'Late-night study tips'),
            ('🛌', 'How can I sleep better?'),
            ('💭', 'Help me wind down'),
          ],
        );
    }
  }
}

_DayPeriod _detectPeriod() {
  final h = DateTime.now().hour;
  if (h >= 5  && h < 9)  return _DayPeriod.dawn;
  if (h >= 9  && h < 12) return _DayPeriod.morning;
  if (h >= 12 && h < 17) return _DayPeriod.afternoon;
  if (h >= 17 && h < 21) return _DayPeriod.evening;
  return _DayPeriod.night;
}

// ── Message model ─────────────────────────────────────────────

class AiMessage {
  final String   role;
  final String   content;
  final bool     isStreaming;
  final bool     isError;
  final DateTime createdAt;

  AiMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isError     = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AiMessage copyWith({String? content, bool? isStreaming, bool? isError}) =>
      AiMessage(
        role:        role,
        content:     content     ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        isError:     isError     ?? this.isError,
        createdAt:   createdAt,
      );

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ═════════════════════════════════════════════════════════════

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  final _api        = ApiService();

  late final _DayPeriod   _period;
  late final _PeriodTheme _theme;

  final List<AiMessage> _messages = [];
  String _userName      = '';
  bool   _isLoading     = false;
  int    _rateLimitUsed = 0;
  int    _rateLimitMax  = 30;

  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryFade;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _period = _detectPeriod();
    _theme  = _PeriodTheme.of(_period);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();

    _inputCtrl.addListener(() => setState(() {}));
    _inputFocus.addListener(() => setState(() {}));

    _fetchUserName();
    _fetchStatus();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    for (final path in const ['/users/me/', '/me/', '/auth/me/']) {
      try {
        final data = await _api.get(path);
        if (mounted && data is Map) {
          final name = (data['preferred_name']
                  ?? data['first_name']
                  ?? data['display_name']
                  ?? data['name']
                  ?? data['username']
                  ?? '')
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

  Future<void> _fetchStatus() async {
    try {
      final data = await _api.get('/ai/status/');
      if (mounted && data is Map) {
        setState(() {
          _rateLimitUsed = data['messages_used'] as int? ?? 0;
          _rateLimitMax  = data['limit']         as int? ?? 30;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🤖 status fetch failed: $e');
    }
  }

  String get _greeting {
    final base = _theme.greetingHeadline;
    return _userName.isNotEmpty ? '$base, $_userName' : base;
  }

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    _inputCtrl.clear();

    setState(() {
      _messages.add(AiMessage(role: 'user', content: msg));
      _isLoading = true;
    });
    _scrollToBottom();

    final aiMsgIndex = _messages.length;
    setState(() {
      _messages.add(AiMessage(
          role: 'assistant', content: '', isStreaming: true));
    });

    try {
      final token   = await _api.accessToken;
      final baseUrl = ApiConfig.baseUrl;
      final history = _messages
          .sublist(0, aiMsgIndex - 1)
          .where((m) => !m.isStreaming && !m.isError)
          .map((m) => m.toJson())
          .toList();

      final request = http.Request('POST',
          Uri.parse('$baseUrl/api/ai/chat/'))
        ..headers.addAll({
          'Content-Type':  'application/json',
          'Accept':        'text/event-stream',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode({
          'message': msg,
          'history': history,
          'stream':  true,
        });

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
            'Dale is taking longer than usual.'),
      );

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        if (kDebugMode) debugPrint('🤖 ${streamed.statusCode}: $body');
        throw HttpException(_humanizeStatus(streamed.statusCode));
      }

      streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (!line.startsWith('data:')) return;
          final data = line.substring(5).trim();
          if (data.isEmpty) return;
          if (data == '[DONE]') {
            if (mounted) {
              setState(() {
                _messages[aiMsgIndex] =
                    _messages[aiMsgIndex].copyWith(isStreaming: false);
                _isLoading = false;
                _rateLimitUsed++;
              });
              _scrollToBottom();
            }
            return;
          }
          try {
            final chunk = jsonDecode(data);
            if (chunk is Map && chunk['error'] != null) {
              _handleError(aiMsgIndex, chunk['error'].toString());
              return;
            }
            final tok = (chunk['token']
                    ?? chunk['content']
                    ?? chunk['delta']
                    ?? '')
                .toString();
            if (tok.isNotEmpty && mounted) {
              setState(() {
                _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
                    content: _messages[aiMsgIndex].content + tok);
              });
              _scrollToBottom();
            }
          } catch (e) {
            if (kDebugMode) debugPrint('🤖 parse fail: $e for: $data');
          }
        },
        onError: (e) {
          if (kDebugMode) debugPrint('🤖 stream error: $e');
          _handleError(aiMsgIndex, 'Connection lost. Try again.');
        },
        onDone: () {
          if (mounted && _isLoading) {
            setState(() {
              _messages[aiMsgIndex] =
                  _messages[aiMsgIndex].copyWith(isStreaming: false);
              _isLoading = false;
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('🚨 Dale send failed: $e');
      String userMsg;
      if (e is TimeoutException) {
        userMsg = e.message ?? 'Request timed out.';
      } else if (e is HttpException) {
        userMsg = e.message;
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        userMsg = "Can't reach the server — check your connection.";
      } else {
        userMsg = 'Something went wrong. Please try again.';
      }
      _handleError(aiMsgIndex, userMsg);
    }
  }

  String _humanizeStatus(int code) {
    if (code == 401 || code == 403) return 'Session expired — log in again.';
    if (code == 429) return 'Slow down a sec — too many requests.';
    if (code >= 500) return "Dale's having issues right now.";
    return 'Server error ($code).';
  }

  void _handleError(int index, String error) {
    if (!mounted) return;
    setState(() {
      _messages[index] = AiMessage(
          role: 'assistant', content: error, isError: true);
      _isLoading = false;
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
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _entryFade,
                  child: ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      const SizedBox(height: 8),
                      _buildHero(),
                      const SizedBox(height: 28),
                      if (_messages.isEmpty) _buildSuggestions(),
                      ..._messages.asMap().entries.map(
                          (e) => _buildMessage(e.value, e.key)),
                    ],
                  ),
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final left = _rateLimitMax - _rateLimitUsed;
    final low  = left < 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
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
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kInkSoft, size: 16),
            ),
          ),
          const Spacer(),
          if (_rateLimitMax > 0)
            _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 14,
              borderWidth: 1.2,
              innerColor: _kCard,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: low ? _kDanger : _kOnline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$left left',
                  style: TextStyle(
                    fontFamily: 'Momo', fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: low ? _kDanger : _kSlate,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _theme.gradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _theme.gradient.last.withOpacity(
                      0.22 + 0.18 * _pulse.value),
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
                      errorBuilder: (_, e, __) {
                        if (kDebugMode) debugPrint('🤖 Lottie: $e');
                        return const Center(
                          child: Text('🤖',
                              style: TextStyle(fontSize: 60)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: _theme.gradient,
            begin: Alignment.centerLeft, end: Alignment.centerRight,
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
        const SizedBox(height: 6),
        Text(
          _theme.greetingTagline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            color: _kSlate,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _theme.suggestions.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_theme.icon,
                size: 14,
                color: _theme.gradient.last.withOpacity(0.75)),
            const SizedBox(width: 6),
            Text(
              'TRY ASKING',
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _kSlate.withOpacity(0.8),
                letterSpacing: 1.4,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: suggestions.map((s) {
              return _SuggestionChip(
                emoji:   s.$1,
                label:   s.$2,
                shimmer: _shimmerCtrl,
                onTap:   () => _sendMessage(s.$2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(AiMessage msg, int index) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _MiniAiAvatar(gradient: _theme.gradient),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: _theme.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser
                    ? null
                    : (msg.isError
                        ? _kDanger.withOpacity(0.06)
                        : _kCard),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: msg.isError
                            ? _kDanger.withOpacity(0.25)
                            : _kBorder),
                boxShadow: [BoxShadow(
                    color: isUser
                        ? _theme.gradient.last.withOpacity(0.18)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: isUser ? 12 : 6,
                    offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.isStreaming && msg.content.isEmpty)
                    _TypingDots(color: _theme.gradient.last)
                  else
                    Row(
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
                  if (msg.isStreaming && msg.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _CursorBlink(color: _theme.gradient.last),
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

  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final canSend = hasText && !_isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14, 10, 14,
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
            child: _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 22,
              borderWidth: 1.2,
              innerColor: _kInputBg,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _inputCtrl,
                focusNode:  _inputFocus,
                enabled:    !_isLoading,
                maxLines: 4,
                minLines: 1,
                cursorColor: _theme.gradient.last,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(2),
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 14,
                  color: _kInk,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  filled:         false,
                  isDense:        true,
                  border:         InputBorder.none,
                  enabledBorder:  InputBorder.none,
                  focusedBorder:  InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: _isLoading
                      ? 'Dale is thinking…'
                      : 'Ask Dale anything…',
                  hintStyle: const TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 14,
                    color: _kSlateLight,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: canSend ? () => _sendMessage(_inputCtrl.text) : null,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: canSend
                    ? LinearGradient(
                        colors: _theme.gradient,
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                      )
                    : null,
                color: canSend ? null : _kInputBg,
                border: Border.all(
                  color: canSend ? Colors.transparent : _kBorder,
                ),
                boxShadow: canSend
                    ? [BoxShadow(
                        color: _theme.gradient.last.withOpacity(0.42),
                        blurRadius: 14,
                        offset: const Offset(0, 5))]
                    : null,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        color: _kSlate, strokeWidth: 2,
                      ),
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
// HELPERS
// ═════════════════════════════════════════════════════════════

class _SuggestionChip extends StatefulWidget {
  final String              emoji;
  final String              label;
  final Animation<double>   shimmer;
  final VoidCallback        onTap;
  const _SuggestionChip({
    required this.emoji,
    required this.label,
    required this.shimmer,
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
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale:    _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: _GradientBorderCard(
          animation: widget.shimmer,
          radius: 22,
          borderWidth: 1.2,
          innerColor: _kCard,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
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

class _MiniAiAvatar extends StatelessWidget {
  final List<Color> gradient;
  const _MiniAiAvatar({required this.gradient});
  @override
  Widget build(BuildContext context) => Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: [BoxShadow(
          color: gradient.last.withOpacity(0.25),
          blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: const Center(
        child: Text('🤖', style: TextStyle(fontSize: 14))),
  );
}

class _MiniUserAvatar extends StatelessWidget {
  final String name;
  const _MiniUserAvatar({required this.name});
  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 28, height: 28,
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
        vsync: this, duration: const Duration(milliseconds: 1200))
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
          final op = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
          return Container(
            width: 7, height: 7,
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

class _CursorBlink extends StatefulWidget {
  final Color color;
  const _CursorBlink({required this.color});
  @override
  State<_CursorBlink> createState() => _CursorBlinkState();
}

class _CursorBlinkState extends State<_CursorBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
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
        color: widget.color.withOpacity(_ctrl.value),
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — same widget pattern as everywhere else
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double>   animation;
  final Widget              child;
  final double              radius;
  final double              borderWidth;
  final Color               innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color>         colors;

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
          math.max(0.0, radius - borderWidth)),
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