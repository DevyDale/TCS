// lib/widgets/quiz_share_picker.dart
//
// Bottom sheet to share a quiz into a 1-on-1 chat / bubble or a study group.
// Chats use POST /chat/rooms/<id>/share-quiz/; study groups post the quiz
// marker as a group message (/posts/). Either way it renders as a tappable
// quiz card in that conversation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/quiz_share.dart';

const _kPurple = Color(0xFF8E54E9);

Future<void> showQuizSharePicker(
  BuildContext context, {
  required String quizId,
  required String title,
  required int count,
  required String difficulty,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuizSharePicker(
      quizId: quizId, title: title, count: count, difficulty: difficulty),
  );
}

class _QuizSharePicker extends StatefulWidget {
  final String quizId, title, difficulty;
  final int count;
  const _QuizSharePicker({
    required this.quizId, required this.title,
    required this.count, required this.difficulty,
  });

  @override
  State<_QuizSharePicker> createState() => _QuizSharePickerState();
}

class _QuizSharePickerState extends State<_QuizSharePicker> {
  final _api = ApiService();
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  String? _sendingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getChatRooms().catchError((_) => <dynamic>[]),
        _api.get('/groups/', query: {'filter': 'mine'})
            .catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _chats = (results[0] as List).cast<Map<String, dynamic>>();
        _groups = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareToChat(Map<String, dynamic> room) async {
    final id = room['id']?.toString() ?? '';
    if (id.isEmpty || _sendingId != null) return;
    setState(() => _sendingId = id);
    try {
      await _api.post('/chat/rooms/$id/share-quiz/', body: {
        'quiz_id': widget.quizId, 'title': widget.title,
        'count': widget.count, 'difficulty': widget.difficulty,
      });
      _done(_chatName(room));
    } catch (_) {
      _fail();
    }
  }

  Future<void> _shareToGroup(Map<String, dynamic> group) async {
    final id = group['id']?.toString() ?? '';
    if (id.isEmpty || _sendingId != null) return;
    setState(() => _sendingId = id);
    try {
      await _api.post('/posts/', body: {
        'content': QuizShare.encode(
            id: widget.quizId, title: widget.title,
            count: widget.count, difficulty: widget.difficulty),
        'post_type': 'post',
        'visibility': 'public',
        'group': id,
      });
      _done(group['name']?.toString() ?? 'the group');
    } catch (_) {
      _fail();
    }
  }

  void _done(String where) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Quiz shared to $where',
          style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _sendingId = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't share. Try again.")));
  }

  String _chatName(Map<String, dynamic> r) {
    final isGroup = (r['room_type'] as String?) == 'group';
    return isGroup
        ? (r['name'] as String? ?? 'Group')
        : ((r['other_user'] as Map<String, dynamic>?)?['name'] as String?
            ?? 'Chat');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppC.border,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(children: [
              const Icon(Icons.ios_share_rounded, color: _kPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Share "${widget.title}"',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 16, color: AppC.text))),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPurple))
                : ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    children: [
                      if (_chats.isNotEmpty) _section('Your chats'),
                      ..._chats.map((r) => _row(
                            key: r['id']?.toString() ?? '',
                            emoji: (r['room_type'] == 'group') ? '👥' : '💬',
                            name: _chatName(r),
                            onTap: () => _shareToChat(r),
                          )),
                      if (_groups.isNotEmpty) _section('Study groups'),
                      ..._groups.map((g) => _row(
                            key: g['id']?.toString() ?? '',
                            emoji: (g['theme_icon'] as String?) ?? '📚',
                            name: g['name']?.toString() ?? 'Group',
                            onTap: () => _shareToGroup(g),
                          )),
                      if (_chats.isEmpty && _groups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: Text(
                              'No chats or study groups yet.',
                              style: TextStyle(fontFamily: 'Momo',
                                  color: AppC.sub))),
                        ),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(label.toUpperCase(),
            style: TextStyle(fontFamily: 'Arch', fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 1,
                color: AppC.sub)),
      );

  Widget _row({
    required String key,
    required String emoji,
    required String name,
    required VoidCallback onTap,
  }) {
    final sending = _sendingId == key;
    return InkWell(
      onTap: _sendingId == null ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppC.card2,
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Arch', fontSize: 14,
                  fontWeight: FontWeight.w600, color: AppC.text))),
          if (sending)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: _kPurple, strokeWidth: 2))
          else
            const Icon(Icons.send_rounded, color: _kPurple, size: 18),
        ]),
      ),
    );
  }
}
