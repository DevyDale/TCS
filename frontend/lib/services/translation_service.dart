// lib/services/translation_service.dart
//
// Auto-localization engine. Any string wrapped in T('...') (or passed to
// TranslationService.I.tr('...')) is shown in the user's selected language.
//
// How it works:
//   • English source text IS the key — no manual key files.
//   • A cache hit returns instantly (memory → disk). English is shown
//     untranslated while a translation is fetched.
//   • Missing strings are batched (debounced) and sent to /ai/translate/,
//     which translates via the AI router and caches server-side too.
//   • New translations notify listeners so T() widgets rebuild in place.
//
// English ('en') is a no-op — strings pass straight through.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class TranslationService extends ChangeNotifier {
  TranslationService._();
  static final TranslationService I = TranslationService._();

  final _api = ApiService();

  String _lang = 'en';
  String get lang => _lang;

  // "<lang>::<english>" -> translated
  final Map<String, String> _cache = {};
  final Set<String> _pending  = {};   // english strings awaiting a batch
  final Set<String> _inflight = {};    // "<lang>::<english>" currently fetching
  Timer? _debounce;

  String _ckey(String lang, String text) => '$lang::$text';
  String _diskKey(String lang) => 'tr_cache_$lang';

  /// Call once at startup (after SharedPreferences is available).
  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _lang = p.getString('language') ?? 'en';
    await _loadDisk(p, _lang);
  }

  /// Switch language (called when the user picks one in Settings).
  Future<void> setLanguage(String lang) async {
    if (lang == _lang) return;
    _lang = lang;
    _pending.clear();
    _inflight.clear();
    final p = await SharedPreferences.getInstance();
    await _loadDisk(p, lang);
    notifyListeners(); // repaint everything in the new language (from cache)
  }

  /// The translation for [english] in the current language, or [english]
  /// itself if not yet translated (it gets queued).
  String tr(String english) {
    if (_lang == 'en' || english.trim().isEmpty) return english;
    final key = _ckey(_lang, english);
    final hit = _cache[key];
    if (hit != null) return hit;
    if (!_inflight.contains(key)) {
      _pending.add(english);
      _schedule();
    }
    return english;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), _flush);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final lang  = _lang;
    final batch = _pending.take(80).toList();
    _pending.removeAll(batch);
    for (final t in batch) {
      _inflight.add(_ckey(lang, t));
    }
    try {
      final res = await _api.post('/ai/translate/',
          body: {'texts': batch, 'target': lang});
      final map = ((res is Map ? res['translations'] : null) as Map?)
          ?.cast<String, dynamic>() ?? {};
      if (lang == _lang && map.isNotEmpty) {
        map.forEach((en, tr) => _cache[_ckey(lang, en)] = tr.toString());
        await _saveDisk(lang);
        notifyListeners();
      }
    } catch (_) {
      // leave English; will retry next time the string is requested
    } finally {
      for (final t in batch) {
        _inflight.remove(_ckey(lang, t));
      }
      if (_pending.isNotEmpty) _schedule();
    }
  }

  // ── Persistence (one JSON blob per language) ──────────────
  Future<void> _loadDisk(SharedPreferences p, String lang) async {
    if (lang == 'en') return;
    try {
      final raw = p.getString(_diskKey(lang));
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m.forEach((en, tr) => _cache[_ckey(lang, en)] = tr.toString());
    } catch (_) {/* corrupt cache — ignore */}
  }

  Future<void> _saveDisk(String lang) async {
    try {
      final p = await SharedPreferences.getInstance();
      final prefix = '$lang::';
      final m = <String, String>{};
      _cache.forEach((k, v) {
        if (k.startsWith(prefix)) m[k.substring(prefix.length)] = v;
      });
      await p.setString(_diskKey(lang), jsonEncode(m));
    } catch (_) {/* best-effort */}
  }
}
