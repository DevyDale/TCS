// lib/services/quiz_share.dart
//
// A shared quiz rides inside a chat message / group post as a text marker:
//   [[quiz|<id>|<title>|<count>|<difficulty>]]
// (usually preceded by a human-readable "📝 Shared a quiz: …" line).
//
// Both the DM chat room and the study-group chat detect the marker and render
// a tappable quiz card instead of plain text.

class QuizShare {
  final String id;
  final String title;
  final int count;
  final String difficulty;

  const QuizShare({
    required this.id,
    required this.title,
    required this.count,
    required this.difficulty,
  });

  static final RegExp _re =
      RegExp(r'\[\[quiz\|([^|]*)\|([^|]*)\|([^|]*)\|([^\]]*)\]\]');

  /// Returns a QuizShare if [text] contains a quiz marker, else null.
  static QuizShare? parse(String? text) {
    if (text == null || !text.contains('[[quiz|')) return null;
    final m = _re.firstMatch(text);
    if (m == null) return null;
    final id = (m.group(1) ?? '').trim();
    if (id.isEmpty) return null;
    return QuizShare(
      id: id,
      title: (m.group(2) ?? 'Quiz').trim(),
      count: int.tryParse((m.group(3) ?? '').trim()) ?? 0,
      difficulty: (m.group(4) ?? '').trim(),
    );
  }

  /// Builds the message body to send (preview line + marker).
  static String encode({
    required String id,
    required String title,
    required int count,
    required String difficulty,
  }) {
    final safe = title.replaceAll('|', '/').replaceAll(']', ')');
    return '📝 Shared a quiz: "$safe"\n[[quiz|$id|$safe|$count|$difficulty]]';
  }
}
