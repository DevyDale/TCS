// lib/screens/groups/group_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _indigo = Color(0xFF3F51B5);
const _deep   = Color(0xFF512DA8);

class GroupScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  const GroupScreen({super.key, required this.group});
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen>
    with SingleTickerProviderStateMixin {
  final _api    = ApiService();
  final _picker = ImagePicker();
  late final TabController _tabCtrl;

  final _msgCtrl = TextEditingController();
  final _addCtrl = TextEditingController();

  List<Map<String, dynamic>> _messages  = [];
  List<Map<String, dynamic>> _members   = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _addResults = [];

  bool _loadingMsgs  = true;
  bool _loadingMats  = true;
  bool _sendingMsg   = false;
  bool _searchingAdd = false;
  bool _isAdmin      = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _isAdmin = widget.group['is_admin'] as bool? ?? false;
    _loadMessages();
    _loadMembers();
    _loadMaterials();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _addCtrl.dispose();
    super.dispose();
  }

  String get _groupId   => widget.group['id']?.toString() ?? '';
  String get _groupName => widget.group['name'] as String? ?? 'Group';
  String get _icon      => widget.group['theme_icon'] as String? ?? '👥';

  // ── Data loading ──────────────────────────────────────────

  Future<void> _loadMessages() async {
    try {
      // FIX 1: /posts/ returns a paginated Map, not a List
      final data = await _api.get('/posts/',
          query: {'group_id': _groupId}) as Map<String, dynamic>;
      setState(() {
        _messages = (data['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loadingMsgs = false;
      });
    } catch (_) {
      setState(() => _loadingMsgs = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      // /groups/<id>/members/ returns a plain List
      final data = await _api.get('/groups/$_groupId/members/');
      setState(() {
        _members = (data as List).cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  Future<void> _loadMaterials() async {
    try {
      // FIX 2: getGroupMaterials returns a plain List, not a Map
      final data = await _api.getGroupMaterials(_groupId);
      setState(() {
        // data may be List or Map<results:List> — handle both
        if (data is List) {
          _materials = data.cast<Map<String, dynamic>>();
        } else if (data is Map) {
          _materials = ((data['results'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
        }
        _loadingMats = false;
      });
    } catch (_) {
      setState(() => _loadingMats = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _sendPost() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sendingMsg) return;
    HapticFeedback.lightImpact();
    setState(() => _sendingMsg = true);
    try {
      // FIX 3: createPost() has no groupId param — use post() directly
      final created = await _api.post('/posts/', body: {
        'content':    text,
        'post_type':  'post',
        'visibility': 'public',
        'group':      _groupId,
      }) as Map<String, dynamic>;
      setState(() {
        _messages.insert(0, created);
        _msgCtrl.clear();
        _sendingMsg = false;
      });
    } catch (_) {
      setState(() => _sendingMsg = false);
    }
  }

  Future<void> _uploadMaterial() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    final file = File(picked.first.path);
    try {
      final title = picked.first.name;
      // Upload via multipart
      final result = await _api.uploadPostMedia(_groupId, file);
      if (result != null) {
        _loadMaterials();
        _snack('Material uploaded ✓');
      }
    } catch (e) {
      _snack('Upload failed: $e');
    }
  }

  Future<void> _searchToAdd(String q) async {
    if (q.trim().isEmpty) {
      setState(() { _addResults = []; _searchingAdd = false; });
      return;
    }
    setState(() => _searchingAdd = true);
    try {
      final res = await _api.get('/groups/user-search/', query: {'q': q.trim()})
          as Map<String, dynamic>;
      setState(() {
        _addResults = (res['results'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _searchingAdd = false;
      });
    } catch (_) {
      setState(() => _searchingAdd = false);
    }
  }

  Future<void> _addMember(String userId) async {
    try {
      await _api.post('/groups/$_groupId/members/add/', body: {'user_id': userId});
      setState(() { _addCtrl.clear(); _addResults = []; });
      _loadMembers();
      _snack('Member added ✓');
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _removeMember(String userId) async {
    final ok = await _confirmDialog('Remove this member?');
    if (!ok) return;
    try {
      await _api.post('/groups/$_groupId/members/remove/',
          body: {'user_id': userId});
      _loadMembers();
      _snack('Member removed');
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _dissolveGroup() async {
    // Ask for reason
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dissolve Group',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Please state why you are dissolving this group.',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: reasonCtrl, autofocus: true, maxLines: 3,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Reason for dissolving...',
                hintStyle: TextStyle(fontFamily: 'Momo',
                    color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14))),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Momo'))),
          GestureDetector(
            onTap: () {
              if (reasonCtrl.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonCtrl.text.trim());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                  color: _kG4, borderRadius: BorderRadius.circular(10)),
              child: const Text('Dissolve',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty || !mounted) return;

    try {
      // FIX 4: delete() has no body param — use patch() to set is_active=false
      // The backend GroupDetailView.destroy() reads request.data["reason"]
      // We workaround by calling PATCH then DELETE separately, or use a
      // dedicated dissolve approach via PATCH:
      await _api.patch('/groups/$_groupId/', body: {
        'dissolve_reason': reason,
        'is_active':       false,
      });
      if (mounted) Navigator.pop(context, 'dissolved');
    } catch (e) {
      _snack('Failed: $e');
    }
  }

  Future<void> _saveMaterial(Map<String, dynamic> mat) async {
    try {
      await _api.post('/chat/saved/save/', body: {
        'title':     mat['title'] ?? '',
        'file_url':  mat['file_url'] ?? '',
        'file_name': mat['file_name'] ?? '',
        'file_type': mat['file_type'] ?? '',
      });
      _snack('Material saved ✓');
    } catch (e) {
      _snack('Could not save: $e');
    }
  }

  Future<bool> _confirmDialog(String msg) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(msg,
                style: const TextStyle(fontFamily: 'Alfa', fontSize: 17)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel',
                      style: TextStyle(fontFamily: 'Momo'))),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes',
                      style: TextStyle(
                          fontFamily: 'Momo', color: _kG4))),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _indigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            _buildChatTab(),
            _buildMembersTab(),
            _buildMaterialsTab(),
          ]),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 8, right: 16, bottom: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _deep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight)),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 12),
        Text(_icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_groupName,
                style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: Colors.white)),
            Text('${_members.length} members',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.white.withOpacity(0.7))),
          ]),
        ),
        if (_isAdmin)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'dissolve') _dissolveGroup();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'dissolve',
                child: Row(children: [
                  Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Dissolve Group',
                      style: TextStyle(fontFamily: 'Momo', color: Colors.red)),
                ]),
              ),
            ],
          ),
      ]),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: _indigo,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _indigo,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
            fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontFamily: 'Arch', fontSize: 13),
        tabs: const [
          Tab(text: 'Chat'),
          Tab(text: 'Members'),
          Tab(text: 'Materials'),
        ],
      ),
    );
  }

  // ── Chat tab ──────────────────────────────────────────────

  Widget _buildChatTab() {
    return Column(children: [
      Expanded(
        child: _loadingMsgs
            ? const Center(
                child: CircularProgressIndicator(color: _indigo))
            : _messages.isEmpty
                ? Center(
                    child: Text('No posts yet — start the conversation!',
                        style: TextStyle(
                            fontFamily: 'Momo',
                            color: Colors.grey.shade400)))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(
                                m['author_name'] as String? ?? 'Unknown',
                                style: const TextStyle(
                                    fontFamily: 'Arch',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _indigo)),
                              const Spacer(),
                              Text(
                                _timeAgo(m['created_at'] as String? ?? ''),
                                style: TextStyle(
                                    fontFamily: 'Momo',
                                    fontSize: 10,
                                    color: Colors.grey.shade400)),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                              m['content'] as String? ?? '',
                              style: const TextStyle(
                                  fontFamily: 'Momo',
                                  fontSize: 14,
                                  color: Color(0xFF1A1A2E),
                                  height: 1.4)),
                          ],
                        ),
                      );
                    },
                  ),
      ),

      // Message input bar
      Container(
        padding: EdgeInsets.fromLTRB(
            12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
              top: BorderSide(color: Colors.grey.shade100))),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _msgCtrl,
                enableSuggestions: false,
                autocorrect: false,
                style: const TextStyle(
                    fontFamily: 'Momo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Post to the group...',
                  hintStyle: TextStyle(
                      fontFamily: 'Momo',
                      color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12)),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendPost,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: _msgCtrl.text.trim().isNotEmpty
                    ? const LinearGradient(colors: [_indigo, _deep])
                    : const LinearGradient(
                        colors: [Color(0xFFDDDDDD), Color(0xFFCCCCCC)]),
                shape: BoxShape.circle),
              child: _sendingMsg
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20)),
          ),
        ]),
      ),
    ]);
  }

  // ── Members tab ───────────────────────────────────────────

  Widget _buildMembersTab() {
    return Column(children: [
      if (_isAdmin) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: _addCtrl,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: _searchToAdd,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search & add members...',
                hintStyle: TextStyle(
                    fontFamily: 'Momo', color: Colors.grey.shade400),
                prefixIcon: _searchingAdd
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _indigo)))
                    : const Icon(Icons.person_add_rounded,
                        color: _indigo),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),

        // Search results dropdown
        if (_addResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: _addResults.take(5).map((u) {
                final name    = u['name'] as String? ?? '';
                final initial = name.isNotEmpty
                    ? name[0].toUpperCase() : '?';
                return ListTile(
                  leading: Container(
                    width: 34, height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [_kG1, _kG2])),
                    child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold)))),
                  title: Text(name,
                      style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: Text(u['role'] as String? ?? '',
                      style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                  trailing: GestureDetector(
                    onTap: () =>
                        _addMember(u['user_id'] as String? ?? ''),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Text('Add',
                          style: TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _indigo)))),
                );
              }).toList(),
            ),
          ),
      ],

      // Members list
      Expanded(
        child: _members.isEmpty
            ? Center(
                child: Text('No members yet',
                    style: TextStyle(
                        fontFamily: 'Momo',
                        color: Colors.grey.shade400)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final m       = _members[i];
                  final name    = m['name'] as String? ?? '';
                  final initial = name.isNotEmpty
                      ? name[0].toUpperCase() : '?';
                  final isAdm   = m['is_admin'] as bool? ?? false;
                  final userId  = m['user_id'] as String? ?? '';

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [_kG1, _kG2])),
                      child: Center(
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Arch',
                                fontWeight: FontWeight.bold,
                                fontSize: 17)))),
                    title: Text(name,
                        style: const TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E))),
                    subtitle: Text(m['role'] as String? ?? '',
                        style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                    trailing: isAdm
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(6)),
                            child: const Text('Admin',
                                style: TextStyle(
                                    fontFamily: 'Momo',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _indigo)))
                        : _isAdmin
                            ? GestureDetector(
                                onTap: () => _removeMember(userId),
                                child: Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: _kG4.withOpacity(0.6),
                                    size: 22))
                            : null,
                  );
                },
              ),
      ),
    ]);
  }

  // ── Materials tab ─────────────────────────────────────────

  Widget _buildMaterialsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: _uploadMaterial,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_indigo, _deep]),
              borderRadius: BorderRadius.circular(14)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Upload Material',
                    style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),

      Expanded(
        child: _loadingMats
            ? const Center(
                child: CircularProgressIndicator(color: _indigo))
            : _materials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        Text('No materials yet',
                            style: TextStyle(
                                fontFamily: 'Alfa',
                                fontSize: 16,
                                color: Colors.grey.shade400)),
                        const SizedBox(height: 6),
                        Text('Upload PDFs, notes, audio files…',
                            style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 12,
                                color: Colors.grey.shade400)),
                      ],
                    ))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _materials.length,
                    itemBuilder: (_, i) {
                      final mat  = _materials[i];
                      final type = mat['file_type'] as String? ?? '';
                      final icon = _fileIcon(type);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6)
                          ],
                        ),
                        child: Row(children: [
                          // File icon tile
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(12)),
                            child: Center(
                              child: Text(icon,
                                  style: const TextStyle(
                                      fontSize: 22)))),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mat['title'] as String? ?? '',
                                  style: const TextStyle(
                                      fontFamily: 'Arch',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1A1A2E)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Text(
                                  'By ${mat['uploaded_by_name'] ?? ''}  ·  '
                                  '${_fmtSize(mat['file_size'])}',
                                  style: TextStyle(
                                      fontFamily: 'Momo',
                                      fontSize: 11,
                                      color: Colors.grey.shade500)),
                              ],
                            ),
                          ),

                          // Save button
                          GestureDetector(
                            onTap: () => _saveMaterial(mat),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _indigo.withOpacity(0.08),
                                borderRadius:
                                    BorderRadius.circular(10)),
                              child: const Icon(
                                  Icons.bookmark_add_outlined,
                                  color: _indigo, size: 20))),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }

  // ── Helpers ───────────────────────────────────────────────

  String _fileIcon(String type) {
    if (type.contains('pdf'))   return '📄';
    if (type.contains('audio')) return '🎵';
    if (type.contains('image')) return '🖼️';
    if (type.contains('video')) return '🎬';
    if (type.contains('word') || type.contains('doc')) return '📝';
    return '📎';
  }

  String _fmtSize(dynamic bytes) {
    if (bytes == null) return '';
    final b = bytes as int;
    if (b >= 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final diff =
          DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inSeconds < 60)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}