// lib/services/app_warmup.dart
//
// "Keep everything ready." Right after login/splash, this fires the
// app's most-visited GET endpoints in parallel and drops them into
// CacheStore. By the time the user taps into Arcade, Feed, Profile, etc,
// the data is already cached and those screens paint instantly.
//
// Call ONCE, unawaited, as soon as the user is authenticated:
//
//   import 'package:tcs_app/services/app_warmup.dart';
//   unawaited(AppWarmup.run());   // splash after auth, or dashboard initState
//
// Individual failures are ignored — a warmup miss just means that one
// screen falls back to its normal first-load fetch.

import 'dart:async';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/cache_store.dart';

class AppWarmup {
  static bool _ran = false;

  static Future<void> run({bool force = false}) async {
    if (_ran && !force) return;
    _ran = true;

    final api = ApiService();
    final c   = CacheStore.I;

    // cache-key → fetcher. Keys MUST match what each screen passes to
    // CacheStore.swr(). Add every endpoint a screen loads on open.
    final targets = <String, Fetcher>{
      '/arcade/games/':       () => api.get('/arcade/games/'),
      '/arcade/leaderboard/': () => api.get('/arcade/leaderboard/'),
      '/arcade/stats/':       () => api.get('/arcade/stats/'),
      '/arcade/tokens/':      () => api.get('/arcade/tokens/'),
      '/ai/status/':          () => api.get('/ai/status/'),

      // ── Add the rest of your hot endpoints here ──
      // '/posts/feed/':   () => api.get('/posts/feed/'),
      // '/clubs/':        () => api.get('/clubs/'),
      // '/events/':       () => api.get('/events/'),
      // '/users/me/':     () => api.get('/users/me/'),
    };

    await Future.wait(
      targets.entries.map((e) => c.prime(e.key, e.value).catchError((_) {})),
    );
  }

  /// Call on logout so the next user never sees stale data.
  static Future<void> reset() async {
    _ran = false;
    await CacheStore.I.clearAll();
  }
}
