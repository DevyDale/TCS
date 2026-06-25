// lib/services/cache_store.dart
//
// TCS client-side cache — kills the "spinner every time" feeling.
//
// Strategy: stale-while-revalidate (SWR).
//   1. Screens paint INSTANTLY from the last-known value (memory, then disk).
//   2. A fresh copy is fetched in the background.
//   3. When it lands, the screen silently swaps in the new data.
// A spinner only shows on the very first load of a key, before any value
// has ever been cached. Nothing here touches api_service.dart — it WRAPS it.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

typedef Fetcher     = Future<dynamic> Function();
typedef SwrCallback = void Function(dynamic data, bool isFresh);

class _Entry {
  final dynamic value;
  final int     ts; // epoch ms when stored
  _Entry(this.value, this.ts);
}

class CacheStore {
  CacheStore._();
  static final CacheStore I = CacheStore._();

  static const _prefix = 'cache::';

  // In-memory layer — instant, survives navigation within a session.
  final Map<String, _Entry> _mem = {};

  // Coalesce concurrent fetches for the same key so we never fire the
  // same request twice at once.
  final Map<String, Future<dynamic>> _inflight = {};

  // ── Synchronous peek ──────────────────────────────────────
  // Returns the in-memory value if present (no await, no network).
  // Use to seed a widget's initial state with zero delay.
  dynamic peek(String key) => _mem[key]?.value;
  bool    has(String key)  => _mem.containsKey(key);

  // ── Stale-while-revalidate ────────────────────────────────
  // Calls [onData] up to twice:
  //   • immediately with the cached value (isFresh = false), if one exists
  //   • again with the network value (isFresh = true) once it arrives
  // If nothing is cached, [onData] is called once with the fresh value.
  // Network errors are swallowed (cached value stays); pass [onError] to react.
  void swr(
    String key, {
    required Fetcher     fetch,
    required SwrCallback onData,
    void Function(Object error)? onError,
    Duration? ttl, // if set and cached value younger than ttl, skip refresh
  }) {
    // 1. Instant paint from memory.
    final mem = _mem[key];
    if (mem != null) onData(mem.value, false);

    // 2. Background: disk fallback (if memory empty) + revalidate.
    () async {
      try {
        if (mem == null) {
          final disk = await _readDisk(key);
          if (disk != null) {
            _mem[key] = disk;
            onData(disk.value, false);
          }
        }
        final current = _mem[key];
        if (ttl != null &&
            current != null &&
            DateTime.now().millisecondsSinceEpoch - current.ts <
                ttl.inMilliseconds) {
          return; // young enough — skip network
        }
        final fresh = await _coalesce(key, fetch);
        await _store(key, fresh);
        onData(fresh, true);
      } catch (e) {
        if (onError != null) onError(e);
      }
    }();
  }

  // ── One-shot get (cached-or-fetch) ────────────────────────
  Future<dynamic> get(
    String key,
    Fetcher fetch, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final mem = _mem[key] ?? await _readDisk(key);
    if (mem != null) {
      _mem[key] = mem;
      final age = DateTime.now().millisecondsSinceEpoch - mem.ts;
      if (age < ttl.inMilliseconds) return mem.value;
    }
    final fresh = await _coalesce(key, fetch);
    await _store(key, fresh);
    return fresh;
  }

  // ── Prime (warmup) ────────────────────────────────────────
  Future<void> prime(String key, Fetcher fetch) async {
    final fresh = await _coalesce(key, fetch);
    await _store(key, fresh);
  }

  // ── Manual write / invalidate ─────────────────────────────
  Future<void> put(String key, dynamic value) => _store(key, value);

  Future<void> invalidate(String key) async {
    _mem.remove(key);
    final p = await SharedPreferences.getInstance();
    await p.remove('$_prefix$key');
  }

  Future<void> clearAll() async {
    _mem.clear();
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith(_prefix))) {
      await p.remove(k);
    }
  }

  // ── Internals ─────────────────────────────────────────────
  Future<dynamic> _coalesce(String key, Fetcher fetch) {
    final existing = _inflight[key];
    if (existing != null) return existing;
    final f = fetch();
    _inflight[key] = f;
    f.whenComplete(() => _inflight.remove(key));
    return f;
  }

  Future<void> _store(String key, dynamic value) async {
    final entry = _Entry(value, DateTime.now().millisecondsSinceEpoch);
    _mem[key] = entry;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          '$_prefix$key', jsonEncode({'ts': entry.ts, 'v': value}));
    } catch (_) {
      // Disk write best-effort; memory copy still serves the session.
    }
  }

  Future<_Entry?> _readDisk(String key) async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString('$_prefix$key');
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return _Entry(m['v'], m['ts'] as int);
    } catch (_) {
      return null;
    }
  }
}
