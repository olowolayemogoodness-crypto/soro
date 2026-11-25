import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Supported languages in Sọ̀rọ̀.
///
/// Sọ̀rọ̀ is English-first with a pluggable second-language slot.
/// Yorùbá (`yo`) is the only extra language for now; more languages can be
/// added to [SoroStrings.catalog] in one place.
enum SoroLanguage {
  en(
    code: 'en',
    locale: Locale('en'),
    displayName: 'English',
    shortBadge: 'EN',
    needsNativeCheck: false,
  ),
  yo(
    code: 'yo',
    locale: Locale('yo'),
    displayName: 'Yorùbá',
    shortBadge: 'YO',
    needsNativeCheck: true,
  );

  const SoroLanguage({
    required this.code,
    required this.locale,
    required this.displayName,
    required this.shortBadge,
    required this.needsNativeCheck,
  });

  final String code;
  final Locale locale;
  final String displayName;
  final String shortBadge;
  final bool needsNativeCheck;
}

/// Plain-word network status tiers (no jargon like 'T0' or 'T1').
enum SoroNetworkStatus {
  live,
  weakSignalVoiceOnly,
  offline,
}

/// Centralized localization catalog so additional languages can be added in one place.
///
/// Every Yorùbá string is stored in Unicode NFC form with tone marks and under-dots
/// (`ọ̀`, `ẹ̀`, `ṣ`, combining grave `U+0300`, combining acute `U+0301`) and flagged
/// `needs native check` per design audit M6 / Firstmate spec.
class SoroStrings {
  SoroStrings._();

  static const String yorubaProofString =
      'Sọ̀rọ̀ · Bẹ̀rọ̀ · ẹ̀kọ́ · ṣe · gbòngbò · ibùdó';

  static const Map<SoroLanguage, Map<String, String>> catalog = {
    SoroLanguage.en: {
      'appTitle': 'Sọ̀rọ̀',
      'tagline': 'Solve it together, step by step',
      'languageSelectorLabel': 'Language selector: English and Yorùbá',
      'languagePillPrefix': 'Language:',
      'nativeCheckFlag': 'Yorùbá copy: needs native check',
      'networkLive': 'Live',
      'networkWeak': 'Weak signal: voice only',
      'networkOffline': 'Offline',
      'networkStatusTooltip': 'Connection status (tap to cycle demo states)',
      'moreMenuLabel': 'More options and My progress',
      'myProgressEntry': 'My progress',
      'myProgressHiddenHint': 'Statistics stay tucked away while you study',
      'greetingBadge': 'Ìlù · Your talking-drum tutor',
      'greetingHeadline': 'What shall we solve together?',
      'greetingSubtitle':
          'Ask any question by typing, speaking out loud, or writing with your stylus. Sọ̀rọ̀ guides your steps and never gives away the final answer.',
      'initialTutorMessage':
          'Hello! Pick a topic below or ask your own question in the box. When we start solving, the notebook board will open so we can work through each step together.',
      'initialTutorBilingualNote':
          'Bilingual support ready: English base with Yorùbá terms (gbòngbò · roots, ibùdó · vertex).',
      'composerHeading': 'Ask anything',
      'composerPlaceholder':
          'Type a problem or concept — e.g. Solve x² − 5x + 6 = 0, or why does friction slow things down?…',
      'composerTypeBtn': 'Type',
      'composerSpeakBtn': 'Speak',
      'composerSpeakListening': 'Listening… tap to finish',
      'composerStylusBtn': 'Write with stylus',
      'composerStylusActive': 'Hide stylus pad',
      'composerAskBtn': 'Ask & open board',
      'stylusPadTitle': 'Handwriting & stylus pad (pointer & pressure aware)',
      'stylusPadHint':
          'Write an equation or sketch with your tablet stylus or finger in student royal-blue ink (#1B56D0).',
      'stylusClearBtn': 'Clear ink',
      'stylusUseBtn': 'Ask from handwriting',
      'stylusRecognisedPrefix': 'Handwritten problem: ',
      'stylusDefaultEquation': 'Solve x² − 5x + 6 = 0 step by step',
      'spokenSampleQuestion':
          'Can we solve x² − 5x + 6 = 0 together step by step?',
      'suggestedTopicsHeading': 'Suggested topics to start with',
      'chipQuadraticTitle': 'Solve a quadratic',
      'chipQuadraticPrompt': 'Help me solve x² − 5x + 6 = 0 step by step.',
      'chipQuadraticTag': 'Maths · Quadratics',
      'chipFrictionTitle': 'Why does friction slow things down?',
      'chipFrictionPrompt':
          'Why does friction slow things down? Explain with a danfo on a wet road.',
      'chipFrictionTag': 'Physics · Forces',
      'chipPdfTitle': 'Explain a PDF concept',
      'chipPdfPrompt':
          'Explain a concept from my lecture PDF in plain steps and analogies.',
      'chipPdfTag': 'Study help · Notes',
      'chipCompleteSquareTitle': 'Complete the square: x² + 2x = 1',
      'chipCompleteSquarePrompt':
          'Show me how to start completing the square for x² + 2x = 1 without giving the final roots.',
      'chipCompleteSquareTag': 'Maths · Algebra',
      'chatSectionLabel': 'Conversation history',
      'chatTutorRole': 'Sọ̀rọ̀ · Tutor',
      'chatStudentRole': 'You · Student',
      'chatOpenBoardAction': 'Working · Open board →',
      'chatTutorReplyPrefix':
          'Let’s work on this together on the notebook board. First, what do you notice about: ',
      'boardPlaceholderTitle': 'Notebook-on-a-Board Session (Placeholder)',
      'boardPlaceholderSubtitle':
          'The full interactive co-solve notebook board, ruled lines, and parabola canvas arrive in task A2.',
      'boardActiveQuestionLabel': 'Current problem on the board:',
      'boardFirstStepPrompt':
          'Sọ̀rọ̀ writes the step structure with blanks — e.g. (x − [ ? ])(x − [ ? ]) = 0 — so your hand moves first.',
      'boardBackToChatBtn': 'Back to home chat',
      'progressPlaceholderTitle': 'My progress (Placeholder)',
      'progressPlaceholderSubtitle':
          'Kept off the home screen so your chat stays calm. Daily activity, subject breakdown, and unaided check records live here.',
      'progressBackToChatBtn': 'Back to home chat',
    },
    // All Yorùbá strings below: needs native check (marked in code only, not on screen).
    SoroLanguage.yo: {
      'appTitle': 'Sọ̀rọ̀', // needs native check
      'tagline': 'A ó jọ yanju rẹ̀ ní ìgbésẹ̀-ń-ìgbésẹ̀', // needs native check
      'languageSelectorLabel': 'Olùyàn èdè: Gẹ̀ẹ́sì àti Yorùbá', // needs native check
      'languagePillPrefix': 'Èdè:', // needs native check
      'networkLive': 'Live · Ó ń ṣiṣẹ́', // needs native check
      'networkWeak': 'Weak signal: voice only · Ohùn nìkan', // needs native check
      'networkOffline': 'Offline · Kò sí ìsopọ̀', // needs native check
      'networkStatusTooltip': 'Ipò ìsopọ̀ (tẹ̀ láti yí padà)', // needs native check
      'moreMenuLabel': 'Àṣàyàn míràn àti Ìlọsíwájú mi', // needs native check
      'myProgressEntry': 'My progress · Ìlọsíwájú mi', // needs native check
      'myProgressHiddenHint': 'Àkójọpọ̀ ìṣirò wà ní ìpamọ́ lórí ojú-ìwé ibẹ̀rẹ̀', // needs native check
      'greetingBadge': 'Ìlù · Olùkọ́ dùndún rẹ', // needs native check
      'greetingHeadline': 'Kí ni kí á jọ yanju lónìí?', // needs native check
      'greetingSubtitle':
          'Kọ ìbéèrè rẹ, sọ ọ́ síta, tàbí fi kálámù (stylus) kọ ọ́. Sọ̀rọ̀ á tọ́ ọ sọ́nà ní ìgbésẹ̀-ń-ìgbésẹ̀ láì sọ ìdáhùn gbẹ̀yìn fún ọ.', // needs native check
      'initialTutorMessage':
          'Káàbọ̀! Yan koko-ọ̀rọ̀ kan ní ìsàlẹ̀ tàbí kọ ìbéèrè tirẹ. Nígbà tí a bá bẹ̀rẹ̀, pátákó ìwé-ìkọ̀wé á ṣí sílẹ̀ kí á lè jọ ṣe é.', // needs native check
      'initialTutorBilingualNote':
          'Àtìlẹ́yìn èdè méjì: Gẹ̀ẹ́sì àti Yorùbá (gbòngbò · roots, ibùdó · vertex, ìlà-àárín · axis of symmetry).', // needs native check
      'composerHeading': 'Béèrè ohunkóhun · Ask anything', // needs native check
      'composerPlaceholder':
          'Kọ ìṣòro tàbí koko-ẹ̀kọ́ — bíi x² − 5x + 6 = 0, tàbí kí ló dé tí ìfagagbága (friction) fi ń dá nǹkan dúró?…', // needs native check
      'composerTypeBtn': 'Kọ ọ́ · Type', // needs native check
      'composerSpeakBtn': 'Sọ̀rọ̀ · Speak', // needs native check
      'composerSpeakListening': 'Mo ń gbọ́… tẹ̀ láti parí', // needs native check
      'composerStylusBtn': 'Kálámù · Stylus', // needs native check
      'composerStylusActive': 'Pa pátákó kálámù dé', // needs native check
      'composerAskBtn': 'Béèrè & ṣí pátákó · Bẹ̀rẹ̀', // needs native check
      'stylusPadTitle': 'Pátákó ìkọ̀wé kálámù (Stylus & pointer pad)', // needs native check
      'stylusPadHint':
          'Fi kálámù tàbí ìka rẹ kọ ìṣedọ́gba pẹ̀lú yíǹkì buluu akẹ́kọ̀ọ́ (#1B56D0).', // needs native check
      'stylusClearBtn': 'Nu yíǹkì · Clear', // needs native check
      'stylusUseBtn': 'Béèrè láti inú ìkọ̀wé', // needs native check
      'stylusRecognisedPrefix': 'Ìṣòro tí a fi ọwọ́ kọ: ', // needs native check
      'stylusDefaultEquation': 'Yanju x² − 5x + 6 = 0 ní ìgbésẹ̀-ń-ìgbésẹ̀', // needs native check
      'spokenSampleQuestion':
          'Ṣé a lè jọ yanju x² − 5x + 6 = 0 ní ìgbésẹ̀-ń-ìgbésẹ̀?', // needs native check
      'suggestedTopicsHeading': 'Àwọn koko-ẹ̀kọ́ tí o lè fi bẹ̀rẹ̀', // needs native check
      'chipQuadraticTitle': 'Solve a quadratic · Yanju ìṣedọ́gba kọ́dratiki', // needs native check
      'chipQuadraticPrompt': 'Ràn mí lọ́wọ́ láti yanju x² − 5x + 6 = 0 ní ìgbésẹ̀-ń-ìgbésẹ̀.', // needs native check
      'chipQuadraticTag': 'Maths · Ìṣedọ́gba Kọ́dratiki', // needs native check
      'chipFrictionTitle': 'Why does friction slow things down? · Ìfagagbága', // needs native check
      'chipFrictionPrompt':
          'Kí ló dé tí friction fi ń dá nǹkan dúró? Fi àpẹẹrẹ ọkọ̀ danfo lórí òpópónà tútù ṣàlàyé.', // needs native check
      'chipFrictionTag': 'Physics · Agbára àti Ìṣípòpadà', // needs native check
      'chipPdfTitle': 'Explain a PDF concept · Ṣàlàyé ìwé PDF', // needs native check
      'chipPdfPrompt':
          'Ṣàlàyé koko-ẹ̀kọ́ kan láti inú ìwé PDF mi ní ìgbésẹ̀ rírọrùn.', // needs native check
      'chipPdfTag': 'Study help · Àkọsílẹ̀', // needs native check
      'chipCompleteSquareTitle': 'Complete the square: x² + 2x = 1', // needs native check
      'chipCompleteSquarePrompt':
          'Fi bí a ṣe ń bẹ̀rẹ̀ completing the square fún x² + 2x = 1 hàn mí láì sọ gbòngbò rẹ̀.', // needs native check
      'chipCompleteSquareTag': 'Maths · Àljẹ́brà', // needs native check
      'chatSectionLabel': 'Ìtàn ìjíròrò · Conversation', // needs native check
      'chatTutorRole': 'Sọ̀rọ̀ · Olùkọ́', // needs native check
      'chatStudentRole': 'Ìwọ · Akẹ́kọ̀ọ́', // needs native check
      'chatOpenBoardAction': 'Working · Ṣí pátákó →', // needs native check
      'chatTutorReplyPrefix':
          'Jẹ́ kí á jọ ṣe èyí lórí pátákó ìwé-ìkọ̀wé. Lákọ̀ọ́kọ́, kí ni o kíyèsí nípa: ', // needs native check
      'boardPlaceholderTitle': 'Pátákó Ìwé-Ìkọ̀wé · Notebook Board (Placeholder)', // needs native check
      'boardPlaceholderSubtitle':
          'Pátákó ìṣirò àti àtẹ kọ́dratiki kikun ń bọ̀ ní ìgbésẹ̀ A2.', // needs native check
      'boardActiveQuestionLabel': 'Ìbéèrè tí a ń yanju lórí pátákó:', // needs native check
      'boardFirstStepPrompt':
          'Sọ̀rọ̀ á kọ ààyè òfo — bíi (x − [ ? ])(x − [ ? ]) = 0 — kí ọwọ́ rẹ lè kọ́kọ́ ṣiṣẹ́.', // needs native check
      'boardBackToChatBtn': 'Padà sí ìjíròrò (Back to chat)', // needs native check
      'progressPlaceholderTitle': 'My progress · Ìlọsíwájú mi (Placeholder)', // needs native check
      'progressPlaceholderSubtitle':
          'A fi pamọ́ kúrò lórí ojú-ìwé ibẹ̀rẹ̀ kí ìjíròrò rẹ lè bàlẹ̀.', // needs native check
      'progressBackToChatBtn': 'Padà sí ìjíròrò (Back to chat)', // needs native check
    },
  };

  static String tr(SoroLanguage lang, String key) {
    return catalog[lang]?[key] ?? catalog[SoroLanguage.en]?[key] ?? key;
  }

  static String networkLabel(SoroLanguage lang, SoroNetworkStatus status) {
    switch (status) {
      case SoroNetworkStatus.live:
        return tr(lang, 'networkLive');
      case SoroNetworkStatus.weakSignalVoiceOnly:
        return tr(lang, 'networkWeak');
      case SoroNetworkStatus.offline:
        return tr(lang, 'networkOffline');
    }
  }
}

/// Renders text with an explicit [Locale] and screen-reader `LocaleStringAttribute`
/// so assistive technology (TalkBack / VoiceOver) switches pronunciation for Yorùbá (`lang="yo"`)
/// and English (`lang="en"`).
class SoroLocalizedText extends StatelessWidget {
  const SoroLocalizedText(
    this.text, {
    super.key,
    required this.language,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final SoroLanguage language;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final locale = language.locale;
    return Semantics(
      attributedLabel: AttributedString(
        text,
        attributes: [
          LocaleStringAttribute(
            range: TextRange(start: 0, end: text.length),
            locale: locale,
          ),
        ],
      ),
      excludeSemantics: true,
      child: Text(
        text,
        locale: locale,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }
}
