// lib/screens/auth/visitor_auth_screen.dart
//
// Email/password auth for visitor & parent accounts. Sign up (name, username,
// email, password, DOB) or sign in (email/username + password). On success,
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

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _identifier = TextEditingController();
  DateTime? _dob;

  @override
  void dispose() {
    _name.dispose(); _username.dispose(); _email.dispose();
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
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      if (_signUp) {
        final name = _name.text.trim();
        final email = _email.text.trim();
        if (name.isEmpty || email.isEmpty || _password.text.length < 6) {
          _snack('Name, email and a 6+ char password are required.');
          return;
        }
        if (_dob == null) { _snack('Please pick your date of birth.'); return; }
        await _api.registerVisitor(
          name: name,
          username: _username.text.trim().isEmpty ? email : _username.text.trim(),
          email: email, password: _password.text,
          dateOfBirth: '${_dob!.year.toString().padLeft(4, '0')}-'
              '${_dob!.month.toString().padLeft(2, '0')}-'
              '${_dob!.day.toString().padLeft(2, '0')}',
          role: widget.role);
      } else {
        final id = _identifier.text.trim();
        if (id.isEmpty || _password.text.isEmpty) {
          _snack('Enter your email and password.'); return;
        }
        await _api.loginPassword(identifier: id, password: _password.text);
      }
      Get.offAll(() => const VisitorDashboardScreen());
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context,
        initialDate: DateTime(now.year - 30),
        firstDate: DateTime(1930), lastDate: now);
    if (d != null) setState(() => _dob = d);
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
            _field(_name, 'Full name'),
            const SizedBox(height: 12),
            _field(_username, 'Username (optional)'),
            const SizedBox(height: 12),
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            GestureDetector(onTap: _pickDob, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(color: AppC.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppC.border)),
              child: Row(children: [
                Icon(Icons.cake_rounded, size: 18, color: AppC.sub),
                const SizedBox(width: 10),
                Text(_dob == null ? 'Date of birth'
                    : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                    style: TextStyle(fontFamily: 'Momo', fontSize: 13.5,
                        color: _dob == null ? AppC.faint : AppC.text)),
              ]))),
            const SizedBox(height: 12),
            _field(_password, 'Password (6+ chars)', obscure: true),
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
