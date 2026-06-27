// lib/screens/staff/staff_settings_screen.dart
//
// Dedicated staff settings — only what applies to staff, and every toggle
// genuinely persists via AppSettings (which the shared student screen failed
// to call). Account info + theme + notifications + privacy + log out.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/services/app_settings.dart';
import 'package:tcs_app/screens/auth/role_selection_screen.dart';
import 'package:tcs_app/screens/staff/staff_ui.dart';
import 'package:tcs_app/screens/about_application_screen.dart';
import 'package:tcs_app/screens/about_developer_screen.dart';
import 'package:tcs_app/screens/privacy_policy_screen.dart';
import 'package:tcs_app/screens/terms_of_service_screen.dart';
import 'package:tcs_app/screens/wellbeing_notice_screen.dart';

class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  final _api = ApiService();
  final _s = AppSettings();
  String _name = '';
  String _role = '';
  String _userId = '';
  bool _loggingOut = false;

  @override
  void initState() { super.initState(); _loadMe(); }

  Future<void> _loadMe() async {
    try {
      final me = (await _api.getMyProfile().catchError((_) => <String, dynamic>{})
          as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _name = (me['display_name'] ?? me['name'] ?? 'Staff').toString();
        _role = (me['role'] ?? '').toString();
        _userId = (me['user_id'] ?? '').toString();
      });
    } catch (_) {}
  }

  String get _roleLabel {
    switch (_role) {
      case 'teaching_staff': return 'Teaching staff';
      case 'non_teaching_staff': return 'Non-teaching staff';
      case 'admin': return 'Admin';
      default: return 'Staff';
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppC.card,
        title: Text('Log out?', style: TextStyle(fontFamily: 'Alfa',
            color: AppC.text, fontSize: 17)),
        content: Text('You\'ll need to sign in again to use the staff console.',
            style: TextStyle(fontFamily: 'Momo', color: AppC.sub, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out', style: TextStyle(
                  color: Color(0xFFE11D48), fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loggingOut = true);
    try { await _api.logout(); } catch (_) {}
    Get.offAll(() => const RoleSelectionScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        _header(),
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(children: [
            // Account
            Container(
              padding: const EdgeInsets.all(16),
              decoration: staffCard(),
              child: Row(children: [
                Container(width: 52, height: 52, alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: kStaffGrad,
                      shape: BoxShape.circle),
                  child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S',
                      style: const TextStyle(fontFamily: 'Alfa', fontSize: 22,
                          color: Colors.white))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                    Text(_name.isEmpty ? '…' : _name, style: TextStyle(
                        fontFamily: 'Alfa', fontSize: 16, color: AppC.text)),
                    const SizedBox(height: 2),
                    Text('$_roleLabel${_userId.isNotEmpty ? "  ·  $_userId" : ""}',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
                            color: AppC.sub)),
                  ])),
              ]),
            ),
            const SizedBox(height: 22),

            _section('Appearance'),
            _toggle('Dark mode', 'Theme across the app',
                Icons.dark_mode_rounded, _s.isDark,
                (v) async { await _s.setDark(v); setState(() {}); }),

            const SizedBox(height: 22),
            _section('Notifications'),
            _toggle('Push notifications', 'Alerts on this device',
                Icons.notifications_rounded, _s.pushEnabled,
                (v) async { await _s.setPush(v); setState(() {}); }),
            _toggle('Announcements', 'Campus announcements',
                Icons.campaign_rounded, _s.announcements,
                (v) async { await _s.setAnnouncements(v); setState(() {}); }),

            const SizedBox(height: 22),
            _section('Privacy'),
            _toggle('Show when online', 'Let others see your online status',
                Icons.visibility_rounded, _s.showOnline,
                (v) async { await _s.setShowOnline(v); setState(() {}); }),
            _aboutRow(Icons.health_and_safety_rounded, 'Wellbeing & Safety',
                'Manage', const Color(0xFF0EA5A4),
                () => _push(const WellbeingNoticeScreen())),

            const SizedBox(height: 22),
            _section('About'),
            _aboutRow(Icons.info_outline_rounded, 'Version', 'TCS 5.0', kStaffG2, null),
            _aboutRow(Icons.school_rounded, 'Institution',
                'Taylors College, Sydney', const Color(0xFF3F51B5), null),
            _aboutRow(Icons.gavel_rounded, 'Terms of Service', 'View', AppC.sub,
                () => _push(const TermsOfServiceScreen())),
            _aboutRow(Icons.privacy_tip_rounded, 'Privacy Policy', 'View', AppC.sub,
                () => _push(const PrivacyPolicyScreen())),
            _aboutRow(Icons.apps_rounded, 'About Application', 'View', kStaffG1,
                () => _push(const AboutApplicationScreen())),
            _aboutRow(Icons.code_rounded, 'About Developer', 'View',
                const Color(0xFFF7971E),
                () => _push(const AboutDeveloperScreen())),

            const SizedBox(height: 26),
            GestureDetector(
              onTap: _loggingOut ? null : _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.4))),
                child: _loggingOut
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Color(0xFFE11D48)))
                    : Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 19),
                        SizedBox(width: 8),
                        Text('Log out', style: TextStyle(fontFamily: 'Arch',
                            fontSize: 14, fontWeight: FontWeight.bold,
                            color: Color(0xFFE11D48))),
                      ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _header() => StaffHeader(
        bottomPad: 22,
        horizontal: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          GestureDetector(onTap: () => Navigator.of(context).maybePop(),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
          const SizedBox(width: 14),
          const Text('Settings', style: TextStyle(fontFamily: 'Alfa', fontSize: 24,
              color: Colors.white)),
        ]),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Align(alignment: Alignment.centerLeft, child: Text(t.toUpperCase(),
            style: TextStyle(fontFamily: 'Arch', fontSize: 10.5,
                fontWeight: FontWeight.bold, letterSpacing: 1, color: AppC.sub))),
      );

  Widget _toggle(String title, String subtitle, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: staffCard(),
      child: Row(children: [
        Container(width: 38, height: 38, alignment: Alignment.center,
          decoration: BoxDecoration(color: kStaffG2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: kStaffG2, size: 18)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: TextStyle(fontFamily: 'Arch', fontSize: 13.5,
                fontWeight: FontWeight.bold, color: AppC.text)),
            const SizedBox(height: 1),
            Text(subtitle, style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                color: AppC.sub)),
          ])),
        Switch(value: value, activeThumbColor: kStaffG2,
            onChanged: (v) { HapticFeedback.selectionClick(); onChanged(v); }),
      ]),
    );
  }

  void _push(Widget s) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
  }

  // A tappable (or static) About row, styled like the staff cards. A null
  // onTap makes it informational (e.g. Version / Institution).
  Widget _aboutRow(IconData icon, String title, String value, Color color,
      VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: staffCard(),
        child: Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 13),
          Expanded(child: Text(title, style: TextStyle(fontFamily: 'Arch',
              fontSize: 13.5, fontWeight: FontWeight.bold, color: AppC.text))),
          Text(value, style: TextStyle(fontFamily: 'Momo', fontSize: 11.5,
              color: AppC.sub)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: AppC.faint, size: 18),
          ],
        ]),
      ),
    );
  }
}
