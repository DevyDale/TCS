// Runtime test for the AI assistant's quick-action entry: when opened with an
// initialInput (as the staff Dale chips do), the composer must actually be
// pre-filled with that text, and the attach-file button must be present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tcs_app/widgets/ai_assistant_screen.dart';

void main() {
  testWidgets('initialInput pre-fills the composer + attach button exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(
      home: AiAssistantScreen(
        initialInput: 'Translate this notice into English:',
      ),
    ));
    await tester.pump(); // first frame
    await tester.pump(); // post-frame callback writes the text

    // The composer's controller now holds the chip's starter prompt.
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, 'Translate this notice into English:');

    // The paperclip attach button is on screen.
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);

    // Dispose the screen so its repeating animations don't dangle at teardown.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with no initialInput the composer starts empty', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: AiAssistantScreen()));
    await tester.pump();
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, '');

    await tester.pumpWidget(const SizedBox());
  });
}
