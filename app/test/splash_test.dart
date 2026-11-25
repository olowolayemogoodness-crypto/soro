import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('splash shows first, finishes under 1.5s, then home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SoroApp());
    expect(find.byKey(const Key('soro-splash')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('soro-splash')), findsNothing);
    expect(find.byKey(const Key('greeting-headline')), findsOneWidget);

    // Reopened in the same session: splash is skipped.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const SoroApp());
    expect(find.byKey(const Key('soro-splash')), findsNothing);
  });
}
