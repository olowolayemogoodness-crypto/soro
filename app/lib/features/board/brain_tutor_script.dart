import 'dart:async';

import '../../l10n/soro_strings.dart';
import 'tutor_client.dart';
import 'tutor_script.dart';

/// [TutorScript] backed by `POST /tutor/turn`. The first turn sends the typed
/// question; later turns send the student's blanks. Any failure hands the
/// session to [fallback] (the scripted quadratic) and flags it as offline.
class BrainTutorScript implements TutorScript {
  BrainTutorScript({
    required this.client,
    required this.question,
    required this.language,
    TutorScript? fallback,
    String? sessionId,
  })  : fallback = fallback ?? DemoQuadraticTutorScript(),
        sessionId =
            sessionId ?? 's${DateTime.now().millisecondsSinceEpoch}';

  final TutorClient client;
  final String question;
  final SoroLanguage language;
  final TutorScript fallback;
  final String sessionId;

  final StreamController<TutorScriptEvent> _controller =
      StreamController<TutorScriptEvent>.broadcast();
  StreamSubscription<TutorScriptEvent>? _fallbackSub;
  bool _offline = false;
  bool _disposed = false;
  String _stepId = '';
  int _rowCounter = 0;

  @override
  Stream<TutorScriptEvent> get events => _controller.stream;

  void _emit(TutorScriptEvent event) {
    if (!_disposed && !_controller.isClosed) _controller.add(event);
  }

  String get _lang => language == SoroLanguage.yo ? 'yo' : 'en';

  @override
  Future<void> start() => _turn(
        text: question,
        mode: wantsSolve(question) ? TutorMode.solve : TutorMode.guide,
        problem: question,
      );

  /// Asks the brain to write out the full worked solution (Show me how).
  Future<void> requestSolve() =>
      _turn(text: 'Show me how', mode: TutorMode.solve);

  @override
  Future<void> submitBlankAnswers({
    required String stepId,
    required Map<String, String> values,
    String inputMethod = 'Typed',
  }) async {
    if (_offline) {
      return fallback.submitBlankAnswers(
        stepId: stepId,
        values: values,
        inputMethod: inputMethod,
      );
    }
    final String text = values.entries
        .map((MapEntry<String, String> e) => e.value.trim())
        .where((String v) => v.isNotEmpty)
        .join(', ');
    _emit(
      TutorScriptEvent(
        studentAnswer: StudentAnswerPayload(
          stepId: stepId,
          text: text,
          values: values,
          inputMethod: inputMethod,
        ),
      ),
    );
    await _turn(
      text: text,
      mode: wantsSolve(text) ? TutorMode.solve : TutorMode.guide,
    );
  }

  Future<void> _turn({
    required String text,
    required TutorMode mode,
    String? problem,
  }) async {
    _emit(
      const TutorScriptEvent(
        boardVisibility: BoardVisibilityPayload(
          visible: true,
          reason: 'Tutor is thinking',
        ),
        turnState: TutorTurnState.soroSpeaking,
        thinking: true,
      ),
    );
    final TutorTurnResponse res;
    try {
      res = await client.turn(
        sessionId: sessionId,
        lang: _lang,
        mode: mode,
        text: text,
        problem: problem,
        stepId: _stepId,
      );
    } on TutorClientException {
      if (_disposed) return;
      await _goOffline();
      return;
    }
    if (_disposed) return;
    _stepId = res.stepId;
    _emitReply(res);
  }

  void _emitReply(TutorTurnResponse res) {
    final bool yo = language == SoroLanguage.yo;
    final List<TutorScriptEvent> events = <TutorScriptEvent>[];
    if (res.analogy.isNotEmpty) {
      events.add(
        TutorScriptEvent(
          tutorLine: TutorLinePayload(
            text: res.analogy,
            textYo: '',
            isAnalogy: true,
          ),
        ),
      );
    }
    TutorBlankRowPayload? blankRow;
    for (final BoardOp op in res.board) {
      switch (op.op) {
        case 'write':
          events.add(
            TutorScriptEvent(
              tutorLine: TutorLinePayload(text: op.text, textYo: ''),
            ),
          );
        case 'blank':
          blankRow = _blankRowFrom(op.text, res.stepId);
        case 'mark':
          if (op.kind == 'tick') {
            events.add(
              const TutorScriptEvent(
                tutorLine: TutorLinePayload(
                  text: '✓',
                  textYo: '',
                  isPraise: true,
                ),
              ),
            );
          }
      }
    }
    for (final TutorScriptEvent e in events) {
      _emit(e);
    }
    _emit(
      TutorScriptEvent(
        caption: res.say,
        captionYo: yo ? res.say : '',
        blankRow: blankRow,
        thinking: false,
        offline: false,
        turnState: TutorTurnState.studentTurn,
      ),
    );
  }

  /// Turns `(x + [ ]) ^ 2 = [ ]` into a template with one `▢` per gap.
  TutorBlankRowPayload? _blankRowFrom(String text, String stepId) {
    final RegExp gap = RegExp(r'\[\s*\]|▢|_{2,}');
    final int count = gap.allMatches(text).length;
    if (count == 0) return null;
    _rowCounter++;
    return TutorBlankRowPayload(
      stepId: stepId.isEmpty ? 'brain-$_rowCounter' : stepId,
      templateText: text.replaceAll(gap, '▢'),
      blanks: <BlankSpec>[
        for (int i = 0; i < count; i++)
          BlankSpec(id: 'b$_rowCounter-${i + 1}', expected: '', label: '▢'),
      ],
    );
  }

  Future<void> _goOffline() async {
    _offline = true;
    _fallbackSub = fallback.events.listen(_emit);
    _emit(const TutorScriptEvent(thinking: false, offline: true));
    await fallback.start();
  }

  @override
  void dispose() {
    _disposed = true;
    _fallbackSub?.cancel();
    fallback.dispose();
    client.close();
    _controller.close();
  }
}
