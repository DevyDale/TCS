// lib/screens/feed/post_open_screen.dart
//
// Opens a single post by id (used when a like/comment/mention notification is
// tapped). Fetches /posts/<id>/ then hands off to the existing PostDetailScreen.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/profile/profile_screen.dart' show PostDetailScreen;

class PostOpenScreen extends StatefulWidget {
  final String postId;
  const PostOpenScreen({super.key, required this.postId});

  @override
  State<PostOpenScreen> createState() => _PostOpenScreenState();
}

class _PostOpenScreenState extends State<PostOpenScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/posts/${widget.postId}/')
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() { _post = data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'This post is no longer available.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppC.bg,
        appBar: AppBar(backgroundColor: AppC.card, elevation: 0,
            iconTheme: IconThemeData(color: AppC.text)),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF8E54E9))),
      );
    }
    if (_post == null) {
      return Scaffold(
        backgroundColor: AppC.bg,
        appBar: AppBar(backgroundColor: AppC.card, elevation: 0,
            iconTheme: IconThemeData(color: AppC.text)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inbox_rounded, size: 52, color: AppC.faint),
              const SizedBox(height: 14),
              T(_error ?? 'Not found',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Momo', color: AppC.sub)),
            ]),
          ),
        ),
      );
    }
    final p = _post!;
    return PostDetailScreen(
      post: p,
      isFweet: (p['post_type'] as String? ?? '') == 'fweet',
      authorName: (p['author_name'] as String? ?? 'Someone'),
      authorAvatar: p['author_avatar'] as String?,
    );
  }
}
