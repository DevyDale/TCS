// lib/widgets/markdown_text.dart
//
// Lightweight markdown renderer for chat — no package dependency.
// Handles **bold**, *italic*/_italic_, `code`, fenced ``` blocks, # headers,
// - and 1. lists, and > quotes. Fixes the literal "****" the AI used to print.

import 'package:flutter/material.dart';

class MarkdownText extends StatelessWidget {
  final String data;
  final Color  color;
  final double fontSize;
  final String fontFamily;
  final double height;

  const MarkdownText(
    this.data, {
    super.key,
    this.color = Colors.white,
    this.fontSize = 14,
    this.fontFamily = 'Momo',
    this.height = 1.45,
  });

  TextStyle get _base => TextStyle(
      color: color, fontSize: fontSize, fontFamily: fontFamily, height: height);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _parseBlocks(data.trim()),
    );
  }

  List<Widget> _parseBlocks(String src) {
    final out   = <Widget>[];
    final lines = src.split('\n');
    final code  = <String>[];
    var inCode  = false;
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final lt   = line.trimLeft();

      if (lt.startsWith('```')) {
        if (!inCode) { inCode = true; code.clear(); }
        else { inCode = false; out.add(_codeBlock(code.join('\n'))); }
        i++; continue;
      }
      if (inCode) { code.add(line); i++; continue; }

      if (line.trim().isEmpty) { out.add(const SizedBox(height: 8)); i++; continue; }

      if (lt.startsWith('### ')) { out.add(_header(lt.substring(4), 1)); i++; continue; }
      if (lt.startsWith('## '))  { out.add(_header(lt.substring(3), 2)); i++; continue; }
      if (lt.startsWith('# '))   { out.add(_header(lt.substring(2), 3)); i++; continue; }
      if (lt.startsWith('> '))   { out.add(_quote(lt.substring(2)));     i++; continue; }

      if (lt.startsWith('- ') || lt.startsWith('* ') || lt.startsWith('• ')) {
        out.add(_bullet(lt.substring(2))); i++; continue;
      }
      final num = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(lt);
      if (num != null) { out.add(_numbered(num.group(1)!, num.group(2)!)); i++; continue; }

      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(text: TextSpan(children: _inline(line.trimRight(), _base))),
      ));
      i++;
    }
    return out;
  }

  Widget _header(String t, int level) {
    final size = level == 1 ? fontSize + 4 : level == 2 ? fontSize + 2 : fontSize + 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: RichText(text: TextSpan(children: _inline(t,
          _base.copyWith(fontSize: size, fontWeight: FontWeight.bold, fontFamily: 'Alfa')))),
    );
  }

  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4, left: 2),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 1, right: 8),
        child: Text('•', style: _base.copyWith(fontWeight: FontWeight.bold))),
      Expanded(child: RichText(text: TextSpan(children: _inline(t, _base)))),
    ]),
  );

  Widget _numbered(String n, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4, left: 2),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(right: 8),
        child: Text('$n.', style: _base.copyWith(fontWeight: FontWeight.bold))),
      Expanded(child: RichText(text: TextSpan(children: _inline(t, _base)))),
    ]),
  );

  Widget _quote(String t) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.only(left: 10),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Color(0xFF8E54E9), width: 3))),
    child: RichText(text: TextSpan(children: _inline(t,
        _base.copyWith(fontStyle: FontStyle.italic, color: color.withOpacity(.85))))),
  );

  Widget _codeBlock(String c) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.35),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(.08))),
    child: Text(c, style: TextStyle(color: color, fontSize: fontSize - 1,
        fontFamily: 'monospace', height: 1.4)),
  );

  List<InlineSpan> _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final buf   = StringBuffer();
    var i = 0;
    void flush() {
      if (buf.isNotEmpty) { spans.add(TextSpan(text: buf.toString(), style: base)); buf.clear(); }
    }
    while (i < text.length) {
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        final end = text.indexOf('**', i + 2);
        if (end != -1) {
          flush();
          spans.add(TextSpan(text: text.substring(i + 2, end),
              style: base.copyWith(fontWeight: FontWeight.bold)));
          i = end + 2; continue;
        }
      }
      if (text[i] == '*' || text[i] == '_') {
        final m = text[i];
        final end = text.indexOf(m, i + 1);
        if (end != -1 && end != i + 1) {
          flush();
          spans.add(TextSpan(text: text.substring(i + 1, end),
              style: base.copyWith(fontStyle: FontStyle.italic)));
          i = end + 1; continue;
        }
      }
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end != -1) {
          flush();
          spans.add(TextSpan(text: text.substring(i + 1, end),
              style: base.copyWith(fontFamily: 'monospace',
                  backgroundColor: Colors.white.withOpacity(.12))));
          i = end + 1; continue;
        }
      }
      buf.write(text[i]); i++;
    }
    flush();
    return spans;
  }
}
