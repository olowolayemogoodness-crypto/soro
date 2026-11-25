import 'package:app/features/board/board_screen.dart';
import 'package:app/features/board/solve_intent.dart';
import 'package:app/features/board/tutor_pen_writer.dart';
import 'package:app/features/board/tutor_script.dart';
import 'package:app/l10n/soro_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isSolveIntent matches explicit solve requests only', () {
    expect(isSolveIntent('Solve this for me'), isTrue);
    expect(isSolveIntent('please show me how'), isTrue);
    expect(isSolveIntent('Just solve it!'), isTrue);
    expect(isSolveIntent("don't solve it, I want to try"), isFalse);
    expect(isSolveIntent('Help me solve x² − 5x + 6 = 0 step by step'), isFalse);
    expect(
      isSolveIntent('Show me how to start without giving the final roots'),
      isFalse,
    );
    expect(isSolveIntent(''), isFalse);
  });

  test('pen layout writes strokes, a hand-drawn box per blank, in order', () {
    const HandwritingPen pen = HandwritingPen();
    final PenLayout l = pen.writeText(
      'x² − 7x + 12 = 0  ⇒  x = ▢ or x = ▢',
      maxWidth: 900,
      rule: 36,
    );
    expect(l.strokes, isNotEmpty);
    expect(l.blanks, hasLength(2));
    expect(l.blanks.first.left, lessThan(l.blanks.last.left));
    expect(l.seconds, inInclusiveRange(0.45, 2.4));
    expect(l.strokes.last.t1, closeTo(1.0, 1e-9));
    final PenLayout long = pen.writeText('word ' * 40, maxWidth: 300, rule: 36);
    expect(long.rows, greaterThan(1));
  });

  testWidgets('Show me how makes the pen write the full solution', (tester) async {
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
            stepDelay: const Duration(milliseconds: 20),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('blank-input-a')), findsOneWidget);

    await tester.tap(find.byKey(const Key('show-me-how-button')));
    await tester.pump(const Duration(milliseconds: 100));
    // Guide-mode blanks are dropped while the tutor writes the solution
    expect(find.byKey(const Key('blank-input-a')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    // Ends back in guide mode with the unaided problem and fillable blanks
    expect(find.byKey(const Key('blank-input-u1')), findsOneWidget);
    expect(find.byKey(const Key('blank-input-u2')), findsOneWidget);
    expect(find.textContaining('Now you try'), findsWidgets);
    expect(find.text('roots: x = 2 ✓ , x = 3 ✓'), findsOneWidget);
  });

  testWidgets('reduced motion shows tutor ink finished at once', (tester) async {
    const HandwritingPen pen = HandwritingPen();
    final PenLayout layout =
        pen.writeText('Look at the equation', maxWidth: 600, rule: 36);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PenInk(layout: layout, color: Colors.red),
        ),
      ),
    );
    final CustomPaint cp = tester.widget(find.byType(CustomPaint).last);
    expect((cp.painter! as PenInkPainter).progress, 1.0);
  });
}
