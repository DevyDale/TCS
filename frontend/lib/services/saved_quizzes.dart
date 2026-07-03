// lib/services/saved_quizzes.dart
//
// A student's personal shortlist of quizzes to come back to. Stored on-device
// (SharedPreferences) — a lightweight "save for future reference" that needs no
// backend. Keyed by quiz id.

import 'package:shared_preferences/shared_preferences.dart';

class SavedQuizzes {
  static const _key = 'saved_quiz_ids_v1';

  static Future<Set<String>> ids() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<bool> isSaved(String id) async => (await ids()).contains(id);

  /// Toggle a quiz's saved state. Returns the new saved value.
  static Future<bool> toggle(String id) async {
    final p = await SharedPreferences.getInstance();
    final set = (p.getStringList(_key) ?? const <String>[]).toSet();
    final nowSaved = !set.contains(id);
    nowSaved ? set.add(id) : set.remove(id);
    await p.setStringList(_key, set.toList());
    return nowSaved;
  }
}
