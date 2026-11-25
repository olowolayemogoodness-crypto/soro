import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/soro_strings.dart';
import '../theme/soro_theme.dart';

/// Placeholder route (`/board`) opened when the student asks a question or picks
/// a suggested topic on the home screen.
///
/// The full interactive notebook-on-a-board canvas is built in task A2.
class BoardPlaceholderScreen extends StatelessWidget {
  const BoardPlaceholderScreen({
    super.key,
    required this.language,
    required this.networkStatus,
    required this.activeQuestion,
    required this.onLanguageChanged,
    required this.onCycleNetworkStatus,
    required this.onBackToChat,
  });

  final SoroLanguage language;
  final SoroNetworkStatus networkStatus;
  final String activeQuestion;
  final ValueChanged<SoroLanguage> onLanguageChanged;
  final VoidCallback onCycleNetworkStatus;
  final VoidCallback onBackToChat;

  @override
  Widget build(BuildContext context) {
    final String question = activeQuestion.trim().isEmpty
        ? SoroStrings.tr(language, 'chipQuadraticPrompt')
        : activeQuestion;

    return Scaffold(
      backgroundColor: SoroTokens.cream,
      body: SoroDottedPaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              _PlaceholderTopBar(
                language: language,
                networkStatus: networkStatus,
                backButtonKey: const Key('board-back-button'),
                backLabel: SoroStrings.tr(language, 'boardBackToChatBtn'),
                onLanguageChanged: onLanguageChanged,
                onCycleNetworkStatus: onCycleNetworkStatus,
                onBack: onBackToChat,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SoroTokens.s20,
                    vertical: SoroTokens.s24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Container(
                        key: const Key('board-placeholder-card'),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFEFA),
                          borderRadius: BorderRadius.circular(SoroTokens.rLg),
                          border: Border.all(
                            color: const Color(0xFF8D5527),
                            width: 6,
                          ),
                          boxShadow: SoroTokens.e2,
                        ),
                        padding: const EdgeInsets.all(SoroTokens.s24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: SoroTokens.s12,
                              runSpacing: SoroTokens.s12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: SoroTokens.s12,
                                    vertical: SoroTokens.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SoroTokens.crimson,
                                    borderRadius: BorderRadius.circular(
                                      SoroTokens.rPill,
                                    ),
                                  ),
                                  child: SoroLocalizedText(
                                    'Sọ̀rọ̀ · Board Session',
                                    language: SoroLanguage.yo,
                                    style: SoroTokens.sans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: SoroTokens.paper,
                                    ),
                                  ),
                                ),
                                if (language.needsNativeCheck)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SoroTokens.s12,
                                      vertical: SoroTokens.s4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SoroTokens.sticky,
                                      borderRadius: BorderRadius.circular(
                                        SoroTokens.rPill,
                                      ),
                                      border: Border.all(
                                        color: SoroTokens.control,
                                      ),
                                    ),
                                    child: Text(
                                      SoroStrings.tr(
                                        language,
                                        'nativeCheckFlag',
                                      ),
                                      style: SoroTokens.sans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: SoroTokens.ink,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: SoroTokens.s16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExcludeSemantics(
                                  child: SvgPicture.asset(
                                    'assets/mascot/soro-ilu-speaking.svg',
                                    width: 68,
                                    height: 68,
                                  ),
                                ),
                                const SizedBox(width: SoroTokens.s16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SoroLocalizedText(
                                        SoroStrings.tr(
                                          language,
                                          'boardPlaceholderTitle',
                                        ),
                                        language: language,
                                        style: SoroTokens.serif(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: SoroTokens.s8),
                                      SoroLocalizedText(
                                        SoroStrings.tr(
                                          language,
                                          'boardPlaceholderSubtitle',
                                        ),
                                        language: language,
                                        style: SoroTokens.sans(
                                          fontSize: 15,
                                          color: SoroTokens.ink2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SoroTokens.s20),
                            const Divider(color: Color(0xFFC4D6EC), height: 1),
                            const SizedBox(height: SoroTokens.s20),
                            SoroLocalizedText(
                              SoroStrings.tr(
                                language,
                                'boardActiveQuestionLabel',
                              ),
                              language: language,
                              style: SoroTokens.sans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: SoroTokens.ink2,
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(SoroTokens.s16),
                              decoration: BoxDecoration(
                                color: SoroTokens.skyDeep,
                                borderRadius:
                                    BorderRadius.circular(SoroTokens.rMd),
                                border: Border.all(
                                  color: SoroTokens.studentBlue,
                                  width: 1.5,
                                ),
                              ),
                              child: SoroLocalizedText(
                                question,
                                key: const Key('board-active-question'),
                                language: language,
                                style: SoroTokens.sans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: SoroTokens.studentBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(SoroTokens.s16),
                              decoration: BoxDecoration(
                                color: SoroTokens.blush.withValues(alpha: 0.45),
                                borderRadius:
                                    BorderRadius.circular(SoroTokens.rMd),
                                border: Border.all(
                                  color: SoroTokens.crimson,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SoroLocalizedText(
                                    SoroStrings.tr(
                                      language,
                                      'boardFirstStepPrompt',
                                    ),
                                    language: language,
                                    style: SoroTokens.sans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: SoroTokens.crimsonDeep,
                                    ),
                                  ),
                                  const SizedBox(height: SoroTokens.s8),
                                  Text(
                                    'x² − 5x + 6 = 0   ⇒   (x − [ ? ])(x − [ ? ]) = 0   ·   roots: ? , ?',
                                    style: SoroTokens.serif(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w600,
                                      color: SoroTokens.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s24),
                            SizedBox(
                              height: SoroTokens.minTapTarget,
                              child: ElevatedButton.icon(
                                onPressed: onBackToChat,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SoroTokens.crimson,
                                  foregroundColor: SoroTokens.paper,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: SoroTokens.s20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      SoroTokens.rPill,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: SoroLocalizedText(
                                  SoroStrings.tr(
                                    language,
                                    'boardBackToChatBtn',
                                  ),
                                  language: language,
                                  style: SoroTokens.sans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: SoroTokens.paper,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder route (`/progress`) opened from the small hidden-by-default
/// "My progress" entry on the home screen.
class MyProgressPlaceholderScreen extends StatelessWidget {
  const MyProgressPlaceholderScreen({
    super.key,
    required this.language,
    required this.networkStatus,
    required this.onLanguageChanged,
    required this.onCycleNetworkStatus,
    required this.onBackToChat,
  });

  final SoroLanguage language;
  final SoroNetworkStatus networkStatus;
  final ValueChanged<SoroLanguage> onLanguageChanged;
  final VoidCallback onCycleNetworkStatus;
  final VoidCallback onBackToChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoroTokens.cream,
      body: SoroDottedPaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              _PlaceholderTopBar(
                language: language,
                networkStatus: networkStatus,
                backButtonKey: const Key('progress-back-button'),
                backLabel: SoroStrings.tr(language, 'progressBackToChatBtn'),
                onLanguageChanged: onLanguageChanged,
                onCycleNetworkStatus: onCycleNetworkStatus,
                onBack: onBackToChat,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SoroTokens.s20,
                    vertical: SoroTokens.s24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Container(
                        key: const Key('progress-placeholder-card'),
                        decoration: BoxDecoration(
                          color: SoroTokens.paper,
                          borderRadius: BorderRadius.circular(SoroTokens.rLg),
                          border: Border.all(color: SoroTokens.line),
                          boxShadow: SoroTokens.e2,
                        ),
                        padding: const EdgeInsets.all(SoroTokens.s24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SoroLocalizedText(
                              SoroStrings.tr(
                                language,
                                'progressPlaceholderTitle',
                              ),
                              language: language,
                              style: SoroTokens.serif(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s8),
                            SoroLocalizedText(
                              SoroStrings.tr(
                                language,
                                'progressPlaceholderSubtitle',
                              ),
                              language: language,
                              style: SoroTokens.sans(
                                fontSize: 15,
                                color: SoroTokens.ink2,
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(SoroTokens.s16),
                              decoration: BoxDecoration(
                                color: SoroTokens.mint,
                                borderRadius:
                                    BorderRadius.circular(SoroTokens.rMd),
                                border: Border.all(
                                  color: SoroTokens.successDeep,
                                ),
                              ),
                              child: Text(
                                'Placeholder · Daily activity, subject breakdown & unaided check results populate here in the dashboard task.',
                                style: SoroTokens.sans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: SoroTokens.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s24),
                            SizedBox(
                              height: SoroTokens.minTapTarget,
                              child: OutlinedButton.icon(
                                onPressed: onBackToChat,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SoroTokens.ink,
                                  side: const BorderSide(
                                    color: SoroTokens.control,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      SoroTokens.rPill,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: SoroLocalizedText(
                                  SoroStrings.tr(
                                    language,
                                    'progressBackToChatBtn',
                                  ),
                                  language: language,
                                  style: SoroTokens.sans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTopBar extends StatelessWidget {
  const _PlaceholderTopBar({
    required this.language,
    required this.networkStatus,
    required this.backButtonKey,
    required this.backLabel,
    required this.onLanguageChanged,
    required this.onCycleNetworkStatus,
    required this.onBack,
  });

  final SoroLanguage language;
  final SoroNetworkStatus networkStatus;
  final Key backButtonKey;
  final String backLabel;
  final ValueChanged<SoroLanguage> onLanguageChanged;
  final VoidCallback onCycleNetworkStatus;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SoroTokens.s20,
        vertical: SoroTokens.s12,
      ),
      decoration: BoxDecoration(
        color: SoroTokens.cream.withValues(alpha: 0.94),
        border: const Border(
          bottom: BorderSide(color: SoroTokens.line),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SoroTokens.s12,
        runSpacing: SoroTokens.s8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: SoroTokens.minTapTarget,
                child: TextButton.icon(
                  key: backButtonKey,
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    foregroundColor: SoroTokens.ink,
                    backgroundColor: SoroTokens.paper,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SoroTokens.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      side: const BorderSide(color: SoroTokens.control),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: SoroLocalizedText(
                    backLabel,
                    language: language,
                    style: SoroTokens.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SoroTokens.s12),
              Semantics(
                label: 'Sọ̀rọ̀ primary colour logo',
                image: true,
                child: SvgPicture.asset(
                  'assets/brand/soro-logo-colour.svg',
                  height: 36,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: SoroTokens.s8,
            runSpacing: SoroTokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                height: SoroTokens.minTapTarget,
                child: OutlinedButton(
                  onPressed: onCycleNetworkStatus,
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        networkStatus == SoroNetworkStatus.weakSignalVoiceOnly
                            ? SoroTokens.warn
                            : SoroTokens.paper,
                    foregroundColor: SoroTokens.ink,
                    side: const BorderSide(color: SoroTokens.control),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  child: SoroLocalizedText(
                    SoroStrings.networkLabel(language, networkStatus),
                    language: language,
                    style: SoroTokens.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: SoroTokens.minTapTarget,
                child: OutlinedButton(
                  onPressed: () {
                    final next = language == SoroLanguage.en
                        ? SoroLanguage.yo
                        : SoroLanguage.en;
                    onLanguageChanged(next);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: SoroTokens.paper,
                    foregroundColor: SoroTokens.ink,
                    side: const BorderSide(color: SoroTokens.control),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  child: Text(
                    language == SoroLanguage.en
                        ? 'EN · Yorùbá'
                        : 'Yorùbá · EN',
                    style: SoroTokens.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
