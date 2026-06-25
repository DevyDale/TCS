// lib/widgets/ai_markdown.dart
//
// Shared markdown renderer for all TCS AI screens.
// LIGHT bubble theme (dark text) + animated SweepGradient borders on
// code blocks and blockquotes.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

// Light-theme palette
Color get _kInk => AppC.text;
Color get _kSlate => AppC.sub;
Color get _kBorder => AppC.border;

class AiMarkdown extends StatefulWidget {
  final String data;
  final Color  accent;

  /// Optional list of colors for the rotating SweepGradient border around
  /// code blocks and blockquotes. Pass at least 2 colors; for a seamless
  /// loop, repeat the first color at the end —
  ///   e.g. [_kG1, _kG2, _kG3, _kG4, _kG1]   (Dale)
  ///        [start, end, start, end, start]  (Companion personas)
  /// If null, borders are a static [accent] color.
  final List<Color>? borderGradient;

  /// If true, code blocks render with header + syntax highlighting + copy.
  /// If false, falls back to flutter_markdown_plus's plain monospace styling.
  final bool richCodeBlocks;

  const AiMarkdown({
    super.key,
    required this.data,
    required this.accent,
    this.borderGradient,
    this.richCodeBlocks = true,
  });

  @override
  State<AiMarkdown> createState() => _AiMarkdownState();
}

class _AiMarkdownState extends State<AiMarkdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  List<Color> get _gradient =>
      (widget.borderGradient != null && widget.borderGradient!.length >= 2)
          ? widget.borderGradient!
          : [widget.accent, widget.accent];

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data:       widget.data,
      selectable: true,
      builders: widget.richCodeBlocks
          ? {
              'code': _CodeBlockBuilder(
                accent:   widget.accent,
                gradient: _gradient,
                shimmer:  _shimmerCtrl,
              ),
            }
          : const {},
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: _kInk,
          fontFamily: 'Momo',
          fontSize: 14,
          height: 1.5,
        ),
        strong:     TextStyle(color: _kInk, fontWeight: FontWeight.w700),
        em:         TextStyle(color: _kInk, fontStyle: FontStyle.italic),
        listBullet: TextStyle(
            color: _kInk, fontFamily: 'Momo', fontSize: 14),
        h1: TextStyle(
            color: _kInk, fontFamily: 'Alfa', fontSize: 20,
            fontWeight: FontWeight.w700),
        h2: TextStyle(
            color: _kInk, fontFamily: 'Alfa', fontSize: 18,
            fontWeight: FontWeight.w700),
        h3: TextStyle(
            color: _kInk, fontFamily: 'Alfa', fontSize: 16,
            fontWeight: FontWeight.w700),
        // Inline `code`
        code: TextStyle(
          color: widget.accent,
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: widget.accent.withOpacity(0.10),
        ),
        // Fallback (when richCodeBlocks: false)
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        // Blockquote — left bar uses the rotating gradient (see custom builder)
        blockquote: TextStyle(
          color: _kSlate,
          fontFamily: 'Momo',
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: widget.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border(
              left: BorderSide(color: widget.accent, width: 3)),
        ),
        a: TextStyle(
            color: widget.accent, decoration: TextDecoration.underline),
      ),
    );
  }
}

// ── Code block: rotating SweepGradient border + dark IDE theme inside ──────

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final Color              accent;
  final List<Color>        gradient;
  final Animation<double>  shimmer;

  _CodeBlockBuilder({
    required this.accent,
    required this.gradient,
    required this.shimmer,
  });

  @override
  Widget? visitElementAfter(md, preferredStyle) {
    final raw      = md.textContent;
    final lang     = (md.attributes['class'] ?? '')
                       .replaceFirst('language-', '').trim();
    final language = lang.isEmpty ? 'plaintext' : lang;

    // Inner content — built once, reused on every frame via AnimatedBuilder.child
    final inner = Container(
      decoration: BoxDecoration(
        color:        const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Text(
                  language,
                  style: TextStyle(
                    color:      accent.withOpacity(0.9),
                    fontFamily: 'monospace',
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _CopyButton(text: raw, accent: accent),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              raw,
              language: language,
              theme:    atomOneDarkTheme,
              padding:  EdgeInsets.zero,
              textStyle:
                  const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
        ],
      ),
    );

    // Outer gradient "border" rotates with the shimmer animation
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        final angle = shimmer.value * 2 * math.pi;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(1.5),   // border thickness
          decoration: BoxDecoration(
            gradient: SweepGradient(
              colors:     gradient,
              startAngle: angle,
              endAngle:   angle + 2 * math.pi,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        );
      },
      child: inner,
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  final Color  accent;
  const _CopyButton({required this.text, required this.accent});
  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 13, color: widget.accent),
            const SizedBox(width: 4),
            Text(_copied ? 'Copied' : 'Copy',
                style: TextStyle(color: widget.accent,
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}