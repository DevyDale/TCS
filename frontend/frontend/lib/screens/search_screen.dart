// lib/screens/search/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _api   = ApiService();
  final _ctrl  = TextEditingController();
  late final TabController _tabCtrl;
  Timer? _debounce;

  List<Map<String, dynamic>> _posts   = [];
  List<Map<String, dynamic>> _people  = [];
  List<Map<String, dynamic>> _groups  = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _posts = []; _people = []; _groups = []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    if (q == _lastQuery || q.isEmpty) return;
    _lastQuery = q;
    setState(() => _loading = true);
    try {
      final res = await _api.get('/posts/search/', query: {'q': q, 'type': 'all'})
          as Map<String, dynamic>;
      setState(() {
        _posts  = (res['posts']  as List? ?? []).cast<Map<String, dynamic>>();
        _people = (res['people'] as List? ?? []).cast<Map<String, dynamic>>();
        _groups = (res['groups'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        _buildSearchBar(),
        _buildTabBar(),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kG2))
            : TabBarView(controller: _tabCtrl, children: [
                _buildPostResults(),
                _buildPeopleResults(),
                _buildGroupResults(),
              ])),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 8, right: 16, bottom: 12,
      ),
      color: Colors.white,
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E), size: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              enableSuggestions: false,
              onChanged: _onChanged,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 15,
                  color: Color(0xFF1A1A2E)),
              decoration: InputDecoration(
                hintText: 'Search posts, people, clubs...',
                hintStyle: TextStyle(fontFamily: 'Momo', color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _ctrl.clear(); setState(() { _posts=[]; _people=[]; _groups=[]; }); },
                        child: Icon(Icons.close_rounded, color: Colors.grey.shade400))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelStyle: const TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Arch', fontSize: 13),
        labelColor: _kG2,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _kG2,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          Tab(text: 'Posts (${_posts.length})'),
          Tab(text: 'People (${_people.length})'),
          Tab(text: 'Groups (${_groups.length})'),
        ],
      ),
    );
  }

  Widget _buildPostResults() {
    if (_ctrl.text.isEmpty) return _emptyState('Search for posts', Icons.article_outlined, _kG2);
    if (_posts.isEmpty && !_loading) {
      return _emptyState('No posts found', Icons.article_outlined, _kG2);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length,
      itemBuilder: (_, i) {
        final p = _posts[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _avatar(p['author_avatar'] as String?, p['author_name'] as String?, _kG2, 34),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['author_name'] as String? ?? '', style: const TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 13, color: Color(0xFF1A1A2E))),
                Text(p['post_type'] as String? ?? '', style: TextStyle(
                    fontFamily: 'Momo', fontSize: 11, color: Colors.grey.shade400)),
              ])),
              _pill(p['post_type'] as String? ?? '', _kG2),
            ]),
            const SizedBox(height: 10),
            Text(p['content'] as String? ?? '', maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Momo', fontSize: 14,
                    color: Color(0xFF1A1A2E), height: 1.4)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.favorite_outline_rounded, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('${p['like_count'] ?? 0}', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11, color: Colors.grey.shade400)),
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('${p['comment_count'] ?? 0}', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11, color: Colors.grey.shade400)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildPeopleResults() {
    if (_ctrl.text.isEmpty) return _emptyState('Search for people', Icons.people_outline, _kG3);
    if (_people.isEmpty && !_loading) {
      return _emptyState('No people found', Icons.people_outline, _kG3);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _people.length,
      itemBuilder: (_, i) {
        final u = _people[i];
        final isFollowing = u['is_following'] as bool? ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            _avatar(u['avatar_url'] as String?, u['name'] as String?, _kG1, 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['name'] as String? ?? '', style: const TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14, color: Color(0xFF1A1A2E))),
              Text(u['role'] as String? ?? '', style: TextStyle(
                  fontFamily: 'Momo', fontSize: 12, color: Colors.grey.shade500)),
            ])),
            GestureDetector(
              onTap: () async {
                await _api.followToggle(u['user_id'] as String? ?? '');
                setState(() => _people[i] = {..._people[i], 'is_following': !isFollowing});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: isFollowing ? null : const LinearGradient(colors: [_kG1, _kG2]),
                  color: isFollowing ? Colors.grey.shade100 : null,
                  borderRadius: BorderRadius.circular(10),
                  border: isFollowing ? Border.all(color: Colors.grey.shade300) : null,
                ),
                child: Text(isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 12, color: isFollowing ? Colors.grey.shade600 : Colors.white)),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildGroupResults() {
    if (_ctrl.text.isEmpty) return _emptyState('Search for groups', Icons.groups_outlined, _kG4);
    if (_groups.isEmpty && !_loading) {
      return _emptyState('No groups found', Icons.groups_outlined, _kG4);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (_, i) {
        final g = _groups[i];
        final isMember = g['is_member'] as bool? ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _kG4.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('👥', style: TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['name'] as String? ?? '', style: const TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  fontSize: 14, color: Color(0xFF1A1A2E))),
              Text('${g['members_count'] ?? 0} members · ${g['category'] ?? ''}',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: Colors.grey.shade500)),
            ])),
            GestureDetector(
              onTap: () async {
                if (!isMember) {
                  await _api.joinGroup(g['id'] as String? ?? '');
                  setState(() => _groups[i] = {..._groups[i], 'is_member': true});
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isMember ? Colors.green.shade50 : _kG4.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMember ? Colors.green.shade300 : _kG4.withOpacity(0.3)),
                ),
                child: Text(isMember ? 'Joined ✓' : 'Join',
                    style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                        fontSize: 12, color: isMember ? Colors.green.shade700 : _kG4)),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _emptyState(String label, IconData icon, Color color) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 52, color: color.withOpacity(0.25)),
      const SizedBox(height: 14),
      Text(label, style: TextStyle(fontFamily: 'Alfa', fontSize: 16, color: color.withOpacity(0.5))),
    ]));
  }

  Widget _avatar(String? url, String? name, Color color, double size) {
    final initial = (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
        image: url != null && url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
      ),
      child: url == null || url.isEmpty
          ? Center(child: Text(initial, style: TextStyle(color: Colors.white,
              fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: size * 0.4)))
          : null,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontFamily: 'Momo', fontSize: 9,
          fontWeight: FontWeight.bold, color: color)),
    );
  }
}