// lib/services/session_keys.dart
//
// Single source of truth for every SharedPreferences key used by the
// auth/session layer. NEVER read or write these keys with a string
// literal anywhere else — always go through SessionKeys.x.
//
// If you ever rename one of these strings in the future, this is the
// only place you need to change it. Every other file imports from here.

class SessionKeys {
  // ── Tokens ────────────────────────────────────────────────
  static const accessToken  = 'access_token';
  static const refreshToken = 'refresh_token';

  // ── Cached user identity ──────────────────────────────────
  // Stored at login so the dashboard can render before /me/ returns.
  static const userJson      = 'sh_current_user';
  static const userId        = 'userId';
  static const fullName      = 'fullName';
  static const preferredName = 'preferredName';
  static const role          = 'role';

  // Convenience: every session key. Used by clearTokens() so we
  // never forget to wipe a key when logging out.
  static const all = <String>[
    accessToken,
    refreshToken,
    userJson,
    userId,
    fullName,
    preferredName,
    role,
  ];

  const SessionKeys._();
}
