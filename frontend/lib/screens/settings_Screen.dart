// lib/screens/settings/settings_screen.dart
// Fully functional — all toggles persist + drive the whole app via AppSettings.
// Uses AppL10n for every visible string so it switches with the language.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tcs_app/screens/suggestion_box_screen.dart';
import 'package:tcs_app/services/app_localisations.dart';
import 'package:tcs_app/services/app_settings.dart';


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

  // Local mirrors for instant UI response
  late bool   _dark;
  late String _lang;
  late bool   _pushEnabled;
  late bool   _announcements;
  late bool   _groupActivity;
  late bool   _showOnline;
  late bool   _discoverable;
  bool        _langExpanded = false;

  final _languages = const {
    'en': ('English',           '🇬🇧'),
    'ms': ('Bahasa Malaysia',   '🇲🇾'),
    'zh': ('中文 (Chinese)',     '🇨🇳'),
    'ta': ('தமிழ் (Tamil)',     '🇮🇳'),
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

  // ── Theme helpers — react to _dark in real time ────────────
  Color get _bg   => _dark ? const Color(0xFF0D0D1A) : const Color(0xFFF2F4F8);
  Color get _card => _dark ? const Color(0xFF161628) : Colors.white;
  Color get _text => _dark ? Colors.white            : const Color(0xFF1A1A2E);
  Color get _sub  => _dark ? Colors.white54           : Colors.grey.shade500;
  Color get _divC => _dark ? Colors.white10           : Colors.grey.shade100;

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
              fontSize: 14, color: _sub, height: 1.65)),
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

  void _showDocument(String title) {
    final l = AppL10n.of(context);
    final isTerms = title == l.settingsTerms;
    final content = isTerms
      ? 'By using TCS StudentHub you agree to use the platform responsibly, '
        'respect other users, and follow Taylors College community guidelines. '
        'Content that is harmful, offensive, or violates academic integrity '
        'policies is strictly prohibited.'
      : 'TCS StudentHub collects only the data necessary to provide its services. '
        'Your personal data is stored securely and never sold to third parties. '
        'You may request deletion of your account and data at any time by '
        'contacting the Taylors College IT helpdesk.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(fontFamily: 'Alfa',
            fontSize: 18, color: _text)),
        content: Text(content, style: TextStyle(fontFamily: 'Momo',
            fontSize: 13, color: _sub, height: 1.65)),
        actions: [TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.btnClose, style: const TextStyle(
              fontFamily: 'Arch', fontWeight: FontWeight.bold, color: _kG2)),
        )],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l   = AppL10n.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [

        // ── Header ──────────────────────────────────────────
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
            const Spacer(),
            // ── Quick dark-mode toggle ─────────────────────
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                setState(() => _dark = !_dark);
                await _s.setDark(_dark);
                // AppSettings notifies → TCSApp rebuilds MaterialApp → whole
                // app switches theme. The snack uses new l10n strings too.
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52, height: 28,
                decoration: BoxDecoration(
                  color: _dark ? _kG2 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(3),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: _dark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      _dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 13,
                      color: _dark ? _kG2 : Colors.grey.shade500))),
              ),
            ),
          ]),
        ),

        // ── Content ─────────────────────────────────────────
        Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: _bg,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ── APPEARANCE ────────────────────────────────
              _section(l.settingsAppearance),
              _group([
                _toggle(
                  icon: Icons.contrast_rounded,
                  iconColor: _dark ? _kG2 : _kG3,
                  title: l.settingsDarkMode,
                  subtitle: _dark ? l.settingsDarkOn : l.settingsDarkOff,
                  value: _dark,
                  onChanged: (v) async {
                    HapticFeedback.lightImpact();
                    setState(() => _dark = v);
                    await _s.setDark(v);
                    // MaterialApp theme switches immediately app-wide
                  },
                ),
              ]),

              // ── LANGUAGE ──────────────────────────────────
              const SizedBox(height: 20),
              _section(l.settingsLanguage),
              _group([
                // Header row (tap to expand)
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
                // Expandable language list
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
                          // AppSettings.notifyListeners() → TCSApp rebuilds
                          // MaterialApp with new locale → AppL10nProvider
                          // propagates new language to every screen
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
                    setState(() {
                      _pushEnabled = v;
                      if (!v) { _announcements = false; _groupActivity = false; }
                    });
                    await _s.setPush(v);
                    _snack(v ? '🔔 ${l.settingsPushOn}' : '🔕 ${l.settingsPushOff}',
                        color: v ? Colors.green.shade600 : Colors.grey.shade600);
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
                  },
                ),
              ]),

              _divLine(),
GestureDetector(
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const SuggestionBoxScreen())),
  child: _info(Icons.lightbulb_rounded, 'Suggestion Box',
      'Share your ideas ›', const Color(0xFFF7971E))),

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
              ]),

              // ── ABOUT ─────────────────────────────────────
              const SizedBox(height: 20),
              _section(l.settingsAbout),
              _group([
                _info(Icons.info_outline_rounded, l.settingsVersion,
                    'TCS StudentHub v1.0.0', _kG2),
                _divLine(),
                _info(Icons.school_rounded, l.settingsInstitution,
                    'Taylors College, Malaysia', const Color(0xFF3F51B5)),
                _divLine(),
                GestureDetector(
                  onTap: () => _showDocument(l.settingsTerms),
                  child: _info(Icons.gavel_rounded, l.settingsTerms,
                      l.settingsView, Colors.grey.shade600)),
                _divLine(),
                GestureDetector(
                  onTap: () => _showDocument(l.settingsPrivacyPol),
                  child: _info(Icons.privacy_tip_rounded, l.settingsPrivacyPol,
                      l.settingsView, Colors.grey.shade600)),
                _divLine(),
                GestureDetector(
                  onTap: () => _snack('✉️  helpdesk@taylors.edu.my'),
                  child: _info(Icons.support_agent_rounded, l.settingsSupport,
                      'helpdesk@taylors.edu.my', _kG1)),
              ]),

              const SizedBox(height: 48),
            ],
          ),
        )),
      ]),
    );
  }

  // ── Widget helpers ────────────────────────────────────────

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

// ── Extension convenience so screens can do: ─────────────────
// Text(context.l10n.feedTitle)
extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}