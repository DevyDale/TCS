// lib/screens/profile/user_profile_screen.dart
//
// Phase 3 spec 3.3 — view of someone ELSE'S profile.
//
// Displays:
//   - Profile + cover image, name, preferred name, role
//   - Bio (only if owner has bio_public = true)
//   - Interests (only if owner has interests_visibility = 'public')
//   - Followers / Following / Posts counts
//
// Actions:
//   - Follow / Unfollow
//   - Send Chat Request
//   - Share Profile (opens ShareProfileSheet)
//
// This is DISTINCT from `profile_screen.dart` which is the OWN-profile
// view (with edit buttons, settings, post management, etc). Routing:
// when navigating from a search result or post author tap, push
// `UserProfileScreen` — never `ProfileScreen`.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/share_profile_screen.dart';

import '../../services/api_service.dart';

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);

class UserProfileScreen extends StatefulWidget {
  final String userId;

  /// Optional: pre-loaded user data (from a search result, feed author
  /// row, etc) so the screen renders immediately while the fresh fetch
  /// runs in the background. Keys we look at: name, preferred_name,
  /// avatar_url, cover_url, role.
  final Map<String, dynamic>? initial;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initial,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _api = ApiService();

  Map<String, dynamic>? _user;
  bool   _loading = true;
  String? _error;

  bool _busyFollow = false;
  bool _busyChat   = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _user    = Map<String, dynamic>.from(widget.initial!);
      _loading = false;
    }
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _api.getUserProfile(widget.userId)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _user    = data;
        _loading = false;
        _error   = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = 'Could not load profile.';
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_user == null || _busyFollow) return;
    HapticFeedback.mediumImpact();

    final wasFollowing = _user!['is_following'] as bool? ?? false;
    final prevCount    = _user!['followers_count'] as int? ?? 0;

    setState(() {
      _busyFollow = true;
      _user!['is_following']    = !wasFollowing;
      _user!['followers_count'] =
          wasFollowing ? (prevCount - 1).clamp(0, 1 << 30) : prevCount + 1;
    });

    try {
      final res = await _api.followToggle(widget.userId)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _user!['followers_count'] =
            res['followers_count'] ?? _user!['followers_count'];
      });
    } catch (e) {
      if (!mounted) return;
      // Roll back optimistic update.
      setState(() {
        _user!['is_following']    = wasFollowing;
        _user!['followers_count'] = prevCount;
      });
      _snack('Could not ${wasFollowing ? 'unfollow' : 'follow'}.', error: true);
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Future<void> _sendChatRequest() async {
    if (_busyChat) return;
    HapticFeedback.mediumImpact();
    setState(() => _busyChat = true);
    try {
      await _api.sendChatRequest(widget.userId);
      if (!mounted) return;
      _snack('Chat request sent ✓', color: const Color(0xFF1D9E75));
    } catch (e) {
      if (!mounted) return;
      _snack(
        e.toString().replaceAll('Exception: ', ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busyChat = false);
    }
  }

  Future<void> _openShare() async {
    if (_user == null) return;
    HapticFeedback.lightImpact();
    await showShareProfileSheet(
      context,
      profile: _user!,
      onShareTo: (room) async {
        final roomId = room['id']?.toString() ?? '';
        if (roomId.isEmpty) return;
        // Send a message to the room embedding the profile link.
        // The backend just stores it as text — clients render it as
        // a profile card if they recognise the format.
        await _api.shareProfileToRoom(
          roomId: roomId,
          targetUserId: widget.userId,
          targetName: (_user!['name'] as String?) ?? '',
        );
      },
    );
  }

  void _snack(String msg, {Color? color, bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: color ?? (error ? _kG4 : _kG2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: _user == null ? _buildLoadingOrError()
                          : RefreshIndicator(
                              color: _kG2,
                              onRefresh: _fetch,
                              child: CustomScrollView(
                                slivers: [
                                  _buildSliverHeader(),
                                  SliverToBoxAdapter(child: _buildBody()),
                                ],
                              ),
                            ),
    );
  }

  Widget _buildLoadingOrError() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kG2));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_rounded, size: 64, color: _kSlate),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Profile not available.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () { setState(() => _loading = true); _fetch(); },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cover header ───────────────────────────────────────────

  Widget _buildSliverHeader() {
    final coverUrl = _user!['cover_url'] as String? ?? '';
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _kInk,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: Material(
            color: Colors.black.withOpacity(0.4),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 38, height: 38,
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFFEDEEF3)),
                errorWidget: (_, __, ___) => _coverFallback(),
              )
            else
              _coverFallback(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_kG1, _kG2, _kG3, _kG4],
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
      ),
    ),
  );

  // ── Body ──────────────────────────────────────────────────

  Widget _buildBody() {
    final u = _user!;
    final name           = u['name']           as String? ?? '';
    final preferredName  = u['preferred_name'] as String? ?? '';
    final role           = u['role']           as String? ?? '';
    final avatarUrl      = u['avatar_url']     as String? ?? '';
    final bio            = u['bio']            as String? ?? '';
    final bioPublic      = u['bio_public']     as bool?   ?? true;
    final interests      = (u['interests']     as List?  ?? const [])
                              .map((e) => e.toString()).toList();
    final interestsPublic = u['interests_public'] as bool? ?? true;
    final followers      = u['followers_count'] as int? ?? 0;
    final following      = u['following_count'] as int? ?? 0;
    final posts          = u['posts_count']     as int? ?? 0;
    final isFollowing    = u['is_following']    as bool? ?? false;
    final isSelf         = u['is_self']         as bool? ?? false;
    final isVerified     = u['is_verified']     as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar (overlapping cover) ──────────────────────
          Transform.translate(
            offset: const Offset(0, -56),
            child: Container(
              width: 112, height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: const Color(0xFFEDEEF3)),
                        errorWidget: (_, __, ___) => _avatarFallback(name),
                      )
                    : _avatarFallback(name),
              ),
            ),
          ),

          // Pull subsequent content up to compensate for the avatar offset.
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(children: [
              // Name + preferred name + verification tick
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Alfa',
                        fontSize: 22,
                        color: _kInk,
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        color: _kG1, size: 18),
                  ],
                ],
              ),
              if (preferredName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kG2.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '"$preferredName"',
                      style: const TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kG2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                _roleLabel(role),
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.4,
                ),
              ),

              const SizedBox(height: 18),

              // Stats
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10, offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _stat(posts, 'Posts'),
                    _vDivider(),
                    _stat(followers, 'Followers'),
                    _vDivider(),
                    _stat(following, 'Following'),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action row (only if not self)
              if (!isSelf) _buildActionRow(isFollowing),

              const SizedBox(height: 22),

              // Bio
              _buildBioSection(bio, bioPublic),

              const SizedBox(height: 22),

              // Interests
              _buildInterestsSection(interests, interestsPublic),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kG1, _kG2],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Alfa',
            fontSize: 42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _stat(int value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          _fmt(value),
          style: const TextStyle(
            fontFamily: 'Alfa',
            fontSize: 18,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Momo',
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    ),
  );

  Widget _vDivider() => Container(
    width: 1, height: 28,
    color: Colors.grey.shade200,
  );

  Widget _buildActionRow(bool isFollowing) {
    return Row(
      children: [
        // Follow / Unfollow — primary
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _busyFollow ? null : _toggleFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 44,
              decoration: BoxDecoration(
                gradient: isFollowing ? null : const LinearGradient(
                  colors: [_kG2, _kG1],
                  begin: Alignment.centerLeft,
                  end:   Alignment.centerRight,
                ),
                color: isFollowing ? Colors.white : null,
                border: isFollowing
                    ? Border.all(color: Colors.grey.shade300, width: 1.5)
                    : null,
                borderRadius: BorderRadius.circular(22),
                boxShadow: isFollowing ? null : [
                  BoxShadow(
                    color: _kG2.withOpacity(0.25),
                    blurRadius: 10, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _busyFollow
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isFollowing ? _kG2 : Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFollowing
                                ? Icons.check_rounded
                                : Icons.person_add_alt_1_rounded,
                            size: 16,
                            color: isFollowing ? _kG2 : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isFollowing ? _kG2 : Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Send chat request
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _busyChat ? null : _sendChatRequest,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: _busyChat
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kG2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Message',
                            style: TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Share profile
        GestureDetector(
          onTap: _openShare,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Icon(
              Icons.ios_share_rounded,
              size: 18, color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(String bio, bool isPublic) {
    if (!isPublic) {
      return _privateSection(
        icon: Icons.lock_outline_rounded,
        title: 'Bio',
        message: 'This user has set their bio to private.',
      );
    }
    if (bio.trim().isEmpty) {
      // Owner is public-by-default but hasn't filled in a bio yet.
      // Hide entirely rather than showing "no bio".
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BIO',
            style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: _kG2,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bio,
            style: const TextStyle(
              fontFamily: 'Momo',
              fontSize: 14,
              color: _kInk,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(List<String> interests, bool isPublic) {
    if (!isPublic) {
      return _privateSection(
        icon: Icons.lock_outline_rounded,
        title: 'Interests',
        message: 'This user has set their interests to private.',
      );
    }
    if (interests.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INTERESTS',
            style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: _kG3,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: interests.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kG3, _kG4],
                  begin: Alignment.centerLeft,
                  end:   Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _privateSection({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching Staff';
      case 'non_teaching_staff': return 'Non-Teaching Staff';
      case 'admin':              return 'Admin';
      case 'parent':             return 'Parent';
      case 'visitor':            return 'Visitor';
      default:                   return role.replaceAll('_', ' ');
    }
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
