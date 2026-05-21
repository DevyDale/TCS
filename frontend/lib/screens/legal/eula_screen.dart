// lib/screens/legal/eula_screen.dart
//
// Apple App Review Guideline 1.2 requires a EULA / terms-of-use
// agreement to be presented BEFORE a user registers or logs in, with
// an explicit acknowledgement that there is zero tolerance for
// objectionable content or abusive users.
//
// Usage — gate the app entry on this screen. In your splash / initial
// routing (e.g. main.dart or splash_screen.dart), before sending the
// user to role selection / login:
//
//   if (!await EulaGate.isAccepted()) {
//     final ok = await Navigator.push<bool>(
//       context,
//       MaterialPageRoute(builder: (_) => const EulaScreen()),
//     );
//     if (ok != true) return;            // user declined → don't proceed
//   }
//   // ...continue to RoleSelectionScreen()
//
// EulaScreen pops `true` on accept and `false` on decline.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _kG1  = Color(0xFF6DD5FA);
const Color _kG2  = Color(0xFF8E54E9);
const Color _kInk = Color(0xFF1A1A2E);
const Color _kBg  = Color(0xFFF7F8FA);

/// Persists EULA acceptance. Bump the key suffix if the terms change
/// materially and you need users to re-accept.
class EulaGate {
  static const _key = 'tcs_eula_accepted_v1';

  static Future<bool> isAccepted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key) ?? false;
  }

  static Future<void> markAccepted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
  }
}

class EulaScreen extends StatefulWidget {
  const EulaScreen({super.key});

  @override
  State<EulaScreen> createState() => _EulaScreenState();
}

class _EulaScreenState extends State<EulaScreen> {
  final _scroll = ScrollController();
  bool _agreed       = false;   // checkbox
  bool _reachedEnd   = false;   // scrolled the terms to the bottom

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_reachedEnd &&
          _scroll.offset >= _scroll.position.maxScrollExtent - 24) {
        setState(() => _reachedEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _canContinue => _agreed && _reachedEnd;

  Future<void> _accept() async {
    HapticFeedback.mediumImpact();
    await EulaGate.markAccepted();
    if (mounted) Navigator.pop(context, true);
  }

  void _decline() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kG1, _kG2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 40),
                  SizedBox(height: 14),
                  Text(
                    'Terms of Use & Community Rules',
                    style: TextStyle(
                      fontFamily: 'Arch',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Please read and accept before continuing.',
                    style: TextStyle(
                      fontFamily: 'Momo',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable terms ────────────────────────────
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: const _TermsBody(),
                ),
              ),
            ),

            // ── Footer: agree + buttons ─────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_reachedEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Scroll to the end to continue',
                        style: TextStyle(
                          fontFamily: 'Momo',
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: _reachedEnd
                        ? () => setState(() => _agreed = !_agreed)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: _reachedEnd
                                ? (v) => setState(() => _agreed = v ?? false)
                                : null,
                            activeColor: _kG2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                          ),
                          const Expanded(
                            child: Text(
                              'I agree to the Terms of Use and accept that there '
                              'is zero tolerance for objectionable content or '
                              'abusive behaviour.',
                              style: TextStyle(
                                fontFamily: 'Momo',
                                fontSize: 12.5,
                                color: _kInk,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _decline,
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              fontFamily: 'Arch',
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _canContinue ? _accept : null,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _canContinue ? 1 : 0.4,
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_kG1, _kG2]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Agree & Continue',
                                style: TextStyle(
                                  fontFamily: 'Arch',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Section(
          title: 'Welcome to TCS',
          body:
              'TCS (Taylors College Social) is a community platform for the '
              'Taylors College community. By creating an account or logging '
              'in, you agree to these Terms of Use and our Community Rules.',
        ),
        _Section(
          title: 'No Objectionable Content',
          body:
              'You agree not to create, upload, post, or share content that '
              'is unlawful, harassing, threatening, hateful, defamatory, '
              'sexually explicit, or otherwise objectionable. There is a '
              'ZERO-TOLERANCE policy for objectionable content and for '
              'abusive behaviour towards other users.',
        ),
        _Section(
          title: 'Reporting & Blocking',
          body:
              'Every post and every user profile includes tools to report '
              'objectionable content and to block abusive users. Blocking a '
              'user immediately removes their content from your feed and '
              'prevents further contact. Reports are sent to our moderation '
              'team for review.',
        ),
        _Section(
          title: 'Moderation & Enforcement',
          body:
              'We review reported content and act on objectionable content '
              'within 24 hours. We may remove content and suspend or '
              'permanently remove accounts that violate these terms, without '
              'prior notice. Automated filtering may also hold suspected '
              'content for review before it appears in feeds.',
        ),
        _Section(
          title: 'Your Responsibilities',
          body:
              'You are responsible for the content you post and for your '
              'conduct. You must be authorised to use the account you sign in '
              'with, must not impersonate others, and must not attempt to '
              'circumvent moderation or blocking.',
        ),
        _Section(
          title: 'Privacy',
          body:
              'We process your data to operate TCS. We do not sell your '
              'personal information. See the in-app Privacy Policy for '
              'details on what we collect and how it is used.',
        ),
        _Section(
          title: 'Contact',
          body:
              'Questions or concerns about these terms or about content on '
              'TCS can be raised through the in-app support / suggestion box.',
        ),
        SizedBox(height: 8),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Arch',
              fontWeight: FontWeight.bold,
              fontSize: 15.5,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Momo',
              fontSize: 13.5,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
