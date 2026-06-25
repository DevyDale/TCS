// lib/screens/settings/blocked_users_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';

import '../../services/moderation_service.dart';

const _kG2 = Color(0xFF8E54E9);
const _kG4 = Color(0xFFFF5858);
Color get _kInk => AppC.text;
const _kBg = Color(0xFFF2F4F8);

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ModerationService.instance.listBlockedUsers();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ModerationService.instance.listBlockedUsers();
    });
    await _future;
  }

  Future<void> _confirmUnblock(Map<String, dynamic> block) async {
    final blocked = (block['blocked'] is Map)
        ? block['blocked'] as Map<String, dynamic>
        : <String, dynamic>{};
    final uuid = (blocked['id'] ?? block['blocked_id'] ?? '').toString();
    final name = (blocked['name'] ??
            blocked['preferred_name'] ??
            blocked['user_id'] ??
            'this user')
        .toString();

    if (uuid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const T('Unblock?'),
        content: Text(
            'Unblocking $name lets them see your posts and message you again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const T('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kG2),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const T('Unblock')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ModerationService.instance.unblockUser(uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '$name unblocked' : 'Could not unblock. Try again.'),
      backgroundColor: ok ? Colors.green.shade700 : _kG4,
    ));
    if (ok) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        elevation: 0,
        title: const T('Blocked users',
            style: TextStyle(fontFamily: 'Alfa', fontSize: 20)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _kG2,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _kG2));
            }
            final blocks = snap.data ?? const [];
            if (blocks.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Center(
                    child: Text("You haven't blocked anyone.",
                        style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 14,
                            color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: T(
                        'Blocking someone hides their posts and stops them '
                        'from messaging you. You can unblock anytime.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 12.5,
                            color: Colors.grey.shade500,
                            height: 1.55),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: blocks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final b = blocks[i];
                final u = (b['blocked'] is Map)
                    ? b['blocked'] as Map<String, dynamic>
                    : <String, dynamic>{};
                final name = (u['name'] ??
                        u['preferred_name'] ??
                        u['user_id'] ??
                        'Unknown')
                    .toString();
                final avatar = u['avatar_url']?.toString() ?? '';
                final sub = (u['role']?.toString().replaceAll('_', ' ') ?? '');
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatar.isNotEmpty
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontFamily: 'Arch',
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(name,
                        style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _kInk)),
                    subtitle: sub.isEmpty
                        ? null
                        : Text(sub,
                            style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                    trailing: TextButton(
                      onPressed: () => _confirmUnblock(b),
                      style: TextButton.styleFrom(
                        foregroundColor: _kG2,
                        textStyle: const TextStyle(
                            fontFamily: 'Arch', fontWeight: FontWeight.bold),
                      ),
                      child: const T('Unblock'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
