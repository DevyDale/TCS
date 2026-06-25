// lib/screens/arcade/transfer_tokens_screen.dart
//
// Peer-to-peer token transfer.
//   • Search a recipient by gamer tag / name
//   • Pick or type an amount (server enforces caps:
//       MAX_TRANSFER_PER_TX = 200, MAX_DAILY_TRANSFER_OUT = 500)
//   • Optional 140-char note
//   • Confirm dialog before sending
//   • Live wallet balance + recent transfer history below

import 'dart:async';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';


const _kDarkBg     = Color(0xFF0D0D1A);
const _kDarkCard   = Color(0xFF161628);
const _kDarkCard2  = Color(0xFF1E1E38);
const _kNeonBlue   = Color(0xFF6DD5FA);
const _kNeonPurple = Color(0xFF8E54E9);
const _kNeonOrange = Color(0xFFF7971E);
const _kNeonRed    = Color(0xFFFF5858);
const _kTokenColor = Color(0xFFFFD700);

const _kQuickAmounts = [10, 25, 50, 100, 200];
const _kMaxPerTx     = 200;
const _kNoteMaxLen   = 140;


class TransferTokensScreen extends StatefulWidget {
  const TransferTokensScreen({super.key});
  @override
  State<TransferTokensScreen> createState() => _TransferTokensScreenState();
}

class _TransferTokensScreenState extends State<TransferTokensScreen> {
  final _api      = ApiService();
  final _search   = TextEditingController();
  final _amount   = TextEditingController();
  final _note     = TextEditingController();
  Timer? _debounce;

  int _myTokens = 0;
  bool _loadingHistory = true;
  bool _sending  = false;
  bool _searching= false;

  Map<String, dynamic>? _selectedRecipient;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _history       = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final wallet = await _api.getTokenWallet() as Map?;
      _myTokens = (wallet?['tokens'] as int?) ?? 0;
    } catch (_) {/* keep 0 */}
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _loadingHistory = true);
    try {
      final res = await _api.getTransferHistory();
      if (!mounted) return;
      setState(() {
        _history = (res as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _loadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _onSearchChange(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _api.searchGamers(query: q.trim()) as Map?;
      if (!mounted) return;
      setState(() {
        _searchResults = (res?['results'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(Map<String, dynamic> u) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedRecipient = u;
      _searchResults = [];
      _search.text = '@${u['gamer_tag'] ?? u['display_name']}';
    });
  }

  void _clearRecipient() {
    setState(() {
      _selectedRecipient = null;
      _search.clear();
    });
  }

  int? _parseAmount() {
    final raw = _amount.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _confirmAndSend() async {
    if (_selectedRecipient == null) {
      _snack('Pick a recipient'); return;
    }
    final amt = _parseAmount();
    if (amt == null || amt <= 0) {
      _snack('Enter a valid amount'); return;
    }
    if (amt > _kMaxPerTx) {
      _snack('Max $_kMaxPerTx 🪙 per transfer'); return;
    }
    if (amt > _myTokens) {
      _snack('You only have $_myTokens 🪙'); return;
    }

    final tag = _selectedRecipient!['gamer_tag'] as String? ?? '';
    final n   = _selectedRecipient!['display_name'] as String? ?? 'Player';
    final ok  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kDarkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const T('Confirm transfer',
          style: TextStyle(fontFamily: 'Alfa',
              color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Send 🪙 $amt to @${tag.isNotEmpty ? tag : n}?',
            style: const TextStyle(fontFamily: 'Momo',
                color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          T('This is final. Tokens move immediately.',
            style: TextStyle(fontFamily: 'Momo',
                color: Colors.white.withOpacity(0.4), fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const T('Cancel',
              style: TextStyle(fontFamily: 'Momo', color: Colors.white60))),
          GestureDetector(onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kNeonOrange, _kNeonRed]),
                borderRadius: BorderRadius.circular(10)),
              child: const T('Send',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 13)))),
          const SizedBox(width: 12),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _sending = true);
    try {
      final res = await _api.sendTokens(
        recipientUserId: _selectedRecipient!['user_id'] as String,
        amount:          amt,
        note:            _note.text.trim(),
      ) as Map<String, dynamic>;
      if (!mounted) return;
      _myTokens = (res['balance'] as int?) ?? _myTokens;
      _snack('Sent 🪙 $amt to @${tag.isNotEmpty ? tag : n}',
          success: true);
      setState(() {
        _selectedRecipient = null;
        _search.clear();
        _amount.clear();
        _note.clear();
        _sending = false;
      });
      await _loadHistory();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        _snack('Failed: $e');
      }
    }
  }

  void _snack(String m, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Momo')),
      backgroundColor: success ? Colors.green.shade700 : _kNeonRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: _kDarkBg, elevation: 0,
        title: const T('Send Tokens',
          style: TextStyle(fontFamily: 'Alfa', color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Wallet header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kNeonOrange, _kNeonRed]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                  color: _kNeonOrange.withOpacity(0.3),
                  blurRadius: 18, offset: const Offset(0, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T('YOUR BALANCE',
                  style: TextStyle(fontFamily: 'Momo',
                      letterSpacing: 2, fontSize: 10,
                      color: Colors.white.withOpacity(0.7))),
                const SizedBox(height: 6),
                Text('🪙 $_myTokens',
                  style: const TextStyle(fontFamily: 'Alfa',
                      fontSize: 36, color: Colors.white)),
                const SizedBox(height: 4),
                T('Daily cap: 500 · Max per send: 200',
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7))),
              ]),
          ),
          const SizedBox(height: 22),

          _stepLabel('1', 'Recipient'),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged:  _onSearchChange,
            enabled:    _selectedRecipient == null,
            style: const TextStyle(color: Colors.white,
                fontFamily: 'Momo', fontSize: 14),
            decoration: InputDecoration(
              hintText: TranslationService.I.tr('Search by gamer tag or name...'),
              hintStyle: TextStyle(fontFamily: 'Momo',
                  color: Colors.white.withOpacity(0.3)),
              filled: true, fillColor: _kDarkCard,
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searching
                ? const Padding(padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kNeonBlue)))
                : (_selectedRecipient != null
                    ? IconButton(icon: const Icon(Icons.close,
                          color: Colors.white54),
                        onPressed: _clearRecipient)
                    : null),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            ),
          ),
          if (_searchResults.isNotEmpty && _selectedRecipient == null) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: _kDarkCard,
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(8),
              child: Column(children: _searchResults.map((u) {
                final tag = u['gamer_tag']    as String? ?? '';
                final n   = u['display_name'] as String? ?? 'Player';
                final av  = u['avatar_url']   as String? ?? '';
                return GestureDetector(onTap: () => _select(u),
                  child: Container(
                    margin:  const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      CircleAvatar(radius: 16,
                        backgroundColor: _kNeonPurple.withOpacity(0.25),
                        backgroundImage: av.isNotEmpty
                            ? NetworkImage(av) : null,
                        child: av.isEmpty ? Text(
                          n.isNotEmpty ? n[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white,
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold)) : null),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment:
                          CrossAxisAlignment.start, children: [
                        Text('@${tag.isNotEmpty ? tag : n}',
                          style: const TextStyle(fontFamily: 'Arch',
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: Colors.white)),
                        Text(n, style: const TextStyle(fontFamily: 'Momo',
                            fontSize: 10, color: Colors.white38)),
                      ])),
                      const Icon(Icons.chevron_right,
                          color: Colors.white38),
                    ])));
              }).toList()),
            ),
          ],

          const SizedBox(height: 22),
          _stepLabel('2', 'Amount'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white,
                  fontFamily: 'Alfa', fontSize: 22),
              decoration: InputDecoration(
                hintText: TranslationService.I.tr('0'),
                hintStyle: TextStyle(fontFamily: 'Alfa',
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 22),
                prefixText: '🪙  ',
                prefixStyle: const TextStyle(fontSize: 18),
                filled: true, fillColor: _kDarkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              ),
            )),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _kQuickAmounts.map((amt) {
            final disabled = amt > _myTokens;
            return GestureDetector(
              onTap: disabled ? null : () {
                HapticFeedback.lightImpact();
                _amount.text = '$amt';
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kDarkCard2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07))),
                child: Text('🪙 $amt',
                  style: TextStyle(fontFamily: 'Arch',
                      fontWeight: FontWeight.bold, fontSize: 13,
                      color: disabled ? Colors.white24 : Colors.white60))));
          }).toList()),

          const SizedBox(height: 22),
          _stepLabel('3', 'Note (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: _kNoteMaxLen,
            style: const TextStyle(color: Colors.white,
                fontFamily: 'Momo', fontSize: 13),
            decoration: InputDecoration(
              hintText: TranslationService.I.tr('For pizza? 🍕'),
              hintStyle: TextStyle(fontFamily: 'Momo',
                  color: Colors.white.withOpacity(0.3), fontSize: 13),
              counterStyle: TextStyle(fontFamily: 'Momo',
                  color: Colors.white.withOpacity(0.3), fontSize: 10),
              filled: true, fillColor: _kDarkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 26),
          Opacity(opacity: _sending ? 0.6 : 1.0,
            child: GestureDetector(
              onTap: _sending ? null : _confirmAndSend,
              child: Container(height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kNeonOrange, _kNeonRed]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: _kNeonOrange.withOpacity(0.35),
                      blurRadius: 16, offset: const Offset(0, 6))]),
                child: Center(child: _sending
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const T('💸  Send Tokens',
                      style: TextStyle(fontFamily: 'Alfa',
                          fontSize: 16, color: Colors.white)))))),

          const SizedBox(height: 28),
          _sectionLabel('Recent transfers'),
          const SizedBox(height: 10),
          if (_loadingHistory)
            const Padding(padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(
                  color: _kNeonBlue)))
          else if (_history.isEmpty)
            Padding(padding: const EdgeInsets.all(20),
              child: Center(child: T('No transfers yet',
                  style: TextStyle(fontFamily: 'Momo',
                      color: Colors.white.withOpacity(0.3))))),
          ..._history.map(_historyTile),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> tx) {
    final outgoing = tx['direction'] == 'out';
    final amount   = tx['amount'] as int? ?? 0;
    final note     = tx['note'] as String? ?? '';
    final ts       = tx['created_at'] as String? ?? '';
    final other    = (outgoing ? tx['recipient'] : tx['sender'])
                        as Map<String, dynamic>?;
    final tag      = other?['gamer_tag'] as String? ?? '';
    final name     = other?['display_name'] as String? ?? 'Player';
    final av       = other?['avatar_url'] as String? ?? '';

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kDarkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(children: [
        CircleAvatar(radius: 18,
          backgroundColor: _kNeonPurple.withOpacity(0.2),
          backgroundImage: av.isNotEmpty ? NetworkImage(av) : null,
          child: av.isEmpty ? Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white,
                fontFamily: 'Arch', fontWeight: FontWeight.bold)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment:
            CrossAxisAlignment.start, children: [
          Row(children: [
            Text(outgoing ? 'Sent to ' : 'From ',
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: Colors.white.withOpacity(0.4))),
            Text('@${tag.isNotEmpty ? tag : name}',
              style: const TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold, fontSize: 13,
                  color: Colors.white)),
          ]),
          if (note.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(note, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                    color: Colors.white.withOpacity(0.5)))),
          if (ts.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(_ago(ts),
                style: TextStyle(fontFamily: 'Momo', fontSize: 9,
                    color: Colors.white.withOpacity(0.3)))),
        ])),
        Text('${outgoing ? "-" : "+"}🪙 $amount',
          style: TextStyle(fontFamily: 'Alfa', fontSize: 16,
              color: outgoing ? _kNeonRed : Colors.green.shade400)),
      ]),
    );
  }

  // ── small visual helpers ───────────────────────────────
  Widget _stepLabel(String n, String text) => Row(children: [
    Container(width: 22, height: 22,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kNeonOrange, _kNeonRed]),
        shape: BoxShape.circle),
      child: Center(child: Text(n,
        style: const TextStyle(color: Colors.white, fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 12)))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontFamily: 'Alfa',
        fontSize: 16, color: Colors.white)),
  ]);

  Widget _sectionLabel(String t) => Text(t.toUpperCase(),
    style: const TextStyle(fontFamily: 'Momo', letterSpacing: 2,
        fontSize: 11, color: Colors.white54));

  String _ago(String iso) {
    try {
      final t = DateTime.parse(iso).toLocal();
      final d = DateTime.now().difference(t);
      if (d.inDays    > 0) return '${d.inDays}d ago';
      if (d.inHours   > 0) return '${d.inHours}h ago';
      if (d.inMinutes > 0) return '${d.inMinutes}m ago';
      return 'just now';
    } catch (_) { return ''; }
  }
}