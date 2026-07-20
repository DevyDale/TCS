// lib/screens/ai/companion_chat_screen.dart
//
// Persona chat — light gradient page + rotating SweepGradient
// borders on chrome (matches AI Hub). The persona's own gradient
// is kept on the hero halo, gradient-text greeting, mini avatar,
// user-message bubble fill, and send button — so each companion
// still feels distinct.

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/ai_spinner.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:tcs_app/widgets/ai_markdown.dart';

import '../../../services/api_service.dart';

// ── Light palette ─────────────────────────────────────────────
Color get _kBg1 => AppC.bg;
Color get _kBg2 => AppC.bg;
Color get _kBg3 => AppC.bg;

Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;

Color get _kInk => AppC.text;
Color get _kInkSoft => AppC.sub;
Color get _kSlate => AppC.sub;
Color get _kSlateLight => AppC.sub;
Color get _kBorder => AppC.border;
Color get _kBorderSoft => AppC.border;
Color get _kInputBg => AppC.card2;
const _kDanger = Color(0xFFFF5858);
const _kOnline = Color(0xFF10B981);

// Shared sweep-gradient palette used for animated borders on
// chrome elements (top bar buttons, rate-limit chip, suggestion
// chips, input field).
const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

// ── Suggestions tailored to each category ────────────────────
const Map<String, List<(String, String)>> _suggestionsByCategory = {
  'science': [
    ('🔬', 'Explain a tricky concept to me'),
    ('🧪', 'Walk me through an experiment'),
    ('📊', "Help me with today's homework"),
    ('💡', 'Why does this happen?'),
  ],
  'literature': [
    ('📖', 'Help me analyze a passage'),
    ('✒️', 'Help me write something'),
    ('🎭', 'Explain a theme to me'),
    ('💭', 'What does this quote mean?'),
  ],
  'philosophy': [
    ('🤔', 'What does the good life look like?'),
    ('⚖️', 'Help me think through a dilemma'),
    ('🧘', 'How should I act in this situation?'),
    ('💡', 'Challenge something I believe'),
  ],
  'tech': [
    ('🐛', 'Help me debug this code'),
    ('🧩', 'Explain an algorithm step by step'),
    ('💻', 'How does this technology work?'),
    ('🚀', 'Teach me something new'),
  ],
  'history': [
    ('📜', 'Tell me about your time'),
    ('🏛️', 'What was daily life like then?'),
    ('⚔️', 'A story from your era'),
    ('🌍', 'How does it connect to today?'),
  ],
  'study': [
    ('⏰', 'Help me plan my study session'),
    ('🎯', 'I keep procrastinating'),
    ('😟', "I'm overwhelmed"),
    ('💪', 'Help me get motivated'),
  ],
  'general': [
    ('💭', 'Tell me something interesting'),
    ('🤝', 'Help me think this through'),
    ('🌟', 'Inspire me'),
    ('❓', 'Ask me a question'),
  ],
};

Color _hexToColor(String hex, {Color fallback = const Color(0xFF6A11CB)}) {
  try {
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    return Color(int.parse(s, radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ── Message model ────────────────────────────────────────────
class CompanionMessage {
  final String role;
  final String content;
  final bool isStreaming;
  final bool isError;
  final DateTime createdAt;

  CompanionMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isError = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CompanionMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? isError,
  }) => CompanionMessage(
    role: role,
    content: content ?? this.content,
    isStreaming: isStreaming ?? this.isStreaming,
    isError: isError ?? this.isError,
    createdAt: createdAt,
  );
}

// ═════════════════════════════════════════════════════════════

class CompanionChatScreen extends StatefulWidget {
  final Map<String, dynamic> companion;
  final String? initialConversationId;

  const CompanionChatScreen({
    super.key,
    required this.companion,
    this.initialConversationId,
  });

  @override
  State<CompanionChatScreen> createState() => _CompanionChatScreenState();
}

class _CompanionChatScreenState extends State<CompanionChatScreen>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  final _api = ApiService();

  // Persona
  late final List<Color> _gradient;
  late final String _name;
  late final String _description;
  late final String _category;
  late final String _emoji;
  late final String _companionId;

  // Conversation state
  String? _conversationId;
  String _userName = '';
  bool _isLoading = false;
  int _rateLimitUsed = 0;
  int _rateLimitMax = 60;

  final List<CompanionMessage> _messages = [];

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController
  _shimmerCtrl; // ← shared by every animated border

  @override
  void initState() {
    super.initState();

    _companionId = widget.companion['id']?.toString() ?? '';
    _name = widget.companion['name']?.toString() ?? 'Companion';
    _description = widget.companion['description']?.toString() ?? '';
    _category = widget.companion['category']?.toString() ?? 'general';
    _emoji = widget.companion['avatar_emoji']?.toString() ?? '✨';

    _gradient = [
      _hexToColor(widget.companion['gradient_start']?.toString() ?? '#6A11CB'),
      _hexToColor(
        widget.companion['gradient_end']?.toString() ?? '#2575FC',
        fallback: const Color(0xFF2575FC),
      ),
    ];

    _conversationId = widget.initialConversationId;

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

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _inputCtrl.addListener(() => setState(() {}));
    _inputFocus.addListener(() => setState(() {}));

    _fetchUserName();
    _fetchStatus();
    if (_conversationId != null) {
      _loadConversation(_conversationId!);
    }
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

  // ── User identity / status ────────────────────────────────

  Future<void> _fetchUserName() async {
    for (final path in const ['/users/me/', '/me/', '/auth/me/']) {
      try {
        final data = await _api.get(path);
        if (mounted && data is Map) {
          final name =
              (data['preferred_name'] ??
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

  Future<void> _fetchStatus() async {
    try {
      final data = await _api.get('/ai/status/');
      if (mounted && data is Map) {
        setState(() {
          _rateLimitUsed = data['messages_used'] as int? ?? 0;
          _rateLimitMax = data['limit'] as int? ?? 60;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🤖 status fetch failed: $e');
    }
  }

  Future<void> _loadConversation(String convId) async {
    try {
      final data = await _api.get('/ai/conversations/$convId/messages/');
      if (mounted && data is Map) {
        final msgs = (data['messages'] as List? ?? [])
            .map(
              (m) => CompanionMessage(
                role: m['role']?.toString() ?? '',
                content: m['content']?.toString() ?? '',
              ),
            )
            .toList();
        setState(() {
          _messages.clear();
          _messages.addAll(msgs);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🤖 load conversation failed: $e');
    }
  }

  // ── Send (streaming) ─────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    _inputCtrl.clear();

    setState(() {
      _messages.add(CompanionMessage(role: 'user', content: msg));
      _isLoading = true;
    });
    _scrollToBottom();

    final aiMsgIndex = _messages.length;
    setState(() {
      _messages.add(
        CompanionMessage(role: 'assistant', content: '', isStreaming: true),
      );
    });

    try {
      final token = await _api.accessToken;
      final baseUrl = ApiConfig.baseUrl;

      final request =
          http.Request(
              'POST',
              Uri.parse('$baseUrl/api/ai/companions/$_companionId/chat/'),
            )
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
              'Authorization': 'Bearer $token',
            })
            ..body = jsonEncode({
              'message': msg,
              'conversation_id': _conversationId,
              'stream': true,
            });

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('$_name is taking longer than usual.'),
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
                    _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
                      isStreaming: false,
                    );
                    _isLoading = false;
                    _rateLimitUsed++;
                  });
                  _scrollToBottom();
                }
                return;
              }
              try {
                final chunk = jsonDecode(data);
                if (chunk is Map) {
                  if (chunk['conversation_id'] != null) {
                    setState(
                      () =>
                          _conversationId = chunk['conversation_id'].toString(),
                    );
                    return;
                  }
                  if (chunk['error'] != null) {
                    _handleError(aiMsgIndex, chunk['error'].toString());
                    return;
                  }
                  final tok =
                      (chunk['token'] ??
                              chunk['content'] ??
                              chunk['delta'] ??
                              '')
                          .toString();
                  if (tok.isNotEmpty && mounted) {
                    setState(() {
                      _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
                        content: _messages[aiMsgIndex].content + tok,
                      );
                    });
                    _scrollToBottom();
                  }
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
                  _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
                    isStreaming: false,
                  );
                  _isLoading = false;
                });
              }
            },
            cancelOnError: true,
          );
    } catch (e) {
      if (kDebugMode) debugPrint('🚨 $_name send failed: $e');
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
    if (code >= 500) return "$_name is having issues right now.";
    return 'Server error ($code).';
  }

  void _handleError(int index, String error) {
    if (!mounted) return;
    setState(() {
      _messages[index] = CompanionMessage(
        role: 'assistant',
        content: error,
        isError: true,
      );
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

  void _startNewChat() {
    HapticFeedback.lightImpact();
    setState(() {
      _conversationId = null;
      _messages.clear();
    });
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: _kBg1,
      width: MediaQuery.of(context).size.width * 0.82,
      child: _HistoryDrawer(
        companionId: _companionId,
        gradient: _gradient,
        emoji: _emoji,
        name: _name,
        activeConversationId: _conversationId,
        onSelect: (convId) {
          _scaffoldKey.currentState?.closeDrawer();
          setState(() {
            _conversationId = convId;
            _messages.clear();
          });
          _loadConversation(convId);
        },
        onNewChat: () {
          _scaffoldKey.currentState?.closeDrawer();
          _startNewChat();
        },
      ),
    );
  }

  Future<void> _openHistory() async {
    HapticFeedback.lightImpact();
    _scaffoldKey.currentState?.openDrawer();
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  String get _greeting {
    const base = 'Hello';
    return _userName.isNotEmpty ? '$base, $_userName' : base;
  }

  String get _tagline =>
      _description.isNotEmpty ? "I'm $_name · $_description" : "I'm $_name";

  List<(String, String)> get _suggestions =>
      _suggestionsByCategory[_category] ?? _suggestionsByCategory['general']!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _buildHistoryDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops: [0.0, 0.55, 1.0],
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
                        (e) => _buildMessage(e.value, e.key),
                      ),
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

  // ── Top bar ──────────────────────────────────────────────

  Widget _buildTopBar() {
    final left = _rateLimitMax - _rateLimitUsed;
    final low = left < 5;
    final inSavedThread = _conversationId != null && _messages.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: _miniIconButton(Icons.arrow_back_ios_new_rounded),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openHistory,
            child: _miniIconButton(Icons.history_rounded),
          ),
          if (inSavedThread) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _startNewChat,
              child: _miniIconButton(Icons.add_comment_rounded),
            ),
          ],
          const Spacer(),
          if (_rateLimitMax > 0)
            _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 14,
              borderWidth: 1.2,
              innerColor: _kCard,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: low ? _kDanger : _kOnline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$left left',
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: low ? _kDanger : _kSlate,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniIconButton(IconData icon) => _GradientBorderCard(
    animation: _shimmerCtrl,
    radius: 14,
    borderWidth: 1.2,
    innerColor: _kCard,
    padding: const EdgeInsets.all(11),
    child: Icon(icon, color: _kInkSoft, size: 16),
  );

  // ── Hero (avatar halo + greeting + tagline) ─ keeps persona
  // gradient on the halo + greeting since that's the identity.

  Widget _buildHero() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _gradient.last.withOpacity(0.22 + 0.18 * _pulse.value),
                  blurRadius: 30 + 12 * _pulse.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kCard,
                ),
                child: Center(
                  child: Text(_emoji, style: const TextStyle(fontSize: 60)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: _gradient,
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
        const SizedBox(height: 6),
        Text(
          _tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            color: _kSlate,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── Suggestions ──────────────────────────────────────────

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: _gradient.last.withOpacity(0.75),
              ),
              const SizedBox(width: 6),
              T(
                'TRY ASKING',
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
            children: _suggestions.map((s) {
              return _SuggestionChip(
                emoji: s.$1,
                label: s.$2,
                shimmer: _shimmerCtrl,
                onTap: () => _sendMessage(s.$2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────

  Widget _buildMessage(CompanionMessage msg, int index) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _MiniCompanionAvatar(gradient: _gradient, emoji: _emoji),
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
                    ? LinearGradient(
                        colors: _gradient,
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
                            : _kBorder,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _gradient.last.withOpacity(0.18)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: isUser ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _buildBubbleBody(msg, isUser),
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

  Widget _buildBubbleBody(CompanionMessage msg, bool isUser) {
    if (msg.isStreaming && msg.content.isEmpty) {
      return AiSpinner(color: _gradient.last);
    }
    if (isUser) {
      return Text(
        msg.content,
        style: const TextStyle(
          fontFamily: 'Momo',
          fontSize: 13.5,
          color: Colors.white,
          height: 1.5,
        ),
      );
    }
    if (msg.isError) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 15, color: _kDanger),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              msg.content,
              style: const TextStyle(
                fontFamily: 'Momo',
                fontSize: 13.5,
                color: _kDanger,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiMarkdown(
          data: msg.content,
          accent: _gradient.last,
          borderGradient: _gradColors,
        ),
        if (msg.isStreaming && msg.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _CursorBlink(color: _gradient.last),
          ),
      ],
    );
  }

  // ── Input bar — chrome uses shared rotating gradient,
  //               send button keeps persona gradient (identity)

  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final canSend = hasText && !_isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
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
                focusNode: _inputFocus,
                enabled: !_isLoading,
                maxLines: 4,
                minLines: 1,
                cursorColor: _gradient.last,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(2),
                style: TextStyle(
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
                  hintText: _isLoading
                      ? '$_name is thinking…'
                      : 'Ask $_name anything…',
                  hintStyle: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 14,
                    color: _kSlateLight,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: canSend
                    ? LinearGradient(
                        colors: _gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSend ? null : _kInputBg,
                border: Border.all(
                  color: canSend ? Colors.transparent : _kBorder,
                ),
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: _gradient.last.withOpacity(0.42),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: _isLoading
                  ? Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        color: _kSlate,
                        strokeWidth: 2,
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
  final String emoji;
  final String label;
  final Animation<double> shimmer;
  final VoidCallback onTap;
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: _GradientBorderCard(
          animation: widget.shimmer,
          radius: 22,
          borderWidth: 1.2,
          innerColor: _kCard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
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

class _MiniCompanionAvatar extends StatelessWidget {
  final List<Color> gradient;
  final String emoji;
  const _MiniCompanionAvatar({required this.gradient, required this.emoji});
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: gradient.last.withOpacity(0.25),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
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
          style: TextStyle(
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
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: 2,
      height: 14,
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
  final Animation<double> animation;
  final Widget child;
  final double radius;
  final double borderWidth;
  final Color? innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color> colors;

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
          math.max(0.0, radius - borderWidth),
        ),
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

// ═════════════════════════════════════════════════════════════
// HISTORY DRAWER — per-companion chat history in a side panel
// ═════════════════════════════════════════════════════════════

class _HistoryDrawer extends StatefulWidget {
  final String companionId;
  final List<Color> gradient;
  final String emoji;
  final String name;
  final String? activeConversationId;
  final void Function(String) onSelect;
  final VoidCallback onNewChat;

  const _HistoryDrawer({
    required this.companionId,
    required this.gradient,
    required this.emoji,
    required this.name,
    required this.activeConversationId,
    required this.onSelect,
    required this.onNewChat,
  });

  @override
  State<_HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<_HistoryDrawer> {
  final _api = ApiService();
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(
        '/ai/companions/${widget.companionId}/conversations/',
      );
      if (mounted && data is Map) {
        setState(() {
          _conversations = (data['conversations'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String convId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const T(
          'Delete this conversation?',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 17),
        ),
        content: const T(
          'This cannot be undone.',
          style: TextStyle(fontFamily: 'Momo', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const T('Cancel', style: TextStyle(fontFamily: 'Momo')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const T(
              'Delete',
              style: TextStyle(fontFamily: 'Momo', color: _kDanger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.delete('/ai/conversations/$convId/');
        if (mounted) {
          setState(() => _conversations.removeWhere((c) => c['id'] == convId));
        }
      } catch (_) {}
    }
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Alfa',
                          fontSize: 18,
                          color: _kInk,
                        ),
                      ),
                      T(
                        'Chat history',
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 11,
                          color: _kSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: GestureDetector(
              onTap: widget.onNewChat,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradient.last.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_comment_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    T(
                      'New chat',
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: T(
              'RECENT',
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                color: _kSlate.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: widget.gradient.last,
                      strokeWidth: 2,
                    ),
                  )
                : _conversations.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: _conversations.length,
                    itemBuilder: (_, i) => _conversationTile(_conversations[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 44,
            color: _kBorder,
          ),
          const SizedBox(height: 12),
          T(
            'No past conversations yet',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 14, color: _kSlate),
          ),
          const SizedBox(height: 6),
          T(
            'Your saved chats will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 12,
              color: _kSlateLight,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _conversationTile(Map<String, dynamic> c) {
    final id = c['id']?.toString() ?? '';
    final title = c['title']?.toString() ?? 'Untitled';
    final updatedAt = c['updated_at']?.toString() ?? '';
    final msgCount = c['message_count'] as int? ?? 0;
    final active = id == widget.activeConversationId;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _delete(id);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _kDanger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: _kDanger,
          size: 22,
        ),
      ),
      child: GestureDetector(
        onTap: () => widget.onSelect(id),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? widget.gradient.last.withOpacity(0.10) : _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? widget.gradient.last.withOpacity(0.35) : _kBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: widget.gradient),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$msgCount message${msgCount == 1 ? '' : 's'} · ${_timeAgo(updatedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 10,
                        color: _kSlate,
                      ),
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
}
