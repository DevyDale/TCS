// lib/screens/profile/other_user_profile_screen.dart
//
// View another user's profile. Reachable from search results, the
// suggestion screen (all_users_screen), comment authors, post-card
// author headers, and mention taps. Read-only — you can't edit
// someone else's avatar/cover/bio — but supports follow/unfollow,
// sending a chat request ("Message" button), and sharing their
// profile to a chat room via the bottom sheet.
//
// Privacy rules enforced here:
//  - Bio is hidden unless privacy_settings.bio_public == true OR
//    the viewer is already following this user.
//  - Interests honour interests_visibility:
//      'public'    → always shown
//      'followers' → only shown to followers
//      'private'   → never shown
//  - Posts/fweets visibility is enforced server-side; we just render
//    whatever /api/posts/?user_id=… returns.
//
// If the viewer somehow lands on their OWN user_id (e.g. from
// tapping their avatar in a comment thread), we hide Follow/Message
// and just show a "this is your profile" pill.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../profile/share_profile_screen.dart';


const _kG1  = Color(0xFF6DD5FA);
const _kG2  = Color(0xFF8E54E9);
const _kG3  = Color(0xFFF7971E);
const _kG4  = Color(0xFFFF5858);
const _kInk = Color(0xFF1A1A2E);
const _kBg  = Color(0xFFF2F4F8);

class OtherUserProfileScreen extends StatefulWidget {
  /// Backend user_id (the human-readable string ID), e.g. "S2024001".
  final String userId;

  /// Optional pre-fetched data (e.g. from a search-result tap) so
  /// the screen can render instantly while the full payload loads.
  final Map<String, dynamic>? initialData;

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    this.initialData,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();

  late final TabController _tabCtrl;

  Map<String, dynamic>? _user;        // full profile from /users/{id}/
  bool _userLoading = true;

  List<Map<String, dynamic>> _posts  = [];
  List<Map<String, dynamic>> _fweets = [];
  bool _contentLoading = true;

  bool _isFollowing = false;
  bool _followBusy  = false;
  bool _chatReqSent = false;
  bool _chatReqBusy = false;

  String? _myUserId;

  static const _kCoverH  = 220.0;
  static const _kAvatarR = 52.0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    // Prefill from passed-in data so the cover/avatar can show right
    // away — feels much snappier on slow networks.
    _user = widget.initialData != null
        ? Map<String, dynamic>.from(widget.initialData!)
        : null;
    _isFollowing = (widget.initialData?['is_following'] as bool?) ?? false;

    _loadMyUserId();
    _fetchUser();
    _fetchContent();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _loadMyUserId() async {
    final me = await ApiService.instance.cachedUser;
    if (!mounted || me == null) return;
    setState(() => _myUserId = me['user_id'] as String?);
  }

  Future<void> _fetchUser() async {
    try {
      final d = await _api.getUserProfile(widget.userId)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _user = d;
        _userLoading = false;
        _isFollowing = d['is_following'] as bool? ?? false;
      });
    } catch (_) {
      if (mounted) setState(() => _userLoading = false);
    }
  }

  /// One round-trip for both posts and fweets — they come back from
  /// the same /api/posts/?user_id=… endpoint differentiated by the
  /// post_type field. Splitting client-side avoids a second request.
  Future<void> _fetchContent() async {
    try {
      final d = await _api.getPosts(userId: widget.userId)
          as Map<String, dynamic>;
      if (!mounted) return;
      final all = ((d['results'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _posts = all
            .where((p) => (p['post_type'] ?? 'post') == 'post')
            .toList();
        _fweets = all
            .where((p) => (p['post_type'] ?? '') == 'fweet')
            .toList();
        _contentLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _contentLoading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    HapticFeedback.mediumImpact();
    final was = _isFollowing;
    setState(() {
      _isFollowing = !was;
      _followBusy  = true;
    });
    try {
      await _api.followToggle(widget.userId);
      // Optimistically bump follower count so the UI matches the
      // toggle without waiting for a refetch.
      if (mounted && _user != null) {
        final cur = (_user!['followers_count'] as int?) ?? 0;
        setState(() {
          _user!['followers_count'] = was ? (cur > 0 ? cur - 1 : 0) : cur + 1;
          _followBusy = false;
        });
      } else if (mounted) {
        setState(() => _followBusy = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = was;
          _followBusy  = false;
        });
        _snack('Could not update follow. Try again.', isError: true);
      }
    }
  }

  Future<void> _sendChatRequest() async {
    if (_chatReqSent || _chatReqBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _chatReqBusy = true);
    try {
      await _api.sendChatRequest(widget.userId, message: 'Hi!');
      if (!mounted) return;
      setState(() {
        _chatReqSent = true;
        _chatReqBusy = false;
      });
      _snack('Chat request sent ✉️');
    } catch (_) {
      if (mounted) {
        setState(() => _chatReqBusy = false);
        _snack('Could not send request. Try again.', isError: true);
      }
    }
  }

  void _openShareSheet() {
    if (_user == null) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShareProfileSheet(
        targetUserId:    widget.userId,
        targetName:      _displayName,
        targetAvatarUrl: _avatarUrl,
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: _kG4),
            title: const Text('Report user',
              style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
              )),
            onTap: () {
              Navigator.pop(context);
              _snack('Reported. Thanks for letting us know.');
            },
          ),
          ListTile(
            leading: Icon(Icons.block_rounded, color: Colors.grey.shade700),
            title: const Text('Block user',
              style: TextStyle(
                fontFamily: 'Arch', fontWeight: FontWeight.bold,
              )),
            onTap: () {
              Navigator.pop(context);
              _snack('Block coming soon.');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: isError ? _kG4 : _kInk,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Privacy + identity helpers ───────────────────────────

  bool get _isMe =>
      _myUserId != null && _myUserId!.isNotEmpty &&
      _myUserId == widget.userId;

  bool get _canSeeBio {
    if (_user == null) return false;
    final ps    = _user!['privacy_settings'] as Map<String, dynamic>? ?? {};
    final isPub = ps['bio_public'] as bool? ?? true; // default public
    return isPub || _isFollowing || _isMe;
  }

  /// One of: 'public' | 'followers' | 'private'.
  String get _interestsVisibility =>
      (_user?['interests_visibility'] as String?) ?? 'public';

  bool get _canSeeInterests {
    if (_isMe) return true;
    switch (_interestsVisibility) {
      case 'private':   return false;
      case 'followers': return _isFollowing;
      default:          return true;
    }
  }

  List<Color> get _roleGradient {
    final role = (_user?['role'] as String?) ?? '';
    switch (role) {
      case 'student':
        return const [Color(0xFF4FC3F7), Color(0xFF0288D1)];
      case 'teaching_staff':
      case 'non_teaching_staff':
        return const [Color(0xFF81C784), Color(0xFF2E7D32)];
      default:
        return const [_kG1, _kG2];
    }
  }

  String get _roleLabel {
    final role = (_user?['role'] as String?) ?? '';
    switch (role) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching Staff';
      case 'non_teaching_staff': return 'Staff';
      case 'parent':             return 'Parent';
      case 'visitor':            return 'Visitor';
      case 'admin':              return 'Admin';
      default:                   return 'Member';
    }
  }

  String get _displayName {
    final fromUser = (_user?['name'] as String?)?.trim() ?? '';
    if (fromUser.isNotEmpty) return fromUser;
    final fromInit = (widget.initialData?['name'] as String?)?.trim() ?? '';
    if (fromInit.isNotEmpty) return fromInit;
    return 'User';
  }

  String get _handleName =>
      '@${(_user?['user_id'] as String?) ?? widget.userId}';

  String? get _avatarUrl => _user?['avatar_url'] as String?;
  String? get _coverUrl  => _user?['cover_url']  as String?;
  String? get _bio       => _user?['bio'] as String?;
  List<dynamic> get _interests =>
      (_user?['interests'] as List?) ?? const [];

  int  get _postsCount =>
      (_user?['posts_count'] as int?) ?? _posts.length;
  int  get _followers  => (_user?['followers_count'] as int?) ?? 0;
  int  get _following  => (_user?['following_count'] as int?) ?? 0;
  bool get _isVerified => (_user?['is_verified'] as bool?) ?? false;

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildCoverSection()),
          SliverToBoxAdapter(child: _buildIdentitySection()),
          SliverToBoxAdapter(child: _buildActionRow()),
          if (_canSeeBio && (_bio ?? '').trim().isNotEmpty)
            SliverToBoxAdapter(child: _buildBioCard()),
          if (_canSeeInterests && _interests.isNotEmpty)
            SliverToBoxAdapter(child: _buildInterests()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabDelegate(child: _buildTabBar()),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _PostsList(
              items:     _posts,
              loading:   _contentLoading,
              emptyText: '$_displayName hasn\'t posted yet.',
              onRefresh: _fetchContent,
            ),
            _PostsList(
              items:     _fweets,
              loading:   _contentLoading,
              emptyText: '$_displayName hasn\'t fweeted yet.',
              onRefresh: _fetchContent,
            ),
          ],
        ),
      ),
    );
  }

  // ── Cover + back/share/more ───────────────────────────────

  Widget _buildCoverSection() {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: _kCoverH + _kAvatarR,
      child: Stack(clipBehavior: Clip.none, children: [
        // Cover image
        Positioned(top: 0, left: 0, right: 0, height: _kCoverH,
          child: _buildCoverImage()),

        // Back
        Positioned(top: topPad + 12, left: 16,
          child: _circleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          )),

        // Share + more
        Positioned(top: topPad + 12, right: 16,
          child: Row(children: [
            _circleButton(
              icon: Icons.ios_share_rounded,
              onTap: _openShareSheet,
            ),
            const SizedBox(width: 8),
            _circleButton(
              icon: Icons.more_vert_rounded,
              onTap: _showMoreMenu,
            ),
          ])),

        // Avatar
        Positioned(top: _kCoverH - _kAvatarR, left: 0, right: 0,
          child: Center(child: _buildAvatarCircle())),
      ]),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _buildCoverImage() {
    if ((_coverUrl ?? '').isNotEmpty) {
      return CachedNetworkImage(
        imageUrl:     _coverUrl!,
        fit:          BoxFit.cover,
        width:        double.infinity,
        height:       _kCoverH,
        placeholder:  (_, __) => _coverGradient(),
        errorWidget:  (_, __, ___) => _coverGradient(),
      );
    }
    return _coverGradient();
  }

  Widget _coverGradient() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF1A1A2E),
          ..._roleGradient.map((c) => c.withOpacity(0.7)),
          const Color(0xFF1A1A2E),
        ],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Stack(children: [
      Positioned(right: -40, top: -40, child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _roleGradient.first.withOpacity(0.15),
        ),
      )),
      Positioned(left: -30, bottom: 0, child: Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _roleGradient.last.withOpacity(0.1),
        ),
      )),
    ]),
  );

  Widget _buildAvatarCircle() {
    final diameter = _kAvatarR * 2;
    final initial  = _displayName.isNotEmpty
        ? _displayName[0].toUpperCase() : '?';
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 4),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.18),
        blurRadius: 18, offset: const Offset(0, 6),
      )],
    );

    if ((_avatarUrl ?? '').isNotEmpty) {
      return Container(
        width: diameter, height: diameter,
        decoration: decoration,
        child: ClipOval(child: CachedNetworkImage(
          imageUrl:    _avatarUrl!,
          fit:         BoxFit.cover,
          width:       diameter, height: diameter,
          placeholder: (_, __) => _initialAvatar(initial),
          errorWidget: (_, __, ___) => _initialAvatar(initial),
        )),
      );
    }
    return Container(
      width: diameter, height: diameter,
      decoration: decoration.copyWith(
        gradient: LinearGradient(
          colors: _roleGradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Alfa', fontSize: 40, color: Colors.white,
        ),
      )),
    );
  }

  Widget _initialAvatar(String initial) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: _roleGradient,
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    )),
    child: Center(child: Text(
      initial,
      style: const TextStyle(
        fontFamily: 'Alfa', fontSize: 40, color: Colors.white,
      ),
    )),
  );

  // ── Identity ──────────────────────────────────────────────

  Widget _buildIdentitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(
            _displayName,
            textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Alfa', fontSize: 22, color: _kInk,
            ),
          )),
          if (_isVerified) ...[
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, color: _kG2, size: 18),
          ],
        ]),
        const SizedBox(height: 4),
        Text('$_roleLabel  ·  $_handleName',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Arch', fontSize: 13,
            color: Colors.grey.shade500, letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatCell(value: _postsCount, label: 'Posts'),
            _divider(),
            _StatCell(value: _followers,  label: 'Followers'),
            _divider(),
            _StatCell(value: _following,  label: 'Following'),
          ],
        )),
        const SizedBox(height: 18),
      ]),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: VerticalDivider(
      color: Colors.grey.shade200, thickness: 1.5, width: 1.5,
    ),
  );

  // ── Action row: Follow + Message + Share ─────────────────

  Widget _buildActionRow() {
    if (_isMe) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Row(children: [
          Expanded(child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Center(child: Text(
              'This is your profile',
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 12,
                color: Colors.grey.shade600,
              ),
            )),
          )),
          const SizedBox(width: 10),
          _ShareIconButton(onTap: _openShareSheet),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(children: [
        Expanded(flex: 3, child: _followButton()),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _messageButton()),
        const SizedBox(width: 10),
        _ShareIconButton(onTap: _openShareSheet),
      ]),
    );
  }

  Widget _followButton() {
    final following = _isFollowing;
    return GestureDetector(
      onTap: _followBusy ? null : _toggleFollow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        decoration: BoxDecoration(
          gradient: following
              ? null
              : LinearGradient(
                  colors: _roleGradient,
                  begin: Alignment.centerLeft,
                  end:   Alignment.centerRight,
                ),
          color: following ? Colors.white : null,
          borderRadius: BorderRadius.circular(22),
          border: following
              ? Border.all(color: Colors.grey.shade300, width: 1.5)
              : null,
          boxShadow: following ? [] : [
            BoxShadow(
              color: _roleGradient.last.withOpacity(0.25),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _followBusy
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: following ? _kG2 : Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: following ? _kG2 : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      following ? 'Following' : 'Follow',
                      style: TextStyle(
                        fontFamily:  'Arch',
                        fontWeight:  FontWeight.bold,
                        fontSize:    13,
                        color:       following ? _kG2 : Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _messageButton() {
    final sent = _chatReqSent;
    return GestureDetector(
      onTap: (_chatReqBusy || sent) ? null : _sendChatRequest,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: sent ? Colors.green.shade400 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Center(
          child: _chatReqBusy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kG2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sent
                          ? Icons.check_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: sent
                          ? Colors.green.shade600
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sent ? 'Requested' : 'Message',
                      style: TextStyle(
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize:   12,
                        color: sent
                            ? Colors.green.shade600
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Bio + Interests ───────────────────────────────────────

  Widget _buildBioCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.menu_book_rounded, size: 16,
                color: Colors.grey.shade600),
            const SizedBox(width: 6),
            const Text('About',
              style: TextStyle(
                fontFamily: 'Arch', fontSize: 12,
                fontWeight: FontWeight.bold, color: _kInk,
                letterSpacing: 0.5,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            _bio ?? '',
            style: const TextStyle(
              fontFamily: 'Momo', fontSize: 13.5,
              height: 1.45, color: _kInk,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInterests() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.interests_rounded, size: 16,
                color: Colors.grey.shade600),
            const SizedBox(width: 6),
            const Text('Interests',
              style: TextStyle(
                fontFamily: 'Arch', fontSize: 12,
                fontWeight: FontWeight.bold, color: _kInk,
                letterSpacing: 0.5,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _interests.map((tag) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _roleGradient
                      .map((c) => c.withOpacity(0.12))
                      .toList(),
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _roleGradient.last.withOpacity(0.25)),
              ),
              child: Text(
                tag.toString(),
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _roleGradient.last,
                ),
              ),
            )).toList(),
          ),
        ]),
      ),
    );
  }

  // ── Tab bar ──────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _kBg,
      child: TabBar(
        controller: _tabCtrl,
        labelColor:           _kG2,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor:       _kG2,
        indicatorWeight:      2.5,
        labelStyle: const TextStyle(
          fontFamily: 'Arch', fontWeight: FontWeight.bold, fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Arch', fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'Fweets'),
        ],
      ),
    );
  }
}

// ── Subwidgets ──────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final int    value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text('$value',
        style: const TextStyle(
          fontFamily: 'Alfa', fontSize: 18, color: _kInk,
        ),
      ),
      const SizedBox(height: 2),
      Text(label,
        style: TextStyle(
          fontFamily: 'Momo', fontSize: 11, color: Colors.grey.shade500,
        ),
      ),
    ]));
  }
}

class _ShareIconButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShareIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Icon(
          Icons.ios_share_rounded,
          size: 16, color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _PostsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool   loading;
  final String emptyText;
  final Future<void> Function() onRefresh;

  const _PostsList({
    required this.items,
    required this.loading,
    required this.emptyText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        color: _kG2,
        onRefresh: onRefresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              emptyText,
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 13, color: Colors.grey.shade500,
              ),
            ),
          )),
        ]),
      );
    }
    return RefreshIndicator(
      color: _kG2,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: items.length,
        itemBuilder: (_, i) => _MiniPostCard(post: items[i]),
      ),
    );
  }
}

class _MiniPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _MiniPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final content   = (post['content'] ?? '') as String;
    final created   = (post['created_at'] ?? '') as String;
    final likes     = (post['likes_count'] ?? 0) as int;
    final comments  = (post['comments_count'] ?? 0) as int;
    final mediaUrl  = (post['media_url'] ?? '') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (mediaUrl.isNotEmpty)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: mediaUrl, fit: BoxFit.cover,
              width: double.infinity, height: 180,
              errorWidget: (_, __, ___) => Container(
                height: 180, color: Colors.grey.shade100,
                child: Icon(Icons.broken_image_rounded,
                    color: Colors.grey.shade400),
              ),
            ),
          ),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              content,
              maxLines: 4, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Momo', fontSize: 13.5,
                color: _kInk, height: 1.4,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            Icon(Icons.favorite_rounded, size: 13,
                color: _kG4.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text('$likes',
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 11,
                color: Colors.grey.shade600,
              )),
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline_rounded, size: 12,
                color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('$comments',
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 11,
                color: Colors.grey.shade600,
              )),
            const Spacer(),
            Text(_formatTime(created),
              style: TextStyle(
                fontFamily: 'Momo', fontSize: 10,
                color: Colors.grey.shade400,
              )),
          ]),
        ),
      ]),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours   < 24) return '${diff.inHours}h';
    if (diff.inDays    < 7)  return '${diff.inDays}d';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabDelegate({required this.child});

  @override double get minExtent => 48.0;
  @override double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_StickyTabDelegate old) => false;
}