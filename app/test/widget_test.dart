import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets(
    'Soro home shell renders ask-anything composer, switches language to Yoruba, cycles network status, opens board on ask, and keeps My progress hidden by default',
    (WidgetTester tester) async {
      // Test at Android tablet landscape resolution (1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SoroApp());
      await tester.pumpAndSettle();

      // 1. Home screen renders greeting, ask-anything box, and suggested topic chips
      expect(find.byKey(const Key('greeting-headline')), findsOneWidget);
      expect(find.text('What shall we solve together?'), findsOneWidget);
      expect(find.byKey(const Key('ask-anything-composer')), findsOneWidget);
      expect(find.byKey(const Key('topic-chip-quadratic')), findsOneWidget);
      expect(find.byKey(const Key('topic-chip-friction')), findsOneWidget);
      expect(find.byKey(const Key('topic-chip-pdf')), findsOneWidget);

      // 2. Statistics / My progress entry is hidden by default on the home screen
      expect(find.byKey(const Key('my-progress-entry-button')), findsNothing);

      // Reveal hidden My progress entry via subtle more-options toggle and navigate
      await tester.tap(find.byKey(const Key('more-options-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my-progress-entry-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('my-progress-entry-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-placeholder-card')), findsOneWidget);

      // Return to home chat
      await tester.tap(find.byKey(const Key('progress-back-button')));
      await tester.pumpAndSettle();

      // 3. Plain-word network status cycles through 'Live', 'Weak signal: voice only', 'Offline'
      expect(find.text('Live'), findsOneWidget);
      await tester.tap(find.byKey(const Key('network-status-pill')));
      await tester.pumpAndSettle();
      expect(find.text('Weak signal: voice only'), findsOneWidget);
      await tester.tap(find.byKey(const Key('network-status-pill')));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      await tester.tap(find.byKey(const Key('network-status-pill')));
      await tester.pumpAndSettle();
      expect(find.text('Live'), findsOneWidget);

      // 4. Language selector switches to Yorùbá (flagged needsNativeCheck in code only, not on screen)
      await tester.tap(find.byKey(const Key('lang-yo-button')));
      await tester.pumpAndSettle();
      expect(find.text('Kí ni kí á jọ yanju lónìí?'), findsOneWidget);
      expect(find.textContaining('needs native check'), findsNothing);

      // Switch back to English
      await tester.tap(find.byKey(const Key('lang-en-button')));
      await tester.pumpAndSettle();

      // 5. Stylus handwriting pad opens and accepts stylus pointer events
      await tester.ensureVisible(find.byKey(const Key('composer-stylus-button')));
      await tester.tap(find.byKey(const Key('composer-stylus-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stylus-handwriting-pad')), findsOneWidget);

      final TestGesture stylusGesture = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
      );
      final Offset padCenter =
          tester.getCenter(find.byKey(const Key('stylus-pointer-listener')));
      await stylusGesture.down(padCenter);
      await stylusGesture.moveBy(const Offset(30, 12));
      await stylusGesture.up();
      await tester.pumpAndSettle();

      // Close stylus pad before testing text submission
      await tester.tap(find.byKey(const Key('composer-stylus-button')));
      await tester.pumpAndSettle();

      // 6. Submitting a message appends to chat and opens the placeholder board route
      await tester.ensureVisible(find.byKey(const Key('ask-anything-input')));
      await tester.enterText(
        find.byKey(const Key('ask-anything-input')),
        'Solve x² − 5x + 6 = 0',
      );
      await tester.ensureVisible(find.byKey(const Key('composer-submit-button')));
      await tester.tap(find.byKey(const Key('composer-submit-button')));
      await tester.pumpAndSettle();

      // Verify placeholder board route opened with the submitted problem
      expect(find.byKey(const Key('board-placeholder-card')), findsOneWidget);
      expect(find.byKey(const Key('board-active-question')), findsOneWidget);
      expect(find.text('Solve x² − 5x + 6 = 0'), findsOneWidget);

      // Return to home chat and confirm message was appended to the conversation history
      await tester.tap(find.byKey(const Key('board-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('Solve x² − 5x + 6 = 0'), findsOneWidget);
    },
  );

  testWidgets(
    'Soro home shell renders cleanly at 200% text scale on phone viewport (390x844) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2.0),
            disableAnimations: true,
          ),
          child: const SoroApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('ask-anything-composer')), findsOneWidget);
    },
  );
}
