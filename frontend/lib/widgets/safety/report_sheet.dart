// lib/widgets/safety/report_sheet.dart
//
// A reusable "Report" bottom sheet for posts, users, and comments.
// Wired to POST /api/safety/report/ via ApiService.reportContent().
//
// Usage:
//   await ReportSheet.show(
//     context,
//     targetType: 'post',          // 'post' | 'user' | 'comment'
//     targetId:   post['id'],
//     subtitle:   'this post',     // shown in the header, optional
//   );
//
// Returns true if a report was submitted, false/null otherwise.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const Color _kG1  = Color(0xFF6DD5FA);
const Color _kG2  = Color(0xFF8E54E9);
const Color _kInk = Color(0xFF1A1A2E);

class _Reason {
  final String key;
  final String label;
  const _Reason(this.key, this.label);
}

const List<_Reason> _reasons = [
  _Reason('harassment', 'Harassment or bullying'),
  _Reason('hate_speech',       'Hate speech'),
  _Reason('violence',   'Violence or threats'),
  _Reason('sexual',     'Sexual or explicit content'),
  _Reason('spam',       'Spam or scam'),
  _Reason('self_harm',  'Self-harm'),
  _Reason('other',      'Something else'),
];

class ReportSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String? subtitle;

  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.subtitle,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    String? subtitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        targetType: targetType,
        targetId: targetId,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _api    = ApiService();
  final _detail = TextEditingController();
  String? _selected;
  bool _submitting = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();
    try {
      await _api.reportContent(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selected!,
        detail: _detail.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks — our team will review this shortly.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit report. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Report ${widget.subtitle ?? 'content'}',
              style: const TextStyle(
                fontFamily: 'Arch',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Why are you reporting this?',
              style: TextStyle(
                fontFamily: 'Momo',
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 14),
            ..._reasons.map((r) {
              final sel = _selected == r.key;
              return GestureDetector(
                onTap: () => setState(() => _selected = r.key),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: sel ? _kG2.withOpacity(0.08) : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? _kG2 : Colors.grey.shade200,
                      width: sel ? 1.6 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontFamily: 'Momo',
                            fontSize: 14,
                            color: _kInk,
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (sel)
                        const Icon(Icons.check_circle_rounded,
                            color: _kG2, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            TextField(
              controller: _detail,
              maxLines: 2,
              maxLength: 300,
              style: const TextStyle(fontFamily: 'Momo', fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Add any details (optional)',
                hintStyle: TextStyle(
                    fontFamily: 'Momo', color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: (_selected != null && !_submitting) ? _submit : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_selected != null && !_submitting) ? 1 : 0.4,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kG1, _kG2]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.4),
                        )
                      : const Text(
                          'Submit report',
                          style: TextStyle(
                            fontFamily: 'Arch',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
