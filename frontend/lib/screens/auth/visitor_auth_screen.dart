// lib/screens/auth/visitor_auth_screen.dart
//
// Email/password auth for visitor & parent accounts. Sign up collects only a
// username, email and password — plus a required tick of the visitor-specific
// Terms & Conditions. Sign in takes email/username + password. On success,
// routes to the sandboxed VisitorDashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/visitor/visitor_dashboard_screen.dart';

const _kG1 = Color(0xFF6DD5FA);
const _kG2 = Color(0xFF8E54E9);

class VisitorAuthScreen extends StatefulWidget {
  final String role; // 'visitor' | 'parent'
  const VisitorAuthScreen({super.key, required this.role});

  @override
  State<VisitorAuthScreen> createState() => _VisitorAuthScreenState();
}

class _VisitorAuthScreenState extends State<VisitorAuthScreen> {
  final _api = ApiService();
  bool _signUp = true;
  bool _busy = false;
  bool _agreed = false;

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _identifier = TextEditingController();

  @override
  void dispose() {
    _username.dispose(); _email.dispose();
    _password.dispose(); _identifier.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFB3261E),
      content: Text(m, style: const TextStyle(fontFamily: 'Momo', color: Colors.white))));
  }

  Future<void> _submit() async {
    if (_signUp) {
      final username = _username.text.trim();
      final email = _email.text.trim();
      if (username.isEmpty || email.isEmpty || _password.text.length < 6) {
        _snack('Username, email and a 6+ char password are required.');
        return;
      }
      if (!email.contains('@') || !email.contains('.')) {
        _snack('Enter a valid email address.'); return;
      }
      if (!_agreed) {
        _snack('Please accept the Visitor Terms & Conditions to continue.');
        return;
      }
    } else {
      if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
        _snack('Enter your email and password.'); return;
      }
    }

    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      if (_signUp) {
        await _api.registerVisitor(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: widget.role);
      } else {
        await _api.loginPassword(
            identifier: _identifier.text.trim(), password: _password.text);
      }
      Get.offAll(() => const VisitorDashboardScreen());
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.role == 'parent' ? 'Parent' : 'Visitor';
    return Scaffold(
      backgroundColor: AppC.bg,
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 26),
          decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [_kG1, _kG2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
            const SizedBox(height: 16),
            Text('$label access', style: const TextStyle(fontFamily: 'Alfa',
                fontSize: 26, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Browse public clubs & events at Taylors College Sydney',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.9))),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          // Sign up / Sign in toggle
          Row(children: [
            for (final t in const [[true, 'Sign up'], [false, 'Sign in']])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _signUp = t[0] as bool),
                child: Container(
                  margin: EdgeInsets.only(right: t[0] == true ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _signUp == t[0] ? _kG2 : AppC.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _signUp == t[0] ? _kG2 : AppC.border)),
                  child: Text(t[1] as String, style: TextStyle(fontFamily: 'Arch',
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: _signUp == t[0] ? Colors.white : AppC.sub)),
                ),
              )),
          ]),
          const SizedBox(height: 18),
          if (_signUp) ...[
            _field(_username, 'Username'),
            const SizedBox(height: 12),
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_password, 'Password (6+ chars)', obscure: true),
            const SizedBox(height: 16),
            _termsRow(),
          ] else ...[
            _field(_identifier, 'Email or username',
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_password, 'Password', obscure: true),
          ],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _kG2,
                disabledBackgroundColor: _kG2.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _busy
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_signUp ? 'Create account & enter' : 'Sign in',
                    style: const TextStyle(fontFamily: 'Arch', fontSize: 14.5,
                        fontWeight: FontWeight.bold, color: Colors.white)),
          )),
          const SizedBox(height: 14),
          Text('Visitor accounts only see public club & event posts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Momo', fontSize: 11,
                  color: AppC.faint, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _termsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22, height: 22, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _agreed ? _kG2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: _agreed ? _kG2 : AppC.border, width: 1.6)),
          child: _agreed
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null),
        const SizedBox(width: 10),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('I have read and agree to the ',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                    color: AppC.sub, height: 1.35)),
            GestureDetector(
              onTap: _showTerms,
              child: Text('Visitor Terms & Conditions',
                  style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                      fontWeight: FontWeight.bold, color: _kG2,
                      decoration: TextDecoration.underline,
                      decorationColor: _kG2, height: 1.35)),
            ),
            Text('.', style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
          ]),
        )),
      ]),
    );
  }

  void _showTerms() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppC.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.5,
        builder: (ctx, scroll) => ListView(
          controller: scroll, padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppC.faint,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Visitor Terms & Conditions',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: AppC.text)),
            const SizedBox(height: 6),
            Text('Please read these before creating a guest account.',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
            const SizedBox(height: 18),
            for (final t in _kVisitorTerms) _clause(t.$1, t.$2),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: () { setState(() => _agreed = true); Navigator.pop(ctx); },
              style: ElevatedButton.styleFrom(backgroundColor: _kG2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('I agree',
                  style: TextStyle(fontFamily: 'Arch', fontWeight: FontWeight.bold,
                      color: Colors.white)))),
          ],
        ),
      ),
    );
  }

  Widget _clause(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, size: 6, color: _kG2)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 14, color: AppC.text))),
          ]),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.only(left: 14),
            child: Text(body, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                height: 1.5, color: AppC.sub))),
        ]),
      );

  Widget _field(TextEditingController c, String hint,
          {bool obscure = false, TextInputType? keyboard}) =>
      TextField(controller: c, obscureText: obscure, keyboardType: keyboard,
        style: TextStyle(color: AppC.text, fontFamily: 'Momo', fontSize: 14),
        decoration: InputDecoration(hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Momo', color: AppC.faint, fontSize: 13.5),
            filled: true, fillColor: AppC.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none)));
}

// Visitor-specific terms (title, body). Kept short and plain.
const List<(String, String)> _kVisitorTerms = [
  ('Guest access only',
   'A visitor account is a limited guest pass. You can browse public club and '
   'event posts shared by Taylors College Sydney. You will not have access to '
   'student profiles, messaging, study groups, or any private content.'),
  ('No student data',
   'You agree not to attempt to identify, contact, profile, scrape or collect '
   'information about any student, and not to use the app to reach minors.'),
  ('Respectful use',
   'You will not impersonate anyone, post or transmit unlawful, harassing or '
   'objectionable material, or attempt to bypass the visitor restrictions or '
   'the app’s security.'),
  ('Content & moderation',
   'Posts you view are owned by their authors and may be edited, hidden or '
   'removed at any time. Content is moderated and is not guaranteed accurate.'),
  ('Your account & data',
   'We store your username and email to operate your guest account. See the '
   'Privacy Policy for how your information is handled. You may request '
   'deletion of your account at any time.'),
  ('Revoking access',
   'The College may suspend or revoke visitor access at any time, with or '
   'without notice, if these terms are breached or for safeguarding reasons.'),
];
