import 'package:flutter/material.dart';
import 'package:tcs_app/services/app_settings.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final _s = AppSettings();
  bool get _dark => _s.isDark;

  Color get _bg   => _dark ? const Color(0xFF0D0D1A) : const Color(0xFFF2F4F8);
  Color get _card => _dark ? const Color(0xFF161628) : Colors.white;
  Color get _text => _dark ? Colors.white            : const Color(0xFF1A1A2E);
  Color get _sub  => _dark ? Colors.white70          : Colors.grey.shade700;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        Container(
          color: _card,
          padding: EdgeInsets.only(top: top + 12, left: 8, right: 16, bottom: 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _bg,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.arrow_back_rounded, size: 20, color: _text)),
            ),
            const SizedBox(width: 12),
            Text('Privacy Policy', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 22, color: _text)),
          ]),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Effective: 1 January 2026',
                style: TextStyle(fontFamily: 'Momo', fontSize: 12, color: _sub)),
            const SizedBox(height: 16),
            _h('1. Who We Are'),
            _p('TCS StudentHub is operated by Taylors College Sydney. We are '
              'the data controller for any personal information collected '
              'through the App. This Policy explains what we collect, why, '
              'and your rights under the Australian Privacy Principles.'),
            _h('2. Information We Collect'),
            _p('Account data: your name, college email, student ID, course, '
              'and profile photo if you choose to upload one.\n\n'
              'Content data: posts, comments, messages, and study group '
              'activity you create within the App.\n\n'
              'Device data: device type, operating system version, app '
              'version, and crash logs used to keep the App stable.\n\n'
              'Notification data: a push notification token issued by your '
              'device, used only to deliver notifications you have enabled.'),
            _h('3. How We Use Your Information'),
            _p('To provide the core features of the App, deliver '
              'announcements, enable communication between students, '
              'moderate content, improve reliability, and respond to '
              'support requests. We do not sell your personal information '
              'to anyone.'),
            _h('4. Sharing'),
            _p('Your name, profile, and posts are visible to other '
              'authorised users of the App in line with your privacy '
              'settings. We use trusted service providers (cloud hosting, '
              'analytics, push notification delivery) bound by '
              'confidentiality and data-protection obligations.'),
            _h('5. Storage and Security'),
            _p('Data is stored on secure servers and protected with '
              'encryption in transit and at rest. Access by College staff '
              'is limited to those with a legitimate operational need.'),
            _h('6. Your Choices'),
            _p('You can change your visibility, discoverability, and '
              'notification preferences at any time in Settings. You may '
              'request a copy of your personal information or its deletion '
              'by contacting the IT Helpdesk.'),
            _h('7. Retention'),
            _p('We retain account data for as long as you remain a student '
              'or staff member, plus a limited period afterwards as required '
              'for record-keeping. Deletion requests are honoured within 30 '
              'days unless the law requires otherwise.'),
            _h('8. AI Features'),
            _p('Messages you send to AI-assisted features are processed to '
              'generate replies. Conversations may be retained in your own '
              'account history. We do not use your personal messages to '
              'train third-party models.'),
            _h('9. Children'),
            _p('The App is not intended for users under 16. If you believe a '
              'minor has registered without consent, please contact the '
              'Helpdesk immediately.'),
            _h('10. Changes'),
            _p('We may update this Policy. Material changes will be '
              'announced in-app at least 14 days before they take effect.'),
            _h('11. Contact'),
            _p('Privacy questions or requests: privacy@taylorscollege.edu.au '
              'or the Taylors College Sydney IT Helpdesk.'),
            const SizedBox(height: 40),
          ],
        )),
      ]),
    );
  }

  Widget _h(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(t, style: TextStyle(
        fontFamily: 'Arch', fontWeight: FontWeight.bold,
        fontSize: 15, color: _text)),
  );
  Widget _p(String t) => Text(t, style: TextStyle(
      fontFamily: 'Momo', fontSize: 13, color: _sub, height: 1.6));
}