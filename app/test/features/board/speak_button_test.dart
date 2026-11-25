import 'package:app/features/board/board_screen.dart';
import 'package:app/features/board/tutor_script.dart';
import 'package:app/features/board/tutor_speaker.dart';
import 'package:app/l10n/soro_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeaker implements TutorSpeaker {
  final List<String> spoken = <String>[];
  int stops = 0;
  @override
  final ValueNotifier<bool> speaking = ValueNotifier<bool>(false);
  @override
  bool muted = false;

  @override
  Future<void> speak(String text, {String? audioUrl}) async {
    if (!muted) spoken.add(text);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  void dispose() {}
}

Future<FakeSpeaker> _pumpBoard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final FakeSpeaker speaker = FakeSpeaker();
  await tester.pumpWidget(
    MaterialApp(
      home: BoardScreen(
        language: SoroLanguage.en,
        networkStatus: SoroNetworkStatus.live,
        activeQuestion: 'Problem: x² − 5x + 6 = 0',
        onLanguageChanged: (_) {},
        onCycleNetworkStatus: () {},
        onBackToChat: () {},
        speaker: speaker,
        tutorScript: DemoQuadraticTutorScript(
          stepDelay: const Duration(milliseconds: 20),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return speaker;
}

void main() {
  testWidgets('Hear Soro on a board line speaks that line, 48 px tall', (
    tester,
  ) async {
    final FakeSpeaker speaker = await _pumpBoard(tester);
    final Finder btn = find.byKey(const Key('hear-soro-entry-0'));
    expect(btn, findsOneWidget);
    expect(
      tester
          .getSize(
            find.descendant(of: btn, matching: find.byType(SizedBox)).first,
          )
          .height,
      48,
    );
    await tester.tap(btn);
    await tester.pump();
    expect(speaker.spoken, hasLength(1));
    expect(speaker.spoken.single, isNotEmpty);
  });

  testWidgets('dock Hear Soro speaks the caption, Read it to me speaks all, '
      'press again stops, mute silences', (tester) async {
    final FakeSpeaker speaker = await _pumpBoard(tester);
    await tester.tap(find.byKey(const Key('hear-soro-dock')));
    await tester.pump();
    expect(speaker.spoken, hasLength(1));

    await tester.tap(find.byKey(const Key('read-it-to-me')));
    await tester.pump();
    expect(speaker.spoken, hasLength(2));
    expect(
      speaker.spoken.last.length,
      greaterThan(speaker.spoken.first.length),
    );

    await tester.tap(find.byKey(const Key('mute-toggle')));
    await tester.pump();
    expect(speaker.muted, isTrue);
    expect(speaker.stops, greaterThan(0));
    await tester.tap(find.byKey(const Key('hear-soro-dock')));
    await tester.pump();
    expect(speaker.spoken, hasLength(2));
  });
}
