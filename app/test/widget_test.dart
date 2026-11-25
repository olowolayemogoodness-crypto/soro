import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/board/board_screen.dart';
import 'package:app/features/board/tutor_script.dart';
import 'package:app/l10n/soro_strings.dart';
import 'package:app/main.dart';

void main() {
  testWidgets(
    'Soro home shell renders ask-anything composer, switches language to Yoruba, cycles network status, opens board on ask, and opens My progress in one tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SoroApp(showSplash: false));
      await tester.pumpAndSettle();

      // 1. Home screen renders greeting, ask-anything box, and suggested topic chips
      expect(find.byKey(const Key('greeting-headline')), findsOneWidget);
      expect(find.text('What shall we solve together?'), findsOneWidget);
      expect(find.byKey(const Key('ask-anything-composer')), findsOneWidget);
      expect(find.byKey(const Key('topic-chip-quadratic')), findsOneWidget);
      expect(find.byKey(const Key('topic-chip-friction')), findsOneWidget);
      expect(find.byKey(const Key('topic-chip-pdf')), findsOneWidget);

      // 2. One tap on "My progress" opens the dashboard (no statistics on home)
      expect(find.byKey(const Key('my-progress-entry-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('my-progress-entry-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-screen')), findsOneWidget);
      expect(find.text('My progress'), findsOneWidget);
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

      // 4. Language selector switches to Yorùbá and displays 'needs native check' flag
      await tester.tap(find.byKey(const Key('lang-yo-button')));
      await tester.pumpAndSettle();
      expect(find.text('Kí ni kí á jọ yanju lónìí?'), findsOneWidget);
      expect(find.byKey(const Key('yoruba-native-check-badge')), findsOneWidget);

      await tester.tap(find.byKey(const Key('lang-en-button')));
      await tester.pumpAndSettle();

      // Stylus handwriting pad opens and accepts stylus pointer events
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

      // 5. Submitting a message appends to chat and opens the real Notebook Board screen
      await tester.ensureVisible(find.byKey(const Key('ask-anything-input')));
      await tester.enterText(
        find.byKey(const Key('ask-anything-input')),
        'Solve x² − 5x + 6 = 0',
      );
      await tester.ensureVisible(find.byKey(const Key('composer-submit-button')));
      await tester.tap(find.byKey(const Key('composer-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('board-screen')), findsOneWidget);
      expect(find.byKey(const Key('wooden-board-frame')), findsOneWidget);
      expect(find.byKey(const Key('ruled-notebook-page')), findsOneWidget);
      expect(find.text('Problem: x² − 5x + 6 = 0'), findsWidgets);

      // Return to home chat
      await tester.tap(find.byKey(const Key('board-back-button')));
      await tester.pumpAndSettle();
      expect(find.text('Solve x² − 5x + 6 = 0'), findsOneWidget);
    },
  );

  testWidgets(
    'BoardScreen runs scripted quadratic co-solve end-to-end, voice dock tap-and-hold, stylus palm rejection, and 10s idle tuck-away with Working card',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: BoardScreen(
            language: SoroLanguage.en,
            networkStatus: SoroNetworkStatus.live,
            activeQuestion: 'Problem: x² − 5x + 6 = 0',
            onLanguageChanged: (_) {},
            onCycleNetworkStatus: () {},
            onBackToChat: () {},
            tutorScript: DemoQuadraticTutorScript(
              stepDelay: const Duration(milliseconds: 50),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Step 1: Coefficients a, b, c prompt + analogy line + voice dock turn cue
      expect(find.text('Problem: x² − 5x + 6 = 0'), findsWidgets);
      expect(find.byKey(const Key('board-analogy-line')), findsOneWidget);
      expect(
        find.textContaining(
          'Look at the equation. What are the coefficients a, b and c?',
        ),
        findsWidgets,
      );
      expect(find.text('a = ▢, b = ▢, c = ▢'), findsOneWidget);
      expect(find.text('Your turn: say it or write it'), findsOneWidget);

      // Voice orb tap-and-hold shows 'Listening…'
      final TestGesture orbGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('voice-orb-button'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Listening…'), findsWidgets);
      await orbGesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Your turn: say it or write it'), findsOneWidget);

      // Fill Step 1 coefficients (a=1, b=-5, c=6)
      await tester.enterText(find.byKey(const Key('blank-input-a')), '1');
      await tester.enterText(find.byKey(const Key('blank-input-b')), '-5');
      await tester.enterText(find.byKey(const Key('blank-input-c')), '6');
      await tester.tap(find.byKey(const Key('submit-blank-step-button')));
      await tester.pump(const Duration(milliseconds: 200));

      // Student line appears in blue and Step 2 factoring opens
      expect(find.text('a = 1, b = −5, c = 6'), findsOneWidget);
      expect(
        find.textContaining('Which two numbers multiply to 6 and add to −5?'),
        findsWidgets,
      );
      expect(find.text('(x − ▢)(x − ▢) = 0'), findsOneWidget);

      // Wrong first answer (sign error) gets targeted correction question, never the answer
      await tester.ensureVisible(
        find.byKey(const Key('demo-wrong-sign-button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('demo-wrong-sign-button')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining('Check the sign of the middle term when you expand'),
        findsWidgets,
      );

      // Correct factoring answer via stylus pad with palm rejection
      await tester.ensureVisible(
        find.byKey(const Key('board-toggle-stylus-button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('board-toggle-stylus-button')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(
        find.byKey(const Key('board-stylus-listener')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final Offset padCenter =
          tester.getCenter(find.byKey(const Key('board-stylus-listener')));
      final TestGesture stylus = await tester.createGesture(
        kind: PointerDeviceKind.stylus,
      );
      await stylus.down(padCenter);
      await tester.pump();
      // Palm touch around stylus contact is rejected
      final TestGesture palmTouch = await tester.createGesture(
        kind: PointerDeviceKind.touch,
      );
      await stylus.moveBy(const Offset(35, 10));
      await stylus.up();
      await tester.pump();
      // Palm landing right after the stylus lifts is still rejected
      await palmTouch.down(padCenter + const Offset(10, 10));
      await tester.pump();
      await palmTouch.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('palm-rejected-notice')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('board-apply-stylus-button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('board-apply-stylus-button')));
      await tester.pump(const Duration(milliseconds: 200));

      // Correct badge lights up ('Ó tọ́ · Correct') and roots stay as '?' until student writes x = 2 or x = 3 in blue
      expect(find.text('Ó tọ́ · Correct'), findsWidgets);
      expect(find.text('roots: x = ? , x = ?'), findsOneWidget);

      // Student writes roots x = 2, x = 3 in blue
      await tester.ensureVisible(find.byKey(const Key('blank-input-r1')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byKey(const Key('blank-input-r1')), '2');
      await tester.enterText(find.byKey(const Key('blank-input-r2')), '3');
      await tester.ensureVisible(
        find.byKey(const Key('submit-blank-step-button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('submit-blank-step-button')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('x = 2 or x = 3'), findsOneWidget);
      expect(find.text('roots: x = 2 ✓ , x = 3 ✓'), findsOneWidget);

      // Unaided check appears: 'Now try x² − 7x + 12 = 0 on your own'
      expect(
        find.textContaining('Now try x² − 7x + 12 = 0 on your own'),
        findsWidgets,
      );

      // After 10 seconds idle with no touch, pen or voice, the board tucks away and shows 'Working' card
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 11));
      await tester.pump(const Duration(seconds: 11));
      expect(find.byKey(const Key('working-reopen-card')), findsOneWidget);

      // Reopen board from 'Working' card and pin it open
      await tester.tap(find.byKey(const Key('working-reopen-button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('wooden-board-frame')), findsOneWidget);

      await tester.tap(find.byKey(const Key('board-pin-button')));
      await tester.pump(const Duration(seconds: 12));
      // Pinned board stays open past 10 seconds
      expect(find.byKey(const Key('wooden-board-frame')), findsOneWidget);
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
          child: const SoroApp(showSplash: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('ask-anything-composer')), findsOneWidget);
    },
  );
}
