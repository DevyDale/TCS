// lib/screens/profile/profile_screen.dart
//
// Profile (own) — redesigned to match the arcade light theme.
//
// Updates in this revision:
//   1. Posts and Fweets cards now wear LINEAR-GRADIENT borders — each
//      card pulls a gradient pair from a 6-pair palette so the wall
//      reads vibrant without becoming chaotic. The gradient is static
//      (not animated) so a long list of cards doesn't tax the GPU.
//   2. Highlights are GROUPED BY UPLOADER — multiple highlights from
//      the same user collapse into ONE circle, and tapping plays the
//      whole batch back-to-back in the viewer. On the user's own
//      profile this naturally produces a single "You" circle.
//   3. Highlights EXPIRE AFTER 24 HOURS. Stale entries are filtered
//      client-side using `created_at`; the backend should also be
//      pruning these on its own.
//   4. A new "Clubs" tab joins Posts / Fweets / Favorites — it lists
//      the latest posts from clubs the user has joined, rendered with
//      a club-logo header instead of an author-avatar header.
//   5. The Favorites tab now renders favorited EVENT posters as well
//      as posts/fweets. Items with `type == 'event'` show a poster
//      card with title, date, location, and host club.
//
// What still needs OTHER files (out of scope for this rewrite):
//   • Event comment & share features — needs an EventDetailScreen,
//     reuse of the existing comments widget, and API endpoints
//     (POST /events/<id>/comments/, POST /events/<id>/share/).
//   • Event tile redesign in club_screen.dart — replace the calendar-
//     icon placeholder in event tiles with a more characterful visual.
//   • Highlight story viewer caption position — move the highlight
//     title from the top of the viewer to the bottom-left corner
//     in highlight_story_viewer.dart.
//   • API endpoints: getMyClubsPosts() — backend should expose
//     GET /api/me/clubs/feed/ returning posts from clubs the user
//     has joined. The Clubs tab here calls _api.getMyClubsPosts()
//     and gracefully handles its absence (empty state).

import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/services/settings_Screen.dart';

import '../../models/biodata.dart';
import '../../services/api_service.dart';
import 'bio.dart';
import 'create_highlight_page.dart';
import 'createpostspage.dart';
import 'fweetspage.dart';
import 'interests.dart';
import 'media_item_view.dart';
import '../../highlight_story_viewer.dart';
import '../../widgets/privacy_toggle_sheet.dart';
import 'share_profile_screen.dart';

// ── Light palette (matches arcade) ───────────────────────────
const _kBg1     = Color(0xFFFAFAFC);
const _kBg2     = Color(0xFFE6E6EE);
const _kBg3     = Color(0xFFF2F2F6);
const _kCard    = Color(0xFFFFFFFF);
const _kCardLo  = Color(0xFFF5F5F8);
const _kBorder  = Color(0xFFE5E7EB);
const _kSlate2  = Color(0xFF9CA3AF);
const _kSlate   = Color(0xFF6B7280);
const _kInkSoft = Color(0xFF374151);
const _kInk     = Color(0xFF0D0D1A);

const _kBlue   = Color(0xFF6DD5FA);
const _kPurple = Color(0xFF7C3AED);
const _kAmber  = Color(0xFFF59E0B);
const _kCoral  = Color(0xFFFF4F6E);

const _gradColors = <Color>[
  Color(0xFF6DD5FA), Color(0xFF7C3AED),
  Color(0xFFF59E0B), Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

// ── Gradient palette for STATIC tile borders ─────────────────
// Each card pulls one pair from this list using `_gradFor(index)` so
// neighboring cards never wear the same gradient. Six pairs cover
// most lists without obvious repetition above the fold.
const _gradientPairs = <List<Color>>[
  [_kBlue,   _kPurple],
  [_kPurple, _kCoral ],
  [_kCoral,  _kAmber ],
  [_kAmber,  _kBlue  ],
  [_kPurple, _kAmber ],
  [_kBlue,   _kCoral ],
];
List<Color> _gradFor(int i) =>
    _gradientPairs[i % _gradientPairs.length];

// ── Global notifier (preserved) ──────────────────────────────
final deletedPostIds = ValueNotifier<Set<String>>({});
void notifyPostDeleted(String id) =>
    deletedPostIds.value = {...deletedPostIds.value, id};
/// Reset cross-screen UI state. Call this on logout.
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
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _api    = ApiService();
  final _picker = ImagePicker();
  late final TabController _tabCtrl;
  late final AnimationController _shimmerCtrl;

  List<Map<String, dynamic>> _posts      = [];
  List<Map<String, dynamic>> _fweets     = [];
  List<Map<String, dynamic>> _favorites  = [];
  List<Map<String, dynamic>> _highlights = [];
  // NEW — posts from clubs the user has joined, for the Clubs tab.
  List<Map<String, dynamic>> _clubPosts  = [];
  final List<String>         _interests  = [];

  int  _followers = 0;
  int  _following = 0;
  bool _postsLoading      = true;
  bool _fweetsLoading     = true;
  bool _favoritesLoading  = true;
  bool _highlightsLoading = true;
  bool _clubPostsLoading  = true;     // NEW

  String? _myUserId;

  bool   _bioPublic    = true;
  String _interestsVis = 'public';
  bool _interestsSeeded = false;

  BioData? _bioData;

  File?   _avatarFile;
  String? _avatarUrl;
  File?   _coverFile;
  String? _coverUrl;
  bool    _avatarUploading = false;
  bool    _coverUploading  = false;

  // ── user-scoped SharedPreferences keys ──
  // Suffixed with the current user_id so two accounts on the
  // same device never read each other's avatar/cover URLs.
  static const _kAvatarUrlPrefix = 'profile_avatar_url_';
  static const _kCoverUrlPrefix  = 'profile_cover_url_';
  static const _kCoverH    = 180.0;
  static const _kAvatarR   = 52.0;

  @override
  void initState() {
    super.initState();
    // FOUR tabs now: Posts · Fweets · Favorites · Clubs
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))..repeat();
    _loadSavedUrls();
    _fetchPosts();
    _fetchFweets();
    _fetchFavorites();
    _fetchHighlights();
    _fetchClubPosts();      // NEW
    _fetchStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _shimmerCtrl.dispose();
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

  /// NEW — fetches posts from clubs the user has joined.
  ///
  /// Calls `_api.getMyClubsPosts()`. If that method isn't wired up in
  /// ApiService yet, the dynamic call will throw NoSuchMethodError
  /// and we simply fall through to an empty list / empty state.
  Future<void> _fetchClubPosts() async {
    setState(() => _clubPostsLoading = true);
    try {
      // Use dynamic dispatch so a missing method on ApiService doesn't
      // break the build — it just leaves the tab empty until the
      // backend endpoint exists.
      final dynamic api = _api;
      final d = await api.getMyClubsPosts() as Map<String, dynamic>;
      setState(() {
        _clubPosts        = (d['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _clubPostsLoading = false;
      });
    } catch (_) {
      setState(() {
        _clubPosts        = [];
        _clubPostsLoading = false;
      });
    }
  }

  Future<void> _fetchHighlights() async {
    setState(() => _highlightsLoading = true);
    try {
      final d = await _api.getMyHighlights();
      final list = d is List
          ? d
          : (d as Map<String, dynamic>?)?['results'] as List? ?? [];
      // Apply the 24-HOUR EXPIRY filter on the client. Anything with a
      // `created_at` older than 24h gets dropped before display.
      final cast = list.cast<Map<String, dynamic>>();
      final fresh = cast.where(_isHighlightFresh).toList();
      setState(() {
        _highlights        = fresh;
        _highlightsLoading = false;
      });
    } catch (_) {
      setState(() => _highlightsLoading = false);
    }
  }

  /// Returns true if a highlight was created within the last 24 hours,
  /// OR if we can't tell (missing/unparseable timestamp → keep it
  /// rather than risk hiding good content).
  bool _isHighlightFresh(Map<String, dynamic> h) {
    final iso = h['created_at'] as String?;
    if (iso == null || iso.isEmpty) return true;
    try {
      final age = DateTime.now().toUtc().difference(
          DateTime.parse(iso).toUtc());
      return age.inHours < 24;
    } catch (_) {
      return true;
    }
  }

  /// NEW — groups _highlights by uploader so the row renders ONE circle
  /// per person. On the user's own profile this is always a single
  /// bucket; on a future "friends' stories" feed it would split.
  ///
  /// Each entry returned has the shape:
  ///   {
  ///     uploader_id, uploader_name, uploader_avatar, cover_url,
  ///     highlights: [ <original highlight maps> ],
  ///   }
  List<Map<String, dynamic>> get _uploaderBundles {
    final Map<String, List<Map<String, dynamic>>> bucketed = {};
    for (final h in _highlights) {
      final uid = (h['author_id']
              ?? h['user_id']
              ?? 'self')
          .toString();
      bucketed.putIfAbsent(uid, () => []).add(h);
    }
    return bucketed.entries.map((e) {
      // The first highlight in the bucket supplies fallback display
      // info — uploader name, uploader avatar, and a cover image for
      // the circle (in case the uploader has no avatar set).
      final first = e.value.first;
      final isSelf = e.key == 'self' ||
                     (_myUserId != null && e.key == _myUserId);
      return {
        'uploader_id': e.key,
        'uploader_name': isSelf
            ? 'You'
            : (first['author_name'] as String? ?? 'Member'),
        'uploader_avatar': isSelf
            ? (_avatarUrl ?? '')
            : (first['author_avatar']     as String?
            ?? first['author_avatar_url'] as String?
            ?? ''),
        'cover_url'   : first['cover_url'] as String? ?? '',
        'highlights'  : e.value,
        'is_self'     : isSelf,
      };
    }).toList();
  }

  Future<void> _fetchStats() async {
    try {
      final d = await _api.getMyProfile() as Map<String, dynamic>;
      setState(() {
        _followers = d['followers_count'] as int? ?? 0;
        _following = d['following_count'] as int? ?? 0;

        final uid = d['user_id'] as String?;
        if (uid != null && uid.isNotEmpty) _myUserId = uid;

        final ps = (d['privacy_settings'] as Map?)?.cast<String, dynamic>()
            ?? const {};
        _bioPublic    = ps['bio_public'] as bool? ?? true;
        _interestsVis = d['interests_visibility'] as String? ?? 'public';

        if (!_interestsSeeded) {
          final saved = (d['interests'] as List?)?.cast<String>();
          if (saved != null && saved.isNotEmpty) {
            _interests..clear()..addAll(saved);
          }
          _interestsSeeded = true;
        }

        // Re-hydrate _bioData on every fetch so navigating away and back
        // does not wipe the displayed bio. Always overwrite from backend,
        // since the backend is the source of truth after a save.
        final hasBio = d['bio'] != null || d['quote'] != null ||
            d['pronouns'] != null || d['country'] != null ||
            d['year'] != null || d['school'] != null ||
            d['study_style'] != null;
        if (hasBio) {
          _bioData = BioData(
            bio:        d['bio']         as String?,
            quote:      d['quote']       as String?,
            pronouns:   d['pronouns']    as String?,
            country:    d['country']     as String?,
            year:       d['year']        as String?,
            school:     d['school']      as String?,
            studyStyle: d['study_style'] as String?,
            availableForStudy: d['is_available_study'] as bool? ?? false,
          );
        }

        // Always rehydrate interests after the first seed so a server-side
        // save (via InterestsPage) survives a screen pop+push.
        if (_interestsSeeded) {
          final saved = (d['interests'] as List?)?.cast<String>();
          if (saved != null) {
            _interests..clear()..addAll(saved);
          }
        }

        final av = d['avatar_url'] as String?;
        final cv = d['cover_url']  as String?;
        if (av != null && av.isNotEmpty && _avatarFile == null) _avatarUrl = av;
        if (cv != null && cv.isNotEmpty && _coverFile  == null) _coverUrl  = cv;
      });
    } catch (_) {}
  }

  // ── Persist / restore URLs ────────────────────────────────

  Future<String?> _ownUserId() async =>
      (await SharedPreferences.getInstance()).getString('userId');

  Future<void> _loadSavedUrls() async {
    final uid = await _ownUserId();
    if (uid == null || uid.isEmpty) return;
    final p  = await SharedPreferences.getInstance();
    final av = p.getString('$_kAvatarUrlPrefix$uid');
    final cv = p.getString('$_kCoverUrlPrefix$uid');
    if (av != null && av.isNotEmpty) setState(() => _avatarUrl = av);
    if (cv != null && cv.isNotEmpty) setState(() => _coverUrl  = cv);
  }

  Future<void> _saveAvatarUrl(String url) async {
    final uid = await _ownUserId();
    if (uid == null || uid.isEmpty) return;
    (await SharedPreferences.getInstance())
        .setString('$_kAvatarUrlPrefix$uid', url);
  }

  Future<void> _saveCoverUrl(String url) async {
    final uid = await _ownUserId();
    if (uid == null || uid.isEmpty) return;
    (await SharedPreferences.getInstance())
        .setString('$_kCoverUrlPrefix$uid', url);
  }

  // ── Delete (unchanged) ────────────────────────────────────

  Future<void> _deletePost(int i) async {
    final id = _posts[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete(context, 'post')) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: _kPurple)),
    );
    try {
      await _api.deletePost(id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _posts.removeAt(i));
      notifyPostDeleted(id);
      _snack('Post deleted');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('Could not delete: $e', error: true);
    }
  }

  Future<void> _deleteFweet(int i) async {
    final id = _fweets[i]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _confirmDelete(context, 'fweet')) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: _kPurple)),
    );
    try {
      await _api.deletePost(id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _fweets.removeAt(i));
      notifyPostDeleted(id);
      _snack('Fweet deleted');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('Could not delete: $e', error: true);
    }
  }

  Future<bool> _confirmDelete(BuildContext ctx, String type) async =>
    await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $type?', style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900,
            color: _kInk, letterSpacing: -0.3)),
        content: Text('This $type will be permanently removed.',
            style: const TextStyle(fontSize: 13, color: _kSlate, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(
                fontWeight: FontWeight.w700, color: _kSlate))),
          GestureDetector(onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: _kCoral,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Delete', style: TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)))),
          const SizedBox(width: 4),
        ],
      ),
    ) ?? false;

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

  // ── Image picking + upload (unchanged) ────────────────────

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

  // ── Navigation (unchanged) ────────────────────────────────

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

  Future<void> _openCreateHighlight() async {
    HapticFeedback.lightImpact();
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreateHighlightPage()));
    if (created == true) _fetchHighlights();
  }

  /// NEW — opens the story viewer with EVERY item from every highlight
  /// in this uploader's bundle, in order. If items are missing from
  /// the list payload, fetch each highlight in full first.
  Future<void> _openUploaderHighlights(Map<String, dynamic> bundle) async {
    HapticFeedback.lightImpact();
    final highlights = (bundle['highlights'] as List)
        .cast<Map<String, dynamic>>();
    if (highlights.isEmpty) return;

    final allItems = <Map<String, dynamic>>[];
    for (final h in highlights) {
      var items = (h['items'] as List?)?.cast<Map<String, dynamic>>()
          ?? const <Map<String, dynamic>>[];
      if (items.isEmpty) {
        try {
          final full = await _api.getHighlight(h['id']?.toString() ?? '')
              as Map<String, dynamic>;
          items = (full['items'] as List?)?.cast<Map<String, dynamic>>()
              ?? const <Map<String, dynamic>>[];
        } catch (_) {/* swallow — skip this highlight */}
      }
      allItems.addAll(items);
    }

    if (allItems.isEmpty) {
      _snack('No stories to show yet');
      return;
    }

    final stories = allItems
        .map((it) => HighlightStory.fromJson(it))
        .toList();

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HighlightStoryViewer(stories: stories),
    ));
  }

Future<void> _shareMyProfile() async {
  HapticFeedback.lightImpact();

  // ── Ensure current user id exists ─────────────────────────
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

  // ── Load recent chats directly here ──────────────────────
  List<Map<String, dynamic>> recent = [];

  try {
    final data = await _api.getRecentChats(limit: 5);

    if (data is List) {
      recent = data.cast<Map<String, dynamic>>();
    }
  } catch (_) {
    try {
      final data = await _api.getChatRooms();

      if (data is List) {
        recent = data
            .cast<Map<String, dynamic>>()
            .take(5)
            .toList();
      }
    } catch (_) {}
  }

  if (!mounted) return;

  final searchCtrl = TextEditingController();
  List<Map<String, dynamic>> filtered = List.from(recent);

  String roomName(Map<String, dynamic> r) {
    final type = r['room_type'] as String? ?? 'direct';

    if (type == 'group') {
      return (r['name'] as String?) ?? 'Group';
    }

    final other = r['other_user'] as Map<String, dynamic>?;

    return (other?['name'] as String?) ?? 'Unknown';
  }

  String? roomAvatar(Map<String, dynamic> r) {
    final type = r['room_type'] as String? ?? 'direct';

    if (type == 'group') {
      return r['avatar_url'] as String?;
    }

    final other = r['other_user'] as Map<String, dynamic>?;

    return other?['avatar_url'] as String?;
  }

  // ── Bottom sheet directly inside function ────────────────
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void applyFilter(String q) {
            final query = q.trim().toLowerCase();

            setModalState(() {
              if (query.isEmpty) {
                filtered = List.from(recent);
              } else {
                filtered = recent.where((r) {
                  return roomName(r)
                      .toLowerCase()
                      .contains(query);
                }).toList();
              }
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollCtrl) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 12, bottom: 4),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Row(
                        children: [
                          const Text(
                            'Share Profile',
                            style: TextStyle(
                              fontFamily: 'Alfa',
                              fontSize: 20,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              '· ${widget.fullName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 13,
                                color: Color(0xFF64687A),
                              ),
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF64687A),
                            ),
                            onPressed: () =>
                                Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Search
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5FA),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: applyFilter,
                          style: const TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Search recent chats...',
                            hintStyle: TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                recent.isEmpty
                                    ? 'No recent chats yet'
                                    : 'No matches',
                                style: const TextStyle(
                                  fontFamily: 'Alfa',
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(
                                  12, 4, 12, 24),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final room = filtered[i];
                                final name = roomName(room);
                                final avatar = roomAvatar(room);
                                final type = room['room_type']
                                        as String? ??
                                    'direct';
                                final isGroup = type == 'group';
                                final initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?';

                                return InkWell(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  onTap: () async {
                                    try {
                                      HapticFeedback
                                          .mediumImpact();

                                      final roomId =
                                          room['id']?.toString() ??
                                              '';

                                      if (roomId.isEmpty) return;

                                      await _api
                                          .shareProfileToRoom(
                                        roomId: roomId,
                                        targetUserId: _myUserId!,
                                        targetName:
                                            widget.fullName,
                                      );

                                      if (!mounted) return;

                                      Navigator.pop(context);

                                      _snack(
                                          'Profile shared to $name ✓');
                                    } catch (e) {
                                      _snack('Share failed',
                                          error: true);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets
                                        .symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration:
                                              BoxDecoration(
                                            gradient:
                                                const LinearGradient(
                                              colors: [
                                                Color(
                                                    0xFF6DD5FA),
                                                Color(
                                                    0xFF8E54E9),
                                              ],
                                            ),
                                            shape: isGroup
                                                ? BoxShape
                                                    .rectangle
                                                : BoxShape
                                                    .circle,
                                            borderRadius:
                                                isGroup
                                                    ? BorderRadius
                                                        .circular(
                                                            14)
                                                    : null,
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                isGroup
                                                    ? BorderRadius
                                                        .circular(
                                                            14)
                                                    : BorderRadius
                                                        .circular(
                                                            24),
                                            child: avatar !=
                                                        null &&
                                                    avatar
                                                        .isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl:
                                                        avatar,
                                                    fit: BoxFit
                                                        .cover,
                                                    errorWidget:
                                                        (_, __,
                                                                ___) =>
                                                            Center(
                                                      child: Text(
                                                        initial,
                                                        style:
                                                            const TextStyle(
                                                          color: Colors
                                                              .white,
                                                          fontFamily:
                                                              'Arch',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(
                                                      initial,
                                                      style:
                                                          const TextStyle(
                                                        color:
                                                            Colors.white,
                                                        fontFamily:
                                                            'Arch',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    const TextStyle(
                                                  fontFamily:
                                                      'Arch',
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                  fontSize: 14,
                                                  color: Color(
                                                      0xFF1A1A2E),
                                                ),
                                              ),
                                              Text(
                                                isGroup
                                                    ? 'Group chat'
                                                    : 'Direct message',
                                                style: TextStyle(
                                                  fontFamily:
                                                      'Momo',
                                                  fontSize: 11,
                                                  color: Colors
                                                      .grey
                                                      .shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.send_rounded,
                                          color: Color(0xFF8E54E9),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

  Future<void> _changeBioPrivacy() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.transparent,
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
      context: context, backgroundColor: Colors.transparent,
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
      case 'student':        return [const Color(0xFF22C55E), const Color(0xFF06B6D4)];
      case 'teaching_staff':
      case 'staff':          return [_kPurple, _kBlue];
      case 'parent':         return [_kAmber, _kCoral];
      default:               return [_kBlue, _kPurple];
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

  IconData _visibilityIcon(String vis) {
    switch (vis) {
      case 'private':   return Icons.lock_rounded;
      case 'followers': return Icons.people_alt_rounded;
      default:          return Icons.public_rounded;
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3], stops: [0.0, 0.55, 1.0]),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(child: _buildCoverSection()),
            SliverToBoxAdapter(child: _buildIdentitySection()),
            if (_bioData != null && !_bioData!.isEmpty)
              SliverToBoxAdapter(child: _buildBioCard()),
            SliverToBoxAdapter(child: _buildHighlightsRow()),
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
              _PostsTab(posts: _posts, loading: _postsLoading,
                  onCreate: _openCreatePost, onDelete: _deletePost,
                  onRefresh: _fetchPosts,
                  userName: widget.fullName, avatarUrl: _avatarUrl),
              _FweetsTab(fweets: _fweets, loading: _fweetsLoading,
                  onCreate: _openCreateFweet, onDelete: _deleteFweet,
                  onRefresh: _fetchFweets,
                  userName: widget.fullName, avatarUrl: _avatarUrl),
              _FavoritesTab(favorites: _favorites, loading: _favoritesLoading,
                  onRefresh: _fetchFavorites),
              // NEW — Clubs tab.
              _ClubsTab(
                clubPosts: _clubPosts,
                loading: _clubPostsLoading,
                onRefresh: _fetchClubPosts,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cover section ─────────────────────────────────────────

  Widget _buildCoverSection() {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: _kCoverH + _kAvatarR,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: 0, left: 0, right: 0, height: _kCoverH,
          child: GestureDetector(onTap: _pickCover,
            child: Stack(children: [
              _buildCoverImage(),
              if (_coverUploading)
                Container(color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))),
            ]))),

      Positioned(
        top: topPad + 12,
        left: 16,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            ),
          ),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: _kInk,
              size: 18,
            ),
          ),
        ),
      ),
        // Edit cover button
        Positioned(top: topPad + 12, right: 16,
          child: GestureDetector(onTap: _pickCover,
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.photo_camera_rounded,
                  color: _kInkSoft, size: 16)))),

        // Avatar with animated gradient ring
        Positioned(top: _kCoverH - _kAvatarR, left: 0, right: 0,
          child: Center(child: GestureDetector(onTap: _pickAvatar,
            child: Stack(children: [
              _GradientBorderCard(
                animation: _shimmerCtrl,
                radius: _kAvatarR + 4,
                borderWidth: 3.5,
                innerColor: _kCard,
                padding: const EdgeInsets.all(0),
                child: ClipOval(child: SizedBox(
                  width: _kAvatarR * 2, height: _kAvatarR * 2,
                  child: _buildAvatarContent(),
                )),
              ),
              if (_avatarUploading)
                Positioned.fill(child: ClipOval(child: Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))))),
              Positioned(bottom: 2, right: 2,
                child: Container(width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: _roleGradient,
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: _kCard, width: 2.5)),
                  child: const Icon(Icons.photo_camera_rounded,
                      color: Colors.white, size: 13))),
            ])))),
      ]),
    );
  }

  Widget _buildCoverImage() {
    if (_coverFile != null) {
      return Image.file(_coverFile!, fit: BoxFit.cover, width: double.infinity);
    }
    if (_coverUrl != null && _coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _coverUrl!,
        fit: BoxFit.cover,
        width: double.infinity, height: _kCoverH,
        placeholder: (_, __) => _coverGradient(),
        errorWidget: (_, __, ___) => _coverGradient(),
      );
    }
    return _coverGradient();
  }

  Widget _coverGradient() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _roleGradient.map((c) => c.withOpacity(0.85)).toList(),
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Stack(children: [
      Positioned(right: -40, top: -40, child: Container(width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _kCard.withOpacity(0.10)))),
      Positioned(left: -30, bottom: 0, child: Container(width: 140, height: 140,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _kCard.withOpacity(0.08)))),
    ]));

  Widget _buildAvatarContent() {
    if (_avatarFile != null) {
      return Image.file(_avatarFile!, fit: BoxFit.cover);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _avatarUrl!, fit: BoxFit.cover,
        placeholder: (_, __) => _avatarFallback(),
        errorWidget: (_, __, ___) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: _roleGradient,
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Text(
        widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 36,
            fontWeight: FontWeight.w900, color: Colors.white))));

  // ── Identity section ──────────────────────────────────────
Widget _buildIdentitySection() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Column(children: [
      Text(widget.fullName, textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: _kInk, letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Text('$_roleLabel  ·  $_handleName', textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: _kSlate,
            fontWeight: FontWeight.w600, letterSpacing: 0.2)),
      const SizedBox(height: 18),

      // Stats card
      Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder)),
        child: IntrinsicHeight(child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatCell(value: _posts.length + _fweets.length, label: 'Posts'),
            _divider(),
            _StatCell(value: _followers, label: 'Followers'),
            _divider(),
            _StatCell(value: _following, label: 'Following'),
          ],
        )),
      ),
      const SizedBox(height: 14),

      // Action Row — Edit Bio + Add Interests + Share
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _openBio,
            child: _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 14,
              borderWidth: 1.4,
              innerColor: _kCard,
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit_rounded, color: _kInk, size: 14),
                const SizedBox(width: 6),
                Text(_bioData != null ? 'Edit Bio' : 'Add Bio',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _kInk, fontSize: 13, letterSpacing: -0.2)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _openInterests,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.interests_rounded, color: _kPurple, size: 14),
                const SizedBox(width: 6),
                Text(_interests.isEmpty ? 'Add Interests' : 'Edit Interests',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _kInk, fontSize: 13, letterSpacing: -0.2)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _shareMyProfile,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kCard,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder)),
            child: const Icon(Icons.ios_share_rounded,
                size: 18, color: _kInkSoft)),
        ),
      ]),
      const SizedBox(height: 8),
    ]),
  );
}
  Widget _divider() => Container(width: 1, height: 28, color: _kBorder);

  // ── Bio card ──────────────────────────────────────────────
Widget _buildBioCard() {
  final bio = _bioData;
  final hasBio = bio != null && !bio.isEmpty;

  return GestureDetector(
    onTap: _showBioSheet,
    child: Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _kPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.person_outline_rounded,
                color: _kPurple, size: 14)),
          const SizedBox(width: 8),
          const Text('About me', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 13,
              color: _kInk, letterSpacing: -0.2)),
          const Spacer(),
          _privacyChip(
            icon: _bioPublic ? Icons.public_rounded : Icons.lock_rounded,
            label: PrivacyToggleSheet.bioLabel(_bioPublic),
            onTap: _changeBioPrivacy,
          ),
        ]),

        if (hasBio && bio!.bio != null) ...[
          const SizedBox(height: 10),
          Text(bio.bio!, style: const TextStyle(
              fontSize: 14, color: _kInkSoft, height: 1.5)),
        ],

        // Interests inside About section
        if (_interests.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Interests', style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12, color: _kSlate)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests.map((interest) {
              final c = [_kBlue, _kPurple, _kAmber, _kCoral][_interests.indexOf(interest) % 4];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.10),
                  border: Border.all(color: c.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(interest, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: c)),
              );
            }).toList(),
          ),
        ],

        if (_interests.isEmpty && !hasBio)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              "Tell others about yourself and your interests",
              style: TextStyle(fontSize: 13, color: _kSlate),
            ),
          ),
      ]),
    ),
  );
}
  Widget _metaChip(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (color ?? _kSlate).withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (color ?? _kSlate).withOpacity(0.18))),
    child: Text(label, style: TextStyle(
        fontSize: 11, color: color ?? _kSlate,
        fontWeight: FontWeight.w600)));

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
          color: _kCardLo,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: _kSlate),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: _kInkSoft)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 12, color: _kSlate2),
        ]),
      ),
    );

  void _showBioSheet() {
    final bio = _bioData!;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: _kBg1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.65, maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl, padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 4,
              decoration: BoxDecoration(color: _kBorder,
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Bio', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: _kInk, letterSpacing: -0.4)),
            const SizedBox(height: 16),
            if (bio.bio        != null) _BioRow(Icons.edit_note_rounded,    'Bio',         bio.bio!,        _kPurple),
            if (bio.quote      != null) _BioRow(Icons.format_quote_rounded, 'Quote',       bio.quote!,      _kAmber),
            if (bio.pronouns   != null) _BioRow(Icons.tag_rounded,          'Pronouns',    bio.pronouns!,   _kBlue),
            if (bio.country    != null) _BioRow(Icons.public_rounded,       'Country',     bio.country!,    _kCoral),
            if (bio.year       != null) _BioRow(Icons.grade_rounded,        'Year',        bio.year!,       _kBlue),
            if (bio.school     != null) _BioRow(Icons.location_city_rounded,'School',      bio.school!,     _kAmber),
            if (bio.studyStyle != null) _BioRow(Icons.menu_book_rounded,    'Study Style', bio.studyStyle!, _kAmber),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { Navigator.pop(context); _openBio(); },
              child: Container(width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  color: _kInk,
                  borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('Edit Bio', style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white, fontSize: 14))))),
          ]),
        ),
      ),
    );
  }

  // ── Interests strip ───────────────────────────────────────

  Widget _buildInterestsStrip() {
    if (_interests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(onTap: _openInterests,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            height: 42,
            decoration: BoxDecoration(color: _kCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kBorder, width: 1.5)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline_rounded, size: 14, color: _kSlate2),
              SizedBox(width: 6),
              Text('Add your interests', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12, color: _kSlate2)),
            ]))),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            const Text('Interests', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12,
                color: _kInk, letterSpacing: 0.5)),
            const SizedBox(width: 10),
            _privacyChip(
              icon:  _visibilityIcon(_interestsVis),
              label: PrivacyToggleSheet.interestsLabel(_interestsVis),
              onTap: _changeInterestsPrivacy,
            ),
          ]),
        ),
        SizedBox(height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            itemCount: _interests.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == _interests.length) {
                return GestureDetector(onTap: _openInterests,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kCard,
                      border: Border.all(color: _kBorder, width: 1.5),
                      borderRadius: BorderRadius.circular(22)),
                    child: const Text('+ Edit', style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 11,
                        color: _kSlate))));
              }
              final c = [_kBlue, _kPurple, _kAmber, _kCoral][i % 4];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.10),
                  border: Border.all(color: c.withOpacity(0.30), width: 1.5),
                  borderRadius: BorderRadius.circular(22)),
                child: Text(_interests[i], style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 11, color: c)));
            },
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // HIGHLIGHTS ROW — one circle per uploader (grouped)
  // ══════════════════════════════════════════════════════════

  Widget _buildHighlightsRow() {
    // Compute the grouped, freshness-filtered bundles once per build.
    final bundles = _uploaderBundles;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(children: [
            const Text('Highlights', style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 12,
                color: _kInk, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            // Tiny "24h" pill to set the expectation that highlights
            // disappear after a day. Communicates the new behaviour
            // without needing a tooltip.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kPurple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6)),
              child: const Text('24h', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 9,
                  color: _kPurple, letterSpacing: 0.5)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: _highlightsLoading
              ? const Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: _kPurple, strokeWidth: 2)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: bundles.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    // Position 0 is the Add tile; the rest are
                    // uploader bundles.
                    if (i == 0) return _buildAddHighlightCircle();
                    return _buildUploaderCircle(bundles[i - 1]);
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildAddHighlightCircle() {
    return GestureDetector(
      onTap: _openCreateHighlight,
      child: SizedBox(
        width: 66,
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kCardLo,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder, width: 1.5)),
            child: const Icon(Icons.add_rounded, color: _kSlate2, size: 26),
          ),
          const SizedBox(height: 6),
          const Text('New', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: _kSlate)),
        ]),
      ),
    );
  }

  /// One circle per uploader. Renders the uploader's avatar inside the
  /// gradient ring, falling back to the cover image of their first
  /// highlight if no avatar is set, then to the uploader's initial.
  Widget _buildUploaderCircle(Map<String, dynamic> bundle) {
    final name    = bundle['uploader_name'] as String? ?? 'You';
    final avatar  = bundle['uploader_avatar'] as String? ?? '';
    final cover   = bundle['cover_url'] as String? ?? '';
    final count   = (bundle['highlights'] as List).length;
    final imgUrl  = avatar.isNotEmpty ? avatar : cover;

    return GestureDetector(
      onTap: () => _openUploaderHighlights(bundle),
      child: SizedBox(
        width: 66,
        child: Column(children: [
          Stack(children: [
            Container(
              width: 64, height: 64,
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_kBlue, _kPurple, _kCoral],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: _kBg1, shape: BoxShape.circle),
                child: ClipOval(
                  child: imgUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imgUrl, fit: BoxFit.cover,
                          placeholder: (_, __) => _circleInitial(name),
                          errorWidget: (_, __, ___) => _circleInitial(name))
                      : _circleInitial(name),
                ),
              ),
            ),
            // Small badge showing how many highlights this uploader has.
            // Hidden when there's only one — keeps the row tidy on
            // first-time-user profiles.
            if (count > 1)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kInk,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBg1, width: 1.5)),
                  child: Text('$count', style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: _kInk)),
        ]),
      ),
    );
  }

  Widget _circleInitial(String name) => Container(
        color: _kCardLo,
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: _kPurple, fontWeight: FontWeight.w900, fontSize: 22),
        ),
      );

  // ── Custom segmented tab bar — now FOUR segments ──────────

  Widget _buildTabBar() {
    const labels = ['Posts', 'Fweets', 'Favorites', 'Clubs'];
    const n = 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
            // Clamp to (n-1) so the sliding indicator stays inside.
            final pos = _tabCtrl.animation!.value.clamp(0.0, n - 1.0);
            return LayoutBuilder(builder: (_, c) {
              final segW = c.maxWidth / n;
              return Stack(children: [
                Positioned(
                  left: pos * segW,
                  top: 0, bottom: 0, width: segW,
                  child: Container(decoration: BoxDecoration(
                    color: _kInk, borderRadius: BorderRadius.circular(10))),
                ),
                Row(children: [
                  for (int i = 0; i < n; i++)
                    Expanded(child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _tabCtrl.animateTo(i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(labels[i], style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                            color: Color.lerp(_kSlate, Colors.white,
                                1.0 - (pos - i).abs().clamp(0.0, 1.0)))),
                      ),
                    )),
                ]),
              ]);
            });
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard — ANIMATED sweep gradient (used for avatar
// ring and the Edit Bio CTA). Heavy; only used where it matters.
// ═════════════════════════════════════════════════════════════

class _GradientBorderCard extends StatelessWidget {
  final Animation<double>   animation;
  final Widget              child;
  final double              radius;
  final double              borderWidth;
  final Color               innerColor;
  final EdgeInsetsGeometry? padding;
  final List<Color>         colors;

  const _GradientBorderCard({
    required this.animation,
    required this.child,
    this.radius = 20,
    this.borderWidth = 1.4,
    this.innerColor = _kCard,
    this.padding,
    this.colors = _gradColors,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            math.max(0.0, radius - borderWidth)),
        color: innerColor,
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
// _GradientTile — STATIC linear-gradient border. Cheap. Use for
// every post / fweet / club-post / favourite card.
// ═════════════════════════════════════════════════════════════

class _GradientTile extends StatelessWidget {
  final Widget       child;
  final List<Color>  gradient;
  final double       radius;
  final double       borderWidth;
  final EdgeInsetsGeometry? margin;
  final Color        innerColor;

  const _GradientTile({
    required this.child,
    required this.gradient,
    this.radius      = 18,
    this.borderWidth = 1.8,
    this.margin,
    this.innerColor  = _kCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          color: innerColor,
          borderRadius: BorderRadius.circular(
              math.max(0.0, radius - borderWidth)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
              math.max(0.0, radius - borderWidth)),
          child: child,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Sticky tab bar delegate
// ═════════════════════════════════════════════════════════════

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final WidgetBuilder builder;
  final double height;
  _StickyTabBarDelegate({required this.builder, required this.height});

  @override double get minExtent => height;
  @override double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
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
// STAT CELL
// ═════════════════════════════════════════════════════════════

class _StatCell extends StatelessWidget {
  final int value; final String label;
  const _StatCell({required this.value, required this.label});
  String get _fmt {
    if (value >= 1000000) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1000)    return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(_fmt, style: const TextStyle(
        fontSize: 19, fontWeight: FontWeight.w900,
        color: _kInk, letterSpacing: -0.3)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(
        fontSize: 11, color: _kSlate, fontWeight: FontWeight.w600)),
  ]));
}

// ═════════════════════════════════════════════════════════════
// POSTS TAB
// ═════════════════════════════════════════════════════════════

class _PostsTab extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool loading;
  final VoidCallback onCreate;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onRefresh;
  final String userName;
  final String? avatarUrl;
  const _PostsTab({
    required this.posts,
    required this.loading,
    required this.onCreate,
    required this.onDelete,
    required this.onRefresh,
    required this.userName,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _TabLoadingShimmer();

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isEmpty = posts.isEmpty;

    return Stack(children: [
      RefreshIndicator(
        color: _kInk,
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset + 96),
          physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics()),
          itemCount: isEmpty ? 1 : posts.length,
          itemBuilder: (_, i) {
            if (isEmpty) {
              return const _InlineEmptyState(
                icon:  Icons.article_outlined,
                label: 'No posts yet',
                sub:   'Tap the + button to share your first post '
                       'with the campus.',
                color: _kPurple,
              );
            }
            final p     = posts[i];
            final media = (p['media'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            // NEW — wrap every post card in a gradient border. The
            // gradient pair rotates with index so neighbouring cards
            // never share a gradient.
            return _ProfilePostCard(
              post:     p,
              media:    media,
              content:  p['content'] as String? ?? '',
              onDelete: () => onDelete(i),
              gradient: _gradFor(i),
            );
          },
        ),
      ),
      // Always-reachable FAB, lifted clear of the app's bottom nav bar.
      Positioned(
        bottom: 20 + bottomInset + 80,
        right: 20,
        child: GestureDetector(
          onTap: onCreate,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPurple, _kBlue],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _kPurple.withOpacity(0.4),
                blurRadius: 14, offset: const Offset(0, 5))]),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════
// STATS BOTTOM SHEET — tap a post/fweet stats row to open
// ═════════════════════════════════════════════════════════════

int _statInt(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is int) return v;
    if (v is String) { final p = int.tryParse(v); if (p != null) return p; }
  }
  return 0;
}

void showPostStatsSheet(BuildContext context, Map<String, dynamic> post) {
  final likes    = _statInt(post, ['like_count','likes_count']);
  final comments = _statInt(post, ['comment_count','comments_count']);
  final favs     = _statInt(post, ['favorite_count','favorites_count','bookmark_count']);
  _showStatsSheet(context, likes, comments, favs, 'Post stats');
}

void showFweetStatsSheet(BuildContext context, Map<String, dynamic> fweet) {
  final likes    = _statInt(fweet, ['like_count','likes_count']);
  final comments = _statInt(fweet, ['comment_count','comments_count']);
  final favs     = _statInt(fweet, ['favorite_count','favorites_count','bookmark_count']);
  _showStatsSheet(context, likes, comments, favs, 'Fweet stats');
}

void _showStatsSheet(BuildContext context, int likes, int comments, int favs, String title) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, fontFamily: 'Alfa')),
          const SizedBox(height: 18),
          _StatTile(icon: Icons.favorite_rounded,
            label: 'Likes', count: likes, color: const Color(0xFFFF4F6E)),
          const SizedBox(height: 10),
          _StatTile(icon: Icons.mode_comment_rounded,
            label: 'Comments', count: comments, color: const Color(0xFF6DD5FA)),
          const SizedBox(height: 10),
          _StatTile(icon: Icons.bookmark_rounded,
            label: 'Favourites', count: favs, color: const Color(0xFFF59E0B)),
        ],
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  final IconData icon; final String label; final int count; final Color color;
  const _StatTile({required this.icon, required this.label,
    required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Momo'))),
        Text('$count', style: TextStyle(fontSize: 22,
          fontWeight: FontWeight.w800, color: color, fontFamily: 'Alfa')),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _ProfilePostCard — gradient-bordered. Takes a `gradient` list
// from the parent; falls back to blue→purple if none supplied.
// ═════════════════════════════════════════════════════════════

class _ProfilePostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> media;
  final String content;
  final VoidCallback onDelete;
  final List<Color> gradient;
  const _ProfilePostCard({
    required this.post, required this.media,
    required this.content, required this.onDelete,
    this.gradient = const [_kBlue, _kPurple],
  });
  @override State<_ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<_ProfilePostCard> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final location = widget.post['location'] as String? ?? '';
    final hasMedia = widget.media.isNotEmpty;
    final multi    = widget.media.length > 1;

    return _GradientTile(
      gradient: widget.gradient,
      margin: const EdgeInsets.only(bottom: 16),
      radius: 20,
      borderWidth: 1.8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasMedia) ...[
          Stack(children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: widget.media.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (_, i) => MediaItemView(
                  item:   widget.media[i], height: 220),
              ),
            ),
            if (multi) Positioned(top: 10, right: 10,
              child: IgnorePointer(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_page + 1}/${widget.media.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w700))))),
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
            Positioned(top: 10, left: 10,
              child: GestureDetector(onTap: widget.onDelete,
                child: Container(width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.white, size: 16)))),
          ]),
        ],

        Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!hasMedia)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              GestureDetector(onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _kCoral.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline_rounded, size: 14, color: _kCoral),
                    SizedBox(width: 4),
                    Text('Delete', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: _kCoral)),
                  ]))),
            ]),
          if (widget.content.isNotEmpty) ...[
            if (!hasMedia) const SizedBox(height: 4),
            Text(widget.content, style: const TextStyle(
                fontSize: 14, color: _kInk, height: 1.5)),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 13, color: _kCoral),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(
                  fontSize: 12, color: _kSlate)),
            ]),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showPostStatsSheet(context, widget.post),
            child: _PostStatsRow(post: widget.post)),
        ])),
      ]),
    );
  }
}

class _PostStatsRow extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostStatsRow({required this.post});

  int _n(String k) {
    final v = post[k];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final likes = _n('like_count') + _n('likes_count');
    final comments = _n('comment_count') + _n('comments_count');
    final favs = _n('favorite_count') + _n('favorites_count') + _n('bookmark_count');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        _statChip(Icons.favorite_rounded, likes, _kCoral),
        const SizedBox(width: 14),
        _statChip(Icons.mode_comment_rounded, comments, _kBlue),
        const SizedBox(width: 14),
        _statChip(Icons.bookmark_rounded, favs, _kPurple),
      ]),
    );
  }

  Widget _statChip(IconData icon, int count, Color color) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text('$count', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
}

class _FweetStatsRow extends StatelessWidget {
  final Map<String, dynamic> fweet;
  final bool onColored;
  const _FweetStatsRow({required this.fweet, required this.onColored});

  int _n(String k) {
    final v = fweet[k];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final likes = _n('like_count') + _n('likes_count');
    final comments = _n('comment_count') + _n('comments_count');
    final favs = _n('favorite_count') + _n('favorites_count') + _n('bookmark_count');
    final c = onColored ? Colors.white : _kInkSoft;
    return Row(children: [
      _stat(Icons.favorite_rounded, likes, c),
      const SizedBox(width: 14),
      _stat(Icons.mode_comment_rounded, comments, c),
      const SizedBox(width: 14),
      _stat(Icons.bookmark_rounded, favs, c),
    ]);
  }

  Widget _stat(IconData icon, int count, Color color) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color.withOpacity(0.85)),
      const SizedBox(width: 4),
      Text('$count', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
}

// ═════════════════════════════════════════════════════════════
// FWEETS TAB — cards wrapped in gradient borders too
// ═════════════════════════════════════════════════════════════

class _FweetsTab extends StatelessWidget {
  final List<Map<String, dynamic>> fweets;
  final bool loading;
  final VoidCallback onCreate;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onRefresh;
  final String userName;
  final String? avatarUrl;
  const _FweetsTab({
    required this.fweets,
    required this.loading,
    required this.onCreate,
    required this.onDelete,
    required this.onRefresh,
    required this.userName,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _TabLoadingShimmer();

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isEmpty = fweets.isEmpty;

    return Stack(children: [
      RefreshIndicator(
        color: _kInk,
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset + 96),
          physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics()),
          itemCount: isEmpty ? 1 : fweets.length,
          itemBuilder: (_, i) {
            if (isEmpty) {
              return const _InlineEmptyState(
                icon:  Icons.chat_bubble_outline_rounded,
                label: 'No fweets yet',
                sub:   'Fweets are quick thoughts and campus updates. '
                       'Tap the + button to post one.',
                color: _kCoral,
              );
            }
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

            // Same gradient-border treatment as posts. When the fweet
            // already has a background colour, the gradient frame still
            // reads against it nicely because of the 1.8px width.
            return _GradientTile(
              gradient: _gradFor(i),
              margin: const EdgeInsets.only(bottom: 14),
              radius: 18,
              borderWidth: 1.8,
              innerColor: bg ?? _kCard,
              child: Column(children: [
                Container(
                  color: bg != null
                      ? Colors.black.withOpacity(0.10) : _kCardLo,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Text('⚡ Fweet', style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 11,
                        color: bg != null ? Colors.white : _kCoral,
                        letterSpacing: 0.3)),
                    const Spacer(),
                    GestureDetector(onTap: () => onDelete(i),
                      child: Icon(Icons.delete_outline_rounded, size: 18,
                          color: bg != null ? Colors.white70 : _kCoral)),
                  ])),
                Padding(padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content, style: TextStyle(
                          fontSize: 15, height: 1.5,
                          color: bg != null ? Colors.white : _kInk)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showFweetStatsSheet(context, f),
                        child: _FweetStatsRow(
                            fweet: f, onColored: bg != null)),
                    ],
                  ),
                ),
              ]),
            );
          },
        ),
      ),
      Positioned(
        bottom: 20 + bottomInset + 80,
        right: 20,
        child: GestureDetector(
          onTap: onCreate,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kCoral, Color(0xFFFF8A65)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _kCoral.withOpacity(0.4),
                blurRadius: 14, offset: const Offset(0, 5))]),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════
// FAVORITES TAB — now handles event posters too
// ═════════════════════════════════════════════════════════════
//
// Each favourite entry is routed by its `type` field (or `post_type`
// for legacy payloads):
//   • 'event'         → _FavoriteEventCard (poster-style)
//   • 'fweet'         → existing post-style row with ⚡ badge
//   • anything else   → standard favourite post card
//
// Backend NOTE: GET /api/me/favorites/ should now return events
// alongside posts, with `type: 'event'` and these fields:
//   id, title, start_time, location, club_name, club_logo,
//   poster_url (or card_url).

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
        sub: 'Posts and event posters you bookmark appear here',
        color: _kPurple);
    }
    return RefreshIndicator(
      color: _kInk, onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          16 + MediaQuery.of(context).padding.bottom + 90,
        ),
        itemCount: favorites.length,
        itemBuilder: (_, i) {
          final p = favorites[i];
          // Branch on item type — events render very differently from
          // posts/fweets.
          final kind = (p['type'] ?? p['kind'] ?? p['post_type'] ?? 'post')
              .toString();
          if (kind == 'event') {
            return _FavoriteEventCard(event: p, gradient: _gradFor(i));
          }

          final content = p['content']     as String? ?? '';
          final author  = p['author_name'] as String? ?? 'Unknown';
          final isFweet = kind == 'fweet';
          final initial = author.isNotEmpty ? author[0].toUpperCase() : '?';
          final media   = (p['media'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          return _GradientTile(
            gradient: _gradFor(i),
            margin: const EdgeInsets.only(bottom: 14),
            radius: 18, borderWidth: 1.8,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                color: _kCardLo,
                child: Row(children: [
                  Container(width: 26, height: 26,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_kBlue, _kPurple])),
                    child: Center(child: Text(initial, style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 11)))),
                  const SizedBox(width: 8),
                  Text(author, style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12, color: _kInk)),
                  if (isFweet) ...[
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _kCoral.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('⚡', style: TextStyle(fontSize: 10))),
                  ],
                  const Spacer(),
                  const Icon(Icons.bookmark_rounded, color: _kPurple, size: 16),
                ])),
              if (media.isNotEmpty)
                MediaItemView(item: media.first, height: 180),
              if (content.isNotEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Text(content, style: const TextStyle(
                      fontSize: 14, color: _kInk, height: 1.5))),
              if (content.isEmpty) const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _FavoriteEventCard — poster-style card for favourited events.
//
// Layout:
//   • Poster image at top (16:9). If the event has no poster URL,
//     show a decorative gradient block with a big day/month badge
//     instead of a flat calendar icon.
//   • Below: title (bold), date+time row, location row, host club row.
//   • Wrapped in the same rotating-gradient border as posts.
// ═════════════════════════════════════════════════════════════

class _FavoriteEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final List<Color> gradient;
  const _FavoriteEventCard({required this.event, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final title     = event['title']      as String? ?? 'Untitled event';
    final loc       = event['location']   as String? ?? '';
    final start     = event['start_time'] as String? ?? '';
    final club      = event['club_name']  as String? ?? '';
    final clubLogo  = event['club_logo']  as String? ?? '';
    final poster    = (event['poster_url'] as String?) ??
                      (event['card_url']   as String?) ?? '';
    final dt        = _tryParse(start);

    return _GradientTile(
      gradient: gradient,
      margin: const EdgeInsets.only(bottom: 14),
      radius: 18, borderWidth: 1.8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero image / decorative date block
        AspectRatio(
          aspectRatio: 16 / 9,
          child: poster.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _decorativeDateBlock(dt),
                  errorWidget: (_, __, ___) => _decorativeDateBlock(dt),
                )
              : _decorativeDateBlock(dt),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.celebration_rounded,
                    size: 13, color: _kAmber),
                const SizedBox(width: 5),
                const Text('EVENT', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: _kAmber, letterSpacing: 0.8)),
                const Spacer(),
                const Icon(Icons.bookmark_rounded,
                    color: _kPurple, size: 16),
              ]),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: _kInk, letterSpacing: -0.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (dt != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.event_rounded,
                      size: 13, color: _kPurple),
                  const SizedBox(width: 5),
                  Text(_fmtDateTime(dt),
                      style: const TextStyle(
                          fontSize: 12, color: _kInkSoft,
                          fontWeight: FontWeight.w700)),
                ]),
              ],
              if (loc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.place_outlined,
                      size: 13, color: _kCoral),
                  const SizedBox(width: 5),
                  Expanded(child: Text(loc, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: _kSlate))),
                ]),
              ],
              if (club.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  // Tiny club logo / initial — same pattern as the
                  // chat-room avatars elsewhere in the app.
                  Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [_kBlue, _kPurple])),
                    child: ClipOval(
                      child: clubLogo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: clubLogo, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _clubInitial(club),
                              placeholder: (_, __) =>
                                  _clubInitial(club))
                          : _clubInitial(club),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('Hosted by $club',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: _kSlate,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  /// Decorative day/month block used when there's no poster. Beats the
  /// old "single calendar icon on a flat tint" placeholder — feels
  /// more like a save-the-date than a system glyph.
  Widget _decorativeDateBlock(DateTime? dt) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN',
                    'JUL','AUG','SEP','OCT','NOV','DEC'];
    final day   = dt?.day.toString() ?? '?';
    final month = dt != null ? months[dt.month - 1] : 'TBA';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(children: [
        // Soft decorative circles
        Positioned(right: -20, top: -20, child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.10)))),
        Positioned(left: -10, bottom: -30, child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08)))),
        // Day/month badge centered
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(month, style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w900, letterSpacing: 3)),
              Text(day, style: const TextStyle(
                  color: Colors.white, fontSize: 54,
                  fontWeight: FontWeight.w900, height: 1.0,
                  letterSpacing: -1.5)),
            ],
          ),
        ),
        // Small "save the date" ribbon at the corner
        Positioned(
          top: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(8)),
            child: const Text('SAVE THE DATE', style: TextStyle(
                color: Colors.white, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }

  Widget _clubInitial(String name) => Container(
    color: _kCardLo,
    alignment: Alignment.center,
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: _kPurple, fontSize: 9, fontWeight: FontWeight.w900)),
  );

  DateTime? _tryParse(String iso) {
    if (iso.isEmpty) return null;
    try { return DateTime.parse(iso).toLocal(); } catch (_) { return null; }
  }

  String _fmtDateTime(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} · $hh:$mm';
  }
}

// ═════════════════════════════════════════════════════════════
// CLUBS TAB — posts from clubs the user has joined
// ═════════════════════════════════════════════════════════════
//
// Backend NOTE: needs GET /api/me/clubs/feed/ (paginated, newest first)
// returning posts authored *in* clubs the user is a member of. Shape
// expected per post:
//   id, content, media[], created_at,
//   author_name, author_avatar,
//   club_id, club_name, club_logo,
//   like_count, comment_count, favorite_count
// If the endpoint is missing the tab renders the empty state.

class _ClubsTab extends StatelessWidget {
  final List<Map<String, dynamic>> clubPosts;
  final bool loading;
  final Future<void> Function() onRefresh;
  const _ClubsTab({
    required this.clubPosts,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _TabLoadingShimmer();
    if (clubPosts.isEmpty) {
      return const _EmptyTab(
        icon: Icons.groups_rounded,
        label: 'No club posts yet',
        sub: 'When clubs you\'ve joined post updates, they show up here.',
        color: _kBlue,
      );
    }
    return RefreshIndicator(
      color: _kInk,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          16 + MediaQuery.of(context).padding.bottom + 90),
        itemCount: clubPosts.length,
        itemBuilder: (_, i) => _ClubPostCard(
          post: clubPosts[i],
          gradient: _gradFor(i),
        ),
      ),
    );
  }
}

class _ClubPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final List<Color> gradient;
  const _ClubPostCard({required this.post, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final content    = post['content']      as String? ?? '';
    final clubName   = post['club_name']    as String? ?? 'Club';
    final clubLogo   = post['club_logo']    as String? ?? '';
    final authorName = post['author_name']  as String? ?? '';
    final media      = (post['media'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return _GradientTile(
      gradient: gradient,
      margin: const EdgeInsets.only(bottom: 14),
      radius: 18, borderWidth: 1.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: club logo + club name (+ optional author).
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: _kCardLo,
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                      colors: [_kBlue, _kPurple])),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: clubLogo.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: clubLogo, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _initial(clubName),
                          placeholder: (_, __) => _initial(clubName))
                      : _initial(clubName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clubName, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: _kInk, letterSpacing: -0.2)),
                    if (authorName.isNotEmpty)
                      Text('Posted by $authorName',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: _kSlate,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.groups_rounded,
                  size: 16, color: _kBlue),
            ]),
          ),

          // Media (first item, if any).
          if (media.isNotEmpty)
            MediaItemView(item: media.first, height: 200),

          // Content + stats.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content.isNotEmpty)
                  Text(content,
                      style: const TextStyle(
                          fontSize: 14, color: _kInk, height: 1.5)),
                if (content.isNotEmpty) const SizedBox(height: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showPostStatsSheet(context, post),
                  child: _PostStatsRow(post: post),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String name) => Container(
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
          color: Colors.white, fontSize: 13,
          fontWeight: FontWeight.w900)),
  );
}

// ═════════════════════════════════════════════════════════════
// LOADING SHIMMER
// ═════════════════════════════════════════════════════════════

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
      final o = 0.04 + _a.value * 0.06;
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          16 + MediaQuery.of(context).padding.bottom + 90,
        ),
        children: [
          _sh(o, 200), const SizedBox(height: 16),
          _sh(o, 120), const SizedBox(height: 16),
          _sh(o, 160),
        ]);
    });
  Widget _sh(double o, double h) => Container(
    decoration: BoxDecoration(color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder)),
    child: Column(children: [
      Container(height: h,
        decoration: BoxDecoration(
          color: _kInk.withOpacity(o),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)))),
      Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Container(height: 14, width: double.infinity,
          decoration: BoxDecoration(color: _kInk.withOpacity(o),
              borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 8),
        Container(height: 14, width: 160,
          decoration: BoxDecoration(color: _kInk.withOpacity(o),
              borderRadius: BorderRadius.circular(6))),
      ])),
    ]));
}

// ═════════════════════════════════════════════════════════════
// EMPTY STATE  (responsive — scrolls when tab area is short)
// ═════════════════════════════════════════════════════════════

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sub;
  final String?  buttonLabel;
  final Color    color;
  final VoidCallback? onTap;

  const _EmptyTab({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    this.buttonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped  = constraints.maxHeight < 240;
        final iconSize = cramped ? 56.0 : 72.0;
        final iconInner = cramped ? 24.0 : 30.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth:  constraints.maxWidth,
            ),
            child: IntrinsicHeight(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    32, 16, 32,
                    16 + MediaQuery.of(context).padding.bottom + 90,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: iconInner,
                          color: color.withOpacity(0.7),
                        ),
                      ),
                      SizedBox(height: cramped ? 12 : 18),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _kInk,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kSlate,
                        ),
                      ),
                      if (buttonLabel != null && onTap != null) ...[
                        SizedBox(height: cramped ? 14 : 22),
                        GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _kInk,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              buttonLabel!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════
// BIO ROW
// ═════════════════════════════════════════════════════════════

class _BioRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _BioRow(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(label, style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 11,
            color: _kSlate2, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, color: _kInk)),
      ])),
    ]));
}

// ═════════════════════════════════════════════════════════════
// INLINE EMPTY STATE — sits under the composer when a tab is empty.
// ═════════════════════════════════════════════════════════════

class _InlineEmptyState extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   sub;
  final Color    color;
  const _InlineEmptyState({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          ),
          child: Icon(icon, size: 30, color: color.withOpacity(0.7)),
        ),
        const SizedBox(height: 16),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900,
            color: _kInk, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(sub, textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, color: _kSlate, height: 1.55)),
        ),
      ]),
    );
  }
}