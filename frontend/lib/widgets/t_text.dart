// lib/widgets/t_text.dart
//
// T('English string') — a drop-in replacement for Text() that auto-translates
// into the user's selected language via TranslationService. Rebuilds in place
// when the language changes or a translation arrives. Use it anywhere a static
// UI string is shown. For strings outside a widget (snackbars, dialogs), use
// context.trs('...') or TranslationService.I.tr('...').

import 'package:flutter/material.dart';

import '../services/translation_service.dart';

class T extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool? softWrap;

  const T(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.textAlign,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationService.I,
      builder: (_, __) => Text(
        TranslationService.I.tr(data),
        style: style,
        maxLines: maxLines,
        textAlign: textAlign,
        overflow: overflow,
        softWrap: softWrap,
      ),
    );
  }
}

extension TrContext on BuildContext {
  /// Translate a bare string (snackbars, dialog text, labels passed as String).
  String trs(String s) => TranslationService.I.tr(s);
}
