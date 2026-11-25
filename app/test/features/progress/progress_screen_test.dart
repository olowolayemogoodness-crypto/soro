import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soro/features/progress/progress_data.dart';
import 'package:soro/features/progress/progress_screen.dart';
import 'package:soro/features/progress/progress_strings.dart';

void main() {
  group('currentStreak', () {
    final today = DateTime(2026, 11, 25);
    DateTime d(int back) => today.subtract(Duration(days: back));

    test('counts consecutive days ending today', () {
      expect(currentStreak([d(0), d(1), d(2)], today), 3);
    });
    test('stays alive when today is not done yet', () {
      expect(currentStreak([d(1), d(2)], today), 2);
    });
    test('a missed day resets to zero', () {
      expect(currentStreak([d(2), d(3)], today), 0);
    });
    test('a gap ends the run', () {
      expect(currentStreak([d(0), d(1), d(3)], today), 2);
    });
  });

  testWidgets('renders seeded data, streak badge and unaided checks', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ProgressScreen(data: ProgressData.sample(today: DateTime(2026, 11, 25)))));

    expect(find.text('My progress'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('5'), findsWidgets); // streak counter
    expect(find.text('Sample data'), findsOneWidget);
    expect(find.text('Passed on your own'), findsWidgets);
    expect(find.text('Not enough attempts yet · based on 1 attempt'), findsOneWidget);
  });

  testWidgets('Parent view switches the wording and shows the consent note', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ProgressScreen(data: ProgressData.sample(today: DateTime(2026, 11, 25)))));

    expect(find.textContaining('Hi Ada'), findsOneWidget);
    expect(find.textContaining('agreed to share'), findsNothing);

    await tester.tap(find.text('Parent view'));
    await tester.pumpAndSettle();

    expect(find.text("Ada's progress"), findsOneWidget);
    expect(find.textContaining('agreed to share'), findsOneWidget);
    expect(find.text('Weekly email to parents'), findsOneWidget);
  });

  testWidgets('language slot switches to Yoruba and flags it for a native check', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: ProgressScreen(data: ProgressData.sample(today: DateTime(2026, 11, 25)), initialLang: ProgressLang.yo)));

    expect(find.text('Ìlọsíwájú mi'), findsOneWidget);
    expect(find.text('Yorùbá text: needs native check'), findsOneWidget);
    expect(progressRoutePath, '/progress');
  });
}
