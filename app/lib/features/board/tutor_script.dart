import 'dart:async';

import '../../l10n/soro_strings.dart';
import 'board_strings.dart';

/// Author of a notebook line (`tutor` in crimson, `student` in royal blue #1B56D0).
enum ScriptAuthor { tutor, student }

/// Turn state displayed in the bottom Voice Dock.
enum TutorTurnState { soroSpeaking, studentTurn, listening }

/// Shape: `{id, expected}` representing a fillable blank in a tutor structure row.
class BlankSpec {
  const BlankSpec({required this.id, required this.expected, this.label = '▢'});

  final String id;
  final String expected;
  final String label;

  Map<String, String> toJson() => {'id': id, 'expected': expected};
}

/// Shape: `{author: tutor, text}` emitted by [TutorScript].
class TutorLinePayload {
  const TutorLinePayload({
    required this.text,
    required this.textYo,
    this.author = ScriptAuthor.tutor,
    this.isAnalogy = false,
    this.isCorrection = false,
    this.isPraise = false,
    this.isUnaided = false,
    this.writeDuration,
    this.audioUrl,
  });

  /// How long the tutor pen should take to write this line (synced to voice).
  final Duration? writeDuration;
  final String? audioUrl;

  final ScriptAuthor author;
  final String text;
  final String textYo;
  final bool isAnalogy;
  final bool isCorrection;
  final bool isPraise;
  final bool isUnaided;

  Map<String, Object> toJson() => {
    'author': author.name,
    'text': text,
    'text_yo': textYo,
    'is_analogy': isAnalogy,
  };
}

/// Shape: student answer line rendered in royal blue `#1B56D0`.
class StudentAnswerPayload {
  const StudentAnswerPayload({
    required this.stepId,
    required this.text,
    required this.values,
    this.inputMethod = 'Typed',
    this.isCorrect = true,
  });

  final String stepId;
  final String text;
  final Map<String, String> values;
  final String inputMethod;
  final bool isCorrect;

  Map<String, Object> toJson() => {
    'author': ScriptAuthor.student.name,
    'step_id': stepId,
    'text': text,
    'values': values,
    'input_method': inputMethod,
    'is_correct': isCorrect,
  };
}

/// Shape: `board_visibility` control message emitted by the tutor script.
class BoardVisibilityPayload {
  const BoardVisibilityPayload({required this.visible, required this.reason});

  final bool visible;
  final String reason;

  Map<String, Object> toJson() => {
    'board_visibility': visible,
    'reason': reason,
  };
}

/// A step structure written by Sọ̀rọ̀ with blanks (`▢`) that the student fills in.
/// The tutor never writes the final answer itself.
class TutorBlankRowPayload {
  const TutorBlankRowPayload({
    required this.stepId,
    required this.templateText,
    required this.blanks,
    this.prefixText = '',
    this.suffixText = '',
  });

  final String stepId;
  final String templateText;
  final List<BlankSpec> blanks;
  final String prefixText;
  final String suffixText;
}

/// Unified event emitted by [TutorScript] so a real backend stream can replace
/// the scripted demo implementation without changing the UI layer.
class TutorScriptEvent {
  const TutorScriptEvent({
    this.tutorLine,
    this.blankRow,
    this.studentAnswer,
    this.boardVisibility,
    this.turnState,
    this.rootsRevealed,
    this.caption,
    this.captionYo,
    this.thinking,
    this.offline,
  });

  /// Dock caption only (a `say` from the brain), not written on the page.
  final String? caption;
  final String? captionYo;

  /// True while a brain request is in flight (shows the thinking indicator).
  final bool? thinking;

  /// True when the scripted fallback replaced the brain ('Offline tutor' chip).
  final bool? offline;

  final TutorLinePayload? tutorLine;
  final TutorBlankRowPayload? blankRow;
  final StudentAnswerPayload? studentAnswer;
  final BoardVisibilityPayload? boardVisibility;
  final TutorTurnState? turnState;
  final bool? rootsRevealed;
}

/// Abstract tutor script contract that emits co-solve steps with a delay.
///
/// A real WebSocket / LiveKit / Gemini backend can implement [TutorScript]
/// later while emitting the exact same event shapes:
/// - tutor line `{author: tutor, text}`
/// - blank `{id, expected}`
/// - student answer
/// - `board_visibility`
abstract class TutorScript {
  Stream<TutorScriptEvent> get events;

  /// Starts the session and emits the opening step.
  Future<void> start();

  /// Submits the student's blank values for [stepId].
  /// Never reveals the answer if wrong; emits a targeted correction question instead.
  Future<void> submitBlankAnswers({
    required String stepId,
    required Map<String, String> values,
    String inputMethod = 'Typed',
  });

  void dispose();
}

/// Identifiers for the four stages of the quadratic demo script.
class QuadraticStepIds {
  QuadraticStepIds._();

  static const String coefficients = 'step-1-coefficients';
  static const String factors = 'step-2-factors';
  static const String roots = 'step-3-roots';
  static const String unaided = 'step-4-unaided';
}

/// Scripted demo tutor for `Problem: x² − 5x + 6 = 0` followed by the unaided
/// check `Now try x² − 7x + 12 = 0 on your own`.
class DemoQuadraticTutorScript implements TutorScript {
  DemoQuadraticTutorScript({
    this.stepDelay = const Duration(milliseconds: 280),
  });

  final Duration stepDelay;
  final StreamController<TutorScriptEvent> _controller =
      StreamController<TutorScriptEvent>.broadcast();

  bool _disposed = false;

  @override
  Stream<TutorScriptEvent> get events => _controller.stream;

  void _emit(TutorScriptEvent event) {
    if (!_disposed && !_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> _waitDelay() async {
    if (stepDelay > Duration.zero) {
      await Future<void>.delayed(stepDelay);
    }
  }

  static String _normalizeNum(String raw) {
    return raw
        .trim()
        .replaceAll('−', '-')
        .replaceAll('–', '-')
        .replaceAll('+', '')
        .replaceAll(' ', '');
  }

  @override
  Future<void> start() async {
    // 1. Open board when tutor shows working and signal Soro is speaking
    _emit(
      const TutorScriptEvent(
        boardVisibility: BoardVisibilityPayload(
          visible: true,
          reason: 'Tutor opened notebook board to show working',
        ),
        turnState: TutorTurnState.soroSpeaking,
        rootsRevealed: false,
      ),
    );

    await _waitDelay();

    // Emit one allowed analogy line + Step 1 prompt & blank row: a = ▢, b = ▢, c = ▢
    _emit(
      TutorScriptEvent(
        tutorLine: TutorLinePayload(
          text: 'Analogy: ${BoardStrings.tr(SoroLanguage.en, 'analogyText')}.',
          textYo: BoardStrings.tr(SoroLanguage.yo, 'analogyText'),
          isAnalogy: true,
        ),
      ),
    );

    _emit(
      TutorScriptEvent(
        tutorLine: TutorLinePayload(
          text: BoardStrings.tr(SoroLanguage.en, 'step1Prompt'),
          textYo: BoardStrings.tr(SoroLanguage.en, 'step1Yo'),
        ),
        blankRow: const TutorBlankRowPayload(
          stepId: QuadraticStepIds.coefficients,
          templateText: 'a = ▢, b = ▢, c = ▢',
          blanks: [
            BlankSpec(id: 'a', expected: '1', label: 'a'),
            BlankSpec(id: 'b', expected: '-5', label: 'b'),
            BlankSpec(id: 'c', expected: '6', label: 'c'),
          ],
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
  }) async {
    if (stepId == QuadraticStepIds.coefficients) {
      final String a = _normalizeNum(values['a'] ?? '');
      final String b = _normalizeNum(values['b'] ?? '');
      final String c = _normalizeNum(values['c'] ?? '');

      final bool isCorrect = (a == '1') && (b == '-5') && (c == '6');
      final String formattedB = b == '-5' ? '−5' : (values['b'] ?? '?').trim();
      final String studentLine =
          'a = ${values['a']?.trim() ?? '?'}, b = $formattedB, c = ${values['c']?.trim() ?? '?'}';

      _emit(
        TutorScriptEvent(
          studentAnswer: StudentAnswerPayload(
            stepId: stepId,
            text: studentLine,
            values: values,
            inputMethod: inputMethod,
            isCorrect: isCorrect,
          ),
          turnState: TutorTurnState.soroSpeaking,
        ),
      );

      await _waitDelay();

      if (!isCorrect) {
        _emit(
          const TutorScriptEvent(
            tutorLine: TutorLinePayload(
              text: 'Look closely at the signs in x² − 5x + 6 = 0. What sign is in front of 5x?',
              textYo: 'Wo àmì iwájú 5x nínú x² − 5x + 6 = 0 dáadáa. Àmì wo ló wà níbẹ̀? [needs native check]',
              isCorrection: true,
            ),
            turnState: TutorTurnState.studentTurn,
          ),
        );
        return;
      }

      // Move to Step 2: Factoring (x − ▢)(x − ▢) = 0
      _emit(
        TutorScriptEvent(
          boardVisibility: const BoardVisibilityPayload(
            visible: true,
            reason: 'Tutor emitted Step 2 structure',
          ),
          tutorLine: TutorLinePayload(
            text: BoardStrings.tr(SoroLanguage.en, 'step2Prompt'),
            textYo: BoardStrings.tr(SoroLanguage.en, 'step2Yo'),
            isPraise: true,
          ),
          blankRow: const TutorBlankRowPayload(
            stepId: QuadraticStepIds.factors,
            templateText: '(x − ▢)(x − ▢) = 0',
            blanks: [
              BlankSpec(id: 'f1', expected: '2', label: 'first number'),
              BlankSpec(id: 'f2', expected: '3', label: 'second number'),
            ],
          ),
          turnState: TutorTurnState.studentTurn,
        ),
      );
      return;
    }

    if (stepId == QuadraticStepIds.factors) {
      final String raw1 = (values['f1'] ?? '').trim();
      final String raw2 = (values['f2'] ?? '').trim();
      final String n1 = _normalizeNum(raw1);
      final String n2 = _normalizeNum(raw2);

      // Check if student made a sign error (e.g. typed -2/-3 or explicit +2/+3 sign error flag)
      final bool isSignError =
          values['sign_error'] == 'true' ||
          raw1.startsWith('+') ||
          raw2.startsWith('+') ||
          (n1 == '-2' && n2 == '-3') ||
          (n1 == '-3' && n2 == '-2');

      final bool isCorrectPair =
          !isSignError &&
          ((n1 == '2' && n2 == '3') || (n1 == '3' && n2 == '2'));

      final String displayLine = isSignError
          ? '(x + 2)(x + 3) = 0   [sign error: +2 and +3 add to +5]'
          : '(x − ${raw1.isEmpty ? '?' : raw1})(x − ${raw2.isEmpty ? '?' : raw2}) = 0';

      _emit(
        TutorScriptEvent(
          studentAnswer: StudentAnswerPayload(
            stepId: stepId,
            text: displayLine,
            values: values,
            inputMethod: inputMethod,
            isCorrect: isCorrectPair,
          ),
          turnState: TutorTurnState.soroSpeaking,
        ),
      );

      await _waitDelay();

      if (!isCorrectPair) {
        // Targeted correction question, NEVER giving the answer!
        _emit(
          TutorScriptEvent(
            boardVisibility: const BoardVisibilityPayload(
              visible: true,
              reason: 'Tutor asked targeted sign-error correction question',
            ),
            tutorLine: TutorLinePayload(
              text: BoardStrings.tr(SoroLanguage.en, 'step2WrongCorrection'),
              textYo: BoardStrings.tr(
                SoroLanguage.en,
                'step2WrongCorrectionYo',
              ),
              isCorrection: true,
            ),
            turnState: TutorTurnState.studentTurn,
          ),
        );
        return;
      }

      // Correct factoring! Lights up with 'Ó tọ́ · Correct', roots stay as '?' until student writes x = 2 or x = 3 in blue
      _emit(
        TutorScriptEvent(
          boardVisibility: const BoardVisibilityPayload(
            visible: true,
            reason:
                'Factoring correct; waiting for student to write roots in blue',
          ),
          tutorLine: TutorLinePayload(
            text: BoardStrings.tr(SoroLanguage.en, 'rootsPrompt'),
            textYo: BoardStrings.tr(SoroLanguage.en, 'rootsPromptYo'),
            isPraise: true,
          ),
          blankRow: const TutorBlankRowPayload(
            stepId: QuadraticStepIds.roots,
            templateText: 'x = ▢  or  x = ▢',
            blanks: [
              BlankSpec(id: 'r1', expected: '2', label: 'root 1'),
              BlankSpec(id: 'r2', expected: '3', label: 'root 2'),
            ],
          ),
          turnState: TutorTurnState.studentTurn,
          rootsRevealed: false,
        ),
      );
      return;
    }

    if (stepId == QuadraticStepIds.roots) {
      final String r1 = _normalizeNum(values['r1'] ?? '');
      final String r2 = _normalizeNum(values['r2'] ?? '');
      final bool isCorrect =
          (r1 == '2' && r2 == '3') ||
          (r1 == '3' && r2 == '2') ||
          r1 == '2' ||
          r1 == '3' ||
          r2 == '2' ||
          r2 == '3';

      final String displayR1 = r1.isEmpty ? '2' : r1;
      final String displayR2 = r2.isEmpty ? '3' : r2;
      final String studentText = 'x = $displayR1 or x = $displayR2';

      _emit(
        TutorScriptEvent(
          studentAnswer: StudentAnswerPayload(
            stepId: stepId,
            text: studentText,
            values: values,
            inputMethod: inputMethod,
            isCorrect: isCorrect,
          ),
          turnState: TutorTurnState.soroSpeaking,
          rootsRevealed: isCorrect,
        ),
      );

      await _waitDelay();

      if (!isCorrect) {
        _emit(
          const TutorScriptEvent(
            tutorLine: TutorLinePayload(
              text: 'If (x − 2) = 0 or (x − 3) = 0, what values of x make each bracket zero?',
              textYo: 'Tí (x − 2) = 0 tàbí (x − 3) = 0, iye x wo ni yóò mú kí àkámọ́ kọ̀ọ̀kan jẹ́ òdo? [needs native check]',
              isCorrection: true,
            ),
            turnState: TutorTurnState.studentTurn,
          ),
        );
        return;
      }

      // Now emit the unaided check: 'Now try x² − 7x + 12 = 0 on your own' with no hints!
      _emit(
        TutorScriptEvent(
          boardVisibility: const BoardVisibilityPayload(
            visible: true,
            reason: 'Tutor launched unaided transfer check',
          ),
          tutorLine: TutorLinePayload(
            text: BoardStrings.tr(SoroLanguage.en, 'unaidedPrompt'),
            textYo: BoardStrings.tr(SoroLanguage.en, 'unaidedPromptYo'),
            isPraise: true,
            isUnaided: true,
          ),
          blankRow: const TutorBlankRowPayload(
            stepId: QuadraticStepIds.unaided,
            templateText: 'x² − 7x + 12 = 0   ⇒   x = ▢  or  x = ▢',
            blanks: [
              BlankSpec(id: 'u1', expected: '3', label: 'first root'),
              BlankSpec(id: 'u2', expected: '4', label: 'second root'),
            ],
          ),
          turnState: TutorTurnState.studentTurn,
          rootsRevealed: true,
        ),
      );
      return;
    }

    if (stepId == QuadraticStepIds.unaided) {
      final String u1 = _normalizeNum(values['u1'] ?? '');
      final String u2 = _normalizeNum(values['u2'] ?? '');
      final bool isCorrect =
          (u1 == '3' && u2 == '4') || (u1 == '4' && u2 == '3');

      final String studentText =
          'x² − 7x + 12 = 0  ⇒  (x − ${u1.isEmpty ? '?' : u1})(x − ${u2.isEmpty ? '?' : u2}) = 0  ⇒  x = ${u1.isEmpty ? '?' : u1} or x = ${u2.isEmpty ? '?' : u2}';

      _emit(
        TutorScriptEvent(
          studentAnswer: StudentAnswerPayload(
            stepId: stepId,
            text: studentText,
            values: values,
            inputMethod: inputMethod,
            isCorrect: isCorrect,
          ),
          turnState: TutorTurnState.soroSpeaking,
        ),
      );

      await _waitDelay();

      if (isCorrect) {
        _emit(
          TutorScriptEvent(
            tutorLine: TutorLinePayload(
              text: BoardStrings.tr(SoroLanguage.en, 'unaidedCompleteMsg'),
              textYo: BoardStrings.tr(SoroLanguage.en, 'unaidedCompleteYo'),
              isPraise: true,
              isUnaided: true,
            ),
            turnState: TutorTurnState.studentTurn,
          ),
        );
      } else {
        // Unaided check gives no hints!
        _emit(
          const TutorScriptEvent(
            tutorLine: TutorLinePayload(
              text: 'Unaided check (no hints): try checking your two numbers for x² − 7x + 12 = 0 again.',
              textYo: 'Ìdánwò láìsí ìrànlọ́wọ́: tún ṣàyẹ̀wò àwọn nọ́ńbà méjì rẹ fún x² − 7x + 12 = 0. [needs native check]',
              isUnaided: true,
            ),
            turnState: TutorTurnState.studentTurn,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
