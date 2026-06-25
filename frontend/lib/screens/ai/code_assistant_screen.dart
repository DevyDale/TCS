// lib/screens/ai/code_assistant_screen.dart
//
// TCS Code Helper — chat screen styled to match the AI Hub:
//   • Light page gradient (white → soft grey → white)
//   • White card surfaces with animated SweepGradient borders
//   • Dark ink text, monochrome chrome
//   • Code helper identity preserved through:
//       – Green/teal gradient fill on USER message bubbles
//       – Green accent passed to AiMarkdown for inline code,
//         blockquotes, and links
//   • Code blocks inside assistant messages get rotating
//     gradient borders automatically via AiMarkdown.
//   • Left drawer  — chat history (locally persisted), new chat
//   • Input bar    — clean _kInputBg pill with focus highlight +
//                    circular gradient send button (matches the
//                    AI Assistant screen).

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/widgets/ai_markdown.dart';

import 'package:tcs_app/services/api_service.dart';

// ── Light palette (matches AI Hub) ───────────────────────────
const _kBg1 = Color(0xFFFAFAFC);
const _kBg2 = Color(0xFFE6E6EE);
const _kBg3 = Color(0xFFF2F2F6);

Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;
const _kInputBg = Color(0xFFF7F8FB);

Color get _kBorder => AppC.border;

Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
const _kInkSoft = Color(0xFF374151);
Color get _kInk => AppC.text;

// Code-helper identity: teal/green pair used only for user
// bubbles + the AiMarkdown accent. Everything else is mono.
const _kCode2 = Color(0xFF11998E);
const _kCode1 = Color(0xFF38EF7D);

// Shared sweep-gradient palette for animated borders
const _gradColors = <Color>[
  Color(0xFF6DD5FA), // light blue
  Color(0xFF7C3AED), // violet
  Color(0xFFF59E0B), // amber
  Color(0xFFFF4F6E), // coral
  Color(0xFF6DD5FA), // close the loop
];

// ── Message model ─────────────────────────────────────────────

class CodeMessage {
  final String role;
  final String content;
  final bool isStreaming;
  final DateTime createdAt;

  CodeMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CodeMessage copyWith({String? content, bool? isStreaming}) => CodeMessage(
    role: role,
    content: content ?? this.content,
    isStreaming: isStreaming ?? this.isStreaming,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ── Conversation model + local store (separate from AI Assistant) ──

String _genId() => 'c${DateTime.now().microsecondsSinceEpoch}';

class _Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, String>> messages;

  _Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages,
  };

  static _Conversation fromJson(Map<String, dynamic> j) => _Conversation(
    id: (j['id'] ?? _genId()).toString(),
    title: (j['title'] ?? 'New chat').toString(),
    createdAt:
        DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse((j['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    messages: ((j['messages'] ?? []) as List)
        .map<Map<String, String>>(
          (m) => {
            'role': (m['role'] ?? 'assistant').toString(),
            'content': (m['content'] ?? '').toString(),
          },
        )
        .toList(),
  );
}

class _ConversationStore {
  static const _key = 'dale_code_conversations_v1';

  static Future<List<_Conversation>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      final convos = list
          .map(
            (e) => _Conversation.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      convos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return convos;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(_Conversation c) async {
    final all = await loadAll();
    final idx = all.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      all[idx] = c;
    } else {
      all.add(c);
    }
    await _write(all);
  }

  static Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((x) => x.id == id);
    await _write(all);
  }

  static Future<void> _write(List<_Conversation> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(all.map((c) => c.toJson()).toList()),
    );
  }
}

// ── Quick suggestion prompts ──────────────────────────────────

const _codeSuggestions = [
  ('🐍', 'Write a Python function to reverse a linked list'),
  ('⚛️', 'Show me a Flutter widget with a gradient AppBar'),
  ('🎨', 'CSS for a centered card with shadow'),
  ('📊', 'SQL query: top 5 customers by revenue this year'),
  ('🔧', 'Bash one-liner: find the 10 largest files in a folder'),
  ('🧪', 'Write a unit test for a Dart function that returns Future<int>'),
];

// ═════════════════════════════════════════════════════════════
// CODE ASSISTANT SCREEN
// ═════════════════════════════════════════════════════════════

class CodeAssistantScreen extends StatefulWidget {
  const CodeAssistantScreen({super.key});

  @override
  State<CodeAssistantScreen> createState() => _CodeAssistantScreenState();
}

class _CodeAssistantScreenState extends State<CodeAssistantScreen>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  final _api = ApiService();

  final List<CodeMessage> _messages = [];
  bool _isLoading = false;
  bool _showSuggestions = true;
  int _rateLimitUsed = 0;
  int _rateLimitMax = 60;

  // Chat-history (local persistence)
  String _conversationId = _genId();
  DateTime _conversationCreatedAt = DateTime.now();
  List<_Conversation> _savedConversations = [];

  late final AnimationController _entryCtrl;
  late final AnimationController _shimmerCtrl; // ← shared by every border
  late final Animation<double> _entryFade;

  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _inputFocus.addListener(() => setState(() {}));

    _addGreeting();
    _fetchStatus();
    _loadConversations();
  }

  @override
  void dispose() {
    _persistCurrent(reload: false);
    _streamSub?.cancel();
    _entryCtrl.dispose();
    _shimmerCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _addGreeting() {
    _messages.add(
      CodeMessage(
        role: 'assistant',
        content:
            "Hey! 👋 I'm the **TCS Code Helper**.\n\n"
            "Drop a coding question, paste a snippet you're stuck on, or "
            "describe what you want to build. I'll reply with code in "
            "Markdown — tap any block to copy it.\n\n"
            "_Powered by Gemini 2.5 Flash._",
      ),
    );
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
    } catch (_) {}
  }

  // ── Chat history helpers ──────────────────────────────────

  Future<void> _loadConversations() async {
    final all = await _ConversationStore.loadAll();
    if (mounted) setState(() => _savedConversations = all);
  }

  String _deriveTitle(List<CodeMessage> msgs) {
    final firstUser = msgs.where((m) => m.role == 'user').toList();
    if (firstUser.isEmpty) return 'New chat';
    var t = firstUser.first.content.trim().replaceAll('\n', ' ');
    if (t.length > 42) t = '${t.substring(0, 42)}…';
    return t.isEmpty ? 'New chat' : t;
  }

  Future<void> _persistCurrent({bool reload = true}) async {
    final saveable = _messages
        .where((m) => !m.isStreaming && m.content.trim().isNotEmpty)
        .toList();
    if (!saveable.any((m) => m.role == 'user')) return;

    final convo = _Conversation(
      id: _conversationId,
      title: _deriveTitle(saveable),
      createdAt: _conversationCreatedAt,
      updatedAt: DateTime.now(),
      messages: saveable
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
    );
    await _ConversationStore.save(convo);
    if (reload) await _loadConversations();
  }

  Future<void> _newChat() async {
    await _persistCurrent();
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context); // close drawer
    setState(() {
      _conversationId = _genId();
      _conversationCreatedAt = DateTime.now();
      _messages.clear();
      _addGreeting();
      _showSuggestions = true;
      _isLoading = false;
    });
    _inputCtrl.clear();
  }

  Future<void> _openConversation(_Conversation c) async {
    await _persistCurrent();
    if (!mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context); // close drawer
    setState(() {
      _conversationId = c.id;
      _conversationCreatedAt = c.createdAt;
      _isLoading = false;
      _showSuggestions = false;
      _messages
        ..clear()
        ..addAll(
          c.messages.map(
            (m) => CodeMessage(
              role: m['role'] ?? 'assistant',
              content: m['content'] ?? '',
            ),
          ),
        );
    });
    _scrollToBottom();
  }

  Future<void> _deleteConversation(String id) async {
    await _ConversationStore.delete(id);
    if (id == _conversationId && mounted) {
      setState(() {
        _conversationId = _genId();
        _conversationCreatedAt = DateTime.now();
        _messages.clear();
        _addGreeting();
        _showSuggestions = true;
      });
    }
    await _loadConversations();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // ── Send message ──────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;

    HapticFeedback.lightImpact();
    _inputCtrl.clear();
    _inputFocus.unfocus();

    setState(() {
      _messages.add(CodeMessage(role: 'user', content: msg));
      _showSuggestions = false;
      _isLoading = true;
    });

    _scrollToBottom();
    _persistCurrent();

    final aiMsgIndex = _messages.length;
    setState(() {
      _messages.add(
        CodeMessage(role: 'assistant', content: '', isStreaming: true),
      );
    });

    try {
      final token = await _api.accessToken;
      final baseUrl = ApiConfig.baseUrl;
      final history = _messages
          .sublist(0, aiMsgIndex - 1)
          .where((m) => !m.isStreaming)
          .map((m) => m.toJson())
          .toList();

      final request = http.Request('POST', Uri.parse('$baseUrl/api/ai/code/'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode({
          'message': msg,
          'history': history,
          'stream': true,
        });

      final streamed = await request.send();

      _streamSub = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (!line.startsWith('data:')) return;
              final data = line.substring(5).trim();
              if (data == '[DONE]') {
                if (mounted) {
                  setState(() {
                    _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
                      isStreaming: false,
                    );
                    _isLoading = false;
                    _rateLimitUsed++;
                  });
                }
                _scrollToBottom();
                _persistCurrent();
                return;
              }
              try {
                final chunk = jsonDecode(data);
                if (chunk['error'] != null) {
                  _handleError(aiMsgIndex, chunk['error'] as String);
                  return;
                }
                final tok = chunk['token'] as String? ?? '';
                if (tok.isEmpty) return;
                if (!mounted) return;
                setState(() {
                  final current = _messages[aiMsgIndex];
                  _messages[aiMsgIndex] = current.copyWith(
                    content: current.content + tok,
                  );
                });
                _scrollToBottom();
              } catch (_) {}
            },
            onError: (e) => _handleError(aiMsgIndex, e.toString()),
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
          );
    } catch (e) {
      _handleError(aiMsgIndex, e.toString());
    }
  }

  void _handleError(int idx, String err) {
    if (!mounted) return;
    setState(() {
      _messages[idx] = _messages[idx].copyWith(
        content: "Sorry — ran into an error: $err",
        isStreaming: false,
      );
      _isLoading = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _entryFade,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    itemCount: _messages.length + (_showSuggestions ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_showSuggestions && i == _messages.length) {
                        return _buildSuggestions();
                      }
                      return _buildMessageBubble(_messages[i]);
                    },
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

  // ── Drawer (chat history) ─────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _kBg1,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kCode2, _kCode1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: Container(
                          color: _kCard,
                          padding: const EdgeInsets.all(2),
                          child: Lottie.asset(
                            'assets/images/robot.json',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.code_rounded,
                                color: _kCode2,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: T(
                      'Code Helper',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 20,
                        color: _kInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // New chat
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GestureDetector(
                onTap: _newChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kCode2, _kCode1],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _kCode1.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
              child: _savedConversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: T(
                          'No conversations yet.\nStart chatting and it’ll show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 13,
                            color: _kSlate2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _savedConversations.length,
                      itemBuilder: (_, i) {
                        final c = _savedConversations[i];
                        return _ConversationTile(
                          title: c.title,
                          subtitle: _relativeTime(c.updatedAt),
                          active: c.id == _conversationId,
                          accent: _kCode2,
                          onTap: () => _openConversation(c),
                          onDelete: () => _deleteConversation(c.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar (back + menu + title + status chip) ───────────

  Widget _buildTopBar() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
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
                  color: _kInk,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          // Menu → opens the chat-history drawer
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openDrawer();
            },
            child: _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 14,
              borderWidth: 1.2,
              innerColor: _kCard,
              padding: const EdgeInsets.all(11),
              child: Icon(Icons.menu_rounded, color: _kInk, size: 16),
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: T(
              'Code Helper',
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
          // Rate-limit chip
          _GradientBorderCard(
            animation: _shimmerCtrl,
            radius: 12,
            borderWidth: 1.2,
            innerColor: _kCard,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: _kInkSoft, size: 12),
                const SizedBox(width: 4),
                Text(
                  '$_rateLimitUsed / $_rateLimitMax',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestion chips (overflow-safe) ──────────────────────

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _codeSuggestions.map(_buildSuggestionChip).toList(),
      ),
    );
  }

  Widget _buildSuggestionChip((String, String) s) {
    // Constrain chip width so a long label can soft-wrap to multiple
    // lines instead of overflowing the row.
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GestureDetector(
        onTap: () => _sendMessage(s.$2),
        child: _GradientBorderCard(
          animation: _shimmerCtrl,
          radius: 18,
          borderWidth: 1.2,
          innerColor: _kCard,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(s.$1, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              // Flexible + soft-wrap = the actual overflow fix.
              Flexible(
                child: Text(
                  s.$2,
                  softWrap: true,
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────

  Widget _buildMessageBubble(CodeMessage m) {
    final isUser = m.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86,
          ),
          child: isUser ? _buildUserBubble(m) : _buildAssistantBubble(m),
        ),
      ),
    );
  }

  Widget _buildUserBubble(CodeMessage m) {
    // User bubbles keep the Code Helper identity — green/teal gradient
    // fill, white text. Asymmetric corner so the bubble "points" right.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kCode2, _kCode1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: _kCode1.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        m.content,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _buildAssistantBubble(CodeMessage m) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _buildAssistantContent(m),
    );
  }

  Widget _buildAssistantContent(CodeMessage m) {
    if (m.content.isEmpty && m.isStreaming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: 0, color: _kCode2),
          _Dot(delay: 150, color: _kCode2),
          _Dot(delay: 300, color: _kCode2),
        ],
      );
    }
    // The shared AiMarkdown widget renders dark text on the white
    // bubble and gives code blocks a rotating SweepGradient border.
    return AiMarkdown(
      data: m.content,
      accent: _kCode2,
      borderGradient: _gradColors,
    );
  }

  // ── Input bar (matches the AI Assistant screen) ───────────

  Widget _buildInputBar() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    final canSend = hasText && !_isLoading;
    final focused = _inputFocus.hasFocus;

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: focused ? _kCode2.withOpacity(0.5) : _kBorder,
                  width: focused ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                cursorColor: _kCode2,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(2),
                style: TextStyle(color: _kInk, fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: TranslationService.I.tr('Ask for code, paste a snippet…'),
                  hintStyle: TextStyle(color: _kSlate2, fontSize: 14),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _sendMessage,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: canSend ? () => _sendMessage(_inputCtrl.text) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: canSend
                    ? const LinearGradient(
                        colors: [_kCode2, _kCode1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSend ? null : _kCardLo,
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: _kCode1.withOpacity(0.42),
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
                      color: canSend ? Colors.white : _kSlate2,
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
// _ConversationTile — chat-history row in the drawer
// ═════════════════════════════════════════════════════════════

class _ConversationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ConversationTile({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? accent.withOpacity(0.10) : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? accent.withOpacity(0.35) : _kBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: active ? accent : _kSlate,
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
                          fontFamily: 'Momo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 10,
                          color: _kSlate2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: _kSlate2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — same widget pattern as in ai_hub_screen
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
// Loading dot used while the assistant message is empty + streaming
// ═════════════════════════════════════════════════════════════

class _Dot extends StatefulWidget {
  final int delay;
  final Color color;
  const _Dot({required this.delay, required this.color});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
    child: Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
