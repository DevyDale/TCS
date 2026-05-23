// lib/screens/chat/create_chat_bubble_screen.dart
//
// Full-page form for creating a Chat Bubble. Pushed from the chat
// list's app-bar bubble button. On Create:
//   • POST /chat/bubbles/    (members ⇒ pending RoomInvites)
//   • If a picture was picked, upload it to the new room
//   • Pop this screen, push ChatRoomScreen for the new bubble
//
// CHANGE LOG (this revision):
//   • The bubble picture the creator picks is now actually persisted.
//     Previously `_avatarFile` was picked but never sent anywhere, so a
//     new bubble always rendered the generic 👥 icon in the chat list.
//     Now, once createBubble() returns the room id, we upload the file via
//     ApiService.uploadBubbleAvatar(roomId, file). The upload is
//     best-effort: a failure won't block the bubble from being created or
//     opened. After it succeeds the room's avatar_url is returned by
//     /chat/rooms/ and the chat-list tile shows the picture
//     (see chat_list_screen _buildChatTile).
//
// Backend behaviour to keep in mind:
//   • Creator is automatically added as admin + member.
//   • Each id in member_ids gets a PENDING invite — they must accept
//     to actually join. Until they do, the bubble has only the creator.
//   • is_public=true allows discoverability via /chat/bubbles/discover/
//     and lets anyone join without an invite.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tcs_app/widgets/add_members_bottom_sheet.dart';

import '../../services/api_service.dart';
import 'chat_room_screen.dart';

const _kG1   = Color(0xFF6DD5FA);
const _kG2   = Color(0xFF8E54E9);
const _kG3   = Color(0xFFF7971E);
const _kG4   = Color(0xFFFF5858);
const _kInk  = Color(0xFF1A1A2E);


class CreateChatBubbleScreen extends StatefulWidget {
  const CreateChatBubbleScreen({super.key});

  @override
  State<CreateChatBubbleScreen> createState() => _CreateChatBubbleScreenState();
}


class _CreateChatBubbleScreenState extends State<CreateChatBubbleScreen> {
  final _api          = ApiService();
  final _nameCtrl     = TextEditingController();
  final _aboutCtrl    = TextEditingController();
  bool  _isPublic     = false;
  bool  _saving       = false;
  File? _avatarFile;

  /// Selected members (each entry: { user_id, name, avatar_url, role, ... })
  List<Map<String, dynamic>> _members = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _pickMembers() async {
    final picked = await showAddMembersSheet(
      context,
      alreadySelected: _members,
      title: 'Add Members',
    );
    if (picked != null) setState(() => _members = picked);
  }

  Future<void> _pickAvatar() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  void _removeMember(String userId) {
    HapticFeedback.selectionClick();
    setState(() => _members.removeWhere((m) => m['user_id'] == userId));
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Give your bubble a name first.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    try {
      final memberIds = _members
          .map((m) => m['user_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final res = await _api.createBubble(
        name:      name,
        about:     _aboutCtrl.text.trim(),
        isPublic:  _isPublic,
        memberIds: memberIds,
      );

      if (!mounted) return;
      // The endpoint returns the new room object.
      final room = (res is Map) ? res.cast<String, dynamic>() : null;
      if (room == null || room['id'] == null) {
        throw Exception('Bubble created but the server didn\'t return its id.');
      }
      final roomId = room['id'] as String;

      // If the creator picked a bubble picture, upload it now that the room
      // exists. Best-effort: a failed upload must not stop the bubble from
      // being created/opened. Once stored, the room's avatar_url is returned
      // by /chat/rooms/ and renders in the chat-list tile.
      if (_avatarFile != null) {
        try {
          await _api.uploadBubbleAvatar(roomId, _avatarFile!);
        } catch (_) {
          if (mounted) {
            _snack('Bubble created — but the picture didn\'t upload. '
                'You can set it again from the bubble.');
          }
        }
      }

      if (!mounted) return;
      // Replace this screen with the bubble's room — back goes to chat list.
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId:   roomId,
          roomName: room['name'] as String? ?? name,
          userName: 'You',
          roomType: 'group',
        ),
      ));
    } catch (e) {
      _snack('Couldn\'t create the bubble. ${_short(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _short(Object e) {
    final s = e.toString();
    return s.length > 100 ? '${s.substring(0, 100)}…' : s;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
      behavior: SnackBarBehavior.floating, backgroundColor: _kG2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          Expanded(child: _buildForm()),
          _buildCreateButton(),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1))),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kInk, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        const Expanded(child: Text('Create Chat Bubble',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 18, color: _kInk))),
      ]),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero avatar — tap to pick a picture for this bubble
        Center(child: GestureDetector(
          onTap: _pickAvatar,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _avatarFile == null
                    ? const LinearGradient(
                        colors: [_kG3, _kG4],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                image: _avatarFile != null
                    ? DecorationImage(
                        image: FileImage(_avatarFile!), fit: BoxFit.cover)
                    : null,
                boxShadow: [BoxShadow(color: _kG4.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: _avatarFile == null
                  ? const Icon(Icons.bubble_chart_rounded,
                      color: Colors.white, size: 38)
                  : null,
            ),
            Positioned(
              bottom: -2, right: -2,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF7F8FA), width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                      blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Icon(
                  _avatarFile == null
                      ? Icons.add_a_photo_rounded
                      : Icons.edit_rounded,
                  color: _kG2, size: 15),
              ),
            ),
          ]),
        )),
        const SizedBox(height: 8),
        const Center(child: Text(
            'Build your group',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: _kInk))),
        const SizedBox(height: 4),
        Center(child: Text(
            'Name it, describe it, invite people in.',
            style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                color: Colors.grey.shade500))),
        const SizedBox(height: 24),

        // Name
        _label('Name'),
        const SizedBox(height: 6),
        _textField(
          controller:    _nameCtrl,
          hint:          'e.g. CS101 Study Crew',
          icon:          Icons.tag_rounded,
          maxLines:      1,
          maxLength:     60,
        ),
        const SizedBox(height: 18),

        // About
        _label('About (optional)'),
        const SizedBox(height: 6),
        _textField(
          controller: _aboutCtrl,
          hint:       'What\'s this bubble for?',
          icon:       Icons.notes_rounded,
          maxLines:   3,
          maxLength:  200,
        ),
        const SizedBox(height: 18),

        // Participants (placed right after About; min 3 total: you + 2 invited)
        Row(children: [
          Expanded(child: _label(_members.isEmpty
              ? 'Add Participants (at least 2)'
              : _members.length < 2
                  ? 'Participants (${_members.length} / 2 needed)'
                  : 'Participants (${_members.length})')),
          GestureDetector(
            onTap: _pickMembers,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG1, _kG2]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(fontFamily: 'Arch',
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _buildMembersBlock(),
        const SizedBox(height: 22),

        // Privacy toggle
        _label('Privacy'),
        const SizedBox(height: 6),
        _privacyCard(),
      ]),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(
      fontFamily: 'Arch', fontWeight: FontWeight.bold,
      fontSize: 13, color: _kInk));

  Widget _textField({
    required TextEditingController controller,
    required String                hint,
    required IconData              icon,
    int                            maxLines  = 1,
    int?                           maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: controller,
        maxLines:   maxLines, maxLength: maxLength,
        style: const TextStyle(fontFamily: 'Momo', fontSize: 14, color: _kInk),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontFamily: 'Momo', color: Colors.grey.shade400),
          prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Icon(icon, color: Colors.grey.shade400, size: 18)),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
        ),
      ),
    );
  }

  Widget _privacyCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        _privacyOption(
          isPublic:    false,
          icon:        Icons.lock_outline_rounded,
          title:       'Private',
          body:        'Only people you invite can see and join this bubble.',
        ),
        const Divider(height: 1, color: Color(0xFFEFEFEF)),
        _privacyOption(
          isPublic:    true,
          icon:        Icons.public_rounded,
          title:       'Public',
          body:        'Anyone on the platform can find and join this bubble.',
        ),
      ]),
    );
  }

  Widget _privacyOption({
    required bool isPublic,
    required IconData icon,
    required String title,
    required String body,
  }) {
    final selected = _isPublic == isPublic;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () { HapticFeedback.selectionClick();
                  setState(() => _isPublic = isPublic); },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: selected ? _kG2.withOpacity(0.12) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18,
                color: selected ? _kG2 : Colors.grey.shade500),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 14, color: _kInk)),
            const SizedBox(height: 2),
            Text(body, style: TextStyle(fontFamily: 'Momo',
                fontSize: 12, color: Colors.grey.shade500, height: 1.3)),
          ])),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected
                  ? const LinearGradient(colors: [_kG1, _kG2])
                  : null,
              border: selected
                  ? null
                  : Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
        ]),
      ),
    );
  }

  Widget _buildMembersBlock() {
    if (_members.isEmpty) {
      return GestureDetector(
        onTap: _pickMembers,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.grey.shade200,
                style: BorderStyle.solid),
          ),
          child: Column(children: [
            Icon(Icons.people_alt_outlined, size: 30, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No members yet',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('Tap "Add" to find people to invite',
                style: TextStyle(fontFamily: 'Momo',
                    fontSize: 12, color: Colors.grey.shade400)),
          ]),
        ),
      );
    }
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _members.map(_memberChip).toList(),
    );
  }

  Widget _memberChip(Map<String, dynamic> u) {
    final id      = u['user_id']    as String? ?? '';
    final name    = u['name']       as String? ?? 'Unknown';
    final avatar  = u['avatar_url'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_kG1, _kG2]),
            image: avatar.isNotEmpty
                ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                : null),
          child: avatar.isEmpty ? Center(child: Text(initial,
              style: const TextStyle(fontFamily: 'Arch',
                  color: Colors.white, fontWeight: FontWeight.bold,
                  fontSize: 12))) : null,
        ),
        const SizedBox(width: 8),
        Text(name.split(' ').first, style: const TextStyle(
            fontFamily: 'Momo', fontSize: 12, color: _kInk)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _removeMember(id),
          child: Icon(Icons.close_rounded, size: 14, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  Widget _buildCreateButton() {
    final ready = _nameCtrl.text.trim().isNotEmpty && !_saving;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GestureDetector(
          onTap: ready ? _create : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: ready ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kG1, _kG2, _kG3, _kG4],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: ready
                    ? [BoxShadow(color: _kG2.withOpacity(0.4),
                        blurRadius: 16, offset: const Offset(0, 6))]
                    : [],
              ),
              child: Center(child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.4))
                  : const Text('Create Bubble',
                      style: TextStyle(fontFamily: 'Arch',
                          color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15))),
            ),
          ),
        ),
      ),
    );
  }
}