// lib/screens/profile/profile_screen.dart
//
// Redesigned per spec:
//   • No cover photo. A gradient-bordered (2px, r20) header card holds:
//       Row[ avatar(+edit badge) , Column[ name, role tag, stats row ] ]
//       with the Settings button pinned top-right of the card.
//   • A links card: an Add button (opens the links bottom sheet) followed by
//       tappable platform chips that open the user's profile on each platform.
//   • An About Me card with Interests / Bio / Edit buttons.
//   • Tabs Posts · Highlights · Fweets, each a 3-column grid:
//       - empty  → "No … yet" + icon + a "Make your first …" button
//       - filled → first cell is an Add tile, then the items; tap a cell to
//         open it full-screen; long-press a cell to permanently delete it
//         (after a confirm dialog). Highlights also expire after 24h and can
//         be deleted early — deletion propagates to the feed via
//         deletedHighlightIds.
//
// Removed vs the old screen (per the new layout): the cover photo, the
// profile-share sheet, bio/interests privacy toggles, and the Clubs tab. Ask
// if you want any of those re-added.

import 'dart:async';
import 'package:tcs_app/widgets/t_text.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tcs_app/services/settings_Screen.dart';

import '../../models/biodata.dart';
import '../../services/api_service.dart';
import '../../services/cache_store.dart';
import 'bio.dart';
import 'create_highlight_page.dart';
import 'createpostspage.dart';
import 'fweetspage.dart';
import 'interests.dart';
import 'media_item_view.dart';
import '../../highlight_story_viewer.dart';
import '../feed/feed_screen.dart' show deletedHighlightIds;

// ── Light palette ────────────────────────────────────────────
Color get _kBg1 => AppC.bg;
Color get _kBg2 => AppC.bg;
Color get _kBg3 => AppC.bg;
Color get _kCard => AppC.card;
Color get _kCardLo => AppC.card2;
Color get _kBorder => AppC.border;
Color get _kSlate2 => AppC.sub;
Color get _kSlate => AppC.sub;
Color get _kInkSoft => AppC.sub;
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

// ── Cross-screen post-deletion notifier (preserved) ──────────
final deletedPostIds = ValueNotifier<Set<String>>({});
void notifyPostDeleted(String id) =>
    deletedPostIds.value = {...deletedPostIds.value, id};
void resetGlobalProfileState() => deletedPostIds.value = {};

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
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _picker = ImagePicker();
  late final TabController _tabCtrl;
  late final AnimationController _shimmerCtrl;

  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _fweets = [];
  List<Map<String, dynamic>> _highlights = [];
  final List<String> _interests = [];
  Map<String, dynamic> _socialLinks = {};

  int _followers = 0;
  int _following = 0;
  bool _postsLoading = true;
  bool _fweetsLoading = true;
  bool _highlightsLoading = true;

  String? _myUserId;
  BioData? _bioData;

  // AI-composed "About Me" (bio + interests woven into one paragraph).
  String? _aboutMe;
  bool    _aboutLoading = false;
  String? _aboutSig;      // signature of the bio+interests that produced _aboutMe

  File? _avatarFile;
  String? _avatarUrl;
  bool _avatarUploading = false;

  static const _kAvatarUrlPrefix = 'profile_avatar_url_';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _loadSavedUrls();
    _fetchPosts();
    _fetchFweets();
    _fetchHighlights();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Data fetches ──────────────────────────────────────────

  // Stale-while-revalidate: paint instantly from cache (warmed at login),
  // then silently refresh. Loading flags start true (field defaults), so
  // the spinner still shows on the very first load with no cached value.

  void _fetchPosts() {
    CacheStore.I.swr(
      'profile:posts',
      fetch: () => _api.getMyPosts(),
      onData: (data, fresh) {
        if (!mounted) return;
        final d = (data as Map).cast<String, dynamic>();
        setState(() {
          _posts = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
          _postsLoading = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _postsLoading = false);
      },
    );
  }

  void _fetchFweets() {
    CacheStore.I.swr(
      'profile:fweets',
      fetch: () => _api.getMyFweets(),
      onData: (data, fresh) {
        if (!mounted) return;
        final d = (data as Map).cast<String, dynamic>();
        setState(() {
          _fweets = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
          _fweetsLoading = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _fweetsLoading = false);
      },
    );
  }

  void _fetchHighlights() {
    CacheStore.I.swr(
      'profile:highlights',
      fetch: () => _api.getMyHighlights(),
      onData: (data, fresh) {
        if (!mounted) return;
        final list = data is List
            ? data
            : (data as Map<String, dynamic>?)?['results'] as List? ?? [];
        final cast = list.cast<Map<String, dynamic>>();
        final freshItems = cast.where(_isHighlightFresh).toList();
        setState(() {
          _highlights = freshItems;
          _highlightsLoading = false;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _highlightsLoading = false);
      },
    );
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

  void _fetchStats() {
    CacheStore.I.swr(
      'profile:me',
      fetch: () => _api.getMyProfile(),
      onData: (data, fresh) {
        if (!mounted) return;
        final d = (data as Map).cast<String, dynamic>();
        setState(() {
        _followers = d['followers_count'] as int? ?? 0;
        _following = d['following_count'] as int? ?? 0;

        final uid = d['user_id'] as String?;
        if (uid != null && uid.isNotEmpty) _myUserId = uid;

        final saved = (d['interests'] as List?)?.cast<String>();
        if (saved != null) {
          _interests
            ..clear()
            ..addAll(saved);
        }

        final hasBio = d['bio'] != null ||
            d['quote'] != null ||
            d['pronouns'] != null ||
            d['country'] != null ||
            d['year'] != null ||
            d['school'] != null ||
            d['study_style'] != null;
        if (hasBio) {
          _bioData = BioData(
            bio: d['bio'] as String?,
            quote: d['quote'] as String?,
            pronouns: d['pronouns'] as String?,
            country: d['country'] as String?,
            year: d['year'] as String?,
            school: d['school'] as String?,
            studyStyle: d['study_style'] as String?,
            availableForStudy: d['is_available_study'] as bool? ?? false,
          );
        }

        _socialLinks = (d['social_links'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final av = d['avatar_url'] as String?;
        if (av != null && av.isNotEmpty && _avatarFile == null) _avatarUrl = av;
      });
      // Bio + interests are now loaded — compose (or restore) the About Me.
      _maybeGenerateAbout();
      },
      onError: (_) {},
    );
  }

  // ── Persist / restore avatar URL ──────────────────────────

  Future<String?> _ownUserId() async =>
      (await SharedPreferences.getInstance()).getString('userId');

  Future<void> _loadSavedUrls() async {
    final uid = await _ownUserId();
    if (uid == null || uid.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final av = p.getString('$_kAvatarUrlPrefix$uid');
    if (av != null && av.isNotEmpty) setState(() => _avatarUrl = av);
  }

  Future<void> _saveAvatarUrl(String url) async {
    final uid = await _ownUserId();
    if (uid == null || uid.isEmpty) return;
    (await SharedPreferences.getInstance())
        .setString('$_kAvatarUrlPrefix$uid', url);
  }

  // ── Avatar pick + upload ──────────────────────────────────

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (x == null) return;
    final f = File(x.path);
    setState(() {
      _avatarFile = f;
      _avatarUploading = true;
    });
    try {
      final res = await _api.uploadAvatar(f) as Map<String, dynamic>;
      final url = res['avatar_url'] as String? ?? '';
      if (url.isNotEmpty) {
        setState(() => _avatarUrl = url);
        await _saveAvatarUrl(url);
      }
    } catch (_) {
      _snack('Avatar upload failed', error: true);
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────

  Future<void> _openInterests() async {
    final r = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(builder: (_) => InterestsPage(initial: _interests)));
    if (r != null) {
      setState(() {
        _interests
          ..clear()
          ..addAll(r);
      });
      // Persist so interests survive leaving the page / reopening the profile.
      try {
        await _api.updateProfile({'interests': r});
      } catch (_) {
        if (mounted) _snack('Could not save interests', error: true);
      }
      _maybeGenerateAbout();   // interests changed → refresh the About Me
    }
  }

  Future<void> _openBio() async {
    final r = await Navigator.of(context)
        .push<BioData>(MaterialPageRoute(builder: (_) => BioPage(existing: _bioData)));
    if (r != null) {
      setState(() => _bioData = r);
      _maybeGenerateAbout();   // bio changed → refresh the About Me
    }
  }

  // ── AI "About Me" ─────────────────────────────────────────
  // Weave the user's bio + interests into one paragraph via /ai/about-me/.
  // Cached on-device keyed by a signature of the inputs, so we only hit the
  // model when the bio or interests actually change.

  String get _aboutBioText => (_bioData?.bio ?? '').trim();

  String _computeAboutSig() =>
      '$_aboutBioText::${(List<String>.from(_interests)..sort()).join(',')}';

  String get _aboutTextKey => 'about_me_text_${_myUserId ?? ''}';
  String get _aboutSigKey  => 'about_me_sig_${_myUserId ?? ''}';

  /// Generate (or restore from cache) the About Me paragraph. Safe to call
  /// repeatedly — it no-ops when the inputs are unchanged.
  Future<void> _maybeGenerateAbout({bool force = false}) async {
    final bio = _aboutBioText;
    final interests = List<String>.from(_interests);
    if (bio.isEmpty && interests.isEmpty) {
      if (mounted) setState(() { _aboutMe = null; _aboutSig = null; });
      return;
    }
    final sig = _computeAboutSig();
    if (!force && sig == _aboutSig && (_aboutMe?.isNotEmpty ?? false)) return;

    final p = await SharedPreferences.getInstance();
    if (!force) {
      final cachedSig = p.getString(_aboutSigKey);
      final cachedTxt = p.getString(_aboutTextKey);
      if (cachedSig == sig && cachedTxt != null && cachedTxt.isNotEmpty) {
        if (mounted) setState(() { _aboutMe = cachedTxt; _aboutSig = sig; });
        return;
      }
    }

    if (mounted) setState(() => _aboutLoading = true);
    try {
      final d = await _api.generateAboutMe(
        bio: bio,
        interests: interests,
        name: widget.preferredName.isNotEmpty
            ? widget.preferredName
            : widget.fullName,
      ) as Map;
      final about = (d['about'] as String?)?.trim() ?? '';
      if (about.isNotEmpty) {
        await p.setString(_aboutTextKey, about);
        await p.setString(_aboutSigKey, sig);
        if (mounted) setState(() { _aboutMe = about; _aboutSig = sig; });
      }
    } catch (_) {
      // Leave any previous text in place; the card falls back to the raw bio.
    } finally {
      if (mounted) setState(() => _aboutLoading = false);
    }
  }

  Future<void> _openCreatePost() async {
    final r = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CreatePostPage()));
    if (r != null && r is Map) {
      final np = (r['post'] as Map<String, dynamic>?) ?? {};
      if (np.isNotEmpty) setState(() => _posts.insert(0, np));
      _fetchPosts();
    }
  }

  Future<void> _openCreateFweet() async {
    final r = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const CreateFweetPage()));
    if (r != null && r.isNotEmpty) _fetchFweets();
  }

  Future<void> _openCreateHighlight() async {
    HapticFeedback.lightImpact();
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateHighlightPage()));
    if (created == true) _fetchHighlights();
  }

  Future<void> _openHighlight(Map<String, dynamic> h) async {
    HapticFeedback.lightImpact();
    var items = (h['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    if (items.isEmpty) {
      try {
        final full =
            await _api.getHighlight(h['id']?.toString() ?? '') as Map<String, dynamic>;
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
      builder: (_) => PostDetailScreen(
        post: item,
        isFweet: isFweet,
        authorName: widget.fullName,
        authorAvatar: _avatarUrl,
      ),
    ));
  }

  // ── Edit links sheet ──────────────────────────────────────

  Future<void> _editSocialLinks() async {
    HapticFeedback.lightImpact();
    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditLinksSheet(api: _api, initial: _socialLinks),
    );
    if (saved != null && mounted) {
      setState(() => _socialLinks = saved);
      _snack('Links updated');
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

  // ── Delete (long-press) ───────────────────────────────────

  Future<bool> _confirmDelete(String type) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete $type?',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: _kInk)),
          content: Text('This $type will be permanently removed.',
              style: TextStyle(fontSize: 13, color: _kSlate, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: T('Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700, color: _kSlate)),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    color: _kCoral, borderRadius: BorderRadius.circular(12)),
                child: const T('Delete',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ) ??
      false;

  Future<void> _deletePostAt(int i) async {
    final id = _posts[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete('post')) return;
    try {
      await _api.deletePost(id);
      setState(() => _posts.removeAt(i));
      notifyPostDeleted(id);
      _snack('Post deleted');
    } catch (e) {
      _snack('Could not delete: $e', error: true);
    }
  }

  Future<void> _deleteFweetAt(int i) async {
    final id = _fweets[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete('fweet')) return;
    try {
      await _api.deletePost(id);
      setState(() => _fweets.removeAt(i));
      notifyPostDeleted(id);
      _snack('Fweet deleted');
    } catch (e) {
      _snack('Could not delete: $e', error: true);
    }
  }

  Future<void> _deleteHighlightAt(int i) async {
    final id = _highlights[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete('highlight')) return;
    try {
      await _api.delete('/highlights/$id/');
      setState(() => _highlights.removeAt(i));
      // Propagate to the feed (and any screen listening) so it disappears there too.
      deletedHighlightIds.value = {...deletedHighlightIds.value, id};
      _snack('Highlight deleted');
    } catch (e) {
      _snack('Could not delete: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? _kCoral : Colors.green.shade600,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Role helpers ──────────────────────────────────────────

  List<Color> get _roleGradient {
    switch (widget.role.toLowerCase()) {
      case 'student':
        return [const Color(0xFF22C55E), const Color(0xFF06B6D4)];
      case 'teaching_staff':
      case 'staff':
        return [_kPurple, _kBlue];
      case 'parent':
        return [_kAmber, _kCoral];
      default:
        return [_kBlue, _kPurple];
    }
  }

  String get _roleLabel {
    switch (widget.role.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'teaching_staff':
        return 'Teaching Staff';
      case 'non_teaching_staff':
        return 'Staff';
      case 'parent':
        return 'Parent';
      default:
        return widget.role;
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
              SliverToBoxAdapter(child: const SizedBox(height: 12)),
              SliverToBoxAdapter(child: _buildHeaderCard()),
              SliverToBoxAdapter(child: _buildLinksCard()),
              SliverToBoxAdapter(child: _buildAboutCard()),
              SliverToBoxAdapter(child: const SizedBox(height: 8)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  height: 60,
                  isDark: AppC.isDark,
                  builder: (_) => _buildTabBar(),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabCtrl,
              physics: const ClampingScrollPhysics(),
              children: [
                _buildPostsGrid(),
                _buildHighlightsGrid(),
                _buildFweetsGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header card ───────────────────────────────────────────

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: _GradientBorderCard(
        animation: _shimmerCtrl,
        radius: 20,
        borderWidth: 2,
        innerColor: _kCard,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatarWithEdit(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 28),
                          child: Text(
                            widget.fullName,
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
                        const SizedBox(height: 6),
                        _roleTagPill(),
                        const SizedBox(height: 14),
                        _statsRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kCardLo,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Icon(Icons.settings_rounded,
                      color: _kInkSoft, size: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarWithEdit() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: _roleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(child: _avatarContent()),
            ),
            if (_avatarUploading)
              const Positioned.fill(
                child: ClipOval(
                  child: ColoredBox(
                    color: Colors.black38,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: _roleGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  border: Border.all(color: _kCard, width: 2.5),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarContent() {
    if (_avatarFile != null) {
      return Image.file(_avatarFile!, fit: BoxFit.cover);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _avatarFallback(),
        errorWidget: (_, __, ___) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() => Container(
        color: _kCardLo,
        alignment: Alignment.center,
        child: Text(
          widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.w900, color: _kPurple),
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
          Text(
            _roleLabel,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _roleGradient.last),
          ),
          const SizedBox(width: 6),
          Text(_handleName,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: _kSlate)),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCell(_posts.length + _fweets.length, 'Posts'),
        _statDivider(),
        _statCell(_followers, 'Followers'),
        _statDivider(),
        _statCell(_following, 'Following'),
      ],
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 24, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _statCell(int value, String label) {
    String fmt(int v) {
      if (v >= 1000000) return '${(v / 1e6).toStringAsFixed(1)}M';
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
      return '$v';
    }

    return Expanded(
      child: Column(
        children: [
          Text(fmt(value),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _kInk)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, color: _kSlate, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Links card ────────────────────────────────────────────

  // Card shell with a brand purple→blue gradient border. The outer container
  // is the gradient; a 1.4px inset reveals it as a hairline border around the
  // inner (theme-aware) surface.
  Widget _gradientCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPurple, _kBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16.6),
        ),
        child: child,
      ),
    );
  }

  Widget _buildLinksCard() {
    final chips = <Widget>[];
    for (final k in _kSocialOrder) {
      final v = _socialLinks[k]?.toString().trim() ?? '';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _gradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + inline "Add link" button (mirrors About Me).
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.share_rounded,
                      color: _kBlue, size: 15),
                ),
                const SizedBox(width: 8),
                T('Other Socials',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _kInk)),
                const Spacer(),
                GestureDetector(
                  onTap: _editSocialLinks,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [_kPurple, _kBlue]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 4),
                        T('Add Link',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Links: horizontal scroll of same-size chips, or a prompt.
            if (chips.isEmpty)
              T('Add your Instagram, TikTok, YouTube and more.',
                  style: TextStyle(fontSize: 12.5, color: _kSlate))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (int i = 0; i < chips.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                            right: i == chips.length - 1 ? 0 : 8),
                        child: chips[i],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── About card ────────────────────────────────────────────

  Widget _buildAboutCard() {
    final bio = _bioData;
    final hasBio = bio != null && !bio.isEmpty && (bio.bio ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _gradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + inline edit actions (interests / bio).
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
                const Spacer(),
                _aboutIconBtn(Icons.interests_rounded, 'Edit interests',
                    _kPurple, _openInterests),
                const SizedBox(width: 8),
                _aboutIconBtn(Icons.edit_note_rounded, 'Edit bio',
                    _kBlue, hasBio ? _showBioSheet : _openBio),
              ],
            ),
            const SizedBox(height: 12),
            _aboutBody(hasBio),
          ],
        ),
      ),
    );
  }

  // Small circular icon-button used in the About Me header.
  Widget _aboutIconBtn(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  // The card body: AI-woven paragraph, clamped with a "…more" link. Falls
  // back to the raw bio, then to a friendly prompt when there's nothing yet.
  Widget _aboutBody(bool hasBio) {
    if (_aboutLoading && (_aboutMe == null || _aboutMe!.isEmpty)) {
      return Row(
        children: [
          SizedBox(
            width: 15, height: 15,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple),
          ),
          const SizedBox(width: 10),
          Text('Composing your About Me…',
              style: TextStyle(
                  fontSize: 13, color: _kSlate, fontStyle: FontStyle.italic)),
        ],
      );
    }

    final text = (_aboutMe?.trim().isNotEmpty ?? false)
        ? _aboutMe!.trim()
        : (hasBio ? _bioData!.bio!.trim() : '');

    if (text.isEmpty) {
      return Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: _kSlate),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Add a bio and a few interests — I’ll write your About Me for you.',
              style: TextStyle(fontSize: 13, color: _kSlate, height: 1.4),
            ),
          ),
        ],
      );
    }

    final style = TextStyle(fontSize: 14, color: _kInkSoft, height: 1.55);
    const maxLines = 4;

    return LayoutBuilder(
      builder: (ctx, c) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: c.maxWidth);
        final overflows = tp.didExceedMaxLines;

        if (!overflows) return Text(text, style: style);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: style,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showAboutDialog(text),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('…more',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _kPurple)),
                  const SizedBox(width: 2),
                  const Icon(Icons.expand_more_rounded,
                      size: 16, color: _kPurple),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Full-text "About Me" dialog opened from the "…more" link.
  void _showAboutDialog(String text) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => Dialog(
        backgroundColor: _kCard,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header band
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_kPurple, _kBlue]),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.fullName.isNotEmpty
                            ? 'About ${widget.fullName.split(' ').first}'
                            : 'About Me',
                        style: const TextStyle(
                            fontFamily: 'Alfa',
                            fontSize: 17,
                            color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 15, height: 1.6, color: _kInk)),
                ),
              ),
              // Interest chips footer (if any)
              if (_interests.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests.map((interest) {
                      final col = [_kBlue, _kPurple, _kAmber, _kCoral]
                          [_interests.indexOf(interest) % 4];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: col.withOpacity(0.10),
                          border: Border.all(color: col.withOpacity(0.25)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(interest,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: col)),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBioSheet() {
    final bio = _bioData;
    if (bio == null) {
      _openBio();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _kBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              T('Bio',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
              const SizedBox(height: 16),
              if (bio.bio != null)
                _BioRow(Icons.edit_note_rounded, 'Bio', bio.bio!, _kPurple),
              if (bio.quote != null)
                _BioRow(Icons.format_quote_rounded, 'Quote', bio.quote!, _kAmber),
              if (bio.pronouns != null)
                _BioRow(Icons.tag_rounded, 'Pronouns', bio.pronouns!, _kBlue),
              if (bio.country != null)
                _BioRow(Icons.public_rounded, 'Country', bio.country!, _kCoral),
              if (bio.year != null)
                _BioRow(Icons.grade_rounded, 'Year', bio.year!, _kBlue),
              if (bio.school != null)
                _BioRow(Icons.location_city_rounded, 'School', bio.school!, _kAmber),
              if (bio.studyStyle != null)
                _BioRow(Icons.menu_book_rounded, 'Study Style', bio.studyStyle!, _kAmber),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _openBio();
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                      color: _kInk, borderRadius: BorderRadius.circular(14)),
                  child: const Center(
                    child: T('Edit Bio',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────

  Widget _buildTabBar() {
    const labels = ['Posts', 'Highlights', 'Fweets'];
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
                                // Active pill is _kInk (AppC.text) — light in
                                // dark mode — so the active label must resolve
                                // to AppC.bg to stay readable (dark-on-light in
                                // dark theme, light-on-dark in light theme).
                                color: Color.lerp(_kSlate, AppC.bg,
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

  // ── Grids ─────────────────────────────────────────────────

  EdgeInsets get _gridPad => EdgeInsets.fromLTRB(
      16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 90);

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
    if (_postsLoading) return _loader(_kPurple);
    if (_posts.isEmpty) {
      return _emptyTab(
        icon: Icons.article_outlined,
        title: 'No posts yet',
        button: 'Make your first post',
        color: _kPurple,
        onTap: _openCreatePost,
      );
    }
    return GridView.builder(
      padding: _gridPad,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      gridDelegate: _grid,
      itemCount: _posts.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _addTile('Post', _kPurple, _openCreatePost);
        final idx = i - 1;
        final p = _posts[idx];
        return _gridCell(
          onTap: () => _openDetail(p, isFweet: false),
          onLongPress: () => _deletePostAt(idx),
          child: _postThumb(p),
        );
      },
    );
  }

  Widget _buildFweetsGrid() {
    if (_fweetsLoading) return _loader(_kCoral);
    if (_fweets.isEmpty) {
      return _emptyTab(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No fweets yet',
        button: 'Make your first fweet',
        color: _kCoral,
        onTap: _openCreateFweet,
      );
    }
    return GridView.builder(
      padding: _gridPad,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      gridDelegate: _grid,
      itemCount: _fweets.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _addTile('Fweet', _kCoral, _openCreateFweet);
        final idx = i - 1;
        final f = _fweets[idx];
        return _gridCell(
          onTap: () => _openDetail(f, isFweet: true),
          onLongPress: () => _deleteFweetAt(idx),
          child: _fweetThumb(f),
        );
      },
    );
  }

  Widget _buildHighlightsGrid() {
    if (_highlightsLoading) return _loader(_kBlue);
    if (_highlights.isEmpty) {
      return _emptyTab(
        icon: Icons.auto_awesome_rounded,
        title: 'No highlights yet',
        button: 'Add a highlight',
        color: _kBlue,
        onTap: _openCreateHighlight,
      );
    }
    return GridView.builder(
      padding: _gridPad,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      gridDelegate: _grid,
      itemCount: _highlights.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _addTile('Highlight', _kBlue, _openCreateHighlight);
        final idx = i - 1;
        final h = _highlights[idx];
        return _gridCell(
          onTap: () => _openHighlight(h),
          onLongPress: () => _deleteHighlightAt(idx),
          child: _highlightThumb(h),
        );
      },
    );
  }

  // ── Tiles ─────────────────────────────────────────────────

  Widget _addTile(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4), width: 1.6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: color, size: 28),
            const SizedBox(height: 4),
            Text('Add $label',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _gridCell({
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress();
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(color: _kCardLo, child: child),
      ),
    );
  }

  Widget _postThumb(Map<String, dynamic> p) {
    final media = (p['media'] as List? ?? []).cast<Map<String, dynamic>>();
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
        errorWidget: (_, __, ___) => _textThumb(content, const [_kPurple, _kBlue]),
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
      child: Stack(
        children: [
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
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
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

  Widget _emptyTab({
    required IconData icon,
    required String title,
    required String button,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListView(
      padding: _gridPad,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
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
                  border: Border.all(color: color.withOpacity(0.25), width: 1.5),
                ),
                child: Icon(icon, size: 32, color: color.withOpacity(0.7)),
              ),
              const SizedBox(height: 18),
              Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _kInk)),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(button,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontSize: 13.5)),
                    ],
                  ),
                ),
              ),
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
        borderRadius:
            BorderRadius.circular(math.max(0.0, radius - borderWidth)),
        color: innerColor ?? _kCard,
      ),
      padding: padding,
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
  final bool isDark;
  _StickyTabBarDelegate(
      {required this.builder, required this.height, this.isDark = false});

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
      old.height != height || old.isDark != isDark;
}

// ═════════════════════════════════════════════════════════════
// Bio row
// ═════════════════════════════════════════════════════════════

class _BioRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _BioRow(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: _kSlate2,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(fontSize: 14, color: _kInk)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// Edit links sheet
// ═════════════════════════════════════════════════════════════

class _EditLinksSheet extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> initial;
  const _EditLinksSheet({required this.api, required this.initial});
  @override
  State<_EditLinksSheet> createState() => _EditLinksSheetState();
}

class _EditLinksSheetState extends State<_EditLinksSheet> {
  late final Map<String, TextEditingController> _ctrls;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final k in _kSocialOrder)
        k: TextEditingController(text: widget.initial[k]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final map = <String, dynamic>{};
    _ctrls.forEach((k, c) {
      final v = c.text.trim();
      if (v.isNotEmpty) map[k] = v;
    });
    try {
      await widget.api.updateProfile({'social_links': map});
      if (mounted) Navigator.pop(context, map);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: T('Could not save links. Try again.')),
        );
      }
    }
  }

  Widget _field(String key, TextEditingController c) {
    final m = _kSocial[key] ?? _kSocial['website']!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCardLo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(m.icon, size: 18, color: m.color),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(fontSize: 13, color: _kInk),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '${m.label} (handle or link)',
                hintStyle: TextStyle(color: _kSlate2, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppC.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _kBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                T('Your links',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _kInk)),
                const SizedBox(height: 4),
                T('Paste a full URL or just your handle.',
                    style: TextStyle(fontSize: 12, color: _kSlate)),
                const SizedBox(height: 16),
                for (final k in _kSocialOrder) _field(k, _ctrls[k]!),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _busy ? null : _save,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kPurple, _kBlue]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const T('Save',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
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
// POST / FWEET DETAIL — opens full-screen from a grid tile.
// ═════════════════════════════════════════════════════════════

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isFweet;
  final String authorName;
  final String? authorAvatar;
  const PostDetailScreen({
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
    final media = (post['media'] as List? ?? []).cast<Map<String, dynamic>>();
    final location = (post['location'] as String? ?? '').trim();
    final likes = _n('like_count') + _n('likes_count');
    final comments = _n('comment_count') + _n('comments_count');
    final favs = _n('favorite_count') + _n('favorites_count') + _n('bookmark_count');

    Color? bg;
    final bgHex = (post['background_color'] as String? ?? '').trim();
    try {
      if (bgHex.isNotEmpty) {
        bg = Color(int.parse('FF${bgHex.replaceAll('#', '')}', radix: 16));
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppC.bg,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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