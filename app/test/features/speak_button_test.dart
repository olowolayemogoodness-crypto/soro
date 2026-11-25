import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/board/board_screen.dart';
import 'package:app/features/board/tutor_script.dart';
import 'package:app/l10n/soro_strings.dart';

import 'speech_fakes.dart';

const String kQuestionEn =
    'Look at the equation. What are the coefficients a, b and c?';
const String kQuestionYoSpoken = 'Wo ìṣedọ́gba náà. Kí ni àwọn nọ́ńbà a, b àti c?';

final Map<String, String> kManifest = <String, String>{
  'en|$kQuestionEn': 'audio/tutor/en_01.mp3',
  'yo|$kQuestionYoSpoken': 'audio/tutor/yo_01.mp3',
};

/// A script that sends one line carrying a server-made clip.
class _ServerClipScript implements TutorScript {
  final StreamController<TutorScriptEvent> _c =
      StreamController<TutorScriptEvent>.broadcast();

  @override
  Stream<TutorScriptEvent> get events => _c.stream;

  @override
  Future<void> start() async {
    _c.add(
      const TutorScriptEvent(
        tutorLine: TutorLinePayload(
          text: 'Write x² + 2x = 1 and move the constant across',
          textYo: '',
          writeDuration: Duration(seconds: 3),
          audioUrl: '/tutor/audio/abc.mp3',
        ),
        turnState: TutorTurnState.studentTurn,
      ),
    );
  }

  @override
  Future<void> submitBlankAnswers({
    required String stepId,
    required Map<String, String> values,
    String inputMethod = 'Typed',
  }) async {}

  @override
  void dispose() => _c.close();
}

Future<void> _pumpBoard(
  WidgetTester tester, {
  required FakeSpeechPlayer player,
  SoroLanguage language = SoroLanguage.en,
  TutorScript? script,
  Map<String, String>? manifest,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BoardScreen(
        language: language,
        networkStatus: SoroNetworkStatus.live,
        activeQuestion: 'Problem: x² − 5x + 6 = 0',
        onLanguageChanged: (_) {},
        onCycleNetworkStatus: () {},
        onBackToChat: () {},
        tutorScript:
            script ??
            DemoQuadraticTutorScript(stepDelay: const Duration(milliseconds: 50)),
        speechPlayer: player,
        spokenClips: clipsFor(manifest ?? kManifest),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Texts on screen that are a non-empty, strictly shorter start of [full].
List<String> _partials(WidgetTester tester, String full) => <String>[
  for (final Text t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null &&
        t.data!.isNotEmpty &&
        t.data!.length < full.length &&
        full.startsWith(t.data!))
      t.data!,
];

void main() {
  testWidgets('tap plays the bundled clip and writes the line over its length', (
    WidgetTester tester,
  ) async {
    final FakeSpeechPlayer player = FakeSpeechPlayer(
      length: const Duration(seconds: 2),
    );
    await _pumpBoard(tester, player: player);
    expect(_partials(tester, kQuestionEn), isEmpty);

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000)); // halfway

    expect(player.played.map((s) => s.toString()), <String>[
      'asset:audio/tutor/en_01.mp3',
    ]);
    final List<String> half = _partials(tester, kQuestionEn);
    expect(half, isNotEmpty, reason: 'the line is being written, not shown whole');
    expect(half.first.length, greaterThan(kQuestionEn.length ~/ 4));
    expect(half.first.length, lessThan(kQuestionEn.length * 3 ~/ 4));
    expect(find.text('Tap to stop'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1500)); // clip and writing done
    expect(_partials(tester, kQuestionEn), isEmpty);
    expect(find.text('Tap to hear Soro'), findsOneWidget);
    expect(find.text('Your turn: say it or write it'), findsOneWidget);
  });

  testWidgets('tapping again while it plays stops the voice and the writing', (
    WidgetTester tester,
  ) async {
    final FakeSpeechPlayer player = FakeSpeechPlayer();
    await _pumpBoard(tester, player: player);

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tap to stop'), findsWidgets);

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(player.stops, 1);
    expect(find.text('Tap to hear Soro'), findsOneWidget);
    expect(_partials(tester, kQuestionEn), isEmpty);
  });

  testWidgets('the clip reaching its end finishes the turn', (
    WidgetTester tester,
  ) async {
    final FakeSpeechPlayer player = FakeSpeechPlayer(
      length: const Duration(seconds: 30), // timer backstop is far away
    );
    await _pumpBoard(tester, player: player);

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tap to stop'), findsWidgets);

    player.finish();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tap to hear Soro'), findsOneWidget);
  });

  testWidgets('a line the server voiced plays its URL and keeps the server length', (
    WidgetTester tester,
  ) async {
    final FakeSpeechPlayer player = FakeSpeechPlayer(
      length: const Duration(seconds: 3),
    );
    await _pumpBoard(tester, player: player, script: _ServerClipScript());

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(player.played.single.toString(), 'url:http://127.0.0.1:8000/tutor/audio/abc.mp3');
    expect(
      _partials(tester, 'Write x² + 2x = 1 and move the constant across'),
      isNotEmpty,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Yoruba mode plays the Yoruba clip', (WidgetTester tester) async {
    final FakeSpeechPlayer player = FakeSpeechPlayer();
    await _pumpBoard(tester, player: player, language: SoroLanguage.yo);

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(player.played.single.toString(), 'asset:audio/tutor/yo_01.mp3');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a line with no recording writes silently and says so', (
    WidgetTester tester,
  ) async {
    final FakeSpeechPlayer player = FakeSpeechPlayer();
    await _pumpBoard(
      tester,
      player: player,
      manifest: const <String, String>{}, // nothing recorded
    );

    await tester.tap(find.byKey(const Key('voice-orb-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(player.played, isEmpty);
    expect(find.byKey(const Key('speak-note')), findsOneWidget);
    expect(find.text('No voice recording for this line yet'), findsOneWidget);
    expect(_partials(tester, kQuestionEn), isNotEmpty, reason: 'still written');
    await tester.pump(const Duration(seconds: 6));
  });
}
