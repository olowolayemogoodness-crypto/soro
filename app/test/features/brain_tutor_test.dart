import 'dart:async';
import 'dart:convert';

import 'package:app/features/board/brain_tutor_script.dart';
import 'package:app/features/board/tutor_client.dart';
import 'package:app/features/board/tutor_script.dart';
import 'package:app/l10n/soro_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _guideBody = '''
{"session_id":"s1","step_id":"s2","say":"What do we add?",
 "board":[{"op":"write","text":"x^2 + 2x = 1"},
          {"op":"blank","text":"x^2 + 2x + [ ] = 1 + [ ]"},
          {"op":"mark","kind":"tick","target":"last"}],
 "analogy":"A missing tile","done":false,"source":"gemini"}''';

TutorClient _client(MockClientHandler h, {Duration? timeout}) => TutorClient(
  httpClient: MockClient(h),
  baseUrl: 'http://test',
  timeout: timeout ?? const Duration(milliseconds: 100),
);

BrainTutorScript _script(TutorClient c, String q) => BrainTutorScript(
  client: c,
  question: q,
  language: SoroLanguage.en,
  fallback: DemoQuadraticTutorScript(stepDelay: Duration.zero),
);

Future<List<TutorScriptEvent>> _collect(BrainTutorScript s) async {
  final List<TutorScriptEvent> out = <TutorScriptEvent>[];
  s.events.listen(out.add);
  await s.start();
  await Future<void>.delayed(Duration.zero);
  return out;
}

void main() {
  audioTests();
  test('parses a valid turn reply', () {
    final TutorTurnResponse r = TutorTurnResponse.parse(_guideBody);
    expect(r.stepId, 's2');
    expect(r.say, 'What do we add?');
    expect(r.board.map((BoardOp o) => o.op), <String>[
      'write',
      'blank',
      'mark',
    ]);
    expect(r.source, 'gemini');
  });

  test('rejects invalid JSON and wrong shapes', () {
    expect(
      () => TutorTurnResponse.parse('nope'),
      throwsA(isA<TutorClientException>()),
    );
    expect(
      () => TutorTurnResponse.parse('{"say":1}'),
      throwsA(isA<TutorClientException>()),
    );
  });

  test('wantsSolve routes solve intent but not a guidance question', () {
    expect(wantsSolve('Please solve this for me'), isTrue);
    expect(wantsSolve('Show me how'), isTrue);
    expect(wantsSolve('just solve it'), isTrue);
    expect(wantsSolve('How do I solve x2 + 2x = 1'), isFalse);
    expect(wantsSolve('Help me solve this'), isFalse);
  });

  test('first turn posts the contract and maps reply to events', () async {
    late Map<String, dynamic> sent;
    final BrainTutorScript s = _script(
      _client((http.Request req) async {
        expect(req.url.path, '/tutor/turn');
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(_guideBody, 200);
      }),
      'How do I solve x2 + 2x = 1',
    );
    final List<TutorScriptEvent> ev = await _collect(s);
    expect(sent['mode'], 'guide');
    expect(sent['text'], 'How do I solve x2 + 2x = 1');
    expect(sent['problem'], 'How do I solve x2 + 2x = 1');
    expect(sent['lang'], 'en');
    expect(ev.first.thinking, isTrue);
    final TutorScriptEvent last = ev.last;
    expect(last.caption, 'What do we add?');
    expect(last.blankRow!.templateText, 'x^2 + 2x + ▢ = 1 + ▢');
    expect(last.blankRow!.blanks, hasLength(2));
    expect(ev.where((e) => e.tutorLine?.text == 'x^2 + 2x = 1'), isNotEmpty);
    expect(ev.any((e) => e.offline == true), isFalse);
  });

  test('solve intent sends mode=solve', () async {
    String? mode;
    final BrainTutorScript s = _script(
      _client((http.Request req) async {
        mode = (jsonDecode(req.body) as Map<String, dynamic>)['mode'] as String;
        return http.Response(_guideBody, 200);
      }),
      'Show me how to do x^2 + 2x = 1',
    );
    await _collect(s);
    expect(mode, 'solve');
  });

  test(
    'timeout falls back to the scripted tutor with the offline flag',
    () async {
      final BrainTutorScript s = _script(
        _client(
          (http.Request req) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ),
        'x^2 - 5x + 6 = 0',
      );
      final List<TutorScriptEvent> ev = await _collect(s);
      expect(ev.any((e) => e.offline == true), isTrue);
      expect(
        ev.any((e) => e.blankRow?.stepId == QuadraticStepIds.coefficients),
        isTrue,
      );
    },
  );

  test('HTTP error and invalid JSON also fall back', () async {
    for (final http.Response r in <http.Response>[
      http.Response('boom', 500),
      http.Response('not json', 200),
    ]) {
      final BrainTutorScript s = _script(
        _client((http.Request req) async => r),
        'x',
      );
      final List<TutorScriptEvent> ev = await _collect(s);
      expect(ev.any((e) => e.offline == true), isTrue);
    }
  });

  test('later answers go to the brain as the next turn', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final BrainTutorScript s = _script(
      _client((http.Request req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(_guideBody, 200);
      }),
      'x^2 + 2x = 1',
    );
    await _collect(s);
    await s.submitBlankAnswers(
      stepId: 's2',
      values: {'b1-1': '1', 'b1-2': '1'},
    );
    expect(bodies, hasLength(2));
    expect(bodies[1]['text'], '1, 1');
    expect(bodies[1]['step_id'], 's2');
    expect(bodies[1].containsKey('problem'), isFalse);
  });
}

void audioTests() {
  test('audio fields parse and drive write duration', () {
    final TutorTurnResponse r = TutorTurnResponse.parse(
      '{"say":"hi","audio_url":"http://a/x.mp3","audio_ms":2000,'
      '"board":[{"op":"write","text":"a b c","audio_ms":1500}]}',
    );
    expect(r.audioMs, 2000);
    expect(r.board.first.audioMs, 1500);
    expect(
      writeDurationFor('x', audioMs: 1500),
      const Duration(milliseconds: 1500),
    );
    expect(
      writeDurationFor('one two three four five'),
      const Duration(milliseconds: 1923),
    );
  });
}
