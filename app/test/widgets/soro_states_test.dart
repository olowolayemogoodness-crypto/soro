import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/progress/progress_data.dart';
import 'package:app/features/progress/progress_screen.dart';
import 'package:app/widgets/soro_empty_state.dart';
import 'package:app/widgets/soro_error_state.dart';
import 'package:app/widgets/soro_loading_state.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('SoroEmptyState shows its words and runs its one action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(SoroEmptyState(
      title: 'Your journey starts here',
      message: 'Ask Ìlù a question.',
      actionLabel: 'Ask Ìlù',
      onAction: () => taps++,
    )));
    expect(find.text('Your journey starts here'), findsOneWidget);
    expect(find.text('Ask Ìlù a question.'), findsOneWidget);
    await tester.tap(find.text('Ask Ìlù'));
    expect(taps, 1);
  });

  testWidgets('SoroLoadingState shows a spinner and no action', (tester) async {
    await tester.pumpWidget(_host(const SoroLoadingState()));
    expect(find.text('Getting things ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('SoroErrorState offers Try again and calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(_host(SoroErrorState(onRetry: () => retries++)));
    expect(find.text("That didn't load"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('My progress shows empty, loading and error states', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final today = DateTime(2026, 11, 25);
    final empty = ProgressData(
      studentName: 'Ada',
      today: today,
      week: [for (var i = 6; i >= 0; i--) DayActivity(date: today.subtract(Duration(days: i)), minutes: 0)],
      subjects: const [],
      strengths: const [],
    );

    await tester.pumpWidget(MaterialApp(home: ProgressScreen(data: empty)));
    expect(find.byType(SoroEmptyState), findsOneWidget);
    expect(find.text('Your journey starts here'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: ProgressScreen(loading: true)));
    expect(find.byType(SoroLoadingState), findsOneWidget);

    var retries = 0;
    await tester.pumpWidget(MaterialApp(home: ProgressScreen(failed: true, onRetry: () => retries++)));
    expect(find.byType(SoroErrorState), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
