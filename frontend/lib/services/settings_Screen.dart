// lib/screens/settings/settings_screen.dart
// CHANGES:
// • Removed APPEARANCE section (dark/light theme toggle)
// • Removed Support tile from ABOUT section
// • Dark/light still applies app-wide through AppSettings (theme set elsewhere)
// • Improved dark-mode contrast (_sub is now white70 not white54)
// • Replaced Tamil with Japanese, added Korean
// • Removed Suggestion Box tile
// • About: Taylors College Sydney, v5.0, navigates to dedicated pages
// • Added About Developer & About Application tiles
// • Notification toggles now call syncFcmTopics() so FCM subscriptions
//   update the moment a switch is flipped

import 'package:flutter/material.dart';
import 'package:tcs_app/widgets/t_text.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/main.dart'; // for syncFcmTopics()
import 'package:tcs_app/screens/about_application_screen.dart';
import 'package:tcs_app/screens/about_developer_screen.dart';
import 'package:tcs_app/screens/auth/role_selection_screen.dart';
import 'package:tcs_app/screens/settings/blocked_users_screen.dart';
import 'package:tcs_app/screens/privacy_policy_screen.dart';
import 'package:tcs_app/screens/terms_of_service_screen.dart';
import 'package:tcs_app/services/auth_service.dart';
import 'package:tcs_app/services/api_service.dart';
import 'app_localisations.dart';
import 'app_settings.dart';


const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);
const _kG3 = Color(0xFFF7971E);
const _kG4 = Color(0xFFFF5858);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _s = AppSettings();

  late bool   _dark;
  late String _lang;
  late bool   _pushEnabled;
  late bool   _announcements;
  late bool   _groupActivity;
  bool _loggingOut = false;
  late bool   _showOnline;
  late bool   _discoverable;
  bool        _langExpanded = false;

  // Tamil removed → Japanese + Korean added
  final _languages = const {
    'en': ('English',           '🇬🇧'),
    'ms': ('Bahasa Malaysia',   '🇲🇾'),
    'zh': ('中文 (Chinese)',     '🇨🇳'),
    'ja': ('日本語 (Japanese)',   '🇯🇵'),
    'ko': ('한국어 (Korean)',     '🇰🇷'),
    'ar': ('العربية (Arabic)',  '🇸🇦'),
  };

  @override
  void initState() {
    super.initState();
    _dark          = _s.isDark;
    _lang          = _s.lang;
    _pushEnabled   = _s.pushEnabled;
    _announcements = _s.announcements;
    _groupActivity = _s.groupActivity;
    _showOnline    = _s.showOnline;
    _discoverable  = _s.discoverable;
  }

  // Stronger contrast values for dark mode so nothing disappears
  Color get _bg   => _dark ? const Color(0xFF0D0D1A) : const Color(0xFFF2F4F8);
  Color get _card => _dark ? const Color(0xFF161628) : Colors.white;
  Color get _text => _dark ? Colors.white            : const Color(0xFF1A1A2E);
  Color get _sub  => _dark ? Colors.white70          : Colors.grey.shade600;
  Color get _divC => _dark ? Colors.white12          : Colors.grey.shade200;

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Momo')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? _kG2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _confirmDeleteAccount() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const T('Delete account?'),
        content: const T(
          'This permanently deletes your account and all of your data — '
          'profile, posts, messages, clubs, and arcade progress. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const T('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _kG4),
            child: const T('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ApiService().deleteAccount();
    } catch (e) {
      debugPrint('Delete account error: $e');
    }
    try {
      await AuthService().clearTokens();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close loading
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const RoleSelectionScreen(),
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
  HapticFeedback.lightImpact();
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: _card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _divC,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 22),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: _kG4.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.logout_rounded, color: _kG4, size: 30),
        ),
        const SizedBox(height: 18),
        T('Log out?', style: TextStyle(fontFamily: 'Alfa',
            fontSize: 20, color: _text)),
        const SizedBox(height: 10),
        Text(
          "You'll need to sign in again to access your account, "
          "messages and notifications.",
          style: TextStyle(fontFamily: 'Momo',
              fontSize: 13.5, color: _sub, height: 1.55),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _divC)),
              child: Center(child: T('Cancel',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    color: _text, fontSize: 14))),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kG4, Color(0xFFD63B3B)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: _kG4.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Center(child: T('Log out',
                style: TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 14))),
            ),
          )),
        ]),
      ]),
    ),
  );

  if (confirmed == true) await _performLogout();
}
Future<void> _performLogout() async {
  if (_loggingOut || !mounted) return;

  FocusScope.of(context).unfocus();

  setState(() => _loggingOut = true);

  // Show loading overlay
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 28,
          ),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _kG4.withOpacity(0.15),
                      _kG4.withOpacity(0.05),
                    ],
                  ),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: _kG4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              T(
                'Logging you out',
                style: TextStyle(
                  fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _text,
                ),
              ),

              const SizedBox(height: 6),

              T(
                'Please wait a moment...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Momo',
                  fontSize: 12,
                  color: _text.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    // Disable push notifications for this device
    await _s.setPush(false);

    // Sync & unsubscribe FCM topics
    try {
      await syncFcmTopics();
    } catch (_) {}

    // Logout user + clear tokens/session
    await AuthService().logout();

  } catch (e) {
    debugPrint('Logout error: $e');
  }

  if (!mounted) return;

  // Close loading dialog safely
  Navigator.of(context, rootNavigator: true).pop();

  // Small transition delay for smoother UX
  await Future.delayed(const Duration(milliseconds: 150));

  if (!mounted) return;

  // Clear entire navigation stack
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: const RoleSelectionScreen(),
      ),
    ),
    (route) => false,
  );

  // Reset state after navigation
  if (mounted) {
    setState(() => _loggingOut = false);
  }
}
  void _showInfoSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _divC,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontFamily: 'Alfa',
              fontSize: 18, color: _text)),
          const SizedBox(height: 12),
          Text(body, style: TextStyle(fontFamily: 'Momo',
              fontSize: 14, color: _sub, height: 1.65),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: double.infinity, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kG2, _kG1]),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(AppL10n.of(context).btnGotIt,
                style: const TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, color: Colors.white))))),
        ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l   = AppL10n.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [

        // ── Header ────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _card,
          padding: EdgeInsets.only(
              top: top + 12, left: 8, right: 16, bottom: 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40, height: 40,
                decoration: BoxDecoration(color: _bg,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_rounded, size: 20, color: _text)),
            ),
            const SizedBox(width: 12),
            Text(l.settingsTitle, style: TextStyle(fontFamily: 'Alfa',
                fontSize: 22, color: _text)),
          ]),
        ),

        // ── Content ─────────────────────────────────────────
        Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _bg,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ── ACCOUNT ───────────────────────────────────────
const SizedBox(height: 20),
_section('ACCOUNT'),
_group([
  GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _loggingOut ? null : _confirmLogout,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _iconBox(
          const Icon(Icons.logout_rounded, color: _kG4, size: 20),
          _kG4.withOpacity(0.12)),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          T('Log out',
              style: TextStyle(fontFamily: 'Arch',
                  fontWeight: FontWeight.bold,
                  fontSize: 14, color: _kG4)),
          T('Sign out of this device',
              style: TextStyle(fontFamily: 'Momo',
                  fontSize: 12, color: _sub)),
        ])),
        Icon(Icons.chevron_right_rounded, color: _kG4, size: 20),
      ]),
    ),
  ),
]),

              // ── LANGUAGE ──────────────────────────────────
              _section(l.settingsLanguage),
              _group([
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact();
                    setState(() => _langExpanded = !_langExpanded); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      _iconBox(Center(child: Text(_languages[_lang]!.$2,
                          style: const TextStyle(fontSize: 20))),
                          _kG1.withOpacity(0.1)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.settingsLangLabel,
                            style: TextStyle(fontFamily: 'Arch',
                                fontWeight: FontWeight.bold,
                                fontSize: 14, color: _text)),
                        Text(_languages[_lang]!.$1,
                            style: TextStyle(fontFamily: 'Momo',
                                fontSize: 12, color: _sub)),
                      ])),
                      AnimatedRotation(
                        turns: _langExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: _sub, size: 22)),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _langExpanded ? Column(
                    children: _languages.entries.map((e) {
                      final sel = e.key == _lang;
                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          setState(() { _lang = e.key; _langExpanded = false; });
                          await _s.setLang(e.key);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          color: sel ? _kG2.withOpacity(0.06) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: Row(children: [
                            const SizedBox(width: 50),
                            Text(e.value.$2,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(e.value.$1,
                                style: TextStyle(fontFamily: 'Momo',
                                    fontSize: 14, color: _text))),
                            if (sel) Icon(Icons.check_rounded,
                                color: _kG2, size: 18),
                          ]),
                        ),
                      );
                    }).toList(),
                  ) : const SizedBox.shrink(),
                ),
              ]),

              // ── NOTIFICATIONS ─────────────────────────────
              const SizedBox(height: 20),
              _section(l.settingsNotifications),
              _group([
                _toggle(
                  icon: Icons.notifications_rounded, iconColor: _kG4,
                  title: l.settingsPush,
                  subtitle: _pushEnabled ? l.settingsPushOn : l.settingsPushOff,
                  value: _pushEnabled,
                  onChanged: (v) async {
                    HapticFeedback.lightImpact();
                    final granted = await _s.setPush(v);
                    if (!mounted) return;
                    setState(() {
                      _pushEnabled = granted;
                      if (!granted) { _announcements = false; _groupActivity = false; }
                    });
                    if (v && !granted) {
                      _snack('Enable notifications in iOS Settings',
                          color: Colors.orange.shade700);
                      return;
                    }
                    await syncFcmTopics(); // re-subscribe / unsubscribe FCM
                    _snack(granted ? '🔔 ${l.settingsPushOn}' : '🔕 ${l.settingsPushOff}',
                        color: granted ? Colors.green.shade600 : Colors.grey.shade600);
                  },
                ),
                _divLine(),
                _toggle(
                  icon: Icons.campaign_rounded, iconColor: _kG2,
                  title: l.settingsAnnouncements,
                  subtitle: l.settingsCampusAnn,
                  value: _announcements && _pushEnabled,
                  enabled: _pushEnabled,
                  onChanged: (v) async {
                    if (!_pushEnabled) { _snack(l.settingsPush); return; }
                    HapticFeedback.lightImpact();
                    setState(() => _announcements = v);
                    await _s.setAnnouncements(v);
                    await syncFcmTopics(); // toggle 'announcements' topic
                  },
                ),
                _divLine(),
                _toggle(
                  icon: Icons.group_rounded, iconColor: _kG1,
                  title: l.settingsGroupAct,
                  subtitle: l.settingsGroupSub,
                  value: _groupActivity && _pushEnabled,
                  enabled: _pushEnabled,
                  onChanged: (v) async {
                    if (!_pushEnabled) { _snack(l.settingsPush); return; }
                    HapticFeedback.lightImpact();
                    setState(() => _groupActivity = v);
                    await _s.setGroupActivity(v);
                    await syncFcmTopics(); // toggle 'group_activity' topic
                  },
                ),
              ]),

              // ── PRIVACY ───────────────────────────────────
              const SizedBox(height: 20),
              _section(l.settingsPrivacy),
              _group([
                _toggle(
                  icon: Icons.visibility_rounded, iconColor: _kG3,
                  title: l.settingsOnline,
                  subtitle: _showOnline ? l.settingsOnlineOn : l.settingsOnlineOff,
                  value: _showOnline,
                  onChanged: (v) async {
                    HapticFeedback.lightImpact();
                    setState(() => _showOnline = v);
                    await _s.setShowOnline(v);
                    // PresenceService writes the flag to Firestore so other
                    // users' clients respect it (see additional changes)
                    _snack(v ? '🟢 ${l.settingsOnlineOn}' : '⚫ ${l.settingsOnlineOff}');
                  },
                  onInfo: () => _showInfoSheet(l.settingsOnline,
                    'When enabled, your active status appears as a green dot '
                    'to your followers and group members. Turning this off makes '
                    'you appear offline at all times.'),
                ),
                _divLine(),
                _toggle(
                  icon: Icons.person_search_rounded, iconColor: _kG2,
                  title: l.settingsDiscoverable,
                  subtitle: _discoverable ? l.settingsDiscOn : l.settingsDiscOff,
                  value: _discoverable,
                  onChanged: (v) async {
                    HapticFeedback.lightImpact();
                    setState(() => _discoverable = v);
                    await _s.setDiscoverable(v);
                    _snack(v ? '🔍 ${l.settingsDiscOn}' : '🔒 ${l.settingsDiscOff}');
                  },
                  onInfo: () => _showInfoSheet(l.settingsDiscoverable,
                    'When enabled, other students can find your profile by '
                    'searching your name or username. Disabling this means '
                    'only people who already follow you can view your profile.'),
                ),
                _divLine(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen())),
                  child: _info(Icons.block_rounded, 'Blocked users',
                      'Manage ›', _kG4),
                ),
                _divLine(),
                GestureDetector(
                  onTap: _confirmDeleteAccount,
                  child: _info(Icons.delete_forever_rounded, 'Delete account',
                      'Permanent ›', _kG4),
                ),
              ]),

              // ── ABOUT ─────────────────────────────────────
              const SizedBox(height: 20),
              _section(l.settingsAbout),
              _group([
                _info(Icons.info_outline_rounded, l.settingsVersion,
                    'TCS 5.0', _kG2),
                _divLine(),
                _info(Icons.school_rounded, l.settingsInstitution,
                    'Taylors College, Sydney', const Color(0xFF3F51B5)),
                _divLine(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const TermsOfServiceScreen())),
                  child: _info(Icons.gavel_rounded, l.settingsTerms,
                      l.settingsView, Colors.grey.shade600)),
                _divLine(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen())),
                  child: _info(Icons.privacy_tip_rounded, l.settingsPrivacyPol,
                      l.settingsView, Colors.grey.shade600)),
                _divLine(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AboutApplicationScreen())),
                  child: _info(Icons.apps_rounded, 'About Application',
                      'View ›', _kG1)),
                _divLine(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AboutDeveloperScreen())),
                  child: _info(Icons.code_rounded, 'About Developer',
                      'View ›', _kG3)),
              ]),

              const SizedBox(height: 48),
            ],
          ),
        )),
      ]),
    );
  }

  // ── helpers ───────────────────────────────────────────────
  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(label, style: TextStyle(
        fontFamily: 'Arch', fontWeight: FontWeight.bold,
        fontSize: 11, color: _sub, letterSpacing: 0.9)),
  );

  Widget _group(List<Widget> children) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    decoration: BoxDecoration(color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(_dark ? 0.3 : 0.05),
          blurRadius: 12, offset: const Offset(0, 3))]),
    child: Column(children: children),
  );

  Widget _divLine() => Divider(height: 1, indent: 56, color: _divC);

  Widget _iconBox(Widget child, Color bg) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: child,
  );

  Widget _toggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    VoidCallback? onInfo,
  }) => Opacity(
    opacity: enabled ? 1.0 : 0.42,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _iconBox(Icon(icon, color: iconColor, size: 20),
            iconColor.withOpacity(0.12)),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: 'Arch',
              fontWeight: FontWeight.bold, fontSize: 14, color: _text)),
          Text(subtitle, style: TextStyle(fontFamily: 'Momo',
              fontSize: 12, color: _sub)),
        ])),
        if (onInfo != null)
          GestureDetector(onTap: onInfo,
            child: Padding(padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.info_outline_rounded, size: 16, color: _sub))),
        Switch(
          value: value, onChanged: onChanged,
          activeThumbColor: Colors.white, activeTrackColor: iconColor,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: _dark ? Colors.white24 : Colors.grey.shade300,
        ),
      ]),
    ),
  );

  Widget _info(IconData icon, String title, String value, Color color) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _iconBox(Icon(icon, color: color, size: 20), color.withOpacity(0.1)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: TextStyle(fontFamily: 'Arch',
            fontWeight: FontWeight.bold, fontSize: 14, color: _text))),
        Text(value, style: TextStyle(fontFamily: 'Momo',
            fontSize: 13, color: _sub)),
      ]),
    );
}

extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
