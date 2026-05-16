// lib/screens/groups/groups_study_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_segmented_tab_control/animated_segmented_tab_control.dart';
import 'package:lottie/lottie.dart';
import 'package:tcs_app/screens/ai/ai_hub_screen.dart';
import 'package:tcs_app/screens/ai/saved_materials_screen.dart';

import '../../services/api_service.dart';
import '../chat/chat_room_screen.dart';
import 'create_group_page.dart';
import '../dashboard/group_Screen.dart';
import '../../search/study_hub_search_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);
const _indigo     = Color(0xFF3F51B5);
const _deepPurple = Color(0xFF512DA8);

class GroupsStudyHubScreen extends StatefulWidget {
  const GroupsStudyHubScreen({super.key});
  @override
  State<GroupsStudyHubScreen> createState() => _GroupsStudyHubScreenState();
}

class _GroupsStudyHubScreenState
    extends State<GroupsStudyHubScreen>
    with SingleTickerProviderStateMixin {

  final _api = ApiService();
  late final TabController _tabCtrl;

  bool _availableForStudy = false;
  String _availSubjects   = '';

  List<Map<String, dynamic>> _myGroups        = [];
  List<Map<String, dynamic>> _suggestedGroups = [];
  List<Map<String, dynamic>> _buddies         = [];
  List<Map<String, dynamic>> _activities      = [];

  bool _loadingGroups   = true;
  bool _loadingBuddies  = true;
  bool _loadingActivity = true;

  final Set<String> _deletingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() {
    return Future.wait([
      _loadGroups(),
      _loadBuddies(),
      _loadActivity(),
    ]);
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final mine = await _api.getGroups(filter: 'mine');
      final sugg = await _api.getGroups(filter: 'suggested');
      final mineList = _asList(mine);

      // Emit expiry-approaching activity for groups expiring within 3 days.
      _checkExpiringGroups(mineList);

      setState(() {
        _myGroups        = mineList;
        _suggestedGroups = _asList(sugg);
        _loadingGroups   = false;
      });
    } catch (_) {
      setState(() => _loadingGroups = false);
    }
  }

  void _checkExpiringGroups(List<Map<String, dynamic>> groups) {
    final now = DateTime.now();
    for (final g in groups) {
      final iso = g['expires_at'] as String?;
      if (iso == null || iso.isEmpty) continue;
      try {
        final exp = DateTime.parse(iso).toLocal();
        final daysLeft = exp.difference(now).inDays;
        if (daysLeft >= 0 && daysLeft <= 3) {
          _api.post('/activity/', body: {
            'event_type':  'group_expiring',
            'target_type': 'group',
            'target_id':   g['id']?.toString() ?? '',
            'target_name': g['name'] ?? '',
            'message':     'closes in ${daysLeft == 0 ? 'less than a day' : '$daysLeft day${daysLeft == 1 ? '' : 's'}'}',
          }).catchError((_) {});
        }
      } catch (_) {}
    }
  }

  Future<void> _loadBuddies() async {
    setState(() => _loadingBuddies = true);
    try {
      final data = await _api.getStudyBuddies();
      setState(() {
        _buddies        = _asList(data);
        _loadingBuddies = false;
      });
    } catch (_) {
      setState(() => _loadingBuddies = false);
    }
  }

  Future<void> _loadActivity() async {
    setState(() => _loadingActivity = true);
    try {
      final data = await _api.get('/activity/',
          query: {'limit': '50'}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _activities      = ((data['results'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        _loadingActivity = false;
      });
    } catch (_) {
      // Fallback: announcements
      try {
        final fb = await _api.getFeed(type: 'announcements')
            as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _activities      = ((fb['results'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
          _loadingActivity = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _loadingActivity = false);
      }
    }
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map) {
      return ((raw['results'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> _openMyGroup(Map<String, dynamic> group) async {
    final gid  = group['id']?.toString() ?? '';
    final name = group['name'] as String? ?? 'Group';

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupScreen(group: group)),
    );
    if (!mounted) return;

    if (result == 'dissolved') {
      setState(() => _deletingIds.add(gid));
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() {
        _myGroups.removeWhere((x) => x['id']?.toString() == gid);
        _deletingIds.remove(gid);
      });
      _loadActivity();
      _snack('"$name" dissolved');
    } else {
      _loadGroups();
    }
  }

  // ── Availability ──────────────────────────────────────────

  Future<void> _toggleAvailability() async {
    HapticFeedback.lightImpact();

    if (!_availableForStudy) {
      final subjects = await _showSubjectPicker();
      if (subjects == null) return;
      setState(() {
        _availableForStudy = true;
        _availSubjects     = subjects;
      });
      try {
        await _api.updateStudyBuddy({'available': true, 'subjects': subjects});
        _loadBuddies();
        _snack("✅ You're now available as a Study Buddy!");
      } catch (e) {
        setState(() { _availableForStudy = false; _availSubjects = ''; });
        _snack('Could not update: $e');
      }
    } else {
      setState(() { _availableForStudy = false; _availSubjects = ''; });
      try {
        await _api.updateStudyBuddy({'available': false, 'subjects': ''});
        _loadBuddies();
        _snack("You're now offline from Study Buddy");
      } catch (_) {
        setState(() => _availableForStudy = true);
      }
    }
  }

  Future<String?> _showSubjectPicker() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('What are you studying?',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tell others what subjects you can help with.',
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Math, Physics, Chemistry',
                hintStyle: TextStyle(fontFamily: 'Momo',
                    color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Momo'))),
          GestureDetector(
            onTap: () {
              final v = ctrl.text.trim();
              Navigator.pop(context, v.isEmpty ? 'General' : v);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_indigo, _deepPurple]),
                borderRadius: BorderRadius.circular(10)),
              child: const Text('Go Available',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Buddy connect ─────────────────────────────────────────

  Future<void> _connectBuddy(Map<String, dynamic> buddy) async {
    final userId   = buddy['user_id'] as String? ?? '';
    final subjects = buddy['subjects'] as String? ?? '';
    if (userId.isEmpty) return;

    try {
      final room = await _api.post('/chat/study-buddy/start/', body: {
        'user_id': userId,
        'subject': subjects,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      final subjectLabel = subjects.isEmpty ? 'General' : subjects;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId:   room['id'] as String? ?? '',
          roomName: 'Study Buddies ($subjectLabel)',
          userName: 'You',
          roomType: 'study_buddy',
        ),
      ));
    } catch (e) {
      _snack('Could not start chat: $e');
    }
  }

  // ── Study buddy request: accept / decline (from activity) ─

  Future<void> _acceptStudyBuddyRequest(Map<String, dynamic> a) async {
    final reqId    = (a['request_id'] ?? a['id'])?.toString() ?? '';
    final userId   = (a['actor_user_id'] ?? a['from_user_id'])?.toString() ?? '';
    final actor    = (a['actor_name']    ?? 'a buddy').toString();
    final subjects = (a['subject']       ?? a['subjects'] ?? 'General').toString();

    Map<String, dynamic>? room;
    try {
      // Best-effort: tell backend the request was accepted.
      if (reqId.isNotEmpty) {
        await _api.post('/chat/study-buddy/requests/$reqId/accept/')
            .catchError((_) => null);
      }
      // Open / create the room either way.
      if (userId.isNotEmpty) {
        room = await _api.post('/chat/study-buddy/start/', body: {
          'user_id': userId,
          'subject': subjects,
        }) as Map<String, dynamic>;
      }
    } catch (e) {
      _snack('Could not accept: $e');
      return;
    }

    // Drop the accepted tile locally.
    setState(() {
      _activities.removeWhere((x) =>
          (x['event_type'] == 'study_buddy_request') &&
          ((x['request_id'] ?? x['id'])?.toString() == reqId));
    });

    if (room != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId:   room!['id'] as String? ?? '',
          roomName: 'Study Buddies ($subjects)',
          userName: 'You',
          roomType: 'study_buddy',
        ),
      ));
    }
    _snack('Connected with $actor');
  }

  Future<void> _declineStudyBuddyRequest(Map<String, dynamic> a) async {
    final reqId = (a['request_id'] ?? a['id'])?.toString() ?? '';
    try {
      if (reqId.isNotEmpty) {
        await _api.post('/chat/study-buddy/requests/$reqId/decline/')
            .catchError((_) => null);
      }
    } catch (_) {}
    setState(() {
      _activities.removeWhere((x) =>
          (x['event_type'] == 'study_buddy_request') &&
          ((x['request_id'] ?? x['id'])?.toString() == reqId));
    });
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: success ? Colors.green.shade600 : _indigo,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildQuickActions(),
          _buildTabBar(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildGroupsView(),
                  _buildBuddiesView(),
                  _buildActivityView(),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_indigo, _deepPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.school_rounded,
              color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        const Text('Study Hub',
            style: TextStyle(fontFamily: 'Alfa',
                fontSize: 22, color: Color(0xFF1A1A2E))),
        const Spacer(),

        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const StudyHubSearchScreen())),
          child: _hdrBtn(Icons.search_rounded)),
        const SizedBox(width: 8),

        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AiHubScreen())),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6DD5FA), Color(0xFF8E54E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: const Color(0xFF8E54E9).withOpacity(0.3),
                  blurRadius: 8, offset: const Offset(0, 2))]),
            child: Center(
              child: Lottie.asset(
                'assets/images/robot.json',
                width: 26, height: 26,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _hdrBtn(IconData icon) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: Colors.grey.shade600, size: 20));

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_indigo, _deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: _indigo.withOpacity(0.3),
          blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QAction(
            icon: Icons.add_rounded,
            label: 'Create\nGroup',
            onTap: () async {
              HapticFeedback.mediumImpact();
              final created = await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CreateGroupPage()));
              if (created != null) _loadGroups();
            },
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          _QAction(
            icon: _availableForStudy
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            label: _availableForStudy ? 'Go\nOffline' : 'Go\nAvailable',
            onTap: _toggleAvailability,
          ),
          Container(width: 1, height: 40, color: Colors.white12),
          _QAction(
            icon: Icons.bookmark_rounded,
            label: 'Saved\nMaterials',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SavedMaterialsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedTabControl(
        controller: _tabCtrl,
        barDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.5)),
        indicatorDecoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_indigo, _deepPurple],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12)),
        tabTextColor: Colors.grey.shade500,
        selectedTabTextColor: Colors.white,
        tabs: const [
          SegmentTab(label: 'Groups'),
          SegmentTab(label: 'Study Buddies'),
          SegmentTab(label: 'Activity'),
        ],
      ),
    );
  }

  // ── Groups view ───────────────────────────────────────────

  Widget _buildGroupsView() {
    if (_loadingGroups) {
      return const Center(
          child: CircularProgressIndicator(color: _indigo));
    }

    return RefreshIndicator(
      color: _indigo,
      onRefresh: _loadGroups,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          if (_availableForStudy) _availBanner(),

          if (_myGroups.isNotEmpty) ...[
            _sectionHeader('My Groups', _myGroups.length),
            const SizedBox(height: 10),
            ..._myGroups.map((g) {
              final gid = g['id']?.toString() ?? '';
              return _DismissibleGroupTile(
                isDismissing: _deletingIds.contains(gid),
                child: _GroupCard(
                  group: g,
                  onTap: () => _openMyGroup(g),
                ),
              );
            }),
          ] else ...[
            _emptyGroups(),
          ],

          if (_suggestedGroups.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionHeader('Suggested Groups', _suggestedGroups.length),
            const SizedBox(height: 10),
            ..._suggestedGroups.map((g) => _GroupCard(
              group: g,
              onJoin: () async {
                await _api.joinGroup(g['id']?.toString() ?? '');
                _loadGroups();
                _snack('Joined ${g['name']}!');
              },
              onTap: () async {
                await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => GroupScreen(group: g)));
                _loadGroups();
              },
            )),
          ],
        ],
      ),
    );
  }

  Widget _emptyGroups() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.groups_outlined, size: 52,
            color: Colors.grey.shade300),
        const SizedBox(height: 14),
        const Text('No Groups Yet',
            style: TextStyle(fontFamily: 'Alfa',
                fontSize: 17, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('Create or join a group to get started',
            style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: Colors.grey.shade400)),
      ]),
    ),
  );

  // ── Buddies view ──────────────────────────────────────────

  Widget _buildBuddiesView() {
    if (_loadingBuddies) {
      return const Center(
          child: CircularProgressIndicator(color: _indigo));
    }

    return RefreshIndicator(
      color: _indigo,
      onRefresh: _loadBuddies,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          if (_availableForStudy) _availBanner(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Available Now',
                  style: TextStyle(fontFamily: 'Alfa',
                      fontSize: 18, color: Color(0xFF1A1A2E))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _indigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${_buddies.length} available',
                  style: const TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: _indigo,
                      fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_buddies.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 52,
                    color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text('No study buddies available right now',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 13, color: Colors.grey.shade400)),
              ]),
            ))
          else
            ..._buddies.map((b) => _BuddyCard(
              buddy: b,
              onConnect: () => _connectBuddy(b),
            )),
        ],
      ),
    );
  }

  // ── Activity view ─────────────────────────────────────────

  Widget _buildActivityView() {
    if (_loadingActivity) {
      return const Center(
          child: CircularProgressIndicator(color: _indigo));
    }

    return RefreshIndicator(
      color: _indigo,
      onRefresh: _loadActivity,
      child: _activities.isEmpty
          ? ListView(children: [
              Center(child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_none_rounded, size: 52,
                      color: Colors.grey.shade300),
                  const SizedBox(height: 14),
                  const Text('No Recent Activity',
                      style: TextStyle(fontFamily: 'Alfa',
                          fontSize: 17, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text(
                    'Group events appear here — joins, materials shared,\ndissolutions, expirations and buddy requests.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 13, color: Colors.grey.shade400)),
                ]),
              )),
            ])
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
              itemCount: _activities.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Recent Activity',
                        style: TextStyle(fontFamily: 'Alfa',
                            fontSize: 18, color: Color(0xFF1A1A2E))),
                  );
                }
                final a = _activities[i - 1];
                final type = (a['event_type']
                            ?? a['kind']
                            ?? a['post_type']
                            ?? '').toString();
                if (type == 'study_buddy_request') {
                  return _StudyBuddyRequestCard(
                    activity: a,
                    onAccept: () => _acceptStudyBuddyRequest(a),
                    onDecline: () => _declineStudyBuddyRequest(a),
                  );
                }
                return _ActivityCard(activity: a);
              },
            ),
    );
  }

  Widget _availBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green.shade400, Colors.green.shade600],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_rounded,
            color: Colors.white, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("You're Available for Study! 🟢",
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  color: Colors.white, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            _availSubjects.isNotEmpty
                ? 'Subjects: $_availSubjects'
                : 'Others can see you in Study Buddies',
            style: const TextStyle(fontFamily: 'Momo',
                color: Colors.white70, fontSize: 12)),
        ])),
    ]),
  );

  Widget _sectionHeader(String label, int count) => Row(children: [
    Text(label, style: const TextStyle(fontFamily: 'Alfa',
        fontSize: 18, color: Color(0xFF1A1A2E))),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
      child: Text('$count', style: const TextStyle(
          fontFamily: 'Momo', fontSize: 11,
          fontWeight: FontWeight.bold, color: _indigo))),
  ]);
}

// ─────────────────────────────────────────────────────────────
// GROUP CARD
// ─────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  const _GroupCard({
    required this.group,
    required this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final icon      = group['theme_icon'] as String? ?? '👥';
    final name      = group['name']        as String? ?? 'Group';
    final subject   = group['theme']       as String?
                   ?? group['category']   as String? ?? '';
    final members   = group['members_count'] as int? ?? 0;
    final isPublic  = group['is_public']   as bool? ?? true;
    final isJoined  = group['is_joined']   as bool? ?? false;
    final unread    = group['unread']      as int?  ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))]),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_indigo, _deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(icon,
                style: const TextStyle(fontSize: 26)))),
          const SizedBox(width: 14),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1A1A2E)))),
                if (!isPublic)
                  Padding(padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.lock_outline_rounded,
                        size: 14, color: Colors.grey.shade400)),
              ]),
              const SizedBox(height: 3),
              if (subject.isNotEmpty)
                Text(subject[0].toUpperCase() + subject.substring(1),
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.people_rounded, size: 12,
                    color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('$members members',
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 11, color: Colors.grey.shade400)),
              ]),
            ])),
          const SizedBox(width: 10),

          if (isJoined && unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _kG4,
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$unread',
                  style: const TextStyle(color: Colors.white,
                      fontFamily: 'Momo',
                      fontWeight: FontWeight.bold, fontSize: 11)))
          else if (isJoined)
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey.shade300)
          else
            GestureDetector(
              onTap: onJoin,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_indigo, _deepPurple],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(10)),
                child: const Text('Join',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        color: Colors.white, fontSize: 12)))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BUDDY CARD
// ─────────────────────────────────────────────────────────────

class _BuddyCard extends StatelessWidget {
  final Map<String, dynamic> buddy;
  final VoidCallback onConnect;

  const _BuddyCard({required this.buddy, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final name      = buddy['name']       as String? ?? 'Unknown';
    final role      = buddy['role']       as String? ?? '';
    final subjects  = buddy['subjects']   as String? ?? '';
    final online    = buddy['is_online']  as bool?  ?? false;
    final avatarUrl = buddy['avatar_url'] as String? ?? '';
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final colors  = [_kG4, _kG1, _kG3, _kG2, _indigo];
    final color   = colors[name.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Stack(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withOpacity(0.7), color],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    image: avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover)
                        : null),
                  child: avatarUrl.isEmpty
                      ? Center(child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              fontSize: 20)))
                      : null),
                if (online)
                  Positioned(bottom: 1, right: 1,
                    child: Container(width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2)))),
              ]),
              const SizedBox(width: 14),

              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 3),
                  Text(role, style: TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: Colors.grey.shade500)),
                ])),

              GestureDetector(
                onTap: onConnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_indigo, _deepPurple]),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Text('Connect',
                      style: TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold,
                          color: Colors.white, fontSize: 12)))),
            ]),

            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6,
                children: subjects.split(',').map((s) {
                  final t = s.trim();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withOpacity(0.2))),
                    child: Text(t, style: TextStyle(
                        fontFamily: 'Momo', fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)));
                }).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTIVITY CARD (generic events)
// ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityCard({required this.activity});

  ({IconData icon, Color color, String verb}) _styleFor(String type) {
    switch (type) {
      case 'group_joined':
        return (icon: Icons.group_add_rounded,
                color: Colors.green.shade600,
                verb:  'joined');
      case 'group_left':
      case 'group_removed':
        return (icon: Icons.person_remove_rounded,
                color: _kG3,
                verb:  'left');
      case 'material_shared':
        return (icon: Icons.upload_file_rounded,
                color: _indigo,
                verb:  'shared material in');
      case 'group_dissolved':
        return (icon: Icons.delete_forever_rounded,
                color: _kG4,
                verb:  'dissolved');
      case 'group_expiring':
        return (icon: Icons.timer_outlined,
                color: Colors.amber.shade700,
                verb:  'expiring —');
      case 'group_expired':
        return (icon: Icons.history_toggle_off_rounded,
                color: Colors.grey.shade600,
                verb:  'expired —');
      case 'dale_invoked':
        return (icon: Icons.auto_awesome_rounded,
                color: _kG2,
                verb:  'asked Dale in');
      default:
        return (icon: Icons.campaign_rounded,
                color: _indigo,
                verb:  '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final type      = (activity['event_type']
                    ?? activity['kind']
                    ?? activity['post_type']
                    ?? '').toString();
    final groupName = (activity['group_name']
                    ?? activity['target_name']
                    ?? '').toString();
    final actorName = (activity['actor_name']
                    ?? activity['author_name']
                    ?? 'You').toString();
    final body      = (activity['message']
                    ?? activity['content']
                    ?? '').toString();
    final timeAgo   = _ago(activity['created_at'] as String? ?? '');

    final s = _styleFor(type);

    final headline = groupName.isNotEmpty
        ? '$actorName ${s.verb} "$groupName"'.trim()
        : actorName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
            child: Icon(s.icon, color: s.color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 14, color: Color(0xFF1A1A2E)))),
                const SizedBox(width: 6),
                Text(timeAgo, style: TextStyle(fontFamily: 'Momo',
                    fontSize: 11, color: Colors.grey.shade400)),
              ]),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Momo',
                        fontSize: 13, color: Colors.grey.shade600,
                        height: 1.4)),
              ],
            ])),
        ]),
    );
  }

  String _ago(String iso) {
    if (iso.isEmpty) return '';
    try {
      final diff =
          DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inSeconds < 60)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}

// ─────────────────────────────────────────────────────────────
// STUDY BUDDY REQUEST CARD (accept / decline)
// ─────────────────────────────────────────────────────────────

class _StudyBuddyRequestCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _StudyBuddyRequestCard({
    required this.activity,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final name     = (activity['actor_name']  ?? 'A student').toString();
    final role     = (activity['actor_role']  ?? '').toString();
    final subject  = (activity['subject']     ?? activity['subjects'] ?? 'General').toString();
    final message  = (activity['message']     ?? '').toString();
    final avatar   = (activity['actor_avatar'] ?? '').toString();
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kG2.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_kG1, _kG2]),
              image: avatar.isNotEmpty
                  ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null),
            child: avatar.isEmpty
                ? Center(child: Text(initial,
                    style: const TextStyle(color: Colors.white,
                        fontFamily: 'Arch',
                        fontWeight: FontWeight.bold,
                        fontSize: 18)))
                : null),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$name wants to study together',
                  style: const TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 14, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(role.isEmpty ? subject : '$role  ·  $subject',
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 12, color: Colors.grey.shade500)),
            ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _kG2.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Study Buddy',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 10, fontWeight: FontWeight.bold, color: _kG2))),
        ]),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Text(message,
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.grey.shade300)),
              child: const Center(child: Text('Decline',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13, color: Color(0xFF1A1A2E)))),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: onAccept,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_indigo, _deepPurple]),
                borderRadius: BorderRadius.circular(11)),
              child: const Center(child: Text('Accept',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 13, color: Colors.white))),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QUICK ACTION
// ─────────────────────────────────────────────────────────────

class _QAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22)),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Momo',
                fontSize: 10, fontWeight: FontWeight.w600,
                color: Colors.white, height: 1.2)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DISMISSIBLE TILE WRAPPER
// ─────────────────────────────────────────────────────────────

class _DismissibleGroupTile extends StatelessWidget {
  final bool   isDismissing;
  final Widget child;

  const _DismissibleGroupTile({
    required this.isDismissing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: isDismissing ? 0.0 : 1.0,
        child: isDismissing
            ? const SizedBox(width: double.infinity, height: 0)
            : child,
      ),
    );
  }
}