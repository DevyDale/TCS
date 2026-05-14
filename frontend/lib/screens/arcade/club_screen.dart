import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../services/api_service.dart';
import '../profile/user_screen_profile.dart';


// ─────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────

const _kG1     = Color(0xFF6DD5FA);
const _kG2     = Color(0xFF8E54E9);
const _kG3     = Color(0xFFF7971E);
const _kG4     = Color(0xFFFF5858);
const _kInk    = Color(0xFF1A1A2E);
const _kSlate  = Color(0xFF64687A);
const _kBg     = Color(0xFFF4F5FA);
const _kIndigo = Color(0xFF3F51B5);
const _kDeep   = Color(0xFF512DA8);

// Twitter-style verified blue.
const _kVerified = Color(0xFF1DA1F2);

// Role chip palette — president > executive > member.
const _kPresident = Color(0xFFFFB300);  // amber
const _kExecutive = Color(0xFF8E54E9);  // violet
const _kMember    = Color(0xFF64687A);  // slate

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────

class ClubScreen extends StatefulWidget {
  /// Either pass an `id` (we'll fetch the rest) or a partial `club` map
  /// from a list view (we'll show the cached fields and refresh).
  final String? id;
  final Map<String, dynamic>? club;

  const ClubScreen({super.key, this.id, this.club})
      : assert(id != null || club != null,
            'Provide either id or club');

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabCtrl;
  final _picker = ImagePicker();

  Future<void> _pickLogo() async {
    if (!_isAdmin) return;
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    try {
      await _api.uploadClubLogo(_clubId, filePath: file.path);
      _snack('Logo updated successfully!');
      await _refreshClub();
    } catch (e) {
      _snack('Failed to update logo', error: true);
    }
  }

  Future<void> _pickCover() async {
    if (!_isAdmin) return;
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    try {
      await _api.uploadClubCover(_clubId, filePath: file.path);
      _snack('Cover photo updated!');
      await _refreshClub();
    } catch (e) {
      _snack('Failed to update cover', error: true);
    }
  }

  // Local mutable copy so we can do optimistic updates.
  late Map<String, dynamic> _club;

  List<Map<String, dynamic>> _activeMembers  = [];
  List<Map<String, dynamic>> _pendingMembers = [];

  bool _busy           = false;  // join/leave in flight
  bool _loadingClub    = true;
  bool _loadingMembers = true;

  // ── Phase 6 — Feed tab state ──────────────────────────────
  // Populated by _loadFeed() from GET /api/clubs/<id>/feed/, which
  // returns { posts: [...], events: [...] }. Both arrays come back
  // newest-first; we render events above posts in the Feed tab.
  List<Map<String, dynamic>> _feedPosts  = [];
  List<Map<String, dynamic>> _feedEvents = [];
  bool _loadingFeed = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _club = Map<String, dynamic>.from(widget.club ?? {'id': widget.id});
    _refreshClub();
    _loadMembers();
    _loadFeed();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Derived ───────────────────────────────────────────────

  String  get _clubId       => _club['id']?.toString() ?? widget.id ?? '';
  String  get _name         => _club['name']        as String? ?? 'Club';
  String  get _tagline      => _club['tagline']     as String? ?? '';
  String  get _description  => _club['description'] as String? ?? '';
  String  get _mission      => _club['mission']     as String? ?? '';
  String  get _rules        => _club['rules']       as String? ?? '';
  String  get _contactEmail => _club['contact_email'] as String? ?? '';
  String  get _contactPhone => _club['contact_phone'] as String? ?? '';
  String  get _category     => _club['category']    as String? ?? 'other';
  String? get _coverUrl     => _club['cover_url']   as String?;
  String? get _logoUrl      => _club['logo_url']    as String?;
  bool    get _isVerified   => _club['is_verified'] as bool? ?? false;
  bool    get _isPublic     => _club['is_public']   as bool? ?? true;
  bool    get _requiresApproval =>
      _club['requires_approval'] as bool? ?? false;
  int     get _memberCount  => _club['members_count'] as int? ?? 0;

  Map<String, dynamic> get _membership =>
      (_club['membership'] as Map?)?.cast<String, dynamic>() ??
      {'is_member': false, 'is_pending': false, 'is_admin': false,
       'role': null, 'status': null};

  bool   get _isMember  => _membership['is_member']  == true;
  bool   get _isPending => _membership['is_pending'] == true;
  bool   get _isAdmin   => _membership['is_admin']   == true;
  String get _myRole    => _membership['role'] as String? ?? '';

  // ── Data loading ──────────────────────────────────────────

  Future<void> _refreshClub() async {
    if (_clubId.isEmpty) return;
    try {
      final data = await _api.getClub(_clubId);
      if (!mounted || data is! Map) return;
      setState(() {
        _club = {..._club, ...data.cast<String, dynamic>()};
        _loadingClub = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingClub = false);
    }
  }

  Future<void> _loadMembers() async {
    if (_clubId.isEmpty) {
      setState(() => _loadingMembers = false);
      return;
    }
    setState(() => _loadingMembers = true);
    try {
      // Active list — everyone sees this.
      final activeRaw = await _api.getClubMembers(_clubId, status: 'active');
      final active = (activeRaw is List)
          ? activeRaw.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      // Pending list — only admins should see it.
      List<Map<String, dynamic>> pending = [];
      if (_isAdmin) {
        try {
          final p = await _api.getClubMembers(_clubId, status: 'pending');
          pending = (p is List) ? p.cast<Map<String, dynamic>>() : [];
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _activeMembers  = active;
        _pendingMembers = pending;
        _loadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  /// Phase 6 — load combined posts + events for this club's Feed tab.
  /// Backend endpoint is GET /api/clubs/<id>/feed/. Failure here is
  /// non-fatal: the Feed tab just renders the empty state.
  Future<void> _loadFeed() async {
    if (_clubId.isEmpty) return;
    setState(() => _loadingFeed = true);
    try {
      final res = await _api.getClubFeed(_clubId) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _feedPosts  = (res['posts']  as List? ?? [])
            .cast<Map<String, dynamic>>();
        _feedEvents = (res['events'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loadingFeed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFeed = false);
    }
  }

  // ── Membership actions ────────────────────────────────────

  Future<void> _join() async {
    if (_busy || _clubId.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      final res = await _api.joinClub(_clubId) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _club = {
          ..._club,
          'membership': {
            'is_member':  res['is_member']  ?? false,
            'is_pending': res['is_pending'] ?? false,
            'is_admin':   res['is_admin']   ?? false,
            'role':       res['role'],
            'status':     res['status'],
          },
        };
      });
      if (_isMember) {
        _snack('Welcome to $_name! 🎉');
        await _refreshClub();
        await _loadMembers();
        // Refresh the feed too — joining may unlock private content.
        await _loadFeed();
      } else if (_isPending) {
        _snack('Request sent. The admins will review it shortly.');
      }
    } catch (_) {
      _snack('Could not join the club. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final confirmed = await _confirm(
      title:   'Leave $_name?',
      message: 'You can re-join anytime as long as the club is public.',
      ok:      'Leave',
      okColor: _kG4,
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await _api.leaveClub(_clubId);
      if (!mounted) return;
      setState(() {
        _club = {
          ..._club,
          'membership': {
            'is_member': false, 'is_pending': false, 'is_admin': false,
            'role': null, 'status': null,
          },
          'members_count':
              ((_club['members_count'] as int? ?? 1) - 1).clamp(0, 1 << 30),
        };
      });
      _snack('Left $_name.');
      await _loadMembers();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Admin actions on members ──────────────────────────────

  Future<void> _approve(Map<String, dynamic> m) async {
    final uid  = m['user_id']?.toString() ?? '';
    final name = m['name'] as String? ?? 'Member';
    if (uid.isEmpty) return;
    try {
      await _api.approveClubMember(_clubId, uid);
      _snack('Approved $name.');
      await _loadMembers();
      await _refreshClub();
    } catch (_) {
      _snack('Could not approve.', error: true);
    }
  }

  Future<void> _reject(Map<String, dynamic> m) async {
    final uid  = m['user_id']?.toString() ?? '';
    final name = m['name'] as String? ?? 'Member';
    if (uid.isEmpty) return;
    try {
      await _api.rejectClubMember(_clubId, uid);
      _snack('Rejected $name.');
      await _loadMembers();
    } catch (_) {
      _snack('Could not reject.', error: true);
    }
  }

  Future<void> _showAdminSheet(Map<String, dynamic> m) async {
    final uid       = m['user_id']?.toString() ?? '';
    final name      = m['name']    as String? ?? 'Member';
    final theirRole = m['role']    as String? ?? 'member';
    if (uid.isEmpty) return;

    HapticFeedback.lightImpact();
    final iAmPresident = _myRole == 'president';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Manage $name',
                style: const TextStyle(fontFamily: 'Alfa',
                    fontSize: 18, color: _kInk)),
            const SizedBox(height: 4),
            Text(_roleLabel(theirRole),
                style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 18),

            // Promote to executive (if currently member)
            if (theirRole == 'member')
              _adminTile(
                icon: Icons.upgrade_rounded,
                label: 'Promote to Executive',
                color: _kExecutive,
                onTap: () async {
                  Navigator.pop(context);
                  await _changeRole(uid, 'executive', name);
                },
              ),

            // Demote executive → member
            if (theirRole == 'executive')
              _adminTile(
                icon: Icons.south_rounded,
                label: 'Demote to Member',
                color: _kSlate,
                onTap: () async {
                  Navigator.pop(context);
                  await _changeRole(uid, 'member', name);
                },
              ),

            // Transfer presidency (only president can do this)
            if (iAmPresident && theirRole != 'president')
              _adminTile(
                icon: Icons.workspace_premium_rounded,
                label: 'Transfer Presidency',
                color: _kPresident,
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await _confirm(
                    title:   'Transfer presidency to $name?',
                    message: 'You will be demoted to Executive.',
                    ok:      'Transfer',
                    okColor: _kPresident,
                  );
                  if (ok == true) {
                    await _changeRole(uid, 'president', name);
                  }
                },
              ),

            // Remove member (not allowed on president)
            if (theirRole != 'president')
              _adminTile(
                icon: Icons.person_remove_rounded,
                label: 'Remove from Club',
                color: _kG4,
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await _confirm(
                    title:   'Remove $name?',
                    message: 'They will lose access immediately.',
                    ok:      'Remove',
                    okColor: _kG4,
                  );
                  if (ok == true) {
                    try {
                      await _api.removeClubMember(_clubId, uid);
                      _snack('Removed $name.');
                      await _loadMembers();
                      await _refreshClub();
                    } catch (_) {
                      _snack('Could not remove.', error: true);
                    }
                  }
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _changeRole(String uid, String newRole, String name) async {
    try {
      await _api.changeClubMemberRole(_clubId, uid, newRole);
      _snack('$name is now ${_roleLabel(newRole)}.');
      await _loadMembers();
      await _refreshClub();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String ok,
    required Color  okColor,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text(title,
              style: const TextStyle(fontFamily: 'Alfa', fontSize: 18)),
          content: Text(message,
              style: const TextStyle(fontFamily: 'Momo')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(fontFamily: 'Arch', color: _kSlate)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(ok,
                  style: TextStyle(fontFamily: 'Arch', color: okColor)),
            ),
          ],
        ),
      );

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(
              fontFamily: 'Momo', color: Colors.white)),
      backgroundColor: error ? Colors.red.shade600 : Colors.grey.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

  String _roleLabel(String role) {
    switch (role) {
      case 'president': return 'President';
      case 'executive': return 'Executive';
      case 'member':    return 'Member';
      default:          return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'president': return _kPresident;
      case 'executive': return _kExecutive;
      default:          return _kMember;
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildHeaderInfo()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBar(child: _buildTabBar()),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildAboutTab(),
            _buildMembersTab(),
            _buildFeedTab(),
          ],
        ),
      ),
    );
  }

  // ── App bar with cover image ──────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      stretch: true,
      backgroundColor: _kIndigo,
      flexibleSpace: Container(
        color: _kBg,
      ),
    );
  }

  Widget _coverGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kIndigo, _kDeep],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
        ),
      );

  // ── Header info: logo + name + tagline + meta + action ────

  Widget _buildHeaderInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          // Header with gradient border and embedded back button
          Stack(
            children: [
              // Gradient border outer container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(2), // border thickness
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kG1, _kG2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 16),
                      Text(
                        _name,
                        style: const TextStyle(
                          fontFamily: 'Alfa',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_tagline.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _tagline,
                            style: const TextStyle(
                              fontFamily: 'Momo',
                              fontSize: 14,
                              color: _kSlate,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Back button inside container
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: _kInk,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Meta Chips + Action Button
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _metaChip(
                icon: Icons.people_alt_rounded,
                label: '$_memberCount members',
                color: _kIndigo,
              ),
              _metaChip(
                icon: Icons.category_rounded,
                label: _titleCase(_category),
                color: _kG2,
              ),
              if (_requiresApproval && !_isMember)
                _metaChip(
                  icon: Icons.shield_rounded,
                  label: 'Approval Required',
                  color: _kG3,
                ),
            ],
          ),

          const SizedBox(height: 20),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'C';

    return GestureDetector(
      onTap: _isAdmin ? _pickLogo : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Logo Container
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: _logoUrl != null && _logoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _logoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _logoFallback(initial),
                      placeholder: (_, __) => _logoFallback(initial),
                    )
                  : _logoFallback(initial),
            ),
          ),

          // Camera Icon for Admins
          if (_isAdmin)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: _kG2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logoFallback(String initial) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kG2, _kG1],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: 'Alfa',
              fontSize: 32,
              color: Colors.white,
            ),
          ),
        ),
      );

  Widget _buildAdminBadge() {
    final label = _myRole == 'president' ? 'PRESIDENT' :
                  _myRole == 'executive' ? 'EXECUTIVE' : 'ADMIN';
    final color = _roleColor(_myRole);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.30),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.shield_rounded, color: Colors.white, size: 13),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
          fontFamily: 'Arch',
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Colors.white,
          letterSpacing: 0.7,
        )),
      ]),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          fontFamily: 'Arch',
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: color,
        )),
      ]),
    );
  }

  // ── Action button — drives the full membership state machine ──

  Widget _buildActionButton() {
    // Admins don't see Join/Leave — they manage from the members tab
    // and the badge above already tells them they're admin. Show a
    // subtle "you're managing this club" pill instead.
    if (_isAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _kIndigo.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kIndigo.withOpacity(0.20)),
        ),
        child: const Center(
          child: Text(
            'You manage this club',
            style: TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: _kIndigo,
            ),
          ),
        ),
      );
    }

    if (_isPending) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded,
                color: _kSlate, size: 16),
            SizedBox(width: 8),
            Text('Request sent — awaiting approval',
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _kSlate,
                )),
          ],
        ),
      );
    }

    if (_isMember) {
      return GestureDetector(
        onTap: _busy ? null : _leave,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kG4, width: 1.5),
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kG4),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 16, color: _kG4),
                      SizedBox(width: 8),
                      Text('Leave Club',
                          style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _kG4,
                          )),
                    ],
                  ),
          ),
        ),
      );
    }

    // Not a member, not pending → Join or Request
    final label = _requiresApproval ? 'Request to Join' : 'Join Club';
    final icon  = _requiresApproval ? Icons.send_rounded : Icons.add_rounded;

    return GestureDetector(
      onTap: _busy ? null : _join,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kIndigo.withOpacity(0.30),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────

  Widget _buildTabBar() => Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: _kIndigo,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: _kIndigo,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Arch', fontSize: 13),
          tabs: const [
            Tab(text: 'About'),
            Tab(text: 'Members'),
            Tab(text: 'Feed'),
          ],
        ),
      );

  // ── ABOUT TAB ─────────────────────────────────────────────

  Widget _buildAboutTab() {
    final hasContent = _description.isNotEmpty ||
        _mission.isNotEmpty || _rules.isNotEmpty;
    final hasContact = _contactEmail.isNotEmpty || _contactPhone.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (hasContent) ...[
          if (_description.isNotEmpty)
            _aboutCard(
              title: 'About',
              icon:  Icons.info_outline_rounded,
              tint:  _kG2,
              body:  _description,
            ),
          if (_mission.isNotEmpty) ...[
            const SizedBox(height: 12),
            _aboutCard(
              title: 'Mission',
              icon:  Icons.flag_rounded,
              tint:  _kG3,
              body:  _mission,
            ),
          ],
          if (_rules.isNotEmpty) ...[
            const SizedBox(height: 12),
            _aboutCard(
              title: 'Rules',
              icon:  Icons.gavel_rounded,
              tint:  _kIndigo,
              body:  _rules,
            ),
          ],
        ] else
          _aboutCard(
            title:  'About',
            icon:   Icons.info_outline_rounded,
            tint:   _kG2,
            body:   _isAdmin
                ? 'No description yet. Add one from the Django admin or Edit screen.'
                : 'No description has been added yet.',
            italic: true,
          ),

        if (hasContact) ...[
          const SizedBox(height: 12),
          _contactCard(),
        ],

        const SizedBox(height: 12),
        _detailsCard(),
      ],
    );
  }

  Widget _aboutCard({
    required String   title,
    required IconData icon,
    required Color    tint,
    required String   body,
    bool italic = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
          ]),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(
            fontFamily: 'Momo',
            fontSize: 13,
            height: 1.55,
            color: italic ? Colors.grey.shade500 : _kInk,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          )),
        ],
      ),
    );
  }

  Widget _contactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.contact_mail_rounded, size: 16, color: _kG4),
            SizedBox(width: 8),
            Text('Contact',
                style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
          ]),
          const SizedBox(height: 12),
          if (_contactEmail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.mail_outline_rounded,
                    size: 14, color: _kSlate),
                const SizedBox(width: 8),
                Flexible(
                  child: SelectableText(_contactEmail,
                      style: const TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 13,
                        color: _kInk,
                      )),
                ),
              ]),
            ),
          if (_contactPhone.isNotEmpty)
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: _kSlate),
              const SizedBox(width: 8),
              SelectableText(_contactPhone,
                  style: const TextStyle(
                    fontFamily: 'Momo',
                    fontSize: 13,
                    color: _kInk,
                  )),
            ]),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    final created = _formatDate(_club['created_at']?.toString());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.tune_rounded, size: 16, color: _kIndigo),
            SizedBox(width: 8),
            Text('Details',
                style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 16, color: _kInk)),
          ]),
          const SizedBox(height: 12),
          _detailRow('Visibility',  _isPublic ? 'Public' : 'Private'),
          _detailRow('Approval',    _requiresApproval ? 'Required' : 'Open'),
          _detailRow('Verified',    _isVerified ? 'Yes' : 'No'),
          _detailRow('Category',    _titleCase(_category)),
          if (created.isNotEmpty)
            _detailRow('Founded',   created),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 12,
              color: Colors.grey.shade500,
            )),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _kInk,
            )),
          ),
        ]),
      );

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  // ── MEMBERS TAB ───────────────────────────────────────────

  Widget _buildMembersTab() {
    if (_loadingMembers) {
      return const Center(
          child: CircularProgressIndicator(color: _kIndigo));
    }

    return RefreshIndicator(
      color: _kIndigo,
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Pending requests (admin-only)
          if (_isAdmin && _pendingMembers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kG3.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kG3.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.pending_actions_rounded,
                        size: 16, color: _kG3),
                    const SizedBox(width: 6),
                    Text('PENDING REQUESTS (${_pendingMembers.length})',
                        style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _kG3,
                          letterSpacing: 0.8,
                        )),
                  ]),
                  const SizedBox(height: 8),
                  ..._pendingMembers.map(_buildPendingRow),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_activeMembers.isEmpty)
            _emptyHint(
              icon:    Icons.people_outline_rounded,
              title:   'No members yet',
              message: 'Be the first to join this club.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _activeMembers.length; i++) ...[
                    _buildMemberRow(_activeMembers[i]),
                    if (i < _activeMembers.length - 1)
                      Divider(color: Colors.grey.shade100, height: 1,
                          indent: 60, endIndent: 16),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingRow(Map<String, dynamic> m) {
    final name      = m['name']       as String? ?? 'Member';
    final avatar    = m['avatar_url'] as String? ?? '';
    final userRole  = m['user_role']  as String? ?? '';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        _avatarCircle(url: avatar, initial: initial, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _kInk,
                  )),
              if (userRole.isNotEmpty)
                Text(_userRoleLabel(userRole),
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    )),
            ],
          ),
        ),
        // Approve
        GestureDetector(
          onTap: () => _approve(m),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Icon(Icons.check_rounded,
                color: Colors.green.shade700, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Reject
        GestureDetector(
          onTap: () => _reject(m),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _kG4.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kG4.withOpacity(0.30)),
            ),
            child: const Icon(Icons.close_rounded, color: _kG4, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> m) {
    final name     = m['name']       as String? ?? 'Member';
    final avatar   = m['avatar_url'] as String? ?? '';
    final clubRole = m['role']       as String? ?? 'member';
    final userRole = m['user_role']  as String? ?? '';
    final uid      = m['user_id']?.toString() ?? '';
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return InkWell(
      onTap: () {
        if (uid.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: uid, initial: m),
        ));
      },
      onLongPress: _isAdmin ? () => _showAdminSheet(m) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          _avatarCircle(url: avatar, initial: initial, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _kInk,
                        )),
                  ),
                  if (clubRole != 'member') ...[
                    const SizedBox(width: 8),
                    _roleBadge(clubRole),
                  ],
                ]),
                if (userRole.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_userRoleLabel(userRole),
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      )),
                ],
              ],
            ),
          ),
          if (_isAdmin && uid.isNotEmpty && clubRole != 'president')
            GestureDetector(
              onTap: () => _showAdminSheet(m),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.more_vert_rounded,
                    color: Colors.grey.shade400, size: 18),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Arch',
          fontWeight: FontWeight.bold,
          fontSize: 9,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _userRoleLabel(String r) {
    switch (r.toLowerCase()) {
      case 'student':            return 'Student';
      case 'teaching_staff':     return 'Teaching Staff';
      case 'non_teaching_staff': return 'Staff';
      case 'admin':              return 'Admin';
      case 'parent':             return 'Parent';
      default:                   return r.replaceAll('_', ' ');
    }
  }

  Widget _avatarCircle({
    required String  url,
    required String  initial,
    required double  size,
  }) =>
      Container(
        width: size, height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [_kG1, _kG2]),
        ),
        child: ClipOval(
          child: url.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: size, height: size,
                  errorWidget: (_, __, ___) => _initialFallback(initial, size),
                  placeholder:  (_, __)     => _initialFallback(initial, size),
                )
              : _initialFallback(initial, size),
        ),
      );

  Widget _initialFallback(String initial, double size) => Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Arch',
            fontWeight: FontWeight.bold,
            fontSize: size * 0.40,
          ),
        ),
      );

  Widget _adminTile({
    required IconData    icon,
    required String      label,
    required Color       color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                )),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════
  // FEED TAB — Phase 6
  //
  // Replaces the old "Posts, events, and announcements from this
  // club will land here in the next slice." placeholder. Uses the
  // unified GET /api/clubs/<id>/feed/ endpoint, which returns
  // { posts: [...], events: [...] }.
  //
  //   • Loading        → spinner
  //   • Both empty     → friendly empty card (different copy
  //                      depending on whether the viewer is a
  //                      member or not)
  //   • Has content    → Events section, then Posts section,
  //                      pull-to-refresh on the whole list.
  // ══════════════════════════════════════════════════════════

  Widget _buildFeedTab() {
    if (_loadingFeed) {
      return const Center(
          child: CircularProgressIndicator(color: _kIndigo));
    }
    final hasPosts  = _feedPosts.isNotEmpty;
    final hasEvents = _feedEvents.isNotEmpty;

    if (!hasPosts && !hasEvents) {
      return RefreshIndicator(
        color: _kIndigo,
        onRefresh: _loadFeed,
        child: ListView(
          // Tall enough for a pull-to-refresh on a fresh empty state.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: _kIndigo.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.dynamic_feed_rounded,
                          color: _kIndigo, size: 28),
                    ),
                    const SizedBox(height: 14),
                    const Text('Nothing here yet',
                        style: TextStyle(
                            fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
                    const SizedBox(height: 6),
                    Text(
                      _isMember
                          ? 'Be the first to post or schedule an event for this club.'
                          : 'Join the club to see member posts and upcoming events.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kIndigo,
      onRefresh: _loadFeed,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (hasEvents) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text('UPCOMING EVENTS',
                  style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 11, color: _kIndigo, letterSpacing: 1.2)),
            ),
            ..._feedEvents.map(_buildEventCard),
            const SizedBox(height: 18),
          ],
          if (hasPosts) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text('POSTS',
                  style: TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    fontSize: 11, color: _kIndigo, letterSpacing: 1.2)),
            ),
            ..._feedPosts.map(_buildPostCard),
          ],
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    final title   = e['title']    as String? ?? 'Untitled event';
    final loc     = e['location'] as String? ?? '';
    final start   = e['start_time'] as String? ?? '';
    // Backend gives both card_url (800x600) and poster_url (1200 wide).
    // Prefer the card asset for in-list rendering.
    final cardUrl = (e['card_url']   as String?) ??
                    (e['poster_url'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cardUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: cardUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: _kIndigo.withOpacity(0.08)),
                  placeholder: (_, __) =>
                      Container(color: _kIndigo.withOpacity(0.05)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Alfa', fontSize: 16, color: _kInk),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (loc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.place_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(loc,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: 'Momo', fontSize: 12,
                                color: Colors.grey.shade600)),
                      ),
                    ]),
                  ],
                  if (start.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_fmtEventDateTime(start),
                        style: const TextStyle(
                            fontFamily: 'Momo', fontSize: 12,
                            color: _kIndigo,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> p) {
    final author   = p['author_name'] as String? ?? 'Member';
    final content  = p['content']     as String? ?? '';
    // Mirror the campus-feed renderer: media is a list of objects,
    // the first item drives the preview thumbnail.
    final media    = (p['media'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final firstImg = media.isNotEmpty
        ? (media.first['url'] as String? ?? '')
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16, backgroundColor: _kIndigo.withOpacity(0.15),
              child: Text(
                author.isNotEmpty ? author[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontFamily: 'Arch', fontWeight: FontWeight.bold,
                    color: _kIndigo, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(author,
                  style: const TextStyle(
                      fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      fontSize: 13, color: _kInk),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(content,
                style: const TextStyle(
                    fontFamily: 'Momo', fontSize: 13, height: 1.4),
                maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          if (firstImg.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: firstImg,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: Colors.grey.shade200),
                  placeholder: (_, __) =>
                      Container(color: Colors.grey.shade100),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Event-row date format: "DD MMM · HH:MM" in the user's local TZ.
  /// Distinct from `_formatDate()` (which is just "DD MMM YYYY") so
  /// in-list event timing reads tighter.
  String _fmtEventDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} · $hh:$mm';
    } catch (_) {
      return '';
    }
  }

  Widget _emptyHint({
    required IconData icon,
    required String   title,
    required String   message,
  }) =>
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Alfa', fontSize: 18, color: _kInk)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.5,
                )),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// STICKY TAB BAR DELEGATE
// ─────────────────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabBar({required this.child});

  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override Widget build(BuildContext _, double __, bool ___) => child;
  @override bool shouldRebuild(_StickyTabBar old) => old.child != child;
}