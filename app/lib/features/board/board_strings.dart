import '../../l10n/soro_strings.dart';

/// Centralized strings for the Notebook-on-a-Board session (A2) and Voice Dock (A3).
///
/// English is the base language; Yorùbá is stored in Unicode NFC with tone marks
/// and under-dots (`ọ̀`, `ẹ̀`, `ṣ`) and explicitly flagged `needs native check`.
class BoardStrings {
  BoardStrings._();

  static const String nativeCheckNotice = 'Yorùbá copy: needs native check';

  static const Map<SoroLanguage, Map<String, String>> catalog = {
    SoroLanguage.en: {
      'problemTitle': 'Problem: x² − 5x + 6 = 0',
      'unaidedProblemTitle': 'Unaided check: x² − 7x + 12 = 0',
      'boardSessionBadge': 'Sọ̀rọ̀ · Notebook Board',
      'pinBoard': 'Pin board',
      'pinnedBoard': 'Pinned open',
      'tuckCountdownPrefix': 'Auto-tuck in ',
      'tuckPausedPinned': 'Board pinned open',
      'tuckPausedActive': 'Auto-tuck paused while working',
      'tuckNowBtn': 'Tuck to chat',
      'workingCardTitle': 'Working · Problem: x² − 5x + 6 = 0',
      'workingCardSubtitle':
          'Board tucked away after 10s idle. Your steps and ink are saved.',
      'workingCardReopenBtn': 'Working · Reopen notebook board →',
      'tutorAuthorLabel': 'Sọ̀rọ̀ · Tutor (Crimson ink)',
      'studentAuthorLabel': 'You · Student (Royal blue #1B56D0)',
      'analogyBadge': 'Analogy',
      'analogyText': 'roots are where a thrown ball\'s path meets the ground',
      'step1Prompt':
          'Look at the equation. What are the coefficients a, b and c?',
      'step1Yo':
          'Wo ìṣedọ́gba náà. Kí ni àwọn nọ́ńbà a, b àti c? [needs native check]',
      'step2Prompt': 'Which two numbers multiply to 6 and add to −5?',
      'step2Yo':
          'Àwọn nọ́ńbà méjì wo ni a bá sọ di púpọ̀ tí yóò jẹ́ 6, tí a bá sì ròpọ̀ tí yóò jẹ́ −5? [needs native check]',
      'step2WrongCorrection':
          'Check the sign of the middle term when you expand',
      'step2WrongCorrectionYo':
          'Ṣàyẹ̀wò àmì (+/-) ti àárín nígbà tí o bá ṣí i. [needs native check]',
      'correctBadge': 'Ó tọ́ · Correct',
      'rootsPrompt':
          'Ó tọ́ · Correct! Since (x − 2)(x − 3) = 0, write the roots x = ? or x = ? in blue:',
      'rootsPromptYo':
          'Ó tọ́! Nígbà tí (x − 2)(x − 3) = 0, kọ àwọn gbòngbò x = ? tàbí x = ? pẹ̀lú yíǹkì buluu: [needs native check]',
      'unaidedPrompt': 'Now try x² − 7x + 12 = 0 on your own',
      'unaidedPromptYo':
          'Báyìí, gbìyànjú x² − 7x + 12 = 0 fúnra rẹ láìsí ìrànlọ́wọ́ [needs native check]',
      'unaidedNoHintsTag': 'Unaided check · No hints',
      'unaidedCompleteMsg':
          'Ó tọ́ · Correct! You solved x² − 7x + 12 = 0 (x = 3 or x = 4) on your own.',
      'unaidedCompleteYo':
          'Ó tọ́! O yanju x² − 7x + 12 = 0 (x = 3 tàbí x = 4) fúnra rẹ. [needs native check]',
      'checkStepBtn': 'Write step in blue',
      'trySignErrorBtn': 'Demo wrong sign (+2, +3)',
      'fillWithStylusBtn': 'Write step with stylus',
      'applyStylusStepBtn': 'Apply stylus ink to step',
      'clearStylusBtn': 'Clear ink',
      'palmRejectionBadge': 'Stylus ready · Palm rejection on',
      'palmRejectedNotice': 'Palm touch ignored while stylus is active',
      'turnSoroSpeaking': 'Soro is speaking',
      'turnStudent': 'Your turn: say it or write it',
      'turnListening': 'Listening…',
      'orbHoldHint': 'Tap & hold to talk',
      'orbListeningHint': 'Listening… release to finish',
      'termCardsHeading': 'Tap-to-hear bilingual terms:',
      'graphSupportHeading': 'Supporting parabola view (roots stay ? until you write them)',
      'rootsMysteryLabel': 'roots: x = ? , x = ?',
      'rootsRevealedLabel': 'roots: x = 2 ✓ , x = 3 ✓',
      'vertexMysteryLabel': 'vertex: ?',
      'vertexRevealedLabel': 'vertex: (2.5, −0.25) ✓',
    },
    SoroLanguage.yo: {
      'problemTitle': 'Problem: x² − 5x + 6 = 0',
      'unaidedProblemTitle': 'Ìdánwò fúnra rẹ: x² − 7x + 12 = 0',
      'boardSessionBadge': 'Sọ̀rọ̀ · Pátákó Ìwé-Ìkọ̀wé',
      'pinBoard': 'So pátákó',
      'pinnedBoard': 'A ti so ó sílẹ̀',
      'tuckCountdownPrefix': 'Yóòkọ́ pamọ́ ní ',
      'tuckPausedPinned': 'A so pátákó sílẹ̀',
      'tuckPausedActive': 'Ìsinmi dúró nígbà tí o ń kọ̀wé',
      'tuckNowBtn': 'Kọ́ sí ìjíròrò',
      'workingCardTitle': 'Working · Problem: x² − 5x + 6 = 0',
      'workingCardSubtitle':
          'Pátákó ti kọ́ pamọ́ lẹ́yìn ìṣẹ́jú-àáyá 10. Iṣẹ́ rẹ wà ní ìpamọ́. [needs native check]',
      'workingCardReopenBtn': 'Working · Ṣí pátákó ìwé-ìkọ̀wé →',
      'tutorAuthorLabel': 'Sọ̀rọ̀ · Olùkọ́ (Yíǹkì পিপà)',
      'studentAuthorLabel': 'Ìwọ · Akẹ́kọ̀ọ́ (Buluu #1B56D0)',
      'analogyBadge': 'Àpẹẹrẹ · Analogy',
      'analogyText':
          'roots are where a thrown ball\'s path meets the ground · gbòngbò dà bí ibi tí bọ́ọ̀lù bá bàlẹ̀ sí',
      'step1Prompt':
          'Look at the equation. What are the coefficients a, b and c?',
      'step1Yo':
          'Wo ìṣedọ́gba náà. Kí ni àwọn nọ́ńbà a, b àti c? [needs native check]',
      'step2Prompt': 'Which two numbers multiply to 6 and add to −5?',
      'step2Yo':
          'Àwọn nọ́ńbà méjì wo ni a bá sọ di púpọ̀ tí yóò jẹ́ 6, tí a bá sì ròpọ̀ tí yóò jẹ́ −5? [needs native check]',
      'step2WrongCorrection':
          'Check the sign of the middle term when you expand',
      'step2WrongCorrectionYo':
          'Ṣàyẹ̀wò àmì (+/-) ti àárín nígbà tí o bá ṣí i. [needs native check]',
      'correctBadge': 'Ó tọ́ · Correct',
      'rootsPrompt':
          'Ó tọ́ · Correct! Since (x − 2)(x − 3) = 0, write the roots x = ? or x = ? in blue:',
      'rootsPromptYo':
          'Ó tọ́! Nígbà tí (x − 2)(x − 3) = 0, kọ àwọn gbòngbò x = ? tàbí x = ? pẹ̀lú yíǹkì buluu: [needs native check]',
      'unaidedPrompt': 'Now try x² − 7x + 12 = 0 on your own',
      'unaidedPromptYo':
          'Báyìí, gbìyànjú x² − 7x + 12 = 0 fúnra rẹ láìsí ìrànlọ́wọ́ [needs native check]',
      'unaidedNoHintsTag': 'Ìdánwò láìsí ìrànlọ́wọ́ · No hints',
      'unaidedCompleteMsg':
          'Ó tọ́ · Correct! You solved x² − 7x + 12 = 0 (x = 3 or x = 4) on your own.',
      'unaidedCompleteYo':
          'Ó tọ́! O yanju x² − 7x + 12 = 0 (x = 3 tàbí x = 4) fúnra rẹ. [needs native check]',
      'checkStepBtn': 'Kọ ìgbésẹ̀ pẹ̀lú buluu',
      'trySignErrorBtn': 'Gbìyànjú àṣìṣe àmì (+2, +3)',
      'fillWithStylusBtn': 'Fi kálámù (stylus) kọ ọ́',
      'applyStylusStepBtn': 'Fi ìkọ̀wé kálámù sí ìgbésẹ̀',
      'clearStylusBtn': 'Nu yíǹkì',
      'palmRejectionBadge': 'Kálámù ṣetán · Palm rejection on',
      'palmRejectedNotice': 'A kọ ìfọwọ́kàn àtẹ́lẹwọ́ sílẹ̀',
      'turnSoroSpeaking': 'Soro is speaking',
      'turnStudent': 'Your turn: say it or write it',
      'turnListening': 'Listening…',
      'orbHoldHint': 'Dì mú láti sọ̀rọ̀ · Hold to talk',
      'orbListeningHint': 'Listening… · Mo ń gbọ́…',
      'termCardsHeading': 'Tẹ̀ láti gbọ́ àwọn ọ̀rọ̀ èdè méjì:',
      'graphSupportHeading': 'Àwòrán parabola (gbòngbò wà ní ? títí tí o fi kọ wọ́n)',
      'rootsMysteryLabel': 'gbòngbò / roots: x = ? , x = ?',
      'rootsRevealedLabel': 'gbòngbò / roots: x = 2 ✓ , x = 3 ✓',
      'vertexMysteryLabel': 'ibùdó / vertex: ?',
      'vertexRevealedLabel': 'ibùdó / vertex: (2.5, −0.25) ✓',
    },
  };

  static String tr(SoroLanguage lang, String key) {
    return catalog[lang]?[key] ?? catalog[SoroLanguage.en]?[key] ?? key;
  }
}

/// Bilingual term card model for tap-to-hear glossary terms in the bottom dock.
class BilingualTermCardData {
  const BilingualTermCardData({
    required this.id,
    required this.termEn,
    required this.termYo,
    required this.phoneticHint,
  });

  final String id;
  final String termEn;
  final String termYo;
  final String phoneticHint;
}

const List<BilingualTermCardData> kQuadraticTermCards = [
  BilingualTermCardData(
    id: 'roots',
    termEn: 'roots',
    termYo: 'gbòngbò',
    phoneticHint: 'gbòng-bò · where the parabola meets y = 0',
  ),
  BilingualTermCardData(
    id: 'vertex',
    termEn: 'vertex',
    termYo: 'ibùdó',
    phoneticHint: 'i-bù-dó · turning point of the curve',
  ),
  BilingualTermCardData(
    id: 'symmetry',
    termEn: 'axis of symmetry',
    termYo: 'ìlà-àárín',
    phoneticHint: 'ì-là à-á-rín · mirror line through the vertex',
  ),
];
