// lib/services/csv_export.dart
//
// Builds a CSV from rows and opens the OS share sheet so staff can email/save
// it (engagement, audit, roster exports). RFC-4180 quoting.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

String _field(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Writes [rows] (first row is usually the header) to a temp CSV file named
/// [filename] and shares it via the OS share sheet.
Future<void> exportCsv({
  required String filename,
  required List<List<String>> rows,
}) async {
  final buf = StringBuffer();
  for (final r in rows) {
    buf.writeln(r.map(_field).join(','));
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(buf.toString());
  await Share.shareXFiles([XFile(file.path)], subject: filename);
}
