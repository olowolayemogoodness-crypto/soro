// English-first strings with pluggable Yoruba language slot.
// Every Yoruba string is NFC-normalized with tone marks and under-dots,
// and explicitly marked 'needs native check' per issue #12 and #16.

class BilingualText {
  final String en;
  final String yo;
  final bool needsNativeCheck;

  const BilingualText({
    required this.en,
    required this.yo,
    this.needsNativeCheck = true,
  });
}

class GraphFrictionStrings {
  GraphFrictionStrings._();

  static const String nativeCheckTag = 'needs native check';

  // PhET Forces and Motion: Basics HTML5 simulation URLs (Friction is screen 3).
  // Verified HTTP 200 live builds on phet.colorado.edu:
  // Yoruba title: "Ipá ati ìsún: Ipilẹ" (needs native check)
  static const String phetYorubaUrl =
      'https://phet.colorado.edu/sims/html/forces-and-motion-basics/latest/forces-and-motion-basics_yo.html?screens=3';
  static const String phetEnglishUrl =
      'https://phet.colorado.edu/sims/html/forces-and-motion-basics/latest/forces-and-motion-basics_en.html?screens=3';

  static const BilingualText screenTitle = BilingualText(
    en: 'Supporting Graph & Friction Lab',
    yo: 'Àwòrán Ifihan àti Ìdánwò Ìfọ́wọ́pa', // needs native check
  );

  static const BilingualText tutorName = BilingualText(
    en: 'Sọ̀rọ̀',
    yo: 'Sọ̀rọ̀', // needs native check
  );

  static const BilingualText turnCueStudent = BilingualText(
    en: 'Your turn: drag, say it, or write it',
    yo: 'Ìwọ ni: fà á, sọ ọ́, tàbí kọ ọ́', // needs native check
  );

  static const BilingualText turnCueTutor = BilingualText(
    en: 'Sọ̀rọ̀ is guiding this step',
    yo: 'Sọ̀rọ̀ ń ṣe ìtọ́sọ́nà ìgbésẹ̀ yìí', // needs native check
  );

  // Parabola Graph section
  static const BilingualText parabolaHeader = BilingualText(
    en: 'Supporting Parabola · Roots & Vertex stay as ? until you find them',
    yo: 'Àwòrán Parabola · Gbòǹgbò àti Ògógó ìyípadà wà ní ? títí tí o fi rí wọn', // needs native check
  );

  static const BilingualText parabolaTutorPrompt = BilingualText(
    en: 'Look at this circled crossing (?) on the x-axis. What happens to the curve when you drag b?',
    yo: 'Wo gbòǹgbò tí a yíká yìí (?). Kí ni yóò ṣẹlẹ̀ sí ìlà náà tí o bá yí b padà?', // needs native check
  );

  static const BilingualText parabolaSolvedPrompt = BilingualText(
    en: 'Nice work! Your roots and turning point are now marked in your royal-blue ink.',
    yo: 'Ó dáa gan-an! A ti fi inki bulu rẹ samisi àwọn gbòǹgbò àti ògógó ìyípadà rẹ.', // needs native check
  );

  static const BilingualText parabolaAnalogy = BilingualText(
    en: 'Think of a ball thrown up: it lands where its path meets the ground. Where would that be for this curve?',
    yo: 'Ronú nípa bọ́ọ̀lù tí a ju sókè: ó ń balẹ̀ níbi tí ọ̀nà rẹ̀ ti pàdé ilẹ̀. Níbo ni ìyẹn máa jẹ́ lórí ìlà yìí?', // needs native check
  );

  // Glossary terms (equal-weight bilingual stickies synced with content/lesson-pack.json)
  static const BilingualText termRoots = BilingualText(
    en: 'roots',
    yo: 'gbòǹgbò', // needs native check
  );

  static const BilingualText termVertex = BilingualText(
    en: 'vertex (turning point)',
    yo: 'ògógó ìyípadà · ibùdó', // needs native check
  );

  static const BilingualText termAxisOfSymmetry = BilingualText(
    en: 'axis of symmetry',
    yo: 'ìlà-àárín', // needs native check
  );

  // Friction Physics Illustration section (synced with content/packs/physics-friction.json)
  static const BilingualText frictionHeader = BilingualText(
    en: 'Friction Physics Illustration · PhET Forces & Motion: Basics',
    yo: 'Àpẹẹrẹ Fisiksi Ìfọ́wọ́pa · PhET Ipá ati ìsún: Ipilẹ', // needs native check
  );

  static const BilingualText frictionTutorPushPrompt = BilingualText(
    en: 'Push the crate on the smooth floor; what do you notice about its speed?',
    yo: 'Tì crate náà lórí ilẹ̀ dídán; kí ni o ṣàkíyèsí nípa ìyára rẹ̀?', // needs native check
  );

  static const BilingualText frictionTutorAskWhyPrompt = BilingualText(
    en: 'Change to a rougher surface; what slows the crate down?',
    yo: 'Yí ojú ilẹ̀ padà sí ilẹ̀ tó rẹ̀ jù; kí ló mú kí crate náà dín ìyára kù?', // needs native check
  );

  static const BilingualText frictionAnalogyDanfo = BilingualText(
    en: 'Think of a danfo skidding on a wet road: what is missing between the tyres and the road?',
    yo: 'Ronú nípa danfo tó ń yọ̀ lórí ọ̀nà tó tutù: kí ni ó dín kù láàrin táyà àti ọ̀nà?', // needs native check
  );

  static const BilingualText termFriction = BilingualText(
    en: 'friction',
    yo: 'ìfọ́wọ́pa', // needs native check
  );

  static const BilingualText termSurface = BilingualText(
    en: 'surface',
    yo: 'ojú ilẹ̀', // needs native check
  );

  static const BilingualText termForce = BilingualText(
    en: 'force',
    yo: 'agbára', // needs native check
  );
}
