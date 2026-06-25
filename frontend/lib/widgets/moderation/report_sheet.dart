// lib/widgets/moderation/report_sheet.dart
//
// Modal bottom sheet for reporting a post, comment, or user.

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/translation_service.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';

import '../../services/moderation_service.dart';

const _kG2 = Color(0xFF8E54E9);
const _kG4 = Color(0xFFFF5858);
Color get _kInk => AppC.text;

class ReportSheet extends StatefulWidget {
  final String contentType;
  final String objectId;
  final String targetLabel;

  const ReportSheet({
    super.key,
    required this.contentType,
    required this.objectId,
    required this.targetLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required String contentType,
    required String objectId,
    required String targetLabel,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        contentType: contentType,
        objectId: objectId,
        targetLabel: targetLabel,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  String? _reasonKey;
  final _descCtl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: T('Choose a reason first')),
      );
      return;
    }
    setState(() => _submitting = true);
    final ok = await ModerationService.instance.reportContent(
      contentType: widget.contentType,
      objectId: widget.objectId,
      reason: _reasonKey!,
      description: _descCtl.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Thanks — our team will review this within 24 hours.'
          : 'Could not send report. Please try again.'),
      backgroundColor: ok ? Colors.green.shade700 : _kG4,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final entries = ModerationService.reasons.entries.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: pad),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Report ${widget.targetLabel}',
                      style: TextStyle(
                          fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
                  const SizedBox(height: 6),
                  T(
                    'Why are you reporting this? Reports are confidential and '
                    'reviewed by our moderators within 24 hours.',
                    style: TextStyle(
                        fontFamily: 'Momo',
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  for (final e in entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _reasonKey == e.key
                            ? _kG2.withOpacity(0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _reasonKey == e.key ? _kG2 : Colors.grey.shade200,
                          width: _reasonKey == e.key ? 1.5 : 1,
                        ),
                      ),
                      child: RadioListTile<String>(
                        value: e.key,
                        groupValue: _reasonKey,
                        onChanged: (v) {
                          HapticFeedback.lightImpact();
                          setState(() => _reasonKey = v);
                        },
                        title: Text(e.value,
                            style: TextStyle(
                                fontFamily: 'Arch',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _kInk)),
                        activeColor: _kG2,
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtl,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: TranslationService.I.tr('Add details (optional)'),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kG2, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const T('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kG4,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const T('Submit report'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
