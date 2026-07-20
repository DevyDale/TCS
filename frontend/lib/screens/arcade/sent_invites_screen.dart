// lib/screens/arcade/sent_invites_screen.dart
//
// Invites I've sent. Pending ones can be cancelled — cancelling
// auto-declines all recipients and refunds my escrowed wager.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';


Color get _kDarkBg => AppC.bg;
Color get _kDarkCard => AppC.card;
Color get _kDarkCard2 => AppC.card2;
const _kNeonBlue   = Color(0xFF6DD5FA);
const _kNeonPurple = Color(0xFF8E54E9);
const _kNeonOrange = Color(0xFFF7971E);
const _kNeonRed    = Color(0xFFFF5858);


class SentInvitesScreen extends StatefulWidget {
  const SentInvitesScreen({super.key});
  @override
  State<SentInvitesScreen> createState() => _SentInvitesScreenState();
}

class _SentInvitesScreenState extends State<SentInvitesScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _invites = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await _api.getMySentInvites();
      if (!mounted) return;
      setState(() {
        _invites = (res as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> invite) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kDarkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: T('Cancel challenge?',
          style: TextStyle(fontFamily: 'Alfa', color: AppC.text)),
        content: T(
          'Your wager will be refunded. Recipients will see this challenge '
          'as cancelled.',
          style: TextStyle(fontFamily: 'Momo', color: AppC.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: T('Keep', style: TextStyle(
                fontFamily: 'Momo', color: AppC.sub))),
          GestureDetector(onTap: () => Navigator.pop(context, true),
            child: Container(padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 9),
              decoration: BoxDecoration(color: _kNeonRed,
                  borderRadius: BorderRadius.circular(10)),
              child: const T('Cancel',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, color: Colors.white)))),
          const SizedBox(width: 12),
        ],
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    try {
      await _api.cancelInvite(invite['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        content: const T('Challenge cancelled · wager refunded',
            style: TextStyle(fontFamily: 'Momo'))));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _kNeonRed,
        behavior: SnackBarBehavior.floating,
        content: Text('Failed: $e',
            style: const TextStyle(fontFamily: 'Momo'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg, elevation: 0,
        title: T('Sent Challenges',
          style: TextStyle(fontFamily: 'Alfa', color: AppC.text)),
      ),
      body: RefreshIndicator(
        color: _kNeonBlue,
        onRefresh: () async => _load(),
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kNeonBlue))
          : _invites.isEmpty
            ? ListView(children: [
                const SizedBox(height: 100),
                const Center(child: T('📬', style: TextStyle(fontSize: 56))),
                const SizedBox(height: 12),
                Center(child: Text("You haven't sent any challenges yet",
                  style: TextStyle(fontFamily: 'Alfa',
                      color: AppC.sub, fontSize: 15))),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _invites.length,
                itemBuilder: (_, i) => _InviteCard(
                  invite: _invites[i],
                  onCancel: () => _cancel(_invites[i]),
                ),
              ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
class _InviteCard extends StatelessWidget {
  final Map<String, dynamic> invite;
  final VoidCallback onCancel;
  const _InviteCard({required this.invite, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final game     = invite['game_name']      as String? ?? 'Game';
    final wager    = invite['wager']          as int?    ?? 0;
    final status   = invite['status']         as String? ?? 'pending';
    final accepted = invite['accepted_count'] as int?    ?? 0;
    final pending  = invite['pending_count']  as int?    ?? 0;
    final mode     = invite['invite_mode']    as String? ?? 'first_come';
    final recipients = (invite['recipients'] as List? ?? const [])
                         .cast<Map<String, dynamic>>();

    Color statusColor() {
      switch (status) {
        case 'started':   return _kNeonBlue;
        case 'completed': return Colors.green.shade400;
        case 'expired':   return AppC.faint;
        case 'cancelled': return _kNeonRed;
        default:          return _kNeonOrange;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kDarkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor().withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(game,
              style: TextStyle(fontFamily: 'Alfa',
                  color: AppC.text, fontSize: 16))),
            Container(padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(),
                style: TextStyle(fontFamily: 'Momo',
                    letterSpacing: 1.2, fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: statusColor()))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _kNeonOrange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('🪙 $wager wager',
                style: const TextStyle(fontFamily: 'Momo',
                    fontWeight: FontWeight.bold, fontSize: 11,
                    color: _kNeonOrange))),
            const SizedBox(width: 8),
            if (mode == 'royale')
              Container(padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _kNeonPurple.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8)),
                child: const T('ROYALE',
                  style: TextStyle(fontFamily: 'Momo',
                      fontWeight: FontWeight.bold, fontSize: 9,
                      letterSpacing: 1, color: _kNeonPurple))),
            const Spacer(),
            Text('$accepted accepted · $pending pending',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 10,
                  color: AppC.text.withOpacity(0.4))),
          ]),
          const SizedBox(height: 12),
          // Recipient pills
          Wrap(spacing: 6, runSpacing: 6,
            children: recipients.map((r) {
              final user  = r['user']   as Map<String, dynamic>?;
              final tag   = user?['gamer_tag'] as String? ?? '';
              final name  = user?['display_name'] as String? ?? '?';
              final st    = r['status'] as String? ?? 'pending';
              Color pillColor() {
                switch (st) {
                  case 'accepted':       return Colors.green.shade400;
                  case 'declined':       return _kNeonRed;
                  case 'auto_declined':  return AppC.faint;
                  case 'expired':        return AppC.faint;
                  default:               return _kNeonOrange;
                }
              }
              return Container(padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pillColor().withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('@${tag.isNotEmpty ? tag : name}',
                    style: TextStyle(fontFamily: 'Arch',
                        fontWeight: FontWeight.bold, fontSize: 11,
                        color: pillColor())),
                  const SizedBox(width: 4),
                  Text('· $st',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 9,
                        color: pillColor().withOpacity(0.8))),
                ]));
            }).toList()),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            GestureDetector(onTap: onCancel,
              child: Container(height: 38,
                decoration: BoxDecoration(
                  color: _kNeonRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kNeonRed.withOpacity(0.3))),
                child: const Center(child: T(
                  '✕  Cancel & refund',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      color: _kNeonRed, fontSize: 12))))),
          ],
        ]),
    );
  }
}