// lib/screens/profile/user_profile_screen.dart
//
// Other-user profile — arcade light theme.
//
// Layout, top to bottom:
//   1. Cover banner (180px) — image or animated default gradient
//   2. Avatar with animated SweepGradient ring (overlapping cover)
//   3. Identity — name + verified · preferred name pill · role
//   4. Stats card — Posts / Followers / Following
//   5. Action row — Follow (primary, dark ink) / Message / Share
//   6. Bio card (or "private" placeholder)
//   7. Interests card (or "private" placeholder)
//
// All actions and data fetches preserved from the previous version.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/profile/share_profile_screen.dart';

import '../../services/api_service.dart';

// ── Light palette (matches arcade + profile_screen) ──────────
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
const _kVerified = Color(0xFF1DA1F2);

const _gradColors = <Color>[
  Color(0xFF6DD5FA), Color(0xFF7C3AED),
  Color(0xFFF59E0B), Color(0xFFFF4F6E),
  Color(0xFF6DD5FA),
];

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? initial;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initial,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  late final AnimationController _shimmerCtrl;

  Map<String, dynamic>? _user;
  bool   _loading = true;
  String? _error;

  bool _busyFollow = false;
  bool _busyChat   = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))..repeat();
    if (widget.initial != null) {
      _user    = Map<String, dynamic>.from(widget.initial!);
      _loading = false;
    }
    _fetch();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
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
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
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
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color ?? (error ? _kCoral : _kInk),
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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kBg1, _kBg2, _kBg3], stops: [0.0, 0.55, 1.0]),
        ),
        child: _user == null
            ? _buildLoadingOrError()
            : RefreshIndicator(
                color: _kInk, onRefresh: _fetch,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildCoverSection()),
                    SliverToBoxAdapter(child: _buildBody()),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingOrError() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: _kInk, strokeWidth: 2.4));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_off_rounded, size: 56, color: _kSlate2),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Profile not available.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _kSlate),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () { setState(() => _loading = true); _fetch(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: _kInk, borderRadius: BorderRadius.circular(12)),
              child: const Text('Try again', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Cover section ──────────────────────────────────────────

  Widget _buildCoverSection() {
    final topPad = MediaQuery.of(context).padding.top;
    const coverH = 180.0;
    const avatarR = 56.0;

    final coverUrl = _user!['cover_url'] as String? ?? '';
    final avatarUrl = _user!['avatar_url'] as String? ?? '';
    final name = _user!['name'] as String? ?? '';

    return SizedBox(
      height: coverH + avatarR,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: 0, left: 0, right: 0, height: coverH,
          child: coverUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: coverUrl, fit: BoxFit.cover,
                  placeholder: (_, __) => _coverFallback(),
                  errorWidget: (_, __, ___) => _coverFallback())
              : _coverFallback()),

        // Subtle bottom gradient for legibility of any overlapping content
        Positioned(top: 0, left: 0, right: 0, height: coverH,
          child: IgnorePointer(child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.10)],
              ),
            )))),

        // Back
        Positioned(top: topPad + 12, left: 16,
          child: GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.arrow_back_rounded,
                  color: _kInk, size: 18)))),

        // Share (top-right)
        Positioned(top: topPad + 12, right: 16,
          child: GestureDetector(onTap: _openShare,
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.ios_share_rounded,
                  color: _kInkSoft, size: 16)))),

        // Avatar with animated gradient ring
        Positioned(top: coverH - avatarR, left: 0, right: 0,
          child: Center(child: _GradientBorderCard(
            animation: _shimmerCtrl,
            radius: avatarR + 4,
            borderWidth: 3.5,
            innerColor: _kCard,
            child: ClipOval(child: SizedBox(
              width: avatarR * 2, height: avatarR * 2,
              child: avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl, fit: BoxFit.cover,
                    placeholder: (_, __) => _avatarFallback(name),
                    errorWidget: (_, __, ___) => _avatarFallback(name))
                : _avatarFallback(name),
            )),
          ))),
      ]),
    );
  }

  Widget _coverFallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_kBlue, _kPurple, _kAmber, _kCoral],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Stack(children: [
      Positioned(right: -40, top: -40, child: Container(width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _kCard.withOpacity(0.10)))),
      Positioned(left: -30, bottom: 0, child: Container(width: 140, height: 140,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: _kCard.withOpacity(0.08)))),
    ]));

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBlue, _kPurple],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Text(initial, style: const TextStyle(
          fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white))),
    );
  }

  // ── Body ───────────────────────────────────────────────────

  Widget _buildBody() {
    final u = _user!;
    final name           = u['name']           as String? ?? '';
    final preferredName  = u['preferred_name'] as String? ?? '';
    final role           = u['role']           as String? ?? '';
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [

        // Name + verified
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(name, textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: _kInk, letterSpacing: -0.5))),
          if (isVerified) ...[
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, color: _kVerified, size: 18),
          ],
        ]),

        // Preferred name pill
        if (preferredName.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _kPurple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20)),
              child: Text('"$preferredName"',
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: _kPurple)),
            )),

        const SizedBox(height: 6),
        Text(_roleLabel(role),
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 12,
              color: _kSlate, letterSpacing: 0.4)),

        const SizedBox(height: 18),

        // Stats card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder)),
          child: Row(children: [
            _stat(posts, 'Posts'),
            _vDivider(),
            _stat(followers, 'Followers'),
            _vDivider(),
            _stat(following, 'Following'),
          ]),
        ),

        const SizedBox(height: 14),

        if (!isSelf) _buildActionRow(isFollowing),

        const SizedBox(height: 18),

        _buildBioSection(bio, bioPublic),
        const SizedBox(height: 14),
        _buildInterestsSection(interests, interestsPublic),
      ]),
    );
  }

  Widget _stat(int value, String label) => Expanded(
    child: Column(children: [
      Text(_fmt(value), style: const TextStyle(
          fontSize: 19, fontWeight: FontWeight.w900,
          color: _kInk, letterSpacing: -0.3)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
          fontSize: 11, color: _kSlate, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _vDivider() => Container(width: 1, height: 28, color: _kBorder);

  Widget _buildActionRow(bool isFollowing) {
    return Row(children: [
      // Follow / Following — primary
      Expanded(flex: 3, child: GestureDetector(
        onTap: _busyFollow ? null : _toggleFollow,
        child: isFollowing
          ? Container(
              height: 46,
              decoration: BoxDecoration(
                color: _kCard,
                border: Border.all(color: _kBorder, width: 1.5),
                borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: _busyFollow
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kInk))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.check_rounded, size: 16, color: _kInk),
                      SizedBox(width: 6),
                      Text('Following', style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13,
                          color: _kInk, letterSpacing: -0.2)),
                    ])))
          : _GradientBorderCard(
              animation: _shimmerCtrl,
              radius: 14, borderWidth: 1.4,
              innerColor: _kInk,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _busyFollow
                ? const Center(child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
                : const Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Follow', style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13,
                        color: Colors.white, letterSpacing: -0.2)),
                  ])),
      )),
      const SizedBox(width: 10),

      // Message
      Expanded(flex: 3, child: GestureDetector(
        onTap: _busyChat ? null : _sendChatRequest,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: _kCard,
            border: Border.all(color: _kBorder, width: 1.5),
            borderRadius: BorderRadius.circular(14)),
          child: Center(child: _busyChat
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kInk))
              : const Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: _kInkSoft),
                  SizedBox(width: 6),
                  Text('Message', style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13,
                      color: _kInk, letterSpacing: -0.2)),
                ])),
        ),
      )),
      const SizedBox(width: 10),

      // Share
      GestureDetector(onTap: _openShare,
        child: Container(width: 46, height: 46,
          decoration: BoxDecoration(
            color: _kCard, shape: BoxShape.circle,
            border: Border.all(color: _kBorder, width: 1.5)),
          child: const Icon(Icons.ios_share_rounded,
              size: 18, color: _kInkSoft))),
    ]);
  }

  Widget _buildBioSection(String bio, bool isPublic) {
    if (!isPublic) {
      return _privateSection(
        icon: Icons.lock_outline_rounded,
        title: 'Bio',
        message: 'This user has set their bio to private.',
      );
    }
    if (bio.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BIO', style: TextStyle(
            fontWeight: FontWeight.w900, fontSize: 11,
            color: _kPurple, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(bio, style: const TextStyle(
            fontSize: 14, color: _kInk, height: 1.55)),
      ]),
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
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('INTERESTS', style: TextStyle(
            fontWeight: FontWeight.w900, fontSize: 11,
            color: _kAmber, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
          children: List.generate(interests.length, (i) {
            final c = [_kBlue, _kPurple, _kAmber, _kCoral][i % 4];
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.withOpacity(0.10),
                border: Border.all(color: c.withOpacity(0.30), width: 1.5),
                borderRadius: BorderRadius.circular(20)),
              child: Text(interests[i], style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: c, letterSpacing: -0.1)),
            );
          })),
      ]),
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
        color: _kCardLo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder)),
      child: Row(children: [
        Icon(icon, size: 20, color: _kSlate2),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 11,
                color: _kSlate, letterSpacing: 1.2)),
            const SizedBox(height: 2),
            Text(message, style: const TextStyle(
                fontSize: 12, color: _kSlate)),
          ])),
      ]),
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

// ═════════════════════════════════════════════════════════════
// _GradientBorderCard
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