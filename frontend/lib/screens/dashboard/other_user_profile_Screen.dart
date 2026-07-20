// lib/screens/dashboard/other_user_profile_Screen.dart
//
// View another user's profile — redesigned to mirror the own-profile
// screen (gradient-bordered header card, light theme, 3-column grid
// tabs) with these differences per spec:
//
//   • The header stat area shows ONLY the follower count plus a Follow
//     button and a Chat Request button — no posts / following counts.
//   • The links card is DISPLAY-ONLY (no add button) and is hidden
//     entirely when the user has shared no links.
//   • About Me shows only the public bio + visible interests.
//   • Tabs Posts · Fweets · Highlights render as grids with NO add
//     tiles and NO delete (you can't edit someone else's content);
//     tapping a tile opens it full-screen.
//
// Preserved logic:
//   • Cross-role gate (_isCrossRole) → Follow/Chat replaced with a
//     read-only "Profile view only" pill; backend also returns 403.
//   • Self-view (_isMe) → "This is your profile" pill.
//   • Follow/unfollow, send chat request, block/report, share sheet.
//   • Privacy gates: bio_public / interests_visibility.
//   • Highlight deletion by the owner propagates here via
//     deletedHighlightIds (shared notifier from the feed screen).

import 'dart:math' as math;
import 'package:tcs_app/widgets/t_text.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/moderation_service.dart';
import '../../widgets/moderation/report_sheet.dart';
import '../../highlight_story_viewer.dart';
import '../profile/share_profile_screen.dart';
import '../profile/media_item_view.dart';
import '../feed/feed_screen.dart' show deletedHighlightIds;

// ── Light palette (matches own profile) ──────────────────────
Color get _kBg1 => AppC.bg;
Color get _kBg2 => AppC.bg;
Color get _kBg3 => AppC.bg;
Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;
Color get _kBorder => AppC.border;
Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
const _kInkSoft = Color(0xFF374151);
Color get _kInk => AppC.text;

const _kBlue = Color(0xFF6DD5FA);
const _kPurple = Color(0xFF7C3AED);
const _kAmber = Color(0xFFF59E0B);
const _kCoral = Color(0xFFFF4F6E);

const _gradColors = <Color>[
  Color(0xFF6DD5FA),
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

/// Returns 'student', 'staff', or 'other' for a role string.
String _groupOf(String role) {
  final r = role.toLowerCase();
  if (r == 'student') return 'student';
  if (r == 'teaching_staff' || r == 'non_teaching_staff') return 'staff';
  return 'other';
}

// ── Social meta ──────────────────────────────────────────────
class _SocialMeta {
  final String label;
  final IconData icon;
  final Color color;
  final String base;
  const _SocialMeta(this.label, this.icon, this.color, this.base);
}

const Map<String, _SocialMeta> _kSocial = {
  'instagram': _SocialMeta('Instagram', Icons.camera_alt_rounded,
      Color(0xFFE1306C), 'https://instagram.com/'),
  'facebook': _SocialMeta(
      'Facebook', Icons.facebook, Color(0xFF1877F2), 'https://facebook.com/'),
  'tiktok': _SocialMeta('TikTok', Icons.music_note_rounded, Color(0xFF111111),
      'https://www.tiktok.com/@'),
  'youtube': _SocialMeta('YouTube', Icons.smart_display_rounded,
      Color(0xFFFF0000), 'https://youtube.com/'),
  'twitter': _SocialMeta(
      'X', Icons.alternate_email_rounded, Color(0xFF1D9BF0), 'https://x.com/'),
  'snapchat': _SocialMeta('Snapchat', Icons.camera_rounded, Color(0xFFCBB300),
      'https://snapchat.com/add/'),
  'website':
      _SocialMeta('Website', Icons.language_rounded, Color(0xFF6B7280), ''),
};

const List<String> _kSocialOrder = [
  'instagram',
  'facebook',
  'tiktok',
  'youtube',
  'twitter',
  'snapchat',
  'website',
];

String _socialUrl(String key, String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  final base = _kSocial[key]?.base ?? '';
  if (base.isEmpty) return 'https://$v';
  final handle = v.startsWith('@') ? v.substring(1) : v;
  return '$base$handle';
}

// ─────────────────────────────────────────────────────────────

class OtherUserProfileScreen extends StatefulWidget {
  /// Backend user_id (the human-readable string ID), e.g. "S2024001".
  final String userId;
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
  late final AnimationController _shimmerCtrl;

  Map<String, dynamic>? _user;
  bool _userLoading = true;

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _fweets = [];
  bool _contentLoading = true;

  List<Map<String, dynamic>> _highlights = [];
  bool _highlightsLoading = true;

  bool _isFollowing = false;
  bool _followBusy = false;
  bool _chatReqSent = false;
  bool _chatReqBusy = false;

  String? _myUserId;
  String _myRole = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();

    _user = widget.initialData != null
        ? Map<String, dynamic>.from(widget.initialData!)
        : null;
    _isFollowing = (widget.initialData?['is_following'] as bool?) ?? false;

    _loadMe();
    _fetchUser();
    _fetchContent();
    _fetchHighlights();

    deletedHighlightIds.addListener(_onHighlightsDeleted);
  }

  @override
  void dispose() {
    deletedHighlightIds.removeListener(_onHighlightsDeleted);
    _tabCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────

  Future<void> _loadMe() async {
    final me = await ApiService.instance.cachedUser;
    if (!mounted || me == null) return;
    setState(() {
      _myUserId = me['user_id'] as String?;
      _myRole = (me['role'] as String?) ?? '';
    });
  }

  Future<void> _fetchUser() async {
    try {
      final d =
          await _api.getUserProfile(widget.userId) as Map<String, dynamic>;
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

  Future<void> _fetchContent() async {
    try {
      final d =
          await _api.getPosts(userId: widget.userId) as Map<String, dynamic>;
      if (!mounted) return;
      final all = ((d['results'] as List?) ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _posts =
            all.where((p) => (p['post_type'] ?? 'post') == 'post').toList();
        _fweets = all.where((p) => (p['post_type'] ?? '') == 'fweet').toList();
        _contentLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _contentLoading = false);
    }
  }

  /// Best-effort: the highlights feed returns highlights from people you
  /// follow (and yourself). We filter to this user's by matching either
  /// their user_id string or their UUID. A dedicated
  /// GET /users/<id>/highlights/ endpoint would be more reliable for
  /// users you don't follow — flagged for the backend.
  Future<void> _fetchHighlights() async {
    setState(() => _highlightsLoading = true);
    try {
      final ids = <String>{widget.userId};
      final uuid = (_user?['id'] ?? '').toString();
      if (uuid.isNotEmpty) ids.add(uuid);

      final d = await _api.get('/highlights/feed/');
      final list = d is List
          ? d
          : (d as Map<String, dynamic>?)?['results'] as List? ?? [];
      final cast = list.cast<Map<String, dynamic>>();
      final mine = cast.where((h) {
        final owner =
            (h['owner_id'] ?? h['user_id'] ?? h['author_id'] ?? h['owner'])
                    ?.toString() ??
                '';
        return ids.contains(owner);
      }).where(_isHighlightFresh).toList();

      if (!mounted) return;
      setState(() {
        _highlights = mine;
        _highlightsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _highlightsLoading = false);
    }
  }

  bool _isHighlightFresh(Map<String, dynamic> h) {
    final iso = h['created_at'] as String?;
    if (iso == null || iso.isEmpty) return true;
    try {
      final age =
          DateTime.now().toUtc().difference(DateTime.parse(iso).toUtc());
      return age.inHours < 24;
    } catch (_) {
      return true;
    }
  }

  void _onHighlightsDeleted() {
    final deleted = deletedHighlightIds.value;
    if (deleted.isEmpty || _highlights.isEmpty) return;
    setState(() => _highlights
        .removeWhere((h) => deleted.contains(h['id']?.toString())));
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    HapticFeedback.mediumImpact();
    final was = _isFollowing;
    setState(() {
      _isFollowing = !was;
      _followBusy = true;
    });
    try {
      await _api.followToggle(widget.userId);
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
          _followBusy = false;
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
      _snack('Chat request sent');
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
        targetUserId: widget.userId,
        targetName: _displayName,
        targetAvatarUrl: _avatarUrl,
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: _kCoral),
              title: T('Report user',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _kInk)),
              onTap: () async {
                Navigator.pop(context);
                if (_user == null) return;
                var uuid = (_user!['id'] ?? '').toString();
                if (uuid.isEmpty) uuid = widget.userId;
                final label =
                    (_user?['name'] as String?)?.trim().isNotEmpty == true
                        ? (_user!['name'] as String).trim()
                        : '@${(_user?['user_id'] as String?) ?? widget.userId}';
                await ReportSheet.show(
                  context,
                  contentType: 'user',
                  objectId: uuid,
                  targetLabel: label,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.block_rounded, color: _kSlate),
              title: T('Block user',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _kInk)),
              onTap: () async {
                Navigator.pop(context);
                await _confirmAndBlock();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndBlock() async {
    if (_user == null) {
      _snack('Profile not loaded yet - try again in a sec.', isError: true);
      return;
    }
    String uuid = (_user!['id'] ?? '').toString();
    if (uuid.isEmpty) uuid = widget.userId;
    if (uuid.isEmpty) {
      _snack('Cannot block - missing user identifier.', isError: true);
      return;
    }
    final name = (_user?['name'] as String?)?.trim().isNotEmpty == true
        ? (_user!['name'] as String).trim()
        : '@${(_user?['user_id'] as String?) ?? widget.userId}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: T('Block this user?',
            style: TextStyle(fontWeight: FontWeight.w900, color: _kInk)),
        content: Text(
          'You will no longer see posts or messages from $name, and they '
          'will not see yours. You can unblock anytime in Settings.',
          style: TextStyle(color: _kSlate, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: T('Cancel',
                style: TextStyle(color: _kSlate, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kCoral),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const T('Block'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await ModerationService.instance.blockUser(uuid);
    if (!mounted) return;
    _snack(
      success ? '$name blocked.' : 'Could not block. Try again.',
      isError: !success,
    );
    if (success) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openSocial(String key, String value) async {
    final url = _socialUrl(key, value);
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: url));
    _snack('Link copied - paste it in your browser');
  }

  Future<void> _openHighlight(Map<String, dynamic> h) async {
    HapticFeedback.lightImpact();
    var items = (h['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    if (items.isEmpty) {
      try {
        final full = await _api.getHighlight(h['id']?.toString() ?? '')
            as Map<String, dynamic>;
        items = (full['items'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
      } catch (_) {/* ignore */}
    }
    if (items.isEmpty) {
      _snack('No stories to show yet');
      return;
    }
    final stories = items.map((it) => HighlightStory.fromJson(it)).toList();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HighlightStoryViewer(stories: stories)),
    );
  }

  void _openDetail(Map<String, dynamic> item, {required bool isFweet}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PostDetailScreen(
        post: item,
        isFweet: isFweet,
        authorName: _displayName,
        authorAvatar: _avatarUrl,
      ),
    ));
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? _kCoral : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Privacy + identity helpers ────────────────────────────

  bool get _isMe =>
      _myUserId != null && _myUserId!.isNotEmpty && _myUserId == widget.userId;

  bool get _isCrossRole {
    if (_user == null || _myRole.isEmpty) return false;
    final mine = _groupOf(_myRole);
    final theirs = _groupOf((_user!['role'] as String?) ?? '');
    return (mine == 'student' && theirs == 'staff') ||
        (mine == 'staff' && theirs == 'student');
  }

  bool get _canSeeBio {
    if (_user == null) return false;
    final ps = _user!['privacy_settings'] as Map<String, dynamic>? ?? {};
    final isPub = ps['bio_public'] as bool? ?? true;
    return isPub || _isFollowing || _isMe;
  }

  String get _interestsVisibility =>
      (_user?['interests_visibility'] as String?) ?? 'public';

  bool get _canSeeInterests {
    if (_isMe) return true;
    switch (_interestsVisibility) {
      case 'private':
        return false;
      case 'followers':
        return _isFollowing;
      default:
        return true;
    }
  }

  List<Color> get _roleGradient {
    final role = (_user?['role'] as String?) ?? '';
    switch (role) {
      case 'student':
        return const [Color(0xFF22C55E), Color(0xFF06B6D4)];
      case 'teaching_staff':
      case 'non_teaching_staff':
        return const [_kPurple, _kBlue];
      case 'parent':
        return const [_kAmber, _kCoral];
      default:
        return const [_kBlue, _kPurple];
    }
  }

  String get _roleLabel {
    final role = (_user?['role'] as String?) ?? '';
    switch (role) {
      case 'student':
        return 'Student';
      case 'teaching_staff':
        return 'Teaching Staff';
      case 'non_teaching_staff':
        return 'Staff';
      case 'parent':
        return 'Parent';
      case 'visitor':
        return 'Visitor';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
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
  String? get _bio => _user?['bio'] as String?;
  List<dynamic> get _interests => (_user?['interests'] as List?) ?? const [];

  int get _followers => (_user?['followers_count'] as int?) ?? 0;
  bool get _isVerified => (_user?['is_verified'] as bool?) ?? false;

  Map<String, dynamic> get _socialLinksMap =>
      (_user?['social_links'] as Map?)?.cast<String, dynamic>() ?? const {};

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverToBoxAdapter(child: _buildHeaderCard()),
              SliverToBoxAdapter(child: _buildLinksCard()),
              SliverToBoxAdapter(child: _buildAboutCard()),
              SliverToBoxAdapter(child: const SizedBox(height: 8)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  height: 60,
                  builder: (_) => _buildTabBar(),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabCtrl,
              physics: const ClampingScrollPhysics(),
              children: [
                _buildPostsGrid(),
                _buildFweetsGrid(),
                _buildHighlightsGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
          const Spacer(),
          _circleBtn(Icons.ios_share_rounded, _openShareSheet),
          const SizedBox(width: 8),
          _circleBtn(Icons.more_vert_rounded, _showMoreMenu),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, color: _kInkSoft, size: 18),
        ),
      );

  // ── Header card ───────────────────────────────────────────

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 20,
        borderWidth: 2,
        innerColor: _kCard,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatarCircle(76),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _kInk,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (_isVerified) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded,
                                  color: _kPurple, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _roleTagPill(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _actionArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: _roleGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: (_avatarUrl ?? '').isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _avatarFallback(),
                errorWidget: (_, __, ___) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: _kCardLo,
        alignment: Alignment.center,
        child: Text(
          _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: _kPurple),
        ),
      );

  Widget _roleTagPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: _roleGradient.map((c) => c.withOpacity(0.14)).toList()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _roleGradient.first.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_roleLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _roleGradient.last)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(_handleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _kSlate)),
          ),
        ],
      ),
    );
  }

  /// Followers count + Follow + Chat Request (or a read-only pill for
  /// cross-role / self).
  Widget _actionArea() {
    final followersCell = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_fmt(_followers),
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: _kInk)),
        const SizedBox(height: 1),
        T('Followers',
            style: TextStyle(
                fontSize: 10.5, color: _kSlate, fontWeight: FontWeight.w600)),
      ],
    );

    Widget trailing;
    if (_isMe) {
      trailing = Expanded(child: _infoPill('This is your profile', null));
    } else if (_isCrossRole) {
      trailing = Expanded(
          child: _infoPill('Profile view only', Icons.lock_outline_rounded));
    } else {
      trailing = Expanded(
        child: Row(
          children: [
            Expanded(child: _followBtn()),
            const SizedBox(width: 8),
            Expanded(child: _chatBtn()),
          ],
        ),
      );
    }

    return Row(
      children: [
        SizedBox(width: 70, child: followersCell),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }

  Widget _infoPill(String label, IconData? icon) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: _kCardLo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: _kSlate),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kSlate)),
            ),
          ],
        ),
      );

  Widget _followBtn() {
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
                  end: Alignment.centerRight),
          color: following ? _kCard : null,
          borderRadius: BorderRadius.circular(14),
          border: following ? Border.all(color: _kBorder, width: 1.5) : null,
        ),
        child: Center(
          child: _followBusy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: following ? _kPurple : Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following
                          ? Icons.check_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: following ? _kPurple : Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        following ? 'Following' : 'Follow',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: following ? _kPurple : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _chatBtn() {
    final sent = _chatReqSent;
    return GestureDetector(
      onTap: (_chatReqBusy || sent) ? null : _sendChatRequest,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sent ? Colors.green.shade400 : _kBorder,
            width: 1.5,
          ),
        ),
        child: Center(
          child: _chatReqBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kPurple),
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
                      color: sent ? Colors.green.shade600 : _kInkSoft,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        sent ? 'Requested' : 'Chat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: sent ? Colors.green.shade600 : _kInkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  // ── Links card (display-only, hidden when empty) ──────────

  Widget _buildLinksCard() {
    final links = _socialLinksMap;
    final chips = <Widget>[];
    for (final k in _kSocialOrder) {
      final v = links[k]?.toString().trim() ?? '';
      if (v.isEmpty) continue;
      final m = _kSocial[k] ?? _kSocial['website']!;
      chips.add(GestureDetector(
        onTap: () => _openSocial(k, v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: m.color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: m.color.withOpacity(0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 15, color: m.color),
              const SizedBox(width: 6),
              Text(m.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: m.color)),
            ],
          ),
        ),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      ),
    );
  }

  // ── About card (public bio + visible interests) ───────────

  Widget _buildAboutCard() {
    final bioText = (_bio ?? '').trim();
    final showBio = _canSeeBio && bioText.isNotEmpty;
    final showInterests = _canSeeInterests && _interests.isNotEmpty;
    if (!showBio && !showInterests) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: _kPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.person_outline_rounded,
                      color: _kPurple, size: 15),
                ),
                const SizedBox(width: 8),
                T('About Me',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _kInk)),
              ],
            ),
            if (showBio) ...[
              const SizedBox(height: 10),
              Text(bioText,
                  style: const TextStyle(
                      fontSize: 14, color: _kInkSoft, height: 1.5)),
            ],
            if (showInterests) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_interests.length, (i) {
                  final c = [_kBlue, _kPurple, _kAmber, _kCoral][i % 4];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.10),
                      border: Border.all(color: c.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_interests[i].toString(),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c)),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────

  Widget _buildTabBar() {
    const labels = ['Posts', 'Fweets', 'Highlights'];
    const n = 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kCardLo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: AnimatedBuilder(
          animation: _tabCtrl.animation!,
          builder: (_, __) {
            final pos = _tabCtrl.animation!.value.clamp(0.0, n - 1.0);
            return LayoutBuilder(builder: (_, c) {
              final segW = c.maxWidth / n;
              return Stack(children: [
                Positioned(
                  left: pos * segW,
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: Container(
                    decoration: BoxDecoration(
                        color: _kInk, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < n; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _tabCtrl.animateTo(i);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                // Selected label sits on the _kInk pill, so it
                                // has to invert with the theme, not stay white.
                                color: Color.lerp(_kSlate, AppC.card,
                                    1.0 - (pos - i).abs().clamp(0.0, 1.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ]);
            });
          },
        ),
      ),
    );
  }

  // ── Grids (no add tiles, no delete) ───────────────────────

  EdgeInsets get _gridPad => EdgeInsets.fromLTRB(
      16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 40);

  SliverGridDelegateWithFixedCrossAxisCount get _grid =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      );

  Widget _loader(Color color) =>
      Center(child: CircularProgressIndicator(color: color));

  Widget _buildPostsGrid() {
    if (_contentLoading) return _loader(_kPurple);
    if (_posts.isEmpty) {
      return _emptyTab(Icons.article_outlined, 'No posts yet', _kPurple);
    }
    return GridView.builder(
      padding: _gridPad,
      physics:
          const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      gridDelegate: _grid,
      itemCount: _posts.length,
      itemBuilder: (_, i) {
        final p = _posts[i];
        return _gridCell(
          onTap: () => _openDetail(p, isFweet: false),
          child: _postThumb(p),
        );
      },
    );
  }

  Widget _buildFweetsGrid() {
    if (_contentLoading) return _loader(_kCoral);
    if (_fweets.isEmpty) {
      return _emptyTab(
          Icons.chat_bubble_outline_rounded, 'No fweets yet', _kCoral);
    }
    return GridView.builder(
      padding: _gridPad,
      physics:
          const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      gridDelegate: _grid,
      itemCount: _fweets.length,
      itemBuilder: (_, i) {
        final f = _fweets[i];
        return _gridCell(
          onTap: () => _openDetail(f, isFweet: true),
          child: _fweetThumb(f),
        );
      },
    );
  }

  Widget _buildHighlightsGrid() {
    if (_highlightsLoading) return _loader(_kBlue);
    if (_highlights.isEmpty) {
      return _emptyTab(Icons.auto_awesome_rounded, 'No highlights yet', _kBlue);
    }
    return GridView.builder(
      padding: _gridPad,
      physics:
          const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      gridDelegate: _grid,
      itemCount: _highlights.length,
      itemBuilder: (_, i) {
        final h = _highlights[i];
        return _gridCell(
          onTap: () => _openHighlight(h),
          child: _highlightThumb(h),
        );
      },
    );
  }

  Widget _gridCell({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(color: _kCardLo, child: child),
      ),
    );
  }

  Widget _postThumb(Map<String, dynamic> p) {
    final rawMedia =
        (p['media'] as List?) ?? (p['media_files'] as List?) ?? const [];
    final media = <Map<String, dynamic>>[];
    for (final m in rawMedia) {
      if (m is Map) media.add(Map<String, dynamic>.from(m));
    }
    if (media.isEmpty) {
      final legacy = (p['media_url'] ?? '').toString();
      if (legacy.isNotEmpty) media.add({'url': legacy, 'media_type': 'image'});
    }
    final content = (p['content'] as String? ?? '').trim();
    if (media.isEmpty) return _textThumb(content, const [_kPurple, _kBlue]);

    final m = media.first;
    final isVideo = (m['media_type'] ?? m['type'] ?? '')
        .toString()
        .toLowerCase()
        .contains('video');
    final img = isVideo
        ? (m['thumbnail_url'] ?? m['url'] ?? '').toString()
        : (m['url'] ?? m['thumbnail_url'] ?? '').toString();
    if (img.isEmpty) return _textThumb(content, const [_kPurple, _kBlue]);

    return Stack(fit: StackFit.expand, children: [
      CachedNetworkImage(
        imageUrl: img,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: _kCardLo),
        errorWidget: (_, __, ___) =>
            _textThumb(content, const [_kPurple, _kBlue]),
      ),
      if (isVideo)
        const Center(
          child: Icon(Icons.play_circle_fill_rounded,
              color: Colors.white, size: 30),
        ),
      if (media.length > 1)
        const Positioned(
          top: 6,
          right: 6,
          child: Icon(Icons.collections_rounded, color: Colors.white, size: 15),
        ),
    ]);
  }

  Widget _fweetThumb(Map<String, dynamic> f) {
    final content = (f['content'] as String? ?? '').trim();
    final bgHex = (f['background_color'] as String? ?? '').trim();
    Color? bg;
    try {
      if (bgHex.isNotEmpty) {
        bg = Color(int.parse('FF${bgHex.replaceAll('#', '')}', radix: 16));
      }
    } catch (_) {}
    final colors = bg != null
        ? [bg, bg.withOpacity(0.82)]
        : const [_kCoral, Color(0xFFFF8A65)];
    return _textThumb(content, colors, label: '⚡');
  }

  Widget _textThumb(String content, List<Color> colors, {String? label}) {
    final onColor = colors.first.computeLuminance() > 0.6 ? _kInk : Colors.white;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Stack(children: [
        Center(
          child: Text(
            content.isEmpty ? 'Post' : content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: onColor),
          ),
        ),
        if (label != null)
          Positioned(
              top: 0,
              left: 0,
              child: Text(label, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Widget _highlightThumb(Map<String, dynamic> h) {
    final cover = (h['cover_url'] as String? ?? '').trim();
    final count = (h['items'] as List?)?.length ?? 0;
    return Stack(fit: StackFit.expand, children: [
      if (cover.isNotEmpty)
        CachedNetworkImage(
          imageUrl: cover,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: _kCardLo),
          errorWidget: (_, __, ___) => _highlightFallback(),
        )
      else
        _highlightFallback(),
      Container(color: Colors.black.withOpacity(0.12)),
      const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Colors.white, size: 28),
      ),
      if (count > 1)
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }

  Widget _highlightFallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_kBlue, _kPurple]),
        ),
        child: const Center(
            child: Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 26)),
      );

  Widget _emptyTab(IconData icon, String title, Color color) {
    return ListView(
      padding: _gridPad,
      physics:
          const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      children: [
        const SizedBox(height: 50),
        Center(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withOpacity(0.25), width: 1.5),
                ),
                child: Icon(icon, size: 32, color: color.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _kInk)),
              const SizedBox(height: 6),
              Text('$_displayName hasn\'t shared any yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: _kSlate)),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — animated sweep-gradient border
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final double radius;
  final double borderWidth;
  final Color? innerColor;
  final List<Color> colors;

  _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(math.max(0.0, radius - borderWidth)),
        color: innerColor ?? _kCard,
      ),
      child: child,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (_, c) {
        final v = animation.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: SweepGradient(
                colors: colors, startAngle: v, endAngle: v + 2 * math.pi),
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
// Sticky tab-bar delegate
// ═════════════════════════════════════════════════════════════

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;
  final double height;
  _StickyTabBarDelegate({required this.builder, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: _kBg1,
        border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
      ),
      child: builder(context),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate old) =>
      old.height != height;
}

// ═════════════════════════════════════════════════════════════
// POST / FWEET DETAIL — opens full-screen from a grid tile.
// ═════════════════════════════════════════════════════════════

class _PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isFweet;
  final String authorName;
  final String? authorAvatar;
  const _PostDetailScreen({
    required this.post,
    required this.isFweet,
    required this.authorName,
    required this.authorAvatar,
  });

  int _n(String k) {
    final v = post[k];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final content = (post['content'] as String? ?? '').trim();
    final rawMedia =
        (post['media'] as List?) ?? (post['media_files'] as List?) ?? const [];
    final media = <Map<String, dynamic>>[];
    for (final m in rawMedia) {
      if (m is Map) media.add(Map<String, dynamic>.from(m));
    }
    if (media.isEmpty) {
      final legacy = (post['media_url'] ?? '').toString();
      if (legacy.isNotEmpty) media.add({'url': legacy, 'media_type': 'image'});
    }
    final location = (post['location'] as String? ?? '').trim();
    final likes = _n('like_count') + _n('likes_count');
    final comments = _n('comment_count') + _n('comments_count');
    final favs =
        _n('favorite_count') + _n('favorites_count') + _n('bookmark_count');

    Color? bg;
    final bgHex = (post['background_color'] as String? ?? '').trim();
    try {
      if (bgHex.isNotEmpty) {
        bg = Color(int.parse('FF${bgHex.replaceAll('#', '')}', radix: 16));
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppC.card,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: _kInk),
                onPressed: () => Navigator.pop(context),
              ),
              Text(isFweet ? 'Fweet' : 'Post',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: _kInk)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_kPurple, _kBlue]),
                    ),
                    child: ClipOval(
                      child: (authorAvatar != null && authorAvatar!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: authorAvatar!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _initial())
                          : _initial(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: _kInk)),
                  ),
                ]),
                const SizedBox(height: 14),
                if (isFweet && bg != null)
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [bg, bg.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(content,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                              color: bg.computeLuminance() > 0.6
                                  ? _kInk
                                  : Colors.white)),
                    ),
                  )
                else ...[
                  if (media.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: PageView.builder(
                          itemCount: media.length,
                          itemBuilder: (_, i) =>
                              MediaItemView(item: media[i], height: 300),
                        ),
                      ),
                    ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(content,
                        style: TextStyle(
                            fontSize: 15, color: _kInk, height: 1.5)),
                  ],
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: _kCoral),
                    const SizedBox(width: 4),
                    Text(location,
                        style: TextStyle(fontSize: 12, color: _kSlate)),
                  ]),
                ],
                const SizedBox(height: 18),
                Divider(height: 1, color: _kBorder),
                const SizedBox(height: 14),
                Row(children: [
                  _stat(Icons.favorite_rounded, likes, _kCoral),
                  const SizedBox(width: 22),
                  _stat(Icons.mode_comment_rounded, comments, _kBlue),
                  const SizedBox(width: 22),
                  _stat(Icons.bookmark_rounded, favs, _kPurple),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _initial() => Container(
        color: _kCardLo,
        alignment: Alignment.center,
        child: Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: _kPurple, fontWeight: FontWeight.w900, fontSize: 16)),
      );

  Widget _stat(IconData icon, int count, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _kInk)),
        ],
      );
}