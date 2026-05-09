// lib/screens/chat/chat_search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});
  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  // Track pending requests sent this session
  final Set<String> _requestSent = {};

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/chat/dm/search/', query: {'q': q}) as Map<String, dynamic>;
      setState(() {
        _results = (res['results'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    // If room exists, navigate directly
    final roomId = user['room_id'] as String?;
    if (roomId != null) {
      // Pop back and let the parent open the room
      Navigator.pop(context, {'action': 'open_room', 'room_id': roomId,
          'user_name': user['name'], 'user_id': user['user_id']});
      return;
    }
    // Start new DM
    try {
      final room = await _api.startDM(user['user_id'] as String) as Map<String, dynamic>;
      if (mounted) {
        Navigator.pop(context, {'action': 'open_room', 'room_id': room['id'],
            'user_name': user['name'], 'user_id': user['user_id']});
      }
    } catch (_) {}
  }

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    final uid = user['user_id'] as String? ?? '';
    setState(() => _requestSent.add(uid));
    try {
      await _api.post('/chat/requests/send/', body: {
        'user_id': uid,
        'message': 'Hi! I\'d like to chat with you on TCS 👋',
      });
    } catch (_) { setState(() => _requestSent.remove(uid)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        // Top bar
        Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 8, right: 16, bottom: 12),
          color: Colors.white,
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_rounded, size: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _ctrl, autofocus: true,
                  enableSuggestions: false, onChanged: _onChanged,
                  style: const TextStyle(fontFamily: 'Momo', fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search people to chat with...',
                    hintStyle: TextStyle(fontFamily: 'Momo', color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          ]),
        ),

        // Results
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _kG2)))
        else if (_results.isEmpty && _ctrl.text.isNotEmpty)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No people found', style: TextStyle(fontFamily: 'Alfa',
                fontSize: 16, color: Colors.grey.shade400)),
          ])))
        else if (_results.isEmpty)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search_rounded, size: 52, color: _kG2.withOpacity(0.25)),
            const SizedBox(height: 14),
            Text('Find someone to chat with', style: TextStyle(fontFamily: 'Alfa',
                fontSize: 16, color: _kG2.withOpacity(0.4))),
            const SizedBox(height: 6),
            Text('Type a name or student ID', style: TextStyle(fontFamily: 'Momo',
                fontSize: 13, color: Colors.grey.shade400)),
          ])))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final u           = _results[i];
                final isConnected = u['is_connected'] as bool? ?? false;
                final hasRoom     = u['room_id'] != null;
                final uid         = u['user_id'] as String? ?? '';
                final sent        = _requestSent.contains(uid);
                final name        = u['name'] as String? ?? 'Unknown';
                final role        = u['role'] as String? ?? '';
                final avatarUrl   = u['avatar_url'] as String? ?? '';
                final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    // Avatar
                    Stack(children: [
                      Container(width: 48, height: 48,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [_kG1, _kG2]),
                          image: avatarUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: avatarUrl.isEmpty
                            ? Center(child: Text(initial, style: const TextStyle(
                                color: Colors.white, fontFamily: 'Arch',
                                fontWeight: FontWeight.bold, fontSize: 20)))
                            : null,
                      ),
                      if (u['is_online'] == true)
                        Positioned(bottom: 0, right: 0,
                          child: Container(width: 13, height: 13,
                            decoration: BoxDecoration(color: Colors.green.shade500,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2))),
                        ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(fontFamily: 'Arch',
                          fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 2),
                      Text(role, style: TextStyle(fontFamily: 'Momo',
                          fontSize: 12, color: Colors.grey.shade500)),
                      if (!isConnected && !hasRoom)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('Not in your network', style: TextStyle(fontFamily: 'Momo',
                              fontSize: 10, color: _kG3.withOpacity(0.8))),
                        ),
                    ])),
                    const SizedBox(width: 8),
                    // Action button
                    if (hasRoom || isConnected)
                      GestureDetector(
                        onTap: () => _openChat(u),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_kG1, _kG2]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Chat', style: TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: sent ? null : () => _sendRequest(u),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: sent ? Colors.green.shade50 : _kG3.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sent ? Colors.green.shade300 : _kG3.withOpacity(0.4)),
                          ),
                          child: Text(sent ? 'Sent ✓' : 'Request Chat',
                              style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: sent ? Colors.green.shade700 : _kG3)),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}