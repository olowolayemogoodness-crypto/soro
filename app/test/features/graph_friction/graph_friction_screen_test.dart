import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/graph_friction/graph_friction_screen.dart';

void main() {
  group('A4 GraphFrictionScreen & CanvasBridgeController', () {
    testWidgets(
      'Dragging b updates the curve without printing the answers; roots and vertex stay as ? until student finds them',
      (WidgetTester tester) async {
        final receivedActions = <StudentAction>[];
        var fakeTime = DateTime(2026, 11, 25, 12, 0, 0);
        final controller = CanvasBridgeController(
          clock: () => fakeTime,
          onStudentAction: receivedActions.add,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GraphFrictionScreen(controller: controller),
          ),
        );

        // Initially y = 1x^2 - 2x - 3 -> roots are -1 and 3, vertex is (1, -4),
        // but they must stay hidden behind '?' markers!
        expect(find.byKey(const Key('root_1_marker_label')), findsOneWidget);
        expect(find.text('root 1: ?'), findsOneWidget);
        expect(find.text('root 2: ?'), findsOneWidget);
        expect(find.text('vertex: ?'), findsOneWidget);
        expect(find.textContaining('−1 ✓'), findsNothing);
        expect(find.textContaining('(1, −4)'), findsNothing);

        // Drag coefficient b to 0.0 (y = x^2 - 3)
        fakeTime = fakeTime.add(const Duration(milliseconds: 250));
        controller.dragCoefficient('b', 0.0);
        await tester.pump();

        expect(controller.b, equals(0.0));
        expect(controller.rootsRevealed, isFalse);
        expect(controller.vertexRevealed, isFalse);
        expect(find.text('root 1: ?'), findsOneWidget);
        expect(find.text('root 2: ?'), findsOneWidget);
        expect(find.text('vertex: ?'), findsOneWidget);
        expect(receivedActions.isNotEmpty, isTrue);
        expect(receivedActions.last.action, equals('drag_coefficient'));
        expect(receivedActions.last.params['coeff'], equals('b'));

        // Reset to y = 1x^2 - 2x - 3 and let student reveal the found answers in blue
        controller.applyQuadraticPreset(a: 1.0, b: -2.0, c: -3.0);
        await tester.pump();

        fakeTime = fakeTime.add(const Duration(milliseconds: 250));
        controller.setStudentFoundAnswers(revealed: true);
        await tester.pump();

        expect(controller.rootsRevealed, isTrue);
        expect(controller.vertexRevealed, isTrue);
        expect(find.text('root 1: −1 ✓'), findsOneWidget);
        expect(find.text('root 2: 3 ✓'), findsOneWidget);
        expect(find.text('vertex: (1, −4) ✓'), findsOneWidget);

        // Dragging b again must hide the new answers back to '?' markers
        fakeTime = fakeTime.add(const Duration(milliseconds: 250));
        controller.dragCoefficient('b', -4.0);
        await tester.pump();

        expect(controller.rootsRevealed, isFalse);
        expect(find.text('root 1: ?'), findsOneWidget);
        expect(find.text('vertex: ?'), findsOneWidget);
      },
    );

    testWidgets(
      'canvas_cmd moves the friction sim and updates surface and PhET bridge',
      (WidgetTester tester) async {
        final controller = CanvasBridgeController();

        await tester.pumpWidget(
          MaterialApp(
            home: GraphFrictionScreen(controller: controller),
          ),
        );

        final initialPos = controller.cratePositionM;
        expect(controller.surface, equals(FrictionSurface.wood));

        // Tutor sends canvas_cmd to push the crate and change surface to wet_road
        controller.handleCanvasCmd(<String, dynamic>{
          'v': 1,
          'type': 'canvas_cmd',
          'sim': 'friction-illustration',
          'visual': 'friction-crate',
          'op': 'push_crate',
          'params': <String, dynamic>{
            'force_n': 180.0,
            'surface': 'wet_road',
          },
        });
        await tester.pump();

        expect(controller.surface, equals(FrictionSurface.wetRoad));
        expect(controller.cratePositionM, greaterThan(initialPos));
        expect(controller.simMoveCount, greaterThan(0));
        expect(controller.lastCanvasCmd?.cmd, equals('push_crate'));
      },
    );

    test(
      'student drags reach the agent and student_action is throttled to at most 5 per second',
      () {
        final actions = <StudentAction>[];
        var currentMs = 100000;
        final controller = CanvasBridgeController(
          clock: () => DateTime.fromMillisecondsSinceEpoch(currentMs),
          onStudentAction: actions.add,
        );

        // Simulate 25 rapid student drag events across 1000 ms (one every 40 ms).
        for (int i = 0; i < 25; i++) {
          controller.studentDragFriction(
            forceN: 50.0 + i * 5,
            positionDeltaM: 0.05,
          );
          currentMs += 40;
        }

        // Must be throttled to at most 5 actions within that 1-second window!
        expect(actions.length, equals(5));
        expect(controller.throttledDropCount, equals(20));
        expect(actions.first.target, equals('friction'));

        // After advancing past the 1-second window, a new drag is emitted.
        currentMs += 250;
        controller.studentDragFriction(forceN: 180.0);
        expect(actions.length, equals(6));
      },
    );

    testWidgets(
      'Renders at Android tablet (1280x800) and phone (390x844) with language slot switch and PhET Yoruba build',
      (WidgetTester tester) async {
        // 1. Android tablet landscape (1280x800)
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = CanvasBridgeController();
        await tester.pumpWidget(
          MaterialApp(
            home: GraphFrictionScreen(controller: controller),
          ),
        );

        expect(
          GraphFrictionStrings.parabolaTutorPrompt.needsNativeCheck,
          isTrue,
        );
        expect(
          find.text('✓ PhET Yorùbá build active (_yo.html)'),
          findsOneWidget,
        );

        // Toggle language slot to English-only
        await tester.tap(find.byKey(const Key('lang_slot_toggle_btn')));
        await tester.pump();

        expect(controller.showYoruba, isFalse);
        expect(
          find.text('PhET English build active (_en.html)'),
          findsOneWidget,
        );

        // 2. Phone portrait (390x844)
        tester.view.physicalSize = const Size(390, 844);
        await tester.pump();

        expect(find.byKey(const Key('parabola_graph_card')), findsOneWidget);
        expect(
          find.byKey(const Key('friction_illustration_card')),
          findsOneWidget,
        );
      },
    );
  });
}
