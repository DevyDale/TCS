// lib/screens/staff/staff_suggestions_screen.dart
//
// Staff-only page to read student suggestions made "To the School".
// These are never anonymous — each card shows who sent it.
// Data: GET /api/feedback/school/.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:tcs_app/services/api_service.dart';

const _kIndigo = Color(0xFF4F46E5);
const _kPurple = Color(0xFF8E54E9);

class StaffSuggestionsScreen extends StatefulWidget {
  const StaffSuggestionsScreen({super.key});

  @override
  State<StaffSuggestionsScreen> createState() => _StaffSuggestionsScreenState();
}

class _StaffSuggestionsScreenState extends State<StaffSuggestionsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/feedback/school/') as List;
      if (!mounted) return;
      setState(() {
        _items = data.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('403')
            ? 'This page is for staff only.'
            : 'Could not load suggestions. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            color: _kPurple,
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kPurple))
                : _error != null
                    ? _scrollMessage(_error!)
                    : _items.isEmpty
                        ? _scrollMessage('No school suggestions yet.\n'
                            'When a student sends one, it lands here.')
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => _card(_items[i]),
                          ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 8, right: 16, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kIndigo, _kPurple],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop()),
        const Text('🏫', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const T('Student Suggestions',
              style: TextStyle(fontFamily: 'Alfa',
                  fontSize: 19, color: Colors.white)),
          T('${_items.length} to the school · not anonymous',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 11.5, color: Colors.white.withOpacity(0.85))),
        ])),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final name    = s['student_name'] as String? ?? 'Student';
    final title   = s['title'] as String? ?? '';
    final message = s['message'] as String? ?? '';
    final avatar  = s['avatar_url'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final when    = _ago(s['created_at'] as String? ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppC.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kIndigo, _kPurple]),
              shape: BoxShape.circle,
              image: avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null),
            child: avatar.isEmpty
                ? Center(child: Text(initial,
                    style: const TextStyle(color: Colors.white,
                        fontFamily: 'Arch', fontWeight: FontWeight.bold)))
                : null),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, fontSize: 13.5,
                    color: AppC.text)),
            Text(when, style: TextStyle(fontFamily: 'Momo',
                fontSize: 10.5, color: AppC.faint)),
          ])),
        ]),
        const SizedBox(height: 12),
        if (title.isNotEmpty)
          Text(title, style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 14.5, color: AppC.text)),
        if (title.isNotEmpty) const SizedBox(height: 5),
        Text(message, style: TextStyle(fontFamily: 'Momo',
            fontSize: 13, height: 1.5, color: AppC.sub)),
      ]),
    );
  }

  Widget _scrollMessage(String text) => ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.18),
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              Icon(Icons.forum_outlined, size: 52, color: AppC.border),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Momo',
                      fontSize: 13.5, color: AppC.sub, height: 1.5)),
            ]),
          )),
        ],
      );

  String _ago(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}
