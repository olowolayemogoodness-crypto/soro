import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/board/spoken_clips.dart';
import 'package:app/features/board/tutor_script.dart';
import 'package:app/features/board/typing_text.dart';
import 'package:app/l10n/soro_strings.dart';

import 'speech_fakes.dart';

void main() {
  group('spokenYoruba', () {
    test('drops the review flag', () {
      expect(
        spokenYoruba('Wo ìṣedọ́gba náà. Kí ni a, b àti c? [needs native check]'),
        'Wo ìṣedọ́gba náà. Kí ni a, b àti c?',
      );
    });

    test('keeps only the Yorùbá after the English lead-in', () {
      expect(
        spokenYoruba('roots are where a ball lands · gbòngbò dà bí ibi tí bọ́ọ̀lù bá bàlẹ̀ sí'),
        'gbòngbò dà bí ibi tí bọ́ọ̀lù bá bàlẹ̀ sí',
      );
    });
  });

  group('SpokenClips.sourceFor', () {
    test('a server clip wins and a relative path joins the API base', () async {
      final SpokenClips clips = clipsFor(<String, String>{'en|hi': 'audio/tutor/en_00.mp3'});
      await clips.load();
      expect(
        clips.sourceFor(language: SoroLanguage.en, text: 'hi', audioUrl: '/tutor/audio/x.mp3').toString(),
        'url:http://127.0.0.1:8000/tutor/audio/x.mp3',
      );
      expect(
        clips.sourceFor(language: SoroLanguage.en, text: 'hi', audioUrl: 'https://h/x.mp3').toString(),
        'url:https://h/x.mp3',
      );
    });

    test('finds a bundled clip by exact text, ignoring extra spaces', () async {
      final SpokenClips clips = clipsFor(<String, String>{'yo|Báwo ni': 'audio/tutor/yo_00.mp3'});
      await clips.load();
      expect(
        clips.sourceFor(language: SoroLanguage.yo, text: '  Báwo   ni ').toString(),
        'asset:audio/tutor/yo_00.mp3',
      );
      expect(clips.sourceFor(language: SoroLanguage.en, text: 'Báwo ni'), isNull);
      expect(clips.sourceFor(language: SoroLanguage.yo, text: 'other'), isNull);
    });

    test('a broken manifest means no bundled clips, not a crash', () async {
      final SpokenClips clips = SpokenClips(manifestLoader: () async => throw Exception('boom'));
      await clips.load();
      expect(clips.sourceFor(language: SoroLanguage.en, text: 'hi'), isNull);
    });
  });

  group('bundled recordings', () {
    final Map<String, dynamic> manifest =
        jsonDecode(File('assets/audio/tutor/manifest.json').readAsStringSync())
            as Map<String, dynamic>;

    test('every manifest entry points at a real file', () {
      expect(manifest, isNotEmpty);
      for (final MapEntry<String, dynamic> e in manifest.entries) {
        expect(
          File('assets/${e.value}').existsSync(),
          isTrue,
          reason: '${e.key} -> ${e.value} is missing',
        );
      }
    });

    test('every scripted tutor line has an English and a Yorùbá recording', () async {
      final DemoQuadraticTutorScript script = DemoQuadraticTutorScript(stepDelay: Duration.zero);
      final Map<String, String> yoOf = <String, String>{};
      script.events.listen((TutorScriptEvent e) {
        final TutorLinePayload? l = e.tutorLine;
        if (l != null && l.text != '✓') yoOf[l.text] = spokenYoruba(l.textYo);
      });
      await script.start();
      for (final List<Object> c in <List<Object>>[
        <Object>[QuadraticStepIds.coefficients, <String, String>{'a': '1', 'b': '5', 'c': '6'}],
        <Object>[QuadraticStepIds.coefficients, <String, String>{'a': '1', 'b': '-5', 'c': '6'}],
        <Object>[QuadraticStepIds.factors, <String, String>{'f1': '-2', 'f2': '-3'}],
        <Object>[QuadraticStepIds.factors, <String, String>{'f1': '2', 'f2': '3'}],
        <Object>[QuadraticStepIds.roots, <String, String>{'r1': '1', 'r2': '6'}],
        <Object>[QuadraticStepIds.roots, <String, String>{'r1': '2', 'r2': '3'}],
        <Object>[QuadraticStepIds.unaided, <String, String>{'u1': '1', 'u2': '2'}],
        <Object>[QuadraticStepIds.unaided, <String, String>{'u1': '3', 'u2': '4'}],
      ]) {
        await script.submitBlankAnswers(
          stepId: c[0] as String,
          values: c[1] as Map<String, String>,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      script.dispose();

      expect(yoOf.length, greaterThanOrEqualTo(10));
      for (final MapEntry<String, String> line in yoOf.entries) {
        expect(
          manifest.containsKey('en|${line.key.trim().replaceAll(RegExp(r'\s+'), ' ')}'),
          isTrue,
          reason: 'no English recording for: ${line.key}. Re-record the clips.',
        );
        expect(
          manifest.containsKey('yo|${line.value.trim().replaceAll(RegExp(r'\s+'), ' ')}'),
          isTrue,
          reason: 'no Yorùbá recording for: ${line.value}. Re-record the clips.',
        );
      }
    });
  });

  group('TypingText.visibleCount', () {
    test('reveals in proportion to progress and clamps', () {
      expect(TypingText.visibleCount('hello', 0), 0);
      expect(TypingText.visibleCount('hello', 0.5), 2);
      expect(TypingText.visibleCount('hello', 1), 5);
      expect(TypingText.visibleCount('hello', 3), 5);
      expect(TypingText.visibleCount('hello', -1), 0);
    });

    test('counts a letter with its tone mark as one character', () {
      expect(TypingText.visibleCount('ọ̀ọ̀', 0.5), 1);
    });
  });
}
