// lib/screens/groups/group_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';

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

  // ── Identity (collected from every possible field name) ──
  final Set<String> _myIds   = <String>{};
  final Set<String> _myNames = <String>{};   // lowercase, trimmed
  bool _isCreator = false;

  final _msgCtrl = TextEditingController();
  final _addCtrl = TextEditingController();

  List<Map<String, dynamic>> _messages   = [];
  List<Map<String, dynamic>> _members    = [];
  List<Map<String, dynamic>> _materials  = [];
  List<Map<String, dynamic>> _addResults = [];

  Map<String, dynamic>? _replyingTo;

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
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadMe();          // gather all id / name variants
    await _loadGroupMeta();   // authoritative is_creator
    await _loadMessages();
    _loadMembers();
    _loadMaterials();
  }

  // Pull every possible identifier and name variant for the current
  // user. We hit /auth/me/ first because the cached blob in SharedPrefs
  // is often abbreviated (e.g. user_id only) — but post objects might
  // expose author by a different key (id, pk, author.user_id, ...).
  // By collecting EVERY id and EVERY name into a Set, the match in
  // _computeIsMe becomes resilient regardless of which key the
  // serializer picked.
  Future<void> _loadMe() async {
    Map<String, dynamic>? me;
    try {
      final res = await _api.get('/auth/me/');
      if (res is Map) me = Map<String, dynamic>.from(res);
    } catch (_) {}
    me ??= await _api.cachedUser;
    if (me == null) return;

    // Every key the backend might call the user's id
    const idKeys = ['user_id', 'id', 'pk', 'uuid'];
    for (final k in idKeys) {
      final v = me[k]?.toString().trim();
      if (v != null && v.isNotEmpty) _myIds.add(v);
    }

    // Every key the backend might call the user's name
    const nameKeys = [
      'display_name', 'preferred_name', 'name',
      'full_name', 'first_name', 'username',
    ];
    for (final k in nameKeys) {
      final v = (me[k] as String?)?.trim().toLowerCase();
      if (v != null && v.isNotEmpty) _myNames.add(v);
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadGroupMeta() async {
    bool creator = false;
    try {
      final g = await _api.get('/groups/$_groupId/');
      if (g is Map) {
        final cbId = (g['created_by_id'] ??
                      g['created_by']?['user_id'] ??
                      g['created_by'])?.toString();
        creator = (g['is_creator'] as bool?) ??
                  (cbId != null && _myIds.contains(cbId));
      }
    } catch (_) {
      creator = (widget.group['is_creator'] as bool?) ?? false;
    }
    if (mounted) setState(() => _isCreator = creator);
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _api.get('/posts/',
          query: {'group_id': _groupId}) as Map<String, dynamic>;
      final rawList = (data['results'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final msg in rawList) {
        msg['is_me'] = _computeIsMe(msg);
      }
      setState(() {
        _messages    = rawList;
        _loadingMsgs = false;
      });
    } catch (_) {
      setState(() => _loadingMsgs = false);
    }
  }

  /// Bulletproof "is this message mine?" check. Compares every possible
  /// author identifier on the message against every possible identifier
  /// we know about the current user.
  bool _computeIsMe(Map<String, dynamic> m) {
    if (m['is_me'] == true) return true;

    // 1) Flat id fields on the message
    const idFields = [
      'author_id', 'author', 'user_id',
      'created_by', 'created_by_id', 'author_user_id',
      'sender_id',
    ];
    for (final f in idFields) {
      final v = m[f];
      if (v != null && v is! Map) {
        final s = v.toString().trim();
        if (s.isNotEmpty && _myIds.contains(s)) return true;
      }
    }

    // 2) Nested author map
    if (m['author'] is Map) {
      final a = m['author'] as Map;
      for (final k in ['user_id', 'id', 'pk']) {
        final v = a[k]?.toString().trim();
        if (v != null && v.isNotEmpty && _myIds.contains(v)) return true;
      }
      final aName = (a['name'] as String?)?.trim().toLowerCase();
      if (aName != null && aName.isNotEmpty && _myNames.contains(aName)) {
        return true;
      }
    }

    // 3) author_name fallback
    final authorName = (m['author_name'] as String?)?.trim().toLowerCase();
    if (authorName != null && authorName.isNotEmpty &&
        _myNames.contains(authorName)) {
      return true;
    }

    return false;
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

  Future<void> _loadMembers() async {
    try {
      final data = await _api.get('/groups/$_groupId/members/');
      setState(() => _members = (data as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _loadMaterials() async {
    try {
      final data = await _api.getGroupMaterials(_groupId);
      setState(() {
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

  // ── Activity emit (fire-and-forget) ───────────────────────

  void _emitActivity({
    required String eventType,
    String message = '',
    String? targetName,
  }) {
    _api.post('/activity/', body: {
      'event_type':  eventType,
      'target_type': 'group',
      'target_id':   _groupId,
      'target_name': targetName ?? _groupName,
      if (message.isNotEmpty) 'message': message,
    }).catchError((_) {});
  }

  // ── Send post (with optional reply) ───────────────────────

  Future<void> _sendPost() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sendingMsg) return;
    HapticFeedback.lightImpact();
    setState(() => _sendingMsg = true);

    final reply = _replyingTo;

    String content = text;
    if (reply != null) {
      final qAuthor = (reply['author_name'] as String?) ?? 'someone';
      final qText   = ((reply['content'] as String?) ?? '').trim();
      final preview = qText.length > 120 ? '${qText.substring(0, 117)}…' : qText;
      content = '↩️ @$qAuthor: $preview\n\n$text';
    }

    try {
      final body = {
        'content':    content,
        'post_type':  'post',
        'visibility': 'public',
        'group':      _groupId,
        if (reply != null) 'parent_id': reply['id']?.toString(),
      };
      final created = await _api.post('/posts/', body: body) as Map<String, dynamic>;

      if (reply != null) {
        created['reply_to'] = {
          'id':          reply['id'],
          'author_name': reply['author_name'],
          'content':     (reply['content'] as String?) ?? '',
        };
        created['content'] = text;
      }
      created['is_me'] = true; // we just sent it, force alignment right

      setState(() {
        _messages.insert(0, created);
        _msgCtrl.clear();
        _replyingTo = null;
        _sendingMsg = false;
      });
    } catch (_) {
      setState(() => _sendingMsg = false);
    }
  }

  // ── Share link (BOTTOM SHEET) ─────────────────────────────

  Future<void> _shareLink() async {
    final ctrl = TextEditingController();
    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kG2.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.link_rounded, color: _kG2, size: 20)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Share a Link',
                  style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 18, color: Color(0xFF1A1A2E)))),
            ]),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.url,
                style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'https://example.com',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Cancel',
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E), fontSize: 13))),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_indigo, _deep]),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Share',
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          color: Colors.white, fontSize: 13))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );

    if (url == null || url.isEmpty) return;
    try {
      await _api.post('/groups/$_groupId/materials/', body: {
        'title':        url,
        'file_type':    'link',
        'external_url': url,
      });
      _loadMaterials();
      _emitActivity(eventType: 'material_shared', message: 'shared a link');
      _snack('Link shared');
    } catch (e) {
      _snack('Could not share link: $e');
    }
  }

  // ── Upload photo / video ──────────────────────────────────

  Future<void> _uploadMedia() async {
    final picked = await _picker.pickMedia(requestFullMetadata: false);
    if (picked == null) return;

    final path  = picked.path;
    final lower = path.toLowerCase();
    final isVid = lower.endsWith('.mp4') ||
                  lower.endsWith('.mov')  ||
                  lower.endsWith('.webm');
    final ext = path.split('.').last.toLowerCase();
    final mime = isVid
        ? 'video/$ext'
        : (ext == 'png' ? 'image/png'
           : ext == 'gif' ? 'image/gif' : 'image/jpeg');

    try {
      final fileName = path.split('/').last;
      final result = await _api.uploadFile(
        '/groups/$_groupId/materials/',
        filePath:    path,
        field:       'file',
        mimeType:    mime,
        extraFields: {'title': fileName},
      );
      if (result != null) {
        _loadMaterials();
        _emitActivity(
          eventType: 'material_shared',
          message:   'shared a ${isVid ? 'video' : 'photo'}: $fileName',
        );
        _snack('${isVid ? 'Video' : 'Photo'} uploaded ✓');
      }
    } catch (e) {
      _snack('Upload failed: $e');
    }
  }

  // ── Upload document ───────────────────────────────────────

  Future<void> _uploadDocument() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv',
      ],
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.first;
    if (pf.path == null) {
      _snack('Could not read file path');
      return;
    }

    final ext = (pf.extension ?? '').toLowerCase();
    String mime = 'application/octet-stream';
    if (ext == 'pdf')                          mime = 'application/pdf';
    else if (ext == 'doc' || ext == 'docx')    mime = 'application/msword';
    else if (ext == 'xls' || ext == 'xlsx')    mime = 'application/vnd.ms-excel';
    else if (ext == 'ppt' || ext == 'pptx')    mime = 'application/vnd.ms-powerpoint';
    else if (ext == 'txt')                     mime = 'text/plain';
    else if (ext == 'csv')                     mime = 'text/csv';

    try {
      final result = await _api.uploadFile(
        '/groups/$_groupId/materials/',
        filePath:    pf.path!,
        field:       'file',
        mimeType:    mime,
        extraFields: {'title': pf.name},
      );
      if (result != null) {
        _loadMaterials();
        _emitActivity(
          eventType: 'material_shared',
          message:   'shared "${pf.name}"',
        );
        _snack('Document uploaded ✓');
      }
    } catch (e) {
      _snack('Upload failed: $e');
    }
  }

  // ── Members ───────────────────────────────────────────────

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

  // ── Dissolve (creator only, BOTTOM SHEET reason) ──────────

  Future<void> _dissolveGroup() async {
    if (!_isCreator) {
      _snack('Only the group creator can dissolve this group.');
      return;
    }

    final reasonCtrl = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kG4.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_forever_rounded,
                    color: _kG4, size: 20)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Dissolve Group',
                  style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 18, color: Color(0xFF1A1A2E)))),
            ]),
            const SizedBox(height: 8),
            Text(
              'All shared materials will be saved to your Digital Library '
              'before the group is removed.',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12.5, color: Colors.grey.shade600, height: 1.4)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
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
                  contentPadding: const EdgeInsets.all(14)),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Cancel',
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E), fontSize: 13))),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () {
                  final v = reasonCtrl.text.trim();
                  if (v.isNotEmpty) Navigator.pop(ctx, v);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _kG4,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('Dissolve',
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          color: Colors.white, fontSize: 13))),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );

    if (reason == null || reason.isEmpty || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: _kG4),
            const SizedBox(height: 16),
            Text('Archiving materials & dissolving...',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 13, color: Colors.grey.shade700)),
          ]),
        ),
      ),
    );

    // Save every material to library first
    final saves = <Future>[];
    for (final mat in _materials) {
      saves.add(
        _api.post('/chat/saved/save/', body: {
          'title':              mat['title']     ?? '',
          'file_url':           mat['file_url']  ?? mat['external_url'] ?? '',
          'file_name':          mat['file_name'] ?? '',
          'file_type':          mat['file_type'] ?? '',
          'subject':            widget.group['theme'] ?? widget.group['category'] ?? '',
          'source_group_name':  _groupName,
          'source_type':        'group_dissolved',
        }).catchError((_) => null),
      );
    }
    await Future.wait(saves);

    try {
      await _api.delete('/groups/$_groupId/', body: {'reason': reason});
      _emitActivity(eventType: 'group_dissolved', message: reason);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) Navigator.pop(context, 'dissolved');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('Failed: $e');
    }
  }

  // ── Save material to library (per-item) ───────────────────

  Future<void> _saveMaterial(Map<String, dynamic> mat) async {
    try {
      await _api.post('/chat/saved/save/', body: {
        'title':              mat['title']     ?? '',
        'file_url':           mat['file_url']  ?? mat['external_url'] ?? '',
        'file_name':          mat['file_name'] ?? '',
        'file_type':          mat['file_type'] ?? '',
        'subject':            widget.group['theme'] ?? widget.group['category'] ?? '',
        'source_group_name':  _groupName,
        'source_type':        'group',
      });
      _snack('Material saved ✓');
    } catch (e) {
      _snack('Could not save: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────

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
                      style: TextStyle(fontFamily: 'Momo', color: _kG4))),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 8, right: 8, bottom: 14),
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
        const SizedBox(width: 8),
        Text(_icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_groupName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: Colors.white)),
            Text('${_members.length} members',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.white.withOpacity(0.7))),
          ]),
        ),
        if (_isCreator)
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

  Widget _buildChatTab() {
    return Column(children: [
      Expanded(
        child: _loadingMsgs
            ? const Center(child: CircularProgressIndicator(color: _indigo))
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
                      final isMe = _computeIsMe(m);
                      return _buildMessageBubble(m, isMe);
                    },
                  ),
      ),

      if (_replyingTo != null) _buildReplyBar(),

      Container(
        padding: EdgeInsets.fromLTRB(
            12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100))),
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
                style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: _replyingTo == null
                      ? 'Post to the group...'
                      : 'Reply to ${_replyingTo!['author_name'] ?? 'message'}...',
                  hintStyle: TextStyle(
                      fontFamily: 'Momo', color: Colors.grey.shade400),
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

  Widget _buildReplyBar() {
    final r = _replyingTo!;
    final author = (r['author_name'] as String?) ?? 'Unknown';
    final text   = ((r['content'] as String?) ?? '').replaceAll('\n', ' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Container(width: 3, height: 36,
          decoration: BoxDecoration(
            color: _indigo, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Replying to $author',
                style: const TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    color: _indigo, fontSize: 12)),
            const SizedBox(height: 2),
            Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo',
                    color: Colors.grey.shade600, fontSize: 12)),
          ])),
        IconButton(
          onPressed: () => setState(() => _replyingTo = null),
          icon: const Icon(Icons.close_rounded, size: 20),
          color: Colors.grey),
      ]),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> m, bool isMe) {
    final reply = m['reply_to'] as Map?;

    var content = (m['content'] as String?) ?? '';
    if (reply == null && content.startsWith('↩️ @')) {
      final breakIdx = content.indexOf('\n\n');
      if (breakIdx > 0) content = content.substring(breakIdx + 2);
    }

    return GestureDetector(
      onLongPress: () => _showMessageActions(m),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            bottom: 12,
            left:  isMe ? 64 : 0,
            right: isMe ? 0  : 64,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? _indigo : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(16),
              topRight:    const Radius.circular(16),
              bottomLeft:  Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4  : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    m['author_name'] as String? ?? 'Unknown',
                    style: const TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _indigo,
                    ),
                  ),
                ),
              if (reply != null) _buildQuotedBlock(reply, isMe),
              Text(
                content,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 15,
                  height: 1.4,
                  color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _timeAgo(m['created_at'] as String? ?? ''),
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 10,
                  color: isMe
                      ? Colors.white.withOpacity(0.85)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotedBlock(Map reply, bool isMe) {
    final author = (reply['author_name'] as String?) ?? 'Unknown';
    final text   = ((reply['content'] as String?) ?? '').replaceAll('\n', ' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      constraints: const BoxConstraints(minWidth: 120),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.18)
            : _indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : _indigo,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(author,
              style: TextStyle(
                  fontFamily: 'Arch',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white : _indigo)),
          const SizedBox(height: 2),
          Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  color: isMe
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey.shade700)),
        ],
      ),
    );
  }

  void _showMessageActions(Map<String, dynamic> m) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: _indigo),
              title: const Text('Reply',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: _indigo),
              title: const Text('Copy text',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 14)),
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: (m['content'] as String?) ?? ''));
                Navigator.pop(ctx);
                _snack('Copied');
              },
            ),
            const SizedBox(height: 8),
          ])),
      ),
    );
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
                    : const Icon(Icons.person_add_rounded, color: _indigo),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
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
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                return ListTile(
                  leading: Container(
                    width: 34, height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_kG1, _kG2])),
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
                    onTap: () => _addMember(u['user_id'] as String? ?? ''),
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
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  final isAdm   = m['is_admin'] as bool? ?? false;
                  final userId  = m['user_id'] as String? ?? '';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      width: 42, height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_kG1, _kG2])),
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
                              borderRadius: BorderRadius.circular(6)),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          _matBtn(label: 'Photo / Video', icon: Icons.photo_camera_rounded,
              color: _kG3, onTap: _uploadMedia),
          const SizedBox(width: 8),
          _matBtn(label: 'Document', icon: Icons.description_rounded,
              color: _indigo, onTap: _uploadDocument),
          const SizedBox(width: 8),
          _matBtn(label: 'Link', icon: Icons.link_rounded,
              color: _kG2, onTap: _shareLink, outlined: true),
        ]),
      ),
      Expanded(
        child: _loadingMats
            ? const Center(child: CircularProgressIndicator(color: _indigo))
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
                        Text('Upload photos, videos, docs or links',
                            style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 12,
                                color: Colors.grey.shade400)),
                      ],
                    ))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
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
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6)],
                        ),
                        child: Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: _indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                            child: Center(
                              child: Text(icon,
                                  style: const TextStyle(fontSize: 22)))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          GestureDetector(
                            onTap: () => _saveMaterial(mat),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _indigo.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10)),
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

  Widget _matBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: outlined
                ? null
                : LinearGradient(colors: [color.withOpacity(0.85), color]),
            color: outlined ? Colors.white : null,
            border: outlined ? Border.all(color: color, width: 1.5) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: outlined
                ? null
                : [BoxShadow(color: color.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: outlined ? color : Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: outlined ? color : Colors.white)),
          ]),
        ),
      ),
    );
  }

  String _fileIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('pdf'))                              return '📄';
    if (t.contains('audio'))                            return '🎵';
    if (t.contains('image') || t.contains('photo'))     return '🖼️';
    if (t.contains('video'))                            return '🎬';
    if (t.contains('word') || t.contains('doc'))        return '📝';
    if (t.contains('excel') || t.contains('xls') ||
        t.contains('sheet') || t.contains('csv'))       return '📊';
    if (t.contains('ppt') || t.contains('present'))     return '📽️';
    if (t.contains('link'))                             return '🔗';
    return '📎';
  }

  String _fmtSize(dynamic bytes) {
    if (bytes == null) return '';
    final b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b >= 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inSeconds < 60)  return 'Just now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)    return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}