// lib/screens/auth/visitor_auth_screen.dart
//
// Visitor & parent auth, styled to match the student/staff LoginIdScreen:
// gradient hero header with floating role icon (Hero from the role card),
// a white form card, gradient-prefixed fields and a gradient CTA.
// Sign up collects only username/email/password + a required tick of the
// visitor-specific Terms & Conditions. Sign in takes email/username + password.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/services/api_service.dart';
import 'package:tcs_app/screens/visitor/visitor_dashboard_screen.dart';

// Visitor identity — same amber→gold as the role-selection Visitor card, so the
// hero icon flies in continuously.
const _kViGrad   = [Color(0xFFF7971E), Color(0xFFFFD200)];
const _kViAccent = Color(0xFFD97706);

// Theme-aware surfaces so the form card + fields flip in dark mode.
Color get _kInk         => AppC.text;
Color get _kCard        => AppC.card;
Color get _kField       => AppC.card2;
Color get _kFieldBorder => AppC.border;
Color get _kHint        => AppC.faint;

class VisitorAuthScreen extends StatefulWidget {
  final String role; // 'visitor' | 'parent'
  const VisitorAuthScreen({super.key, required this.role});

  @override
  State<VisitorAuthScreen> createState() => _VisitorAuthScreenState();
}

class _VisitorAuthScreenState extends State<VisitorAuthScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  bool _signUp = true;
  bool _busy = false;
  bool _agreed = false;

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _identifier = TextEditingController();
  final _uFocus = FocusNode();
  final _eFocus = FocusNode();
  final _pFocus = FocusNode();
  final _idFocus = FocusNode();

  late final AnimationController _entryCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _floatAnim;

  String get _label => widget.role == 'parent' ? 'Parent' : 'Visitor';

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _scaleAnim = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut));
    _floatAnim = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose(); _floatCtrl.dispose();
    _username.dispose(); _email.dispose();
    _password.dispose(); _identifier.dispose();
    _uFocus.dispose(); _eFocus.dispose(); _pFocus.dispose(); _idFocus.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
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
    final size = MediaQuery.of(context).size;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppC.bg,
        body: Stack(children: [
          // Gradient hero header
          Positioned(
            top: 0, left: 0, right: 0, height: size.height * 0.42,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _kViGrad,
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(44)),
                boxShadow: [BoxShadow(color: _kViAccent.withOpacity(0.30),
                    blurRadius: 30, offset: const Offset(0, 12))]),
              child: Stack(children: [
                Positioned(right: -50, top: -50, child: _blob(200, 0.08)),
                Positioned(left: -30, bottom: 40, child: _blob(130, 0.06)),
                Positioned(right: 40, bottom: 80, child: _blob(46, 0.10)),
              ]),
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: FadeTransition(opacity: _fadeAnim, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.35))),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18)),
                  )),
                  const SizedBox(height: 18),
                  // Floating Hero role icon
                  Center(child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, child) => Transform.translate(
                        offset: Offset(0, _floatAnim.value), child: child),
                    child: ScaleTransition(scale: _scaleAnim,
                      child: Hero(tag: 'role_icon_${widget.role}', child: _roleIcon())),
                  )),
                  const SizedBox(height: 18),
                  // Title
                  SlideTransition(position: _slideAnim, child: Column(children: [
                    Text(_signUp ? 'Welcome!' : 'Welcome back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Alfa', fontSize: 30,
                            color: Colors.white, fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black.withOpacity(0.18),
                                blurRadius: 10, offset: const Offset(0, 3))])),
                    const SizedBox(height: 6),
                    Text('Browse public clubs & events at Taylors College Sydney',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Momo', fontSize: 13,
                            color: Colors.white.withOpacity(0.85))),
                  ])),
                  const SizedBox(height: 26),
                  // Form card
                  SlideTransition(position: _slideAnim, child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07),
                          blurRadius: 30, offset: const Offset(0, 14))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _rolePill()),
                        const SizedBox(height: 18),
                        _toggle(),
                        const SizedBox(height: 20),
                        if (_signUp) ...[
                          _ViField(controller: _username, focusNode: _uFocus,
                              hint: 'Username', icon: Icons.person_rounded),
                          const SizedBox(height: 16),
                          _ViField(controller: _email, focusNode: _eFocus,
                              hint: 'Email', icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _ViField(controller: _password, focusNode: _pFocus,
                              hint: 'Password (6+ chars)', icon: Icons.lock_rounded,
                              obscure: true),
                          const SizedBox(height: 18),
                          _termsRow(),
                        ] else ...[
                          _ViField(controller: _identifier, focusNode: _idFocus,
                              hint: 'Email or username', icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _ViField(controller: _password, focusNode: _pFocus,
                              hint: 'Password', icon: Icons.lock_rounded, obscure: true),
                        ],
                        const SizedBox(height: 22),
                        _ViButton(
                          isLoading: _busy,
                          label: _signUp ? 'Create account & enter' : 'Sign in',
                          onTap: _submit),
                      ],
                    ),
                  )),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text('Visitor accounts only see public club & event posts',
                        style: TextStyle(fontFamily: 'Momo', fontSize: 12,
                            color: Colors.grey.shade500)),
                  ]),
                ],
              )),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _blob(double s, double o) => Container(width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.white.withOpacity(o)));

  Widget _roleIcon() => Container(
        width: 104, height: 104,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.16),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 2)),
        child: Center(child: Container(
          width: 78, height: 78,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(colors: _kViGrad,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20),
                blurRadius: 18, offset: const Offset(0, 8))]),
          child: const Icon(Icons.public_rounded, color: Colors.white, size: 38))),
      );

  Widget _rolePill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _kViAccent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _kViAccent.withOpacity(0.22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.public_rounded, color: _kViAccent, size: 15),
          const SizedBox(width: 6),
          Text('$_label access', style: const TextStyle(fontFamily: 'Arch',
              fontSize: 12, fontWeight: FontWeight.w700, color: _kViAccent,
              letterSpacing: 0.3)),
        ]),
      );

  Widget _toggle() => Row(children: [
        for (final t in const [[true, 'Sign up'], [false, 'Sign in']])
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _signUp = t[0] as bool),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: t[0] == true ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _signUp == t[0]
                    ? const LinearGradient(colors: _kViGrad) : null,
                color: _signUp == t[0] ? null : AppC.card2,
                borderRadius: BorderRadius.circular(12)),
              child: Text(t[1] as String, style: TextStyle(fontFamily: 'Arch',
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: _signUp == t[0] ? Colors.white : AppC.sub)),
            ),
          )),
      ]);

  Widget _termsRow() => GestureDetector(
        onTap: () => setState(() => _agreed = !_agreed),
        behavior: HitTestBehavior.opaque,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: _agreed ? _kViAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _agreed ? _kViAccent : Colors.grey.shade400, width: 2)),
            child: _agreed
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null),
          const SizedBox(width: 12),
          Expanded(child: Text.rich(TextSpan(
            style: TextStyle(fontFamily: 'Momo', fontSize: 12.5, height: 1.35,
                color: AppC.sub),
            children: const [
              TextSpan(text: 'I have read and agree to the '),
              TextSpan(text: 'Visitor Terms & Conditions',
                  style: TextStyle(color: _kViAccent, fontWeight: FontWeight.bold)),
              TextSpan(text: '.'),
            ],
          ))),
          const SizedBox(width: 8),
          GestureDetector(onTap: _showTerms,
              child: const Icon(Icons.open_in_new_rounded, size: 18, color: _kViAccent)),
        ]),
      );

  void _showTerms() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.5,
        builder: (ctx, scroll) => ListView(
          controller: scroll, padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppC.border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Visitor Terms & Conditions',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 20, color: _kInk)),
            const SizedBox(height: 6),
            Text('Please read these before creating a guest account.',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: AppC.sub)),
            const SizedBox(height: 18),
            for (final t in _kVisitorTerms) _clause(t.$1, t.$2),
            const SizedBox(height: 12),
            _ViButton(isLoading: false, label: 'I agree', onTap: () {
              setState(() => _agreed = true); Navigator.pop(ctx);
            }),
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
                child: Icon(Icons.circle, size: 6, color: _kViAccent)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontFamily: 'Arch',
                fontWeight: FontWeight.bold, fontSize: 14, color: _kInk))),
          ]),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.only(left: 14),
            child: Text(body, style: TextStyle(fontFamily: 'Momo', fontSize: 12.5,
                height: 1.5, color: AppC.sub))),
        ]),
      );
}

// ── Visitor field — white card with gradient prefix icon (login style) ────
class _ViField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  const _ViField({
    required this.controller, required this.focusNode,
    required this.hint, required this.icon,
    this.obscure = false, this.keyboardType});

  @override
  State<_ViField> createState() => _ViFieldState();
}

class _ViFieldState extends State<_ViField> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_f);
  }
  void _f() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); }
  @override
  void dispose() { widget.focusNode.removeListener(_f); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _kField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _focused ? _kViAccent : _kFieldBorder,
            width: _focused ? 2 : 1.5),
        boxShadow: _focused
            ? [BoxShadow(color: _kViAccent.withOpacity(0.14),
                blurRadius: 14, offset: const Offset(0, 4))]
            : const []),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        style: TextStyle(fontFamily: 'Momo', fontSize: 15, color: _kInk),
        decoration: InputDecoration(
          filled: true, fillColor: _kField,
          hintText: widget.hint,
          hintStyle: TextStyle(color: _kHint, fontFamily: 'Momo'),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10), width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _kViGrad),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.icon, color: Colors.white, size: 18)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

// ── Visitor CTA — gradient pill button (login style) ──────────────────────
class _ViButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onTap;
  const _ViButton({required this.isLoading, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading ? [Colors.grey.shade300, Colors.grey.shade400] : _kViGrad,
            begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading ? [] : [BoxShadow(
              color: _kViGrad.last.withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 6))]),
        child: Center(child: isLoading
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: const TextStyle(fontFamily: 'Arch',
                    fontWeight: FontWeight.bold, color: Colors.white,
                    fontSize: 16, letterSpacing: 0.4)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ])),
      ),
    );
  }
}

// Visitor-specific terms (title, body).
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
