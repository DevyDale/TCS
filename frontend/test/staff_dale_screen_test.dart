// Runtime widget test for the staff Dale page: renders the REAL screen and
// drives every interactive element, asserting each one actually responds.
//   • prompt bar + 4 suggestion chips  → request navigation (Ask Dale)
//   • Train Dale card                  → requests navigation (knowledge)
//   • 2 "Soon" tiles                   → show their "coming soon" snackbar
// Navigation targets run infinite animations + network on load, so we observe
// the route push rather than settling into them, then pop back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcs_app/screens/staff/staff_dale_screen.dart';

class _PushSpy extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

void main() {
  late _PushSpy spy;

  Future<void> pumpPage(WidgetTester tester) async {
    spy = _PushSpy();
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [spy],
      home: const StaffDaleScreen(),
    ));
    await tester.pump(); // first frame
    spy.pushes = 0; // ignore the initial home route push
  }

  // Tap something that navigates, confirm a push happened, then pop back so the
  // next control on the page is hittable again.
  Future<void> tapNav(WidgetTester tester, Finder target, String label) async {
    final before = spy.pushes;
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump(); // build + push the destination (don't settle it)
    expect(spy.pushes, before + 1, reason: '"$label" did not navigate');
    // Return to the Dale page for the next assertion.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Dale page renders every widget', (tester) async {
    await pumpPage(tester);

    expect(find.text("Hi, I'm Dale"), findsOneWidget);
    expect(find.text('Ask Dale anything…'), findsOneWidget);
    // Chips live in a lazy horizontal list; scroll each into view to confirm
    // all four are real (off-screen ones aren't built until revealed).
    final chipRow = find.ancestor(
      of: find.text('Draft an announcement'),
      matching: find.byType(Scrollable),
    ).first;
    for (final c in const [
      'Draft an announcement',
      'Summarise a policy',
      'Plan a lesson',
      'Translate a notice',
    ]) {
      await tester.scrollUntilVisible(find.text(c), 120, scrollable: chipRow);
      expect(find.text(c), findsOneWidget, reason: 'chip "$c" missing');
    }
    expect(find.text('Train Dale'), findsOneWidget);
    expect(find.text('What students ask'), findsOneWidget);
    expect(find.text('Quiz curation'), findsOneWidget);
    expect(find.text('SOON'), findsNWidgets(2));
  });

  testWidgets('prompt bar navigates to Ask Dale', (tester) async {
    await pumpPage(tester);
    await tapNav(tester, find.text('Ask Dale anything…'), 'prompt bar');
  });

  testWidgets('every suggestion chip navigates', (tester) async {
    await pumpPage(tester);
    for (final c in const [
      'Draft an announcement',
      'Summarise a policy',
      'Plan a lesson',
      'Translate a notice',
    ]) {
      await tapNav(tester, find.text(c), 'chip $c');
    }
  });

  testWidgets('Train Dale navigates', (tester) async {
    await pumpPage(tester);
    await tapNav(tester, find.text('Train Dale'), 'Train Dale card');
  });

  testWidgets('Soon tiles each show a coming-soon snackbar', (tester) async {
    await pumpPage(tester);

    final whatAsk = find.text('What students ask');
    await tester.ensureVisible(whatAsk);
    await tester.pump();
    await tester.tap(whatAsk);
    await tester.pump(); // snackbar animates in
    expect(find.text('What students ask — coming soon'), findsOneWidget);
    expect(spy.pushes, 0, reason: 'Soon tile must NOT navigate');

    final quiz = find.text('Quiz curation');
    await tester.ensureVisible(quiz);
    await tester.pump();
    await tester.tap(quiz);
    await tester.pump();
    expect(find.text('Quiz curation — coming soon'), findsOneWidget);

    // Let the floating snackbar finish so no timers dangle at teardown.
    await tester.pump(const Duration(seconds: 3));
  });
}
