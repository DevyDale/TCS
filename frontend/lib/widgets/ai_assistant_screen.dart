// lib/screens/ai/ai_assistant_screen.dart
//
// TCS AI Assistant — light theme, hero Lottie, time-aware greeting.
//
// Layout:
//   1. Slim top bar     — back + menu (left), rate-limit chip (right)
//   2. Hero block       — large animated Lottie + "Good morning, Name"
//   3. Chat area        — suggestions (max 5) + message thread
//   4. Sticky input bar — high-contrast text field + gradient send button
//   5. Left drawer      — chat history (locally persisted), new chat
//
// Palette: white card, multiple grey shades, period-driven gradient
// accent for the avatar halo, send button, user bubbles, and cursor.

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/ai_spinner.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_picker/file_picker.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/widgets/markdown_text.dart';
import 'package:tcs_app/screens/ai/scam_check_screen.dart';

// ── Light palette ─────────────────────────────────────────────
Color get _kBg => AppC.bg;
Color get _kCard => AppC.card;
Color get _kInk => AppC.text;
const _kInkSoft = Color(0xFF374151);
Color get _kSlate => AppC.sub;
Color get _kSlateLight => AppC.sub;
Color get _kBorder => AppC.border;
Color get _kBorderSoft => AppC.border;
Color get _kInputBg => AppC.card2;
const _kDanger = Color(0xFFFF5858);
const _kOnline = Color(0xFF10B981);

// ─────────────────────────────────────────────────────────────
// TIME-OF-DAY THEME
// ─────────────────────────────────────────────────────────────

enum _DayPeriod { dawn, morning, afternoon, evening, night }

class _PeriodTheme {
  final String label;
  final String emoji;
  final IconData icon;
  final List<Color> gradient;
  final String greetingHeadline;
  final String greetingTagline;
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
          icon: Icons.wb_twilight_rounded,
          gradient: [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
          greetingHeadline: 'Up early',
          greetingTagline: 'Quiet hours hit different ✨',
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
          icon: Icons.wb_sunny_rounded,
          gradient: [Color(0xFFFFB75E), Color(0xFFED8F03)],
          greetingHeadline: 'Good morning',
          greetingTagline: "Ready to make today productive?",
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
          icon: Icons.wb_sunny_outlined,
          gradient: [Color(0xFF6DD5FA), Color(0xFF8E54E9)],
          greetingHeadline: 'Good afternoon',
          greetingTagline: "What can I help you with?",
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
          icon: Icons.brightness_4_rounded,
          gradient: [Color(0xFFFF6B6B), Color(0xFFFFA07A)],
          greetingHeadline: 'Good evening',
          greetingTagline: "Wind down or gear up — your call",
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
          icon: Icons.bedtime_rounded,
          gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          greetingHeadline: 'Burning the midnight oil',
          greetingTagline: "Here if you need a hand 🌙",
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
  if (h >= 5 && h < 9) return _DayPeriod.dawn;
  if (h >= 9 && h < 12) return _DayPeriod.morning;
  if (h >= 12 && h < 17) return _DayPeriod.afternoon;
  if (h >= 17 && h < 21) return _DayPeriod.evening;
  return _DayPeriod.night;
}

// ── Message model ─────────────────────────────────────────────

class AiMessage {
  final String role;
  final String content;
  final bool isStreaming;
  final bool isError;
  final DateTime createdAt;

  AiMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isError = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AiMessage copyWith({String? content, bool? isStreaming, bool? isError}) =>
      AiMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        isError: isError ?? this.isError,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ── Conversation model + local store ──────────────────────────

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
  static const _key = 'dale_ai_conversations_v1';

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

// ═════════════════════════════════════════════════════════════
// AI ASSISTANT SCREEN
// ═════════════════════════════════════════════════════════════

class AiAssistantScreen extends StatefulWidget {
  /// Optional text to pre-fill the composer with (e.g. a task starter from a
  /// quick-action chip). The field is focused so the user can finish it.
  final String? initialInput;

  /// When true, the file picker opens on entry so the user can attach a
  /// document straight away (used by Translate / Summarise flows).
  final bool openAttachment;

  const AiAssistantScreen({
    super.key,
    this.initialInput,
    this.openAttachment = false,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  final _api = ApiService();

  late final _DayPeriod _period;
  late final _PeriodTheme _theme;

  final List<AiMessage> _messages = [];
  String _userName = '';
  bool _isLoading = false;
  bool _attaching = false;
  int _rateLimitUsed = 0;
  int _rateLimitMax = 60;

  // Chat-history (local persistence)
  String _conversationId = _genId();
  DateTime _conversationCreatedAt = DateTime.now();
  List<_Conversation> _savedConversations = [];

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _period = _detectPeriod();
    _theme = _PeriodTheme.of(_period);

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
    _fetchStatus();
    _loadConversations();

    // Quick-action entry: pre-fill a task starter and/or open the file picker.
    if (widget.initialInput != null || widget.openAttachment) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (widget.initialInput != null) {
          _inputCtrl.text = widget.initialInput!;
          _inputCtrl.selection =
              TextSelection.collapsed(offset: _inputCtrl.text.length);
        }
        if (widget.openAttachment) {
          await _pickAttachment();
        } else if (widget.initialInput != null) {
          _inputFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    // Persist whatever is on screen before tearing down (no setState here).
    _persistCurrent(reload: false);
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Chat history helpers ──────────────────────────────────

  Future<void> _loadConversations() async {
    final all = await _ConversationStore.loadAll();
    if (mounted) setState(() => _savedConversations = all);
  }

  String _deriveTitle(List<AiMessage> msgs) {
    final firstUser = msgs.where((m) => m.role == 'user').toList();
    if (firstUser.isEmpty) return 'New chat';
    var t = firstUser.first.content.trim().replaceAll('\n', ' ');
    if (t.length > 42) t = '${t.substring(0, 42)}…';
    return t.isEmpty ? 'New chat' : t;
  }

  Future<void> _persistCurrent({bool reload = true}) async {
    final saveable = _messages
        .where(
          (m) => !m.isStreaming && !m.isError && m.content.trim().isNotEmpty,
        )
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
      _messages
        ..clear()
        ..addAll(
          c.messages.map(
            (m) => AiMessage(
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

  // ── Identity / status fetch ───────────────────────────────

  Future<void> _fetchUserName() async {
    // Try the most likely user endpoints in order. Silently skip if
    // none exist — the greeting just falls back to no name.
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

  String get _greeting {
    final base = _theme.greetingHeadline;
    return _userName.isNotEmpty ? '$base, $_userName' : base;
  }

  // ── Send message — robust streaming + error reporting ────

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFB3261E) : _theme.gradient.last,
        duration: const Duration(seconds: 3),
        content: Text(msg,
            style: const TextStyle(
                fontFamily: 'Momo', fontSize: 12.5, color: Colors.white)),
      ));
  }

  // Pick a PDF / DOCX / TXT from the phone, extract its text on the server, and
  // drop it into the composer so the user can act on it (translate, summarise…).
  Future<void> _pickAttachment() async {
    if (_attaching || _isLoading) return;
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: false,
        withData: false,
      );
    } catch (_) {
      _toast('Could not open the file picker.', error: true);
      return;
    }
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.first;
    if (pf.path == null) {
      _toast('Could not read that file.', error: true);
      return;
    }

    final ext = (pf.extension ?? '').toLowerCase();
    final mime = ext == 'pdf'
        ? 'application/pdf'
        : ext == 'txt'
            ? 'text/plain'
            : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    setState(() => _attaching = true);
    HapticFeedback.selectionClick();
    try {
      final res = await _api.uploadFile('/ai/extract/',
          filePath: pf.path!, field: 'file', mimeType: mime);
      final text = (res is Map ? res['text'] : null)?.toString().trim() ?? '';
      if (text.isEmpty) {
        _toast('No readable text found in that file.', error: true);
        return;
      }
      final existing = _inputCtrl.text.trimRight();
      _inputCtrl.text = existing.isEmpty ? text : '$existing\n\n$text';
      _inputCtrl.selection =
          TextSelection.collapsed(offset: _inputCtrl.text.length);
      _inputFocus.requestFocus();
      final truncated = res is Map && res['truncated'] == true;
      _toast(truncated
          ? 'Added "${pf.name}" (trimmed to fit) — edit and send.'
          : 'Added "${pf.name}" — edit and send.');
    } catch (_) {
      _toast('Could not read that file.', error: true);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
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
    _persistCurrent();

    final aiMsgIndex = _messages.length;
    setState(() {
      _messages.add(
        AiMessage(role: 'assistant', content: '', isStreaming: true),
      );
    });

    try {
      final token = await _api.accessToken;
      final baseUrl = ApiConfig.baseUrl;
      final history = _messages
          .sublist(0, aiMsgIndex - 1)
          .where((m) => !m.isStreaming && !m.isError)
          .map((m) => m.toJson())
          .toList();

      if (kDebugMode) {
        debugPrint('🤖 POST $baseUrl/api/ai/chat/');
        debugPrint('🤖 history len: ${history.length}, message: $msg');
      }

      // The student's selected app language — Dale always replies in it.
      final lang = (await SharedPreferences.getInstance()).getString('language') ?? 'en';

      final request = http.Request('POST', Uri.parse('$baseUrl/api/ai/chat/'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode({
          'message': msg,
          'history': history,
          'stream': true,
          'language': lang,
        });

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () =>
            throw TimeoutException('The AI is taking longer than usual.'),
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
                  _persistCurrent();
                }
                return;
              }
              try {
                final chunk = jsonDecode(data);
                if (chunk is Map && chunk['error'] != null) {
                  _handleError(aiMsgIndex, chunk['error'].toString());
                  return;
                }
                // Accept either {"token": "..."} or {"content": "..."}
                final tok =
                    (chunk['token'] ?? chunk['content'] ?? chunk['delta'] ?? '')
                        .toString();
                if (tok.isNotEmpty && mounted) {
                  setState(() {
                    _messages[aiMsgIndex] = _messages[aiMsgIndex].copyWith(
                      content: _messages[aiMsgIndex].content + tok,
                    );
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
      if (kDebugMode) debugPrint('🚨 AI send failed: $e');
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
    if (code >= 500) return 'The AI service is having issues.';
    return 'Server error ($code).';
  }

  void _handleError(int index, String error) {
    if (!mounted) return;
    setState(() {
      _messages[index] = AiMessage(
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

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _kBg,
      drawer: _buildDrawer(),
      body: SafeArea(
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
    );
  }

  // ── Drawer (chat history) ─────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _kBg,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _theme.gradient,
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
                              child: T('🤖', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  T(
                    'Dale',
                    style: TextStyle(
                      fontFamily: 'Alfa',
                      fontSize: 20,
                      color: _kInk,
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
                    gradient: LinearGradient(
                      colors: _theme.gradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _theme.gradient.last.withOpacity(0.3),
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
                            color: _kSlateLight,
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
                          accent: _theme.gradient.last,
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

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    final left = _rateLimitMax - _rateLimitUsed;
    final low = left < 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _kInkSoft,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Menu → opens the chat-history drawer
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
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
              child: const Icon(Icons.menu_rounded, color: _kInkSoft, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          // Scam check — paste a suspicious message and get a cautious verdict.
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ScamCheckScreen()));
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5A4), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF0EA5A4).withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const Spacer(),
          if (_rateLimitMax > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: low ? _kDanger.withOpacity(0.3) : _kBorder,
                ),
              ),
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

  // ── Hero (Lottie + greeting) ──────────────────────────────

  Widget _buildHero() {
    return Column(
      children: [
        // Lottie with pulsing gradient halo
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _theme.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _theme.gradient.last.withOpacity(
                    0.22 + 0.18 * _pulse.value,
                  ),
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
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Lottie.asset(
                      'assets/images/robot.json',
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, __) {
                        if (kDebugMode) debugPrint('🤖 Lottie: $e');
                        return const Center(
                          child: T('🤖', style: TextStyle(fontSize: 60)),
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
        // Gradient-text greeting
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: _theme.gradient,
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
          _theme.greetingTagline,
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

  // ── Suggestions (max 5) ───────────────────────────────────

  Widget _buildSuggestions() {
    final suggestions = _theme.suggestions.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _theme.icon,
                size: 14,
                color: _theme.gradient.last.withOpacity(0.75),
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
            children: suggestions.map((s) {
              return _SuggestionChip(
                emoji: s.$1,
                label: s.$2,
                accent: _theme.gradient.last,
                onTap: () => _sendMessage(s.$2),
              );
            }).toList(),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        ? _theme.gradient.last.withOpacity(0.18)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: isUser ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.isStreaming && msg.content.isEmpty)
                    AiSpinner(color: _theme.gradient.last)
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.isError) ...[
                          Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: _kDanger,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          // Assistant replies are markdown — render them so
                          // **bold**, lists and code show properly (no literal ****).
                          child: (!isUser && !msg.isError)
                              ? MarkdownText(
                                  msg.content,
                                  color: _kInk,
                                  fontSize: 13.5,
                                  fontFamily: 'Momo',
                                  height: 1.5,
                                )
                              : Text(
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

  // ── Input bar ─────────────────────────────────────────────
  // Explicitly dark-text on light grey fill so typing is always
  // readable. Cursor + focused border use the period accent.

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
          GestureDetector(
            onTap: (_attaching || _isLoading) ? null : _pickAttachment,
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _kInputBg,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: _attaching
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _theme.gradient.last))
                  : Icon(Icons.attach_file_rounded,
                      color: _isLoading ? _kSlateLight : _theme.gradient.last,
                      size: 22),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: focused
                      ? _theme.gradient.last.withOpacity(0.5)
                      : _kBorder,
                  width: focused ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                enabled: !_isLoading,
                maxLines: 4,
                minLines: 1,
                cursorColor: _theme.gradient.last,
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
                  hintText: _isLoading ? 'Thinking…' : 'Ask anything…',
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: canSend
                    ? LinearGradient(
                        colors: _theme.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSend ? null : _kBorderSoft,
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: _theme.gradient.last.withOpacity(0.42),
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
// HELPER WIDGETS
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
                          color: _kSlateLight,
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
                      color: _kSlateLight,
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

class _SuggestionChip extends StatefulWidget {
  final String emoji;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _SuggestionChip({
    required this.emoji,
    required this.label,
    required this.accent,
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

class _MiniAiAvatar extends StatelessWidget {
  final List<Color> gradient;
  const _MiniAiAvatar({required this.gradient});
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
    child: const Center(child: T('🤖', style: TextStyle(fontSize: 14))),
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
