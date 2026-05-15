// lib/screens/clubs/club_screen.dart
//
// Light-theme club screen matching the mockup layout:
//   • Single scrolling page (no tabs)
//   • Gradient-border banner, overlapping avatar, name + verified, tagline
//   • Inline meta: Founded · Location · Members
//   • Card-stacked sections: About, Upcoming Events, Members, Posts & Videos
//
// New affordances:
//   • Create Event button (president + executive) → inline modal with
//     Flux AI poster generation step
//   • Invite Member button (president only) → user search + multi-select
//   • Posts & Videos section reads from getClubFeed posts payload
//
// Original light palette preserved (_kBg / _kIndigo / _kDeep / gradient _kG1-_kG4).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../profile/user_screen_profile.dart';
import '../profile/createpostspage.dart';

// ─────────────────────────────────────────────────────────────
// PALETTE — keep original light theme
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
const _kVerified = Color(0xFF1DA1F2);

const _kPresident = Color(0xFFFFB300);
const _kExecutive = Color(0xFF8E54E9);
const _kMember    = Color(0xFF64687A);

const _kCategoryLabels = <String, String>{
  'academic':       'Academic',
  'sports':         'Sports',
  'arts':           'Arts',
  'cultural':       'Cultural',
  'technology':     'Technology',
  'social_service': 'Social Service',
  'business':       'Business',
  'gaming':         'Gaming',
  'other':          'Other',
};

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────

class ClubScreen extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? club;

  const ClubScreen({super.key, this.id, this.club})
      : assert(id != null || club != null, 'Provide either id or club');

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();

  late Map<String, dynamic> _club;

  List<Map<String, dynamic>> _activeMembers  = [];
  List<Map<String, dynamic>> _pendingMembers = [];
  List<Map<String, dynamic>> _feedEvents     = [];
  List<Map<String, dynamic>> _feedPosts      = [];

  bool _busy           = false;
  bool _loadingMembers = true;
  bool _loadingFeed    = false;

  @override
  void initState() {
    super.initState();
    _club = Map<String, dynamic>.from(widget.club ?? {'id': widget.id});
    _refreshClub();
    _loadMembers();
    _loadFeed();
  }

  // ── Derived ───────────────────────────────────────────────

  String  get _clubId       => _club['id']?.toString() ?? widget.id ?? '';
  String  get _name         => _club['name']         as String? ?? 'Club';
  String  get _tagline      => _club['tagline']      as String? ?? '';
  String  get _description  => _club['description']  as String? ?? '';
  String  get _mission      => _club['mission']      as String? ?? '';
  String  get _rules        => _club['rules']        as String? ?? '';
  String  get _location     => _club['location']     as String? ?? '';
  String  get _category     => _club['category']     as String? ?? 'other';
  String? get _logoUrl      => _club['logo_url']     as String?;
  String? get _coverUrl     => _club['cover_url']    as String?;
  bool    get _isPublic     => _club['is_public']    as bool? ?? true;
  String  get _categoryLabel =>
      _kCategoryLabels[_category] ?? 'Other';
  bool    get _isVerified   => _club['is_verified']  as bool? ?? false;
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

  bool get _canCreateEvent =>
      _myRole == 'president' || _myRole == 'executive';
  bool get _canInvite => _myRole == 'president';

  String get _foundedYear {
    final iso = _club['created_at'] as String? ?? '';
    if (iso.isEmpty) return '';
    try { return 'Est. ${DateTime.parse(iso).year}'; }
    catch (_) { return ''; }
  }

  // ── Data loading ──────────────────────────────────────────

  Future<void> _refreshClub() async {
    if (_clubId.isEmpty) return;
    try {
      final data = await _api.getClub(_clubId);
      if (!mounted || data is! Map) return;
      setState(() => _club = {..._club, ...data.cast<String, dynamic>()});
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    if (_clubId.isEmpty) {
      setState(() => _loadingMembers = false);
      return;
    }
    setState(() => _loadingMembers = true);
    try {
      final activeRaw = await _api.getClubMembers(_clubId, status: 'active');
      final active = (activeRaw is List)
          ? activeRaw.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

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

  Future<void> _loadFeed() async {
    if (_clubId.isEmpty) return;
    setState(() => _loadingFeed = true);
    try {
      final res = await _api.getClubFeed(_clubId) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _feedEvents = (res['events'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _feedPosts  = (res['posts'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loadingFeed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFeed = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshClub(), _loadMembers(), _loadFeed()]);
  }

  // ── Membership ────────────────────────────────────────────

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
        _snack('Welcome to $_name 🎉');
        await _refreshAll();
      } else if (_isPending) {
        _snack('Request sent. The admins will review it shortly.');
      }
    } catch (_) {
      _snack('Could not join. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final ok = await _confirm(
      title: 'Leave $_name?',
      message: 'You can re-join anytime as long as the club is public.',
      ok: 'Leave',
      okColor: _kG4,
    );
    if (ok != true) return;
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

  Future<void> _pickLogo() async {
    if (!_isAdmin) return;
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    try {
      await _api.uploadClubLogo(_clubId, filePath: file.path);
      _snack('Logo updated!');
      await _refreshClub();
    } catch (_) {
      _snack('Failed to update logo', error: true);
    }
  }

  Future<void> _pickCover() async {
    if (!_isAdmin) return;
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (file == null) return;
    try {
      await _api.uploadClubCover(_clubId, filePath: file.path);
      _snack('Cover updated!');
      await _refreshClub();
    } catch (_) {
      _snack('Failed to update cover', error: true);
    }
  }

  // ── Event RSVP ────────────────────────────────────────────

  Future<void> _rsvp(Map<String, dynamic> event) async {
    final id = event['id']?.toString() ?? '';
    if (id.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await _api.setRsvp(id, 'going');
      _snack('RSVP confirmed ✓');
    } catch (_) {
      _snack('Could not RSVP. Try again.', error: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String ok,
    required Color okColor,
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
          style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
      backgroundColor: error ? Colors.red.shade600 : Colors.grey.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'president':      return 'President';
      case 'vice_president': return 'Vice President';
      case 'executive':      return 'Executive';
      case 'member':         return 'Member';
      default: return role.isEmpty ? 'Member' : role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'president':
      case 'vice_president': return _kPresident;
      case 'executive':      return _kExecutive;
      default:               return _kMember;
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kIndigo,
        onRefresh: _refreshAll,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            if (_description.isNotEmpty || _mission.isNotEmpty)
              _buildAboutCard(),
            if (_description.isNotEmpty || _mission.isNotEmpty)
              const SizedBox(height: 16),
            _buildEventsCard(),
            const SizedBox(height: 16),
            _buildMembersCard(),
            const SizedBox(height: 16),
            _buildPostsCard(),
            const SizedBox(height: 16),
            _buildActionRow(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header card (gradient-border banner) ──────────────────

  Widget _buildHeaderCard() {
    final topPad = MediaQuery.of(context).padding.top;
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'C';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: 160,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kG1, _kG2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _coverUrl != null && _coverUrl!.isNotEmpty
                      ? Stack(fit: StackFit.expand, children: [
                          CachedNetworkImage(
                            imageUrl: _coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.grey.shade100),
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey.shade100),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.28),
                                ],
                              ),
                            ),
                          ),
                        ])
                      : Container(color: Colors.white),
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: _kInk),
                  ),
                ),
              ),
              if (_isAdmin)
                Positioned(
                  top: 12, right: 12,
                  child: GestureDetector(
                    onTap: _pickCover,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Edit Cover',
                              style: TextStyle(
                                fontFamily: 'Arch',
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0, right: 0, bottom: -54,
                child: Center(child: _buildLogo(initial)),
              ),
            ],
          ),
          const SizedBox(height: 70),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(_name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 24, color: _kInk,
                      fontWeight: FontWeight.w800,
                    )),
              ),
              if (_isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded,
                    color: _kVerified, size: 20),
              ],
            ],
          ),
          if (_tagline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_tagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Momo', fontSize: 13.5,
                    color: _kSlate, height: 1.4,
                  )),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6, runSpacing: 6,
            children: [
              _chip(
                icon: Icons.category_rounded,
                label: _categoryLabel,
                color: _kG2,
              ),
              _chip(
                icon: _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                label: _isPublic ? 'Public' : 'Private',
                color: _isPublic ? _kIndigo : _kSlate,
              ),
              if (_requiresApproval)
                _chip(
                  icon: Icons.shield_rounded,
                  label: 'Approval required',
                  color: _kG3,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _metaItem(Icons.calendar_today_rounded,
                  _foundedYear.isEmpty ? '—' : _foundedYear),
              _metaItem(Icons.place_outlined,
                  _location.isEmpty ? '—' : _location),
              _metaItem(Icons.people_alt_outlined,
                  '$_memberCount Members'),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildLogo(String initial) {
    return GestureDetector(
      onTap: _isAdmin ? _pickLogo : null,
      child: Container(
        width: 108, height: 108,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16, offset: const Offset(0, 6),
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
    );
  }

  Widget _logoFallback(String initial) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kG2, _kG1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(initial,
              style: const TextStyle(
                  fontFamily: 'Alfa', fontSize: 32, color: Colors.white)),
        ),
      );

  Widget _metaItem(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _kSlate),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Momo', fontSize: 12.5,
                  color: _kSlate, fontWeight: FontWeight.w600,
                )),
          ),
        ],
      );

  Widget _chip({
    required IconData icon,
    required String   label,
    required Color    color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontSize: 10.5,
                  color: color,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
      );

  // ── About card ────────────────────────────────────────────

  Widget _buildAboutCard() {
    final body = _description.isNotEmpty ? _description : _mission;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _showAboutSheet,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('About',
                        style: TextStyle(
                          fontFamily: 'Alfa', fontSize: 17, color: _kInk,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 6),
                    Text(body,
                        maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Momo', fontSize: 13,
                          color: _kSlate, height: 1.5,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded,
                  color: _kSlate, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('About',
                  style: TextStyle(
                    fontFamily: 'Alfa', fontSize: 22, color: _kInk,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 12),
              if (_description.isNotEmpty)
                Text(_description,
                    style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 14,
                      color: _kInk, height: 1.6,
                    )),
              if (_mission.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Mission',
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 17, color: _kInk)),
                const SizedBox(height: 8),
                Text(_mission,
                    style: const TextStyle(
                        fontFamily: 'Momo', fontSize: 14,
                        color: _kInk, height: 1.6)),
              ],
              if (_rules.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Rules',
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 17, color: _kInk)),
                const SizedBox(height: 8),
                Text(_rules,
                    style: const TextStyle(
                        fontFamily: 'Momo', fontSize: 14,
                        color: _kInk, height: 1.6)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Events card ───────────────────────────────────────────

  Widget _buildEventsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              children: [
                const Expanded(
                  child: Text('Upcoming Events',
                      style: TextStyle(
                        fontFamily: 'Alfa', fontSize: 17, color: _kInk,
                        fontWeight: FontWeight.w800,
                      )),
                ),
                if (_canCreateEvent)
                  GestureDetector(
                    onTap: _openCreateEvent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kIndigo, _kDeep]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _kIndigo.withOpacity(0.25),
                            blurRadius: 8, offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Create',
                              style: TextStyle(
                                fontFamily: 'Arch', fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_loadingFeed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                    child: CircularProgressIndicator(color: _kIndigo)),
              )
            else if (_feedEvents.isEmpty)
              _smallEmpty(
                  icon: Icons.event_outlined,
                  message: _canCreateEvent
                      ? 'No upcoming events. Tap Create to add one.'
                      : 'No upcoming events yet.')
            else
              ..._feedEvents.take(3).map(_buildEventRow),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(Map<String, dynamic> e) {
    final title = e['title'] as String? ?? 'Untitled event';
    final loc   = e['location'] as String? ?? '';
    final start = e['start_time'] as String? ?? '';
    final end   = e['end_time']   as String? ?? '';

    DateTime? dt;
    try { dt = DateTime.parse(start).toLocal(); } catch (_) {}

    const months = ['JAN','FEB','MAR','APR','MAY','JUN',
                    'JUL','AUG','SEP','OCT','NOV','DEC'];
    final monthLabel = dt != null ? months[dt.month - 1] : '—';
    final dayLabel   = dt != null ? '${dt.day}' : '—';

    String timeLabel() {
      if (dt == null) return '';
      String fmt(DateTime t) {
        final h = (t.hour % 12 == 0) ? 12 : t.hour % 12;
        final m = t.minute.toString().padLeft(2, '0');
        final p = t.hour < 12 ? 'AM' : 'PM';
        return '$h:$m $p';
      }
      DateTime? ed;
      try { ed = DateTime.parse(end).toLocal(); } catch (_) {}
      if (ed != null) return '${fmt(dt)} – ${fmt(ed)}';
      return fmt(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _kIndigo.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(monthLabel,
                    style: const TextStyle(
                      fontFamily: 'Arch', fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _kIndigo, letterSpacing: 1,
                    )),
                const SizedBox(height: 2),
                Text(dayLabel,
                    style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 22,
                      color: _kInk, height: 1,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Alfa', fontSize: 15,
                      color: _kInk, fontWeight: FontWeight.w700,
                    )),
                if (timeLabel().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: _kSlate),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(timeLabel(),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Momo', fontSize: 11,
                              color: _kSlate)),
                    ),
                  ]),
                ],
                if (loc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.place_outlined,
                        size: 12, color: _kSlate),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(loc,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Momo', fontSize: 11,
                              color: _kSlate)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _rsvp(e),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kIndigo.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kIndigo),
              ),
              child: const Text('RSVP',
                  style: TextStyle(
                    fontFamily: 'Arch', fontSize: 11,
                    color: _kIndigo, fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  // ── Members card ──────────────────────────────────────────

  Widget _buildMembersCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              children: [
                const Expanded(
                  child: Text('Members',
                      style: TextStyle(
                        fontFamily: 'Alfa', fontSize: 17, color: _kInk,
                        fontWeight: FontWeight.w800,
                      )),
                ),
                if (_canInvite)
                  GestureDetector(
                    onTap: _openInviteSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kIndigo, _kDeep]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_alt_1_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Invite',
                              style: TextStyle(
                                fontFamily: 'Arch', fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (_loadingMembers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                    child: CircularProgressIndicator(color: _kIndigo)),
              )
            else if (_activeMembers.isEmpty)
              _smallEmpty(
                  icon: Icons.people_outline_rounded,
                  message: 'No members yet.')
            else
              SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _activeMembers.length.clamp(0, 12),
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) =>
                      _buildMemberChip(_activeMembers[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberChip(Map<String, dynamic> m) {
    final name    = m['name']       as String? ?? 'Member';
    final avatar  = m['avatar_url'] as String? ?? '';
    final role    = m['role']       as String? ?? 'member';
    final uid     = m['user_id']?.toString() ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color   = _roleColor(role);

    return GestureDetector(
      onTap: () {
        if (uid.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: uid, initial: m),
        ));
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_kG1, _kG2]),
                  ),
                  child: ClipOval(
                    child: avatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatar,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _avatarFallback(initial),
                            placeholder: (_, __) =>
                                _avatarFallback(initial),
                          )
                        : _avatarFallback(initial),
                  ),
                ),
                if (role == 'president')
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: _kPresident,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(name.split(' ').first,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Arch', fontSize: 11,
                  color: _kInk, fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 2),
            Text(_roleLabel(role),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Momo', fontSize: 10,
                  color: color, fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String initial) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_kG1, _kG2]),
        ),
        child: Center(
          child: Text(initial,
              style: const TextStyle(
                color: Colors.white, fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 18,
              )),
        ),
      );

  // ── Posts & Videos card ───────────────────────────────────

  Widget _buildPostsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              children: [
                const Expanded(
                  child: Text('Posts & Videos',
                      style: TextStyle(
                        fontFamily: 'Alfa', fontSize: 17, color: _kInk,
                        fontWeight: FontWeight.w800,
                      )),
                ),
                if (_isMember)
                  GestureDetector(
                    onTap: _openCreatePost,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_kIndigo, _kDeep]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _kIndigo.withOpacity(0.25),
                            blurRadius: 8, offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Add Post',
                              style: TextStyle(
                                fontFamily: 'Arch', fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            if (_loadingFeed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                    child: CircularProgressIndicator(color: _kIndigo)),
              )
            else if (_feedPosts.isEmpty)
              _smallEmpty(
                  icon: Icons.photo_library_outlined,
                  message: 'No posts or videos yet.')
            else
              ..._feedPosts.take(5).map(_buildPostCard),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> p) {
    final author = p['author_name'] as String? ?? 'Member';
    final avatar = p['author_avatar'] as String? ?? '';
    final content = p['content']    as String? ?? '';
    final media  = (p['media'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? firstMedia =
        media.isNotEmpty ? media.first : null;
    final mediaUrl = (firstMedia?['url'] as String?) ??
        (firstMedia?['thumbnail_url'] as String?) ?? '';
    final isVideo = (firstMedia?['type'] as String? ?? '')
            .toLowerCase()
            .contains('video') ||
        (firstMedia?['mime_type'] as String? ?? '')
            .toLowerCase()
            .startsWith('video');

    final initial = author.isNotEmpty ? author[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_kG1, _kG2]),
              ),
              child: ClipOval(
                child: avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _avatarFallback(initial),
                        placeholder: (_, __) =>
                            _avatarFallback(initial),
                      )
                    : _avatarFallback(initial),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(author,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Arch', fontSize: 13,
                    color: _kInk, fontWeight: FontWeight.bold,
                  )),
            ),
          ]),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(content,
                maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Momo', fontSize: 13,
                  color: _kInk, height: 1.45,
                )),
          ],
          if (mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          color: Colors.grey.shade100),
                      errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200),
                    ),
                    if (isVideo)
                      Container(
                        color: Colors.black.withOpacity(0.25),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white, size: 56),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Action row ────────────────────────────────────────────

  Widget _buildActionRow() {
    if (_isAdmin) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _kIndigo.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kIndigo.withOpacity(0.20)),
          ),
          child: const Center(
            child: Text('You manage this club',
                style: TextStyle(
                  fontFamily: 'Arch', fontSize: 13,
                  color: _kIndigo, fontWeight: FontWeight.bold,
                )),
          ),
        ),
      );
    }

    if (_isPending) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded, color: _kSlate, size: 16),
              SizedBox(width: 8),
              Text('Request sent — awaiting approval',
                  style: TextStyle(
                    fontFamily: 'Arch', fontSize: 13,
                    color: _kSlate, fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        ),
      );
    }

    if (_isMember) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: _busy ? null : _leave,
          child: Container(
            width: double.infinity, height: 50,
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
                        Icon(Icons.logout_rounded, color: _kG4, size: 16),
                        SizedBox(width: 8),
                        Text('Leave Club',
                            style: TextStyle(
                              fontFamily: 'Arch', fontSize: 14,
                              color: _kG4, fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    final label = _requiresApproval ? 'Request to Join' : 'Join Club';
    final icon = _requiresApproval ? Icons.send_rounded : Icons.add_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _busy ? null : _join,
        child: Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kIndigo, _kDeep]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kIndigo.withOpacity(0.30),
                blurRadius: 14, offset: const Offset(0, 6),
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
                            fontFamily: 'Arch', fontSize: 14,
                            color: Colors.white, fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _smallEmpty({required IconData icon, required String message}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Column(
            children: [
              Icon(icon, color: Colors.grey.shade300, size: 36),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Momo', fontSize: 12, color: _kSlate,
                  )),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════
  // CREATE EVENT SHEET — with Flux AI poster generator
  // ══════════════════════════════════════════════════════════

  Future<void> _openCreateEvent() async {
    HapticFeedback.lightImpact();
    final created = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateEventSheet(
        api: _api,
        clubId: _clubId,
        clubName: _name,
      ),
    );
    if (created == true) {
      _snack('Event created ✓');
      await _loadFeed();
    }
  }

  // ══════════════════════════════════════════════════════════
  // INVITE MEMBERS SHEET — president only
  // ══════════════════════════════════════════════════════════

  Future<void> _openInviteSheet() async {
    HapticFeedback.lightImpact();
    final sent = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _InviteMembersSheet(
        api: _api,
        clubId: _clubId,
        clubName: _name,
      ),
    );
    if (sent != null && sent > 0) {
      _snack('$sent invite${sent == 1 ? '' : 's'} sent ✓');
    }
  }
}

// ═════════════════════════════════════════════════════════════
// CREATE EVENT SHEET
// ═════════════════════════════════════════════════════════════

class _CreateEventSheet extends StatefulWidget {
  final ApiService api;
  final String clubId;
  final String clubName;
  const _CreateEventSheet({
    required this.api,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _locCtrl   = TextEditingController();
  final _promptCtrl = TextEditingController();

  DateTime? _start;
  DateTime? _end;

  String? _posterUrl;
  bool _generating = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_start ?? now.add(const Duration(hours: 1)))
        : (_end ?? (_start ?? now).add(const Duration(hours: 2)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final combined = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = combined;
        if (_end != null && _end!.isBefore(combined)) _end = null;
      } else {
        _end = combined;
      }
    });
  }

  Future<void> _generatePoster() async {
    final prompt = _promptCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Add a prompt describing your poster',
            style: TextStyle(fontFamily: 'Momo', color: Colors.white)),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _generating = true);
    try {
      // Backend assumption: POST /api/events/generate-poster/
      //   body: { prompt, title, club_id }
      //   returns: { poster_url }
      final res = await widget.api.generateEventPoster(
        prompt: prompt,
        title: title,
        clubId: widget.clubId,
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _posterUrl = res['poster_url'] as String?;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Poster generation failed: ${e.toString().replaceAll("Exception: ", "")}',
            style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _start == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Title and start time are required',
            style: TextStyle(fontFamily: 'Momo', color: Colors.white)),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.createClubEvent(
        clubId: widget.clubId,
        title: title,
        description: _descCtrl.text.trim(),
        location: _locCtrl.text.trim(),
        startTime: _start!.toUtc().toIso8601String(),
        endTime: _end?.toUtc().toIso8601String(),
        posterUrl: _posterUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not create event: ${e.toString().replaceAll("Exception: ", "")}',
            style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  String _fmt(DateTime? d) =>
      d == null ? 'Tap to pick' : DateFormat('EEE, MMM d • h:mm a').format(d);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Expanded(
                child: Text('Create Event',
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 22, color: _kInk,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _kSlate),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                _label('Title'),
                _textField(_titleCtrl, hint: 'e.g. Training Session'),
                const SizedBox(height: 14),

                _label('Description'),
                _textField(_descCtrl,
                    hint: 'What is this event about?', maxLines: 3),
                const SizedBox(height: 14),

                _label('Location'),
                _textField(_locCtrl, hint: 'e.g. Riverside Park'),
                const SizedBox(height: 14),

                _label('Starts'),
                _dateRow(_fmt(_start),
                    onTap: () => _pickDateTime(isStart: true)),
                const SizedBox(height: 14),

                _label('Ends (optional)'),
                _dateRow(_fmt(_end),
                    onTap: () => _pickDateTime(isStart: false)),
                const SizedBox(height: 22),

                // Flux AI poster card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kG2.withOpacity(0.08),
                        _kG1.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kG2.withOpacity(0.20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: _kG2, size: 18),
                        SizedBox(width: 6),
                        Text('AI Poster Generator',
                            style: TextStyle(
                              fontFamily: 'Alfa', fontSize: 15, color: _kInk,
                              fontWeight: FontWeight.w800,
                            )),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'Describe the vibe and we\'ll generate a poster with Flux.',
                        style: TextStyle(
                          fontFamily: 'Momo', fontSize: 12,
                          color: Colors.grey.shade600, height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _textField(_promptCtrl,
                          hint: 'e.g. cinematic football training at sunset, '
                              'dramatic lighting, navy and gold colors',
                          maxLines: 2),
                      const SizedBox(height: 12),
                      if (_posterUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: CachedNetworkImage(
                              imageUrl: _posterUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.shade100,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image_rounded,
                                      color: _kSlate),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      GestureDetector(
                        onTap: _generating ? null : _generatePoster,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_kG2, _kG1]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: _generating
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded,
                                          color: Colors.white, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                          _posterUrl == null
                                              ? 'Generate Poster'
                                              : 'Regenerate',
                                          style: const TextStyle(
                                            fontFamily: 'Arch', fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          )),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    width: double.infinity, height: 52,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [_kIndigo, _kDeep]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _kIndigo.withOpacity(0.30),
                          blurRadius: 14, offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Create Event',
                              style: TextStyle(
                                fontFamily: 'Arch', fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              )),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(text,
            style: const TextStyle(
              fontFamily: 'Arch', fontSize: 11, color: _kSlate,
              fontWeight: FontWeight.bold, letterSpacing: 0.8,
            )),
      );

  Widget _textField(TextEditingController c,
          {String? hint, int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(
            fontFamily: 'Momo', fontSize: 14, color: _kInk),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              fontFamily: 'Momo', fontSize: 13,
              color: Colors.grey.shade400),
          filled: true,
          fillColor: _kBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );

  Widget _dateRow(String value, {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded,
                size: 16, color: _kIndigo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontFamily: 'Momo', fontSize: 13, color: _kInk)),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kSlate),
          ]),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
// INVITE MEMBERS SHEET
// ═════════════════════════════════════════════════════════════

class _InviteMembersSheet extends StatefulWidget {
  final ApiService api;
  final String clubId;
  final String clubName;
  const _InviteMembersSheet({
    required this.api,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<_InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<_InviteMembersSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  final Set<String> _selected = {};
  bool _searching = false;
  bool _sending = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await widget.api.searchUsers(q.trim());
      if (!mounted) return;
      setState(() {
        _results = (res is List)
            ? res.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.api.inviteToClub(
          clubId: widget.clubId, userIds: _selected.toList());
      if (!mounted) return;
      Navigator.pop(context, _selected.length);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Invite failed: ${e.toString().replaceAll("Exception: ", "")}',
            style: const TextStyle(fontFamily: 'Momo', color: Colors.white)),
        backgroundColor: _kG4,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Expanded(
                child: Text('Invite Members',
                    style: TextStyle(
                      fontFamily: 'Alfa', fontSize: 22, color: _kInk,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: _kSlate),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: const TextStyle(
                  fontFamily: 'Momo', fontSize: 14, color: _kInk),
              decoration: InputDecoration(
                hintText: 'Search by name…',
                hintStyle: TextStyle(
                    fontFamily: 'Momo', fontSize: 13,
                    color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _kSlate),
                filled: true,
                fillColor: _kBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(
                    child: CircularProgressIndicator(color: _kIndigo))
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                              _searchCtrl.text.isEmpty
                                  ? 'Start typing to find people to invite.'
                                  : 'No matches.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'Momo', fontSize: 13,
                                  color: Colors.grey.shade500)),
                        ),
                      )
                    : ListView.separated(
                        controller: ctrl,
                        padding:
                            const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final u = _results[i];
                          final uid = u['user_id']?.toString() ??
                              u['id']?.toString() ?? '';
                          final name = u['name']
                              as String? ?? 'User';
                          final avatar = u['avatar_url']
                              as String? ?? '';
                          final selected = _selected.contains(uid);
                          final initial = name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?';
                          return InkWell(
                            onTap: () {
                              if (uid.isEmpty) return;
                              setState(() {
                                if (selected) {
                                  _selected.remove(uid);
                                } else {
                                  _selected.add(uid);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              child: Row(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                        colors: [_kG1, _kG2]),
                                  ),
                                  child: ClipOval(
                                    child: avatar.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: avatar,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Center(
                                              child: Text(initial,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Arch',
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  )),
                                            ),
                                          )
                                        : Center(
                                            child: Text(initial,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Arch',
                                                  fontWeight:
                                                      FontWeight.bold,
                                                )),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Arch',
                                        fontSize: 14,
                                        color: _kInk,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ),
                                Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _kIndigo
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: selected
                                            ? _kIndigo
                                            : Colors.grey.shade400,
                                        width: 1.5),
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 16)
                                      : null,
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: GestureDetector(
              onTap: (_sending || _selected.isEmpty) ? null : _send,
              child: Opacity(
                opacity: _selected.isEmpty ? 0.5 : 1.0,
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_kIndigo, _kDeep]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _selected.isEmpty
                                ? 'Select people to invite'
                                : 'Send ${_selected.length} invite${_selected.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontFamily: 'Arch', fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}