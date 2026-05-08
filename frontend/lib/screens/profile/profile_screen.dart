// lib/screens/profile/profile_screen.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../../models/biodata.dart';
import '../../services/api_service.dart';
import '../bio.dart';
import '../createpostspage.dart';
import '../fweetspage.dart';
import '../interests.dart';
import '../media_item_view.dart';
import '../privacy_toggle_sheet.dart';
import '../share_profile_screen.dart';


const _kG1  = Color(0xFF6DD5FA);
const _kG2  = Color(0xFF8E54E9);
const _kG3  = Color(0xFFF7971E);
const _kG4  = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);
const _kBg  = Color(0xFFF2F4F8);

// ── Global notifier ───────────────────────────────────────────
final deletedPostIds = ValueNotifier<Set<String>>({});
void notifyPostDeleted(String id) =>
    deletedPostIds.value = {...deletedPostIds.value, id};

// ─────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  final String fullName;
  final String preferredName;
  final String role;
  const ProfileScreen({
    super.key,
    required this.fullName,
    required this.preferredName,
    required this.role,
  });
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _api    = ApiService();
  final _picker = ImagePicker();
  late final TabController _tabCtrl;

  List<Map<String, dynamic>> _posts     = [];
  List<Map<String, dynamic>> _fweets    = [];
  List<Map<String, dynamic>> _favorites = [];
  final List<String>         _interests = [];

  int  _followers = 0;
  int  _following = 0;
  bool _postsLoading     = true;
  bool _fweetsLoading    = true;
  bool _favoritesLoading = true;

  // Phase 3: my own user_id, populated from getMyProfile().
  // Needed so the share-profile bottom sheet can embed the right user
  // when sharing my own profile to a chat.
  String? _myUserId;

  // Phase 3: visibility settings, mirrored from the backend.
  // bio_public lives under privacy_settings; interests_visibility
  // is its own top-level field on the user model. Both are loaded in
  // _fetchStats() and persisted via api_service helpers
  // (setBioPublic / setInterestsVisibility) introduced in Section 1.
  bool   _bioPublic    = true;
  String _interestsVis = 'public';

  // Guard so we only seed _interests from the backend on the FIRST
  // /me/ response — otherwise a later refetch could overwrite changes
  // the user just made via the InterestsPage editor.
  bool _interestsSeeded = false;

  BioData? _bioData;

  // ── Image state ───────────────────────────────────────────
  // Local File for instant display while upload is in flight.
  // Cloudinary URL is persisted to SharedPreferences once upload succeeds.
  File?   _avatarFile;
  String? _avatarUrl;
  File?   _coverFile;
  String? _coverUrl;
  bool    _avatarUploading = false;
  bool    _coverUploading  = false;

  static const _kAvatarUrl = 'profile_avatar_cloudinary_url';
  static const _kCoverUrl  = 'profile_cover_cloudinary_url';
  static const _kCoverH    = 220.0;
  static const _kAvatarR   = 52.0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadSavedUrls();
    _fetchPosts();
    _fetchFweets();
    _fetchFavorites();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data fetches ──────────────────────────────────────────

  Future<void> _fetchPosts() async {
    setState(() => _postsLoading = true);
    try {
      final d = await _api.getMyPosts() as Map<String, dynamic>;
      setState(() {
        _posts        = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _postsLoading = false;
      });
    } catch (_) { setState(() => _postsLoading = false); }
  }

  Future<void> _fetchFweets() async {
    setState(() => _fweetsLoading = true);
    try {
      final d = await _api.getMyFweets() as Map<String, dynamic>;
      setState(() {
        _fweets        = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _fweetsLoading = false;
      });
    } catch (_) { setState(() => _fweetsLoading = false); }
  }

  Future<void> _fetchFavorites() async {
    setState(() => _favoritesLoading = true);
    try {
      final d = await _api.getFavorites() as Map<String, dynamic>;
      setState(() {
        _favorites        = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _favoritesLoading = false;
      });
    } catch (_) { setState(() => _favoritesLoading = false); }
  }

  Future<void> _fetchStats() async {
    try {
      final d = await _api.getMyProfile() as Map<String, dynamic>;
      setState(() {
        _followers = d['followers_count'] as int? ?? 0;
        _following = d['following_count'] as int? ?? 0;

        // Phase 3: capture my own user_id for the share sheet.
        final uid = d['user_id'] as String?;
        if (uid != null && uid.isNotEmpty) _myUserId = uid;

        // Phase 3: visibility settings.
        final ps = (d['privacy_settings'] as Map?)?.cast<String, dynamic>()
            ?? const {};
        _bioPublic    = ps['bio_public'] as bool? ?? true;
        _interestsVis = d['interests_visibility'] as String? ?? 'public';

        // Phase 3: seed _interests from the backend on the FIRST fetch
        // only. The interests editor (_openInterests) is the source of
        // truth after that, so we don't clobber pending changes.
        if (!_interestsSeeded) {
          final saved = (d['interests'] as List?)?.cast<String>();
          if (saved != null && saved.isNotEmpty) {
            _interests
              ..clear()
              ..addAll(saved);
          }
          _interestsSeeded = true;
        }

        // Sync Cloudinary URLs from the backend profile response.
        final av = d['avatar_url'] as String?;
        final cv = d['cover_url']  as String?;
        if (av != null && av.isNotEmpty && _avatarFile == null) _avatarUrl = av;
        if (cv != null && cv.isNotEmpty && _coverFile  == null) _coverUrl  = cv;
      });
    } catch (_) {}
  }

  // ── Persist / restore URLs ────────────────────────────────

  Future<void> _loadSavedUrls() async {
    final p  = await SharedPreferences.getInstance();
    final av = p.getString(_kAvatarUrl);
    final cv = p.getString(_kCoverUrl);
    if (av != null && av.isNotEmpty) setState(() => _avatarUrl = av);
    if (cv != null && cv.isNotEmpty) setState(() => _coverUrl  = cv);
  }

  Future<void> _saveAvatarUrl(String url) async =>
      (await SharedPreferences.getInstance()).setString(_kAvatarUrl, url);

  Future<void> _saveCoverUrl(String url) async =>
      (await SharedPreferences.getInstance()).setString(_kCoverUrl, url);

  // ── Delete ────────────────────────────────────────────────

  Future<void> _deletePost(int i) async {
    final id = _posts[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete(context, 'post')) return;
    try {
      await _api.deletePost(id);
      setState(() => _posts.removeAt(i));
      notifyPostDeleted(id);
      _snack('Post deleted');
    } catch (_) { _snack('Failed to delete', error: true); }
  }

  Future<void> _deleteFweet(int i) async {
    final id = _fweets[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete(context, 'fweet')) return;
    try {
      await _api.deletePost(id);
      setState(() => _fweets.removeAt(i));
      notifyPostDeleted(id);
      _snack('Fweet deleted');
    } catch (_) { _snack('Failed to delete', error: true); }
  }

  Future<bool> _confirmDelete(BuildContext ctx, String type) async =>
    await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $type?', style: const TextStyle(
            fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
        content: Text('This $type will be permanently removed.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                color: Colors.grey.shade600, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, color: Colors.grey.shade500))),
          GestureDetector(onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: _kG4,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Delete', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)))),
          const SizedBox(width: 4),
        ],
      ),
    ) ?? false;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? _kG4 : Colors.green.shade600,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Image picking + upload ─────────────────────────────────

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 85,
      maxWidth: 800, maxHeight: 800);
    if (x == null) return;
    final f = File(x.path);
    setState(() { _avatarFile = f; _avatarUploading = true; });
    try {
      final res = await _api.uploadAvatar(f) as Map<String, dynamic>;
      final url = res['avatar_url'] as String? ?? '';
      if (url.isNotEmpty) {
        setState(() => _avatarUrl = url);
        await _saveAvatarUrl(url);
      }
    } catch (_) { _snack('Avatar upload failed', error: true); }
    finally { if (mounted) setState(() => _avatarUploading = false); }
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 85,
      maxWidth: 1200, maxHeight: 400);
    if (x == null) return;
    final f = File(x.path);
    setState(() { _coverFile = f; _coverUploading = true; });
    try {
      final res = await _api.uploadCover(f) as Map<String, dynamic>;
      final url = res['cover_url'] as String? ?? '';
      if (url.isNotEmpty) {
        setState(() => _coverUrl = url);
        await _saveCoverUrl(url);
      }
    } catch (_) { _snack('Cover upload failed', error: true); }
    finally { if (mounted) setState(() => _coverUploading = false); }
  }

  // ── Navigation ────────────────────────────────────────────

  Future<void> _openInterests() async {
    final r = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(builder: (_) => const InterestsPage()));
    if (r != null && r.isNotEmpty) {
      setState(() { _interests.clear(); _interests.addAll(r); });
    }
  }

  Future<void> _openBio() async {
    final r = await Navigator.of(context).push<BioData>(
        MaterialPageRoute(builder: (_) => BioPage(existing: _bioData)));
    if (r != null) setState(() => _bioData = r);
  }

  Future<void> _openCreatePost() async {
    final r = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreatePostPage()));
    if (r != null && r is Map) {
      final np = (r['post'] as Map<String, dynamic>?) ?? {};
      if (np.isNotEmpty) setState(() => _posts.insert(0, np));
      _fetchPosts();
    }
  }

  Future<void> _openCreateFweet() async {
    final r = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CreateFweetPage()));
    if (r != null && r.isNotEmpty) _fetchFweets();
  }

  // Phase 3: share my own profile via the bottom sheet.
  Future<void> _shareMyProfile() async {
    HapticFeedback.lightImpact();

    // If we don't have my user_id yet (initial fetch failed or hasn't
    // returned), grab it now so the share message is correct.
    if (_myUserId == null || _myUserId!.isEmpty) {
      try {
        final me = await _api.getMyProfile() as Map<String, dynamic>;
        _myUserId = me['user_id'] as String? ?? '';
      } catch (_) {
        _snack('Could not load your profile to share.', error: true);
        return;
      }
    }
    if (_myUserId == null || _myUserId!.isEmpty) {
      _snack('Could not load your profile to share.', error: true);
      return;
    }

    if (!mounted) return;
    await showShareProfileSheet(
      context,
      profile: {
        'user_id':    _myUserId,
        'name':       widget.fullName,
        'avatar_url': _avatarUrl ?? '',
        'role':       widget.role,
      },
      onShareTo: (room) async {
        final roomId = room['id']?.toString() ?? '';
        if (roomId.isEmpty) return;
        await _api.shareProfileToRoom(
          roomId:       roomId,
          targetUserId: _myUserId!,
          targetName:   widget.fullName,
        );
      },
    );
  }

  // ── Phase 3: privacy pickers ──────────────────────────────

  Future<void> _changeBioPrivacy() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PrivacyToggleSheet.bio(currentPublic: _bioPublic),
    );
    if (result == null) return;

    final wanted = result == 'public';
    if (wanted == _bioPublic) return;

    final was = _bioPublic;
    setState(() => _bioPublic = wanted);
    try {
      await _api.setBioPublic(wanted);
      _snack(wanted ? 'Bio is now public' : 'Bio is now private');
    } catch (_) {
      setState(() => _bioPublic = was);
      _snack('Could not update bio privacy', error: true);
    }
  }

  Future<void> _changeInterestsPrivacy() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PrivacyToggleSheet.interests(
          currentVisibility: _interestsVis),
    );
    if (result == null || result == _interestsVis) return;

    final was = _interestsVis;
    setState(() => _interestsVis = result);
    try {
      await _api.setInterestsVisibility(result);
      _snack('Interests · ${PrivacyToggleSheet.interestsLabel(result)}');
    } catch (_) {
      setState(() => _interestsVis = was);
      _snack('Could not update interests privacy', error: true);
    }
  }

  // ── Role helpers ──────────────────────────────────────────

  List<Color> get _roleGradient {
    switch (widget.role.toLowerCase()) {
      case 'student':        return [const Color(0xFF43E97B), const Color(0xFF38F9D7)];
      case 'teaching_staff':
      case 'staff':          return [_kG2, _kG1];
      case 'parent':         return [_kG3, _kG4];
      default:               return [_kG1, _kG2];
    }
  }

  String get _roleLabel {
    switch (widget.role.toLowerCase()) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching Staff';
      case 'non_teaching_staff': return 'Staff';
      case 'parent':             return 'Parent';
      default:                   return widget.role;
    }
  }

  String get _handleName =>
      '@${widget.preferredName.toLowerCase().replaceAll(' ', '_')}';

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildCoverSection()),
          SliverToBoxAdapter(child: _buildIdentitySection()),
          if (_bioData != null && !_bioData!.isEmpty)
            SliverToBoxAdapter(child: _buildBioCard()),
          SliverToBoxAdapter(child: _buildInterestsStrip()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabDelegate(child: _buildTabBar()),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabCtrl,
              physics: const ClampingScrollPhysics(),
              children: [
                _PostsTab(posts: _posts, loading: _postsLoading,
                    onCreate: _openCreatePost, onDelete: _deletePost,
                    onRefresh: _fetchPosts),
                _FweetsTab(fweets: _fweets, loading: _fweetsLoading,
                    onCreate: _openCreateFweet, onDelete: _deleteFweet,
                    onRefresh: _fetchFweets),
                _FavoritesTab(favorites: _favorites, loading: _favoritesLoading,
                    onRefresh: _fetchFavorites),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cover section ─────────────────────────────────────────

  Widget _buildCoverSection() {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: _kCoverH + _kAvatarR,
      child: Stack(clipBehavior: Clip.none, children: [

        // Cover
        Positioned(top: 0, left: 0, right: 0, height: _kCoverH,
          child: GestureDetector(onTap: _pickCover,
            child: Stack(children: [
              _buildCoverImage(),
              if (_coverUploading)
                Container(color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))),
            ]))),

        // Back
        Positioned(top: topPad + 12, left: 16,
          child: GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 18)))),

        // Edit cover
        Positioned(top: topPad + 12, right: 16,
          child: GestureDetector(onTap: _pickCover,
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: const Icon(Icons.photo_camera_rounded,
                  color: Colors.white, size: 16)))),

        // Avatar
        Positioned(top: _kCoverH - _kAvatarR, left: 0, right: 0,
          child: Center(child: GestureDetector(onTap: _pickAvatar,
            child: Stack(children: [
              _buildAvatarCircle(),
              if (_avatarUploading)
                Positioned.fill(child: ClipOval(child: Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))))),
              Positioned(bottom: 2, right: 2,
                child: Container(width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: _roleGradient),
                    border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.photo_camera_rounded,
                      color: Colors.white, size: 12))),
            ])))),
      ]),
    );
  }

  Widget _buildCoverImage() {
    // Priority: local file (uploading now) → Cloudinary URL → gradient
    if (_coverFile != null) {
      return Image.file(_coverFile!, fit: BoxFit.cover, width: double.infinity);
    }
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _coverUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: _kCoverH,
        placeholder: (_, __) => _coverGradient(),
        errorWidget: (_, __, ___) => _coverGradient(),
      );
    }
    return _coverGradient();
  }

  Widget _coverGradient() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [const Color(0xFF1A1A2E),
                 ..._roleGradient.map((c) => c.withOpacity(0.7)),
                 const Color(0xFF1A1A2E)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Stack(children: [
      Positioned(right: -40, top: -40, child: Container(width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _roleGradient.first.withOpacity(0.15)))),
      Positioned(left: -30, bottom: 0, child: Container(width: 140, height: 140,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _roleGradient.last.withOpacity(0.1)))),
    ]));

  Widget _buildAvatarCircle() {
    final diameter = _kAvatarR * 2;
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18),
          blurRadius: 18, offset: const Offset(0, 6))]);

    // Local file: show immediately
    if (_avatarFile != null) {
      return Container(width: diameter, height: diameter,
        decoration: decoration.copyWith(
            image: DecorationImage(
                image: FileImage(_avatarFile!), fit: BoxFit.cover)));
    }
    // Cloudinary URL
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Container(width: diameter, height: diameter,
        decoration: decoration,
        child: ClipOval(child: CachedNetworkImage(
          imageUrl: _avatarUrl!, fit: BoxFit.cover,
          width: diameter, height: diameter,
          placeholder: (_, __) => Container(
            decoration: BoxDecoration(gradient: LinearGradient(
                colors: _roleGradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Center(child: Text(
              widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 40, color: Colors.white)))),
          errorWidget: (_, __, ___) => Container(
            decoration: BoxDecoration(gradient: LinearGradient(
                colors: _roleGradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Center(child: Text(
              widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontFamily: 'Alfa',
                  fontSize: 40, color: Colors.white)))),
        )));
    }
    // No image — gradient with initial
    return Container(width: diameter, height: diameter,
      decoration: decoration.copyWith(
          gradient: LinearGradient(colors: _roleGradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Text(
        widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
        style: const TextStyle(fontFamily: 'Alfa',
            fontSize: 40, color: Colors.white))));
  }

  // ── Identity section ──────────────────────────────────────

  Widget _buildIdentitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        Text(widget.fullName, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Alfa', fontSize: 22, color: _kInk)),
        const SizedBox(height: 4),
        Text('$_roleLabel  ·  $_handleName', textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Arch', fontSize: 13,
              color: Colors.grey.shade500, letterSpacing: 0.2)),
        const SizedBox(height: 20),
        IntrinsicHeight(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatCell(value: _posts.length, label: 'Posts'),
            _divider(),
            _StatCell(value: _followers, label: 'Followers'),
            _divider(),
            _StatCell(value: _following, label: 'Following'),
          ],
        )),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(flex: 3, child: GestureDetector(onTap: _openBio,
            child: Container(height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG2, _kG1],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: _kG2.withOpacity(0.25),
                    blurRadius: 10, offset: const Offset(0, 4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(_bioData != null ? 'Edit Bio' : 'Add Bio',
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, color: Colors.white,
                      fontSize: 13)),
              ])))),
          const SizedBox(width: 10),
          // Phase 3: share button opens the share-profile bottom sheet.
          GestureDetector(onTap: _shareMyProfile,
            child: Container(width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 6, offset: const Offset(0, 2))]),
              child: Icon(Icons.ios_share_rounded, size: 16,
                  color: Colors.grey.shade600))),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: VerticalDivider(color: Colors.grey.shade200, thickness: 1.5, width: 1.5));

  // ── Bio card ──────────────────────────────────────────────

  Widget _buildBioCard() {
    final bio = _bioData!;
    return GestureDetector(
      onTap: _showBioSheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG2, _kG1]),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_outlined,
                  color: Colors.white, size: 14)),
            const SizedBox(width: 8),
            const Text('About me', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 13, color: _kInk)),
            const Spacer(),
            // Phase 3: bio visibility chip. Tap-only target — its own
            // GestureDetector wins the gesture arena, so the parent's
            // _showBioSheet won't fire when the chip is tapped.
            _privacyChip(
              icon:  _bioPublic ? Icons.public_rounded : Icons.lock_rounded,
              label: PrivacyToggleSheet.bioLabel(_bioPublic),
              onTap: _changeBioPrivacy,
            ),
            const SizedBox(width: 10),
            Text('Edit ›', style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12, color: _kG2)),
          ]),
          if (bio.bio != null) ...[
            const SizedBox(height: 8),
            Text(bio.bio!, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                  color: Colors.grey.shade600, height: 1.5)),
          ],
          if (bio.country != null || bio.year != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (bio.country != null) _metaChip('📍 ${bio.country!}'),
              if (bio.year    != null) _metaChip('🎓 ${bio.year!}'),
              if (bio.availableForStudy)
                _metaChip('📚 Study Buddy', color: Colors.green.shade600),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _metaChip(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? Colors.grey.shade600).withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (color ?? Colors.grey.shade600).withOpacity(0.15))),
    child: Text(label, style: TextStyle(fontFamily: 'Momo',
        fontSize: 11, color: color ?? Colors.grey.shade600)));

  // Phase 3: small "🌐 Public ▾" pill used in the bio + interests
  // section headers. Has its own GestureDetector so taps don't bubble
  // to whatever surface it's sitting on.
  Widget _privacyChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
    GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
            style: TextStyle(
              fontFamily: 'Arch',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 12, color: Colors.grey.shade500),
        ]),
      ),
    );

  IconData _visibilityIcon(String vis) {
    switch (vis) {
      case 'private':   return Icons.lock_rounded;
      case 'followers': return Icons.people_alt_rounded;
      default:          return Icons.public_rounded;
    }
  }

  void _showBioSheet() {
    final bio = _bioData!;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.65, maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl, padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Bio', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 22, color: _kInk)),
            const SizedBox(height: 16),
            if (bio.bio        != null) _BioRow(Icons.edit_note_rounded,    'Bio',         bio.bio!,        _kG2),
            if (bio.quote      != null) _BioRow(Icons.format_quote_rounded, 'Quote',       bio.quote!,      _kG3),
            if (bio.pronouns   != null) _BioRow(Icons.tag_rounded,          'Pronouns',    bio.pronouns!,   _kG1),
            if (bio.country    != null) _BioRow(Icons.public_rounded,       'Country',     bio.country!,    _kG4),
            if (bio.year       != null) _BioRow(Icons.grade_rounded,        'Year',        bio.year!,       _kG1),
            if (bio.school     != null) _BioRow(Icons.location_city_rounded,'School',      bio.school!,     _kG3),
            if (bio.studyStyle != null) _BioRow(Icons.menu_book_rounded,    'Study Style', bio.studyStyle!, _kG3),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { Navigator.pop(context); _openBio(); },
              child: Container(width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kG2, _kG1]),
                  borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Edit Bio', style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 14))))),
          ]),
        ),
      ),
    );
  }

  // ── Interests strip ───────────────────────────────────────

  Widget _buildInterestsStrip() {
    // Empty state — single "Add your interests" pill, no privacy chip
    // (nothing to be private about yet).
    if (_interests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(onTap: _openInterests,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200, width: 1.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline_rounded, size: 14,
                  color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Add your interests', style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 12,
                  color: Colors.grey.shade400)),
            ]))),
      );
    }

    // Filled state — section header (title + privacy chip) above the
    // horizontal scrollable chips.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            const Text('Interests',
              style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 12,
                color: _kInk, letterSpacing: 0.5)),
            const SizedBox(width: 10),
            // Phase 3: interests visibility chip.
            _privacyChip(
              icon:  _visibilityIcon(_interestsVis),
              label: PrivacyToggleSheet.interestsLabel(_interestsVis),
              onTap: _changeInterestsPrivacy,
            ),
          ]),
        ),
        SizedBox(height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            itemCount: _interests.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == _interests.length) {
                return GestureDetector(onTap: _openInterests,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.shade300, width: 1.5),
                      borderRadius: BorderRadius.circular(22)),
                    child: Text('+ Edit', style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 11,
                        color: Colors.grey.shade500))));
              }
              final c = [_kG1, _kG2, _kG3, _kG4][i % 4];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  border: Border.all(color: c.withOpacity(0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(22)),
                child: Text(_interests[i], style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 11, color: c)));
            },
          ),
        ),
      ]),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Divider(height: 1, color: Colors.grey.shade100),
        TabBar(
          controller: _tabCtrl,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: _roleGradient.first),
            insets: const EdgeInsets.symmetric(horizontal: 24)),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 13),
          labelColor: _kInk,
          unselectedLabelColor: Colors.grey.shade400,
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: 'Posts'), Tab(text: 'Fweets'),
                       Tab(text: 'Favorites')],
        ),
        Divider(height: 1, color: Colors.grey.shade100),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STAT CELL
// ─────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final int value; final String label;
  const _StatCell({required this.value, required this.label});
  String get _fmt {
    if (value >= 1000000) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1000)    return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(_fmt, style: const TextStyle(
        fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontFamily: 'Momo',
        fontSize: 11, color: Colors.grey.shade500)),
  ]);
}

// ─────────────────────────────────────────────────────────────
// STICKY HEADER DELEGATE
// ─────────────────────────────────────────────────────────────

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabDelegate({required this.child});
  @override double get minExtent => 50;
  @override double get maxExtent => 50;
  @override Widget build(BuildContext ctx, double shrink, bool overlaps) => child;
  @override bool shouldRebuild(_StickyTabDelegate o) => o.child != child;
}

// ─────────────────────────────────────────────────────────────
// POSTS TAB
// ─────────────────────────────────────────────────────────────

class _PostsTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final VoidCallback onCreate;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onRefresh;
  const _PostsTab({required this.posts, required this.loading,
      required this.onCreate, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _TabLoadingShimmer();
    if (posts.isEmpty) {
      return _EmptyTab(
      icon: Icons.article_outlined, label: 'No Posts Yet',
      sub: 'Share something with the campus',
      buttonLabel: 'Create First Post', color: _kG2, onTap: onCreate);
    }
    return RefreshIndicator(
      color: _kG2, onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const ClampingScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (_, i) {
          final p = posts[i];
          // media items: {url, thumbnail_url, media_type, order, id}.
          // Pass the full list through so the card can branch on
          // media_type and render images vs videos via MediaItemView.
          final media = (p['media'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          return _ProfilePostCard(
            post:     p,
            media:    media,
            content:  p['content'] as String? ?? '',
            onDelete: () => onDelete(i));
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE POST CARD
// ─────────────────────────────────────────────────────────────

class _ProfilePostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  /// Full media list (images + videos). Each item has the keys
  /// `url`, `thumbnail_url`, `media_type`, `order`, `id`.
  final List<Map<String, dynamic>> media;
  final String content;
  final VoidCallback onDelete;
  const _ProfilePostCard({required this.post, required this.media,
      required this.content, required this.onDelete});
  @override State<_ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<_ProfilePostCard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final location = widget.post['location'] as String? ?? '';
    final hasMedia = widget.media.isNotEmpty;
    final multi    = widget.media.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Media (images + videos from Cloudinary) ───────
        // PageView delegates per-item rendering to MediaItemView, which
        // shows a play badge on videos and opens FullscreenVideoPlayer
        // when tapped. Visual-only overlays (counter, dots) sit on top
        // wrapped in IgnorePointer so video taps reach the card; the
        // delete button is the one exception — it stays interactive.
        if (hasMedia) ...[
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
              child: SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: widget.media.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (_, i) => MediaItemView(
                    item:   widget.media[i],
                    height: 220,
                  ),
                ),
              ),
            ),
            // Page counter
            if (multi) Positioned(top: 10, right: 10,
              child: IgnorePointer(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_page + 1}/${widget.media.length}',
                    style: const TextStyle(fontFamily: 'Momo',
                        color: Colors.white, fontSize: 11))))),
            // Dot indicators
            if (multi) Positioned(bottom: 8, left: 0, right: 0,
              child: IgnorePointer(child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.media.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 16 : 5, height: 5,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(3)));
                })))),
            // Delete button — stays tappable (its own GestureDetector).
            Positioned(top: 10, left: 10,
              child: GestureDetector(onTap: widget.onDelete,
                child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.white, size: 16)))),
          ]),
        ],

        // ── Text / location ───────────────────────────────
        Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!hasMedia)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              GestureDetector(onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _kG4.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline_rounded, size: 14, color: _kG4),
                    const SizedBox(width: 4),
                    Text('Delete', style: TextStyle(fontFamily: 'Momo',
                        fontSize: 11, fontWeight: FontWeight.bold, color: _kG4)),
                  ]))),
            ]),
          if (widget.content.isNotEmpty) ...[
            if (!hasMedia) const SizedBox(height: 4),
            Text(widget.content, style: const TextStyle(
                fontFamily: 'Momo', fontSize: 14, color: _kInk, height: 1.5)),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_rounded, size: 13, color: _kG4),
              const SizedBox(width: 4),
              Text(location, style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ],
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FWEETS TAB
// ─────────────────────────────────────────────────────────────

class _FweetsTab extends StatelessWidget {
  final List<Map<String, dynamic>> fweets;
  final bool loading;
  final VoidCallback onCreate;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onRefresh;
  const _FweetsTab({required this.fweets, required this.loading,
      required this.onCreate, required this.onDelete, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _TabLoadingShimmer();
    if (fweets.isEmpty) {
      return _EmptyTab(
      icon: Icons.chat_bubble_outline_rounded, label: 'No Fweets Yet',
      sub: 'Quick thoughts and campus updates',
      buttonLabel: 'Create First Fweet', color: _kG4, onTap: onCreate);
    }
    return RefreshIndicator(
      color: _kG2, onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const ClampingScrollPhysics(),
        itemCount: fweets.length,
        itemBuilder: (_, i) {
          final f       = fweets[i];
          final content = f['content']          as String? ?? '';
          final bgHex   = f['background_color'] as String? ?? '';
          Color? bg;
          try {
            if (bgHex.isNotEmpty) {
              bg = Color(int.parse(
                  'FF${bgHex.replaceAll('#', '')}', radix: 16));
            }
          } catch (_) {}
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: bg ?? Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(
                  color: (bg ?? Colors.black).withOpacity(0.08),
                  blurRadius: 12, offset: const Offset(0, 4))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(children: [
                Container(
                  color: Colors.black.withOpacity(0.06),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Text('⚡ Fweet', style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 11,
                        color: bg != null ? Colors.white : _kG4)),
                    const Spacer(),
                    GestureDetector(onTap: () => onDelete(i),
                      child: Icon(Icons.delete_outline_rounded, size: 18,
                          color: bg != null ? Colors.white70 : _kG4)),
                  ])),
                Padding(padding: const EdgeInsets.all(16),
                  child: Text(content, style: TextStyle(fontFamily: 'Momo',
                      fontSize: 15, height: 1.5,
                      color: bg != null ? Colors.white : _kInk))),
              ])),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FAVORITES TAB
// ─────────────────────────────────────────────────────────────

class _FavoritesTab extends StatelessWidget {
  final List<Map<String, dynamic>> favorites;
  final bool loading;
  final Future<void> Function() onRefresh;
  const _FavoritesTab({required this.favorites, required this.loading,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _TabLoadingShimmer();
    if (favorites.isEmpty) {
      return const _EmptyTab(
      icon: Icons.bookmark_outline_rounded, label: 'No Favorites Yet',
      sub: 'Posts you bookmark from the feed appear here', color: _kG2);
    }
    return RefreshIndicator(
      color: _kG2, onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const ClampingScrollPhysics(),
        itemCount: favorites.length,
        itemBuilder: (_, i) {
          final p       = favorites[i];
          final content = p['content']     as String? ?? '';
          final author  = p['author_name'] as String? ?? 'Unknown';
          final isFweet = p['post_type']   == 'fweet';
          final initial = author.isNotEmpty ? author[0].toUpperCase() : '?';
          // Keep the full media list — the first item drives the
          // preview, and MediaItemView handles both image and video
          // (videos show a thumbnail with play badge → fullscreen on tap).
          final media   = (p['media'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: _kG2.withOpacity(0.06),
                  blurRadius: 12, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Author header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18))),
                child: Row(children: [
                  Container(width: 26, height: 26,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_kG1, _kG2])),
                    child: Center(child: Text(initial, style: const TextStyle(
                        color: Colors.white, fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 11)))),
                  const SizedBox(width: 8),
                  Text(author, style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 12, color: _kInk)),
                  if (isFweet) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _kG4.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('⚡', style: TextStyle(fontSize: 10))),
                  ],
                  const Spacer(),
                  const Icon(Icons.bookmark_rounded, color: _kG2, size: 16),
                ])),
              // First media item — image or video — from Cloudinary.
              if (media.isNotEmpty)
                ClipRRect(child: MediaItemView(
                  item:   media.first,
                  height: 180,
                )),
              if (content.isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Text(content, style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 14,
                      color: _kInk, height: 1.5))),
              if (content.isEmpty) const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LOADING SHIMMER
// ─────────────────────────────────────────────────────────────

class _TabLoadingShimmer extends StatefulWidget {
  const _TabLoadingShimmer();
  @override State<_TabLoadingShimmer> createState() => _TabLoadingShimmerState();
}

class _TabLoadingShimmerState extends State<_TabLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double>   _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) =>
    AnimatedBuilder(animation: _a, builder: (_, __) {
      final o = 0.06 + _a.value * 0.08;
      return ListView(padding: const EdgeInsets.all(16), children: [
        _sh(o, 200), const SizedBox(height: 16),
        _sh(o, 120), const SizedBox(height: 16),
        _sh(o, 160),
      ]);
    });
  Widget _sh(double o, double h) => Container(
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))]),
    child: Column(children: [
      Container(height: h,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(o),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20)))),
      Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Container(height: 14, width: double.infinity,
          decoration: BoxDecoration(color: Colors.black.withOpacity(o),
              borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 8),
        Container(height: 14, width: 160,
          decoration: BoxDecoration(color: Colors.black.withOpacity(o),
              borderRadius: BorderRadius.circular(6))),
      ])),
    ]));
}

// ─────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon; final String label; final String sub;
  final String? buttonLabel; final Color color; final VoidCallback? onTap;
  const _EmptyTab({required this.icon, required this.label, required this.sub,
      required this.color, this.buttonLabel, this.onTap});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08), shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.15), width: 1.5)),
          child: Icon(icon, size: 32, color: color.withOpacity(0.5))),
        const SizedBox(height: 18),
        Text(label, style: const TextStyle(
            fontFamily: 'Alfa', fontSize: 17, color: _kInk)),
        const SizedBox(height: 7),
        Text(sub, textAlign: TextAlign.center, style: TextStyle(
            fontFamily: 'Momo', fontSize: 13, color: Colors.grey.shade400)),
        if (buttonLabel != null && onTap != null) ...[
          const SizedBox(height: 24),
          GestureDetector(onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4))]),
              child: Text(buttonLabel!, style: const TextStyle(
                  fontFamily: 'Arch', fontWeight: FontWeight.bold,
                  color: Colors.white, fontSize: 13)))),
        ],
      ])));
}

// ─────────────────────────────────────────────────────────────
// BIO ROW
// ─────────────────────────────────────────────────────────────

class _BioRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _BioRow(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(label, style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 11,
            color: Colors.grey.shade400)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
            fontFamily: 'Momo', fontSize: 14, color: _kInk)),
      ])),
    ]));
}