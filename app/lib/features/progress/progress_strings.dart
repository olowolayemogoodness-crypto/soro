/// Language slot for the progress feature. English first; Yoruba is the only
/// extra language for now. Add a language by adding one more map below.
enum ProgressLang { en, yo }

extension ProgressLangLabel on ProgressLang {
  String get code => this == ProgressLang.en ? 'EN' : 'YO';
  String get label => this == ProgressLang.en ? 'English' : 'Yorùbá';
}

/// Looks up a UI string. `{name}` and `{n}` are replaced with [args].
String progressText(ProgressLang lang, String key, [Map<String, Object> args = const {}]) {
  var text = (_strings[lang]?[key]) ?? _strings[ProgressLang.en]![key] ?? key;
  args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
  return text;
}

const _strings = <ProgressLang, Map<String, String>>{
  ProgressLang.en: {
    'title': 'My progress',
    'back': 'Back',
    'viewStudent': 'My view',
    'viewParent': 'Parent view',
    'viewSwitchLabel': 'Who is looking',
    'heroStudent': 'Hi {name}, here is how you are doing',
    'heroParent': "{name}'s progress",
    'heroSubStudent': 'Only what you did with Soro. Nothing here is a grade.',
    'heroSubParent': 'What {name} has practised with Soro this week.',
    'consentParent':
        '{name} agreed to share this with you. {name} can turn sharing off at any time.',
    'consentLaw': 'Shared with consent under the NDPA 2023.',
    'streak': 'day streak',
    'streakOne': 'Day 1. Come back tomorrow to keep it going.',
    'streakNote': 'A streak is encouragement only. It never counts in a report.',
    'streakNone': 'No streak yet. One short step today starts it.',
    'week': 'Activity by day',
    'weekSubStudent': 'You practised on {n} of the last 7 days.',
    'weekSubParent': '{name} practised on {n} of the last 7 days.',
    'today': 'Today',
    'minutes': 'min',
    'noActivity': 'No activity',
    'subjects': 'Subjects and topics',
    'unaided': 'Unaided check',
    'passed': 'Passed on your own',
    'needsPractice': 'Needs more practice',
    'notYet': 'Not taken yet',
    'attempts': '{n} attempts',
    'attemptOne': '1 attempt',
    'steps': '{done} of {total} steps',
    'strengths': 'Strengths and what to practise',
    'strengthsSub': 'By branch of the topic. Based on the unaided checks.',
    'sample': 'Sample data',
    'sampleNote': 'Sample data for the demo. Real scores come after the pilot.',
    'notEnough': 'Not enough attempts yet',
    'basedOn': 'Based on {n} attempts',
    'emailTitle': 'Weekly email to parents',
    'emailSample': 'Sample email',
    'emailBody':
        '{name} practised on {n} days this week and passed the quadratics check on their own. '
            'Next up: friction on a rough road. A short chat about it at home helps.',
    'language': 'Language',
    'yoNeedsCheck': 'Yorùbá text: needs native check',
    'expand': 'Show lessons',
    'collapse': 'Hide lessons',
  },
  // Yoruba strings below are a first draft: needs native check.
  ProgressLang.yo: {
    'title': 'Ìlọsíwájú mi',
    'back': 'Padà',
    'viewStudent': 'Ojú ìwòye mi',
    'viewParent': 'Ojú ìwòye òbí',
    'viewSwitchLabel': 'Ta ni ń wò ó',
    'heroStudent': 'Báwo {name}, ìlọsíwájú rẹ nìyí',
    'heroParent': 'Ìlọsíwájú {name}',
    'heroSubStudent': 'Ohun tí o ṣe pẹ̀lú Sọ̀rọ̀ nìkan. Kò sí máàkì níbí.',
    'heroSubParent': 'Ohun tí {name} ti ṣe pẹ̀lú Sọ̀rọ̀ ní ọ̀sẹ̀ yìí.',
    'consentParent':
        '{name} gbà láti fi èyí hàn ọ́. {name} lè dá ìfihàn dúró nígbàkúgbà.',
    'consentLaw': 'A fi hàn pẹ̀lú ìyọ̀nda lábẹ́ òfin NDPA 2023.',
    'streak': 'ọjọ́ tẹ̀léra',
    'streakOne': 'Ọjọ́ kìíní. Padà wá lọ́la kí ó máa tẹ̀síwájú.',
    'streakNote': 'Ọjọ́ tẹ̀léra jẹ́ ìṣírí nìkan. Kì í wọ inú ìròyìn.',
    'streakNone': 'Kò tíì sí ọjọ́ tẹ̀léra. Ìgbésẹ̀ kékeré kan lónìí yóò bẹ̀rẹ̀ rẹ̀.',
    'week': 'Iṣẹ́ ojoojúmọ́',
    'weekSubStudent': 'O ṣe ìdánrawò ní ọjọ́ {n} nínú méje tó kọjá.',
    'weekSubParent': '{name} ṣe ìdánrawò ní ọjọ́ {n} nínú méje tó kọjá.',
    'today': 'Òní',
    'minutes': 'ìṣẹ́jú',
    'noActivity': 'Kò sí iṣẹ́',
    'subjects': 'Àwọn ẹ̀kọ́ àti àkòrí',
    'unaided': 'Ìdánwò láìsí ìrànlọ́wọ́',
    'passed': 'O yege fúnrarẹ',
    'needsPractice': 'Ó nílò ìdánrawò sí i',
    'notYet': 'A kò tíì ṣe é',
    'attempts': 'ìgbìyànjú {n}',
    'attemptOne': 'ìgbìyànjú kan',
    'steps': 'ìgbésẹ̀ {done} nínú {total}',
    'strengths': 'Ibi tí o lágbára àti ibi tí o máa ṣe ìdánrawò',
    'strengthsSub': 'Ní ẹ̀ka àkòrí. Ó dá lórí àwọn ìdánwò láìsí ìrànlọ́wọ́.',
    'sample': 'Àpẹẹrẹ dátà',
    'sampleNote': 'Àpẹẹrẹ dátà fún ìfihàn. Ìdíwọ̀n gidi yóò wá lẹ́yìn ìdánwò.',
    'notEnough': 'Ìgbìyànjú kò tó síbẹ̀',
    'basedOn': 'Ó dá lórí ìgbìyànjú {n}',
    'emailTitle': 'Ìméèlì ọ̀sẹ̀ sí àwọn òbí',
    'emailSample': 'Àpẹẹrẹ ìméèlì',
    'emailBody':
        '{name} ṣe ìdánrawò ní ọjọ́ {n} ní ọ̀sẹ̀ yìí, ó sì yege ìdánwò quadratics fúnrarẹ̀. '
            'Tókàn: ìforíkorí lójú ọ̀nà tó le. Ìjíròrò kúkúrú nílé ń ranni lọ́wọ́.',
    'language': 'Èdè',
    'yoNeedsCheck': 'Yorùbá text: needs native check',
    'expand': 'Fi àwọn ẹ̀kọ́ hàn',
    'collapse': 'Fi àwọn ẹ̀kọ́ pamọ́',
  },
};
