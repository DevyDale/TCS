import 'package:flutter/material.dart';
import 'package:tcs_app/theme/app_colors.dart';
import 'package:tcs_app/widgets/t_text.dart';

class AboutApplicationScreen extends StatefulWidget {
  const AboutApplicationScreen({super.key});
  @override
  State<AboutApplicationScreen> createState() => _AboutApplicationScreenState();
}

class _AboutApplicationScreenState extends State<AboutApplicationScreen> {
  Color get _bg   => AppC.bg;
  Color get _card => AppC.card;
  Color get _text => AppC.text;
  Color get _sub  => AppC.sub;

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
            T('About Application', style: TextStyle(
                fontFamily: 'Alfa', fontSize: 22, color: _text)),
          ]),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF8E54E9), Color(0xFF6DD5FA)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF8E54E9).withOpacity(0.4),
                    blurRadius: 20, offset: const Offset(0, 8))]),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 52),
            )),
            const SizedBox(height: 18),
            Center(child: T('TCS',
                style: TextStyle(fontFamily: 'Alfa', fontSize: 24, color: _text))),
            const SizedBox(height: 4),
            Center(child: T('Version 5.0',
                style: TextStyle(fontFamily: 'Momo', fontSize: 13, color: _sub))),
            const SizedBox(height: 28),
            _card2([
              _h('What is TCS?'),
              _p('TCS is the official student companion app for '
                'Taylors College Sydney. It brings together everything '
                'you need to stay connected with the college and your '
                'peers — campus announcements, study groups, peer chat, '
                'and AI-assisted study help — in one place.'),
              _h('Key Features'),
              _b('Real-time campus announcements and highlights'),
              _b('Study groups for every course and year level'),
              _b('Peer-to-peer chat with read receipts'),
              _b('AI study buddy to help you understand tricky concepts'),
              _b('Multilingual interface (English, Bahasa Malaysia, '
                  'Chinese, Japanese, Korean, Arabic)'),
              _b('Customisable privacy and notification controls'),
              _b('Light and dark themes'),
              _h('Version 5.0 Highlights'),
              _p('• Added Japanese and Korean language support\n'
                '• App-wide dark mode with improved contrast\n'
                '• Push notifications now arrive even when the app is closed\n'
                '• More granular notification controls\n'
                '• Better privacy controls for online status and discoverability\n'
                '• New About and legal information screens'),
              _h('Built For'),
              _p('Taylors College Sydney students, staff, and authorised '
                'guests. Available on Android and iOS.'),
            ]),
            const SizedBox(height: 40),
          ],
        )),
      ]),
    );
  }

  Widget _card2(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: AppC.shadow,
            blurRadius: 12, offset: const Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );
  Widget _h(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: TextStyle(fontFamily: 'Arch',
        fontWeight: FontWeight.bold, fontSize: 15, color: _text)),
  );
  Widget _p(String t) => Text(t, style: TextStyle(
      fontFamily: 'Momo', fontSize: 13, color: _sub, height: 1.6));
  Widget _b(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('•  $t', style: TextStyle(
        fontFamily: 'Momo', fontSize: 13, color: _sub, height: 1.5)),
  );
}