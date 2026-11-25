import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/soro_strings.dart';
import '../models/chat_models.dart';
import '../theme/soro_theme.dart';

/// A single ink stroke captured via pointer events on the inline stylus pad.
class StylusStroke {
  StylusStroke({
    required this.points,
    required this.widths,
    required this.deviceKind,
  });

  final List<Offset> points;
  final List<double> widths;
  final PointerDeviceKind deviceKind;
}

/// Home screen ("Ask anything" calm chat shell).
///
/// Features:
/// - App shell header with the traced under-dotted `soro-logo-colour.svg`,
///   plain-word network status ('Live', 'Weak signal: voice only', 'Offline'),
///   language selector (English + Yorùbá, flagged 'needs native check'), and
///   a small hidden-by-default entry to "My progress" (keeping statistics hidden
///   on the home screen).
/// - Ìlù talking-drum mascot (`soro-ilu-encouraging.svg` / `soro-ilu-listening.svg`)
///   greeting the student (never any 'confused' state).
/// - Calm chat area above the composer showing the conversation turns and a
///   one-tap "Working · Open board →" button on submitted problems.
/// - Centred ChatGPT/Claude-style "Ask anything" composer with Type, Mic (speech),
///   and Stylus/Handwriting (pointer-event pad in student royal-blue `#1B56D0` ink).
/// - 4 suggested topic chips underneath.
/// - Accessible at 200% text scaling, respects reduced motion, >= 48px tap targets,
///   and explicit keyboard focus order.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.language,
    required this.networkStatus,
    required this.messages,
    required this.onLanguageChanged,
    required this.onNetworkStatusChanged,
    required this.onCycleNetworkStatus,
    required this.onSubmitQuestion,
    required this.onOpenBoard,
    required this.onOpenMyProgress,
  });

  final SoroLanguage language;
  final SoroNetworkStatus networkStatus;
  final List<ChatMessage> messages;
  final ValueChanged<SoroLanguage> onLanguageChanged;
  final ValueChanged<SoroNetworkStatus> onNetworkStatusChanged;
  final VoidCallback onCycleNetworkStatus;
  final void Function(String question, {String? inputMethodLabel})
      onSubmitQuestion;
  final ValueChanged<String> onOpenBoard;
  final VoidCallback onOpenMyProgress;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();

  bool _isMicListening = false;
  bool _isStylusPadOpen = false;

  final List<StylusStroke> _strokes = <StylusStroke>[];
  StylusStroke? _activeStroke;
  PointerDeviceKind _lastPointerKind = PointerDeviceKind.stylus;

  static const List<SuggestedTopic> _suggestedTopics = [
    SuggestedTopic(
      id: 'quadratic',
      titleKey: 'chipQuadraticTitle',
      promptKey: 'chipQuadraticPrompt',
      tagKey: 'chipQuadraticTag',
    ),
    SuggestedTopic(
      id: 'friction',
      titleKey: 'chipFrictionTitle',
      promptKey: 'chipFrictionPrompt',
      tagKey: 'chipFrictionTag',
    ),
    SuggestedTopic(
      id: 'pdf',
      titleKey: 'chipPdfTitle',
      promptKey: 'chipPdfPrompt',
      tagKey: 'chipPdfTag',
    ),
    SuggestedTopic(
      id: 'complete-square',
      titleKey: 'chipCompleteSquareTitle',
      promptKey: 'chipCompleteSquarePrompt',
      tagKey: 'chipCompleteSquareTag',
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _handleTextSubmit() {
    final String text = _textController.text.trim();
    if (text.isEmpty) {
      _composerFocusNode.requestFocus();
      return;
    }
    _textController.clear();
    setState(() {
      _isMicListening = false;
    });
    widget.onSubmitQuestion(text, inputMethodLabel: 'Typed');
  }

  void _handleMicToggle() {
    if (!_isMicListening) {
      setState(() {
        _isMicListening = true;
        if (_textController.text.trim().isEmpty) {
          _textController.text =
              SoroStrings.tr(widget.language, 'spokenSampleQuestion');
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        }
      });
    } else {
      final String spoken = _textController.text.trim().isEmpty
          ? SoroStrings.tr(widget.language, 'spokenSampleQuestion')
          : _textController.text.trim();
      _textController.clear();
      setState(() {
        _isMicListening = false;
      });
      widget.onSubmitQuestion(spoken, inputMethodLabel: 'Voice');
    }
  }

  void _handleStylusToggle() {
    setState(() {
      _isStylusPadOpen = !_isStylusPadOpen;
    });
  }

  void _handleSubmitFromStylus() {
    final String typed = _textController.text.trim();
    final String baseEquation = typed.isNotEmpty
        ? typed
        : SoroStrings.tr(widget.language, 'stylusDefaultEquation');
    final String prefix =
        SoroStrings.tr(widget.language, 'stylusRecognisedPrefix');
    _textController.clear();
    setState(() {
      _isStylusPadOpen = false;
      _strokes.clear();
    });
    widget.onSubmitQuestion(
      '$prefix$baseEquation',
      inputMethodLabel: 'Stylus (${_lastPointerKind.name})',
    );
  }

  double _strokeWidthForEvent(PointerEvent event) {
    final double pressure =
        (event.pressure > 0 && event.pressure <= 1.0) ? event.pressure : 0.55;
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return 2.0 + (pressure * 3.2);
    }
    return 3.2;
  }

  @override
  Widget build(BuildContext context) {
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final SoroLanguage lang = widget.language;

    return Scaffold(
      backgroundColor: SoroTokens.cream,
      body: SoroDottedPaperBackground(
        child: SafeArea(
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: _buildAppShellHeader(context, lang, reducedMotion),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SoroTokens.s16,
                      vertical: SoroTokens.s20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: _buildIluGreetingSection(
                                context,
                                lang,
                                reducedMotion,
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s12),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(3),
                              child: _buildCalmChatSection(context, lang),
                            ),
                            const SizedBox(height: SoroTokens.s12),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(4),
                              child: _buildAskAnythingComposer(
                                context,
                                lang,
                                reducedMotion,
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s16),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(5),
                              child: _buildSuggestedTopicsSection(
                                context,
                                lang,
                              ),
                            ),
                            const SizedBox(height: SoroTokens.s16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppShellHeader(
    BuildContext context,
    SoroLanguage lang,
    bool reducedMotion,
  ) {
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
        runSpacing: SoroTokens.s12,
        children: [
          // Brand lockup with traced under-dotted Sọ̀rọ̀ colour logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Sọ̀rọ̀ primary colour logo with Yorùbá under-dots',
                image: true,
                child: SvgPicture.asset(
                  'assets/brand/soro-logo-colour.svg',
                  key: const Key('soro-header-logo'),
                  height: 40,
                ),
              ),
              const SizedBox(width: SoroTokens.s12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SoroLocalizedText(
                      SoroStrings.tr(lang, 'tagline'),
                      language: lang,
                      style: SoroTokens.sans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: SoroTokens.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right shell controls: Plain-word network status, Language selector, Hidden-by-default My progress
          Wrap(
            spacing: SoroTokens.s8,
            runSpacing: SoroTokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildNetworkStatusPill(lang),
              _buildLanguageSelector(lang),
              _buildMyProgressEntry(lang, reducedMotion),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStatusPill(SoroLanguage lang) {
    final SoroNetworkStatus status = widget.networkStatus;
    final String label = SoroStrings.networkLabel(lang, status);

    Color bgColor = SoroTokens.paper;
    Color dotColor = SoroTokens.success;
    String glyph = '●';

    if (status == SoroNetworkStatus.weakSignalVoiceOnly) {
      bgColor = SoroTokens.warn;
      dotColor = SoroTokens.ink;
      glyph = '◐';
    } else if (status == SoroNetworkStatus.offline) {
      bgColor = SoroTokens.sand;
      dotColor = SoroTokens.control;
      glyph = '○';
    }

    return Semantics(
      button: true,
      label: '${SoroStrings.tr(lang, 'networkStatusTooltip')}: $label',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SoroTokens.minTapTarget,
        ),
        child: OutlinedButton(
          key: const Key('network-status-pill'),
          onPressed: widget.onCycleNetworkStatus,
          style: OutlinedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: SoroTokens.ink,
            padding: const EdgeInsets.symmetric(
              horizontal: SoroTokens.s16,
              vertical: SoroTokens.s8,
            ),
            side: const BorderSide(color: SoroTokens.control, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SoroTokens.rPill),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                glyph,
                style: SoroTokens.sans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: SoroTokens.s8),
              Flexible(
                child: SoroLocalizedText(
                  label,
                  language: lang,
                  style: SoroTokens.sans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(SoroLanguage lang) {
    return Semantics(
      container: true,
      label: SoroStrings.tr(lang, 'languageSelectorLabel'),
      child: Container(
        key: const Key('language-selector'),
        constraints: const BoxConstraints(minHeight: SoroTokens.minTapTarget),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: SoroTokens.paper,
          borderRadius: BorderRadius.circular(SoroTokens.rPill),
          border: Border.all(color: SoroTokens.control, width: 1.5),
          boxShadow: SoroTokens.e1,
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LanguageOptionButton(
              buttonKey: const Key('lang-en-button'),
              label: 'English',
              isSelected: lang == SoroLanguage.en,
              locale: SoroLanguage.en,
              onTap: () => widget.onLanguageChanged(SoroLanguage.en),
            ),
            _LanguageOptionButton(
              buttonKey: const Key('lang-yo-button'),
              label: 'Yorùbá',
              isSelected: lang == SoroLanguage.yo,
              locale: SoroLanguage.yo,
              onTap: () => widget.onLanguageChanged(SoroLanguage.yo),
            ),
          ],
        ),
      ),
    );
  }

  /// One-tap entry to the "My progress" page. Only the button lives here; no
  /// statistics are shown on the home screen.
  Widget _buildMyProgressEntry(
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: SoroTokens.minTapTarget),
      child: OutlinedButton.icon(
        key: const Key('my-progress-entry-button'),
        onPressed: widget.onOpenMyProgress,
        style: OutlinedButton.styleFrom(
          backgroundColor: SoroTokens.paper,
          foregroundColor: SoroTokens.ink,
          padding: const EdgeInsets.symmetric(horizontal: SoroTokens.s16),
          side: const BorderSide(color: SoroTokens.crimson, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SoroTokens.rPill),
          ),
        ),
        icon: const Icon(
          Icons.auto_graph_rounded,
          size: 18,
          color: SoroTokens.crimson,
        ),
        label: SoroLocalizedText(
          SoroStrings.tr(lang, 'myProgressEntry'),
          language: lang,
          style: SoroTokens.sans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildIluGreetingSection(
    BuildContext context,
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    final String mascotAsset = _isMicListening
        ? 'assets/mascot/soro-ilu-listening.svg'
        : 'assets/mascot/soro-ilu-encouraging.svg';

    return Container(
      key: const Key('ilu-greeting-section'),
      padding: const EdgeInsets.symmetric(
        horizontal: SoroTokens.s20,
        vertical: SoroTokens.s16,
      ),
      decoration: BoxDecoration(
        color: SoroTokens.paper,
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        border: Border.all(color: SoroTokens.line),
        boxShadow: SoroTokens.e1,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SoroTokens.blush.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Semantics(
                  label: _isMicListening
                      ? 'Ìlù the talking drum listening to your question'
                      : 'Ìlù the talking drum greeting and encouraging you',
                  image: true,
                  child: SvgPicture.asset(
                    mascotAsset,
                    key: const Key('ilu-mascot-svg'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: SoroTokens.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: SoroTokens.s8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: SoroTokens.blush,
                            borderRadius:
                                BorderRadius.circular(SoroTokens.rPill),
                          ),
                          child: SoroLocalizedText(
                            SoroStrings.tr(lang, 'greetingBadge'),
                            language: lang,
                            style: SoroTokens.sans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: SoroTokens.crimsonDeep,
                            ),
                          ),
                        ),
                        if (lang.needsNativeCheck)
                          Container(
                            key: const Key('yoruba-native-check-badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: SoroTokens.sticky,
                              borderRadius:
                                  BorderRadius.circular(SoroTokens.rPill),
                              border: Border.all(color: SoroTokens.control),
                            ),
                            child: Text(
                              SoroStrings.tr(lang, 'nativeCheckFlag'),
                              style: SoroTokens.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SoroTokens.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SoroLocalizedText(
                      SoroStrings.tr(lang, 'greetingHeadline'),
                      key: const Key('greeting-headline'),
                      language: lang,
                      style: SoroTokens.serif(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: SoroTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SoroLocalizedText(
                      SoroStrings.tr(lang, 'greetingSubtitle'),
                      language: lang,
                      style: SoroTokens.sans(
                        fontSize: 14.5,
                        color: SoroTokens.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalmChatSection(BuildContext context, SoroLanguage lang) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: SoroStrings.tr(lang, 'chatSectionLabel'),
      child: Column(
        key: const Key('calm-chat-area'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ChatMessage msg in widget.messages)
            Padding(
              padding: const EdgeInsets.only(bottom: SoroTokens.s12),
              child: _ChatTurnBubble(
                message: msg,
                currentLanguage: lang,
                onOpenBoard: () => widget.onOpenBoard(msg.text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAskAnythingComposer(
    BuildContext context,
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    return Container(
      key: const Key('ask-anything-composer'),
      padding: const EdgeInsets.all(SoroTokens.s20),
      decoration: BoxDecoration(
        color: SoroTokens.paper,
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        border: Border.all(
          color: _isMicListening ? SoroTokens.crimson : SoroTokens.control,
          width: _isMicListening ? 2.0 : 1.5,
        ),
        boxShadow: SoroTokens.e2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SoroTokens.s8,
            runSpacing: SoroTokens.s8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SvgPicture.asset(
                      'assets/mascot/soro-ilu-icon.svg',
                      width: 26,
                      height: 26,
                    ),
                  ),
                  const SizedBox(width: SoroTokens.s8),
                  Flexible(
                    child: SoroLocalizedText(
                      SoroStrings.tr(lang, 'composerHeading'),
                      language: lang,
                      style: SoroTokens.serif(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: SoroTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
              // Yorùbá tone-mark proof badge so ọ̀ ẹ̀ ṣ rendering is always verifiable on screen
              Semantics(
                label: 'Yorùbá tone marks proof: ${SoroStrings.yorubaProofString}',
                child: Container(
                  key: const Key('yoruba-tone-proof'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SoroTokens.s12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SoroTokens.sky,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  ),
                  child: SoroLocalizedText(
                    'Sọ̀rọ̀ · ọ̀ ẹ̀ ṣ',
                    language: SoroLanguage.yo,
                    style: SoroTokens.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SoroTokens.s12),
          TextField(
            key: const Key('ask-anything-input'),
            controller: _textController,
            focusNode: _composerFocusNode,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleTextSubmit(),
            style: SoroTokens.sans(
              fontSize: 16.5,
              fontWeight: FontWeight.w500,
              color: SoroTokens.ink,
            ),
            decoration: InputDecoration(
              hintText: SoroStrings.tr(lang, 'composerPlaceholder'),
              hintStyle: SoroTokens.sans(
                fontSize: 15.5,
                color: SoroTokens.ink2,
              ),
              hintMaxLines: 3,
              filled: true,
              fillColor: SoroTokens.cream.withValues(alpha: 0.55),
              contentPadding: const EdgeInsets.all(SoroTokens.s16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SoroTokens.rMd),
                borderSide: const BorderSide(color: SoroTokens.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SoroTokens.rMd),
                borderSide: const BorderSide(color: SoroTokens.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SoroTokens.rMd),
                borderSide: const BorderSide(
                  color: SoroTokens.crimson,
                  width: 2.0,
                ),
              ),
            ),
          ),

          // Expandable stylus / handwriting pad using raw PointerEvents (stylus pressure aware)
          if (_isStylusPadOpen) ...[
            const SizedBox(height: SoroTokens.s16),
            _buildStylusHandwritingPad(lang),
          ],

          const SizedBox(height: SoroTokens.s16),

          // Bottom toolbar inside composer: Mic button, Stylus button, and Primary Ask CTA
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SoroTokens.s12,
            runSpacing: SoroTokens.s12,
            children: [
              Wrap(
                spacing: SoroTokens.s12,
                runSpacing: SoroTokens.s8,
                children: [
                  // Mic / Speech Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: SoroTokens.minTapTarget,
                    ),
                    child: OutlinedButton.icon(
                      key: const Key('composer-mic-button'),
                      onPressed: _handleMicToggle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isMicListening
                            ? SoroTokens.blush
                            : SoroTokens.paper,
                        foregroundColor: SoroTokens.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: SoroTokens.s16,
                          vertical: SoroTokens.s12,
                        ),
                        side: BorderSide(
                          color: _isMicListening
                              ? SoroTokens.crimson
                              : SoroTokens.control,
                          width: _isMicListening ? 2.0 : 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SoroTokens.rPill),
                        ),
                      ),
                      icon: Icon(
                        _isMicListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_none_rounded,
                        color: SoroTokens.crimson,
                        size: 20,
                      ),
                      label: SoroLocalizedText(
                        _isMicListening
                            ? SoroStrings.tr(lang, 'composerSpeakListening')
                            : SoroStrings.tr(lang, 'composerSpeakBtn'),
                        language: lang,
                        style: SoroTokens.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SoroTokens.ink,
                        ),
                      ),
                    ),
                  ),

                  // Stylus / Handwriting Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: SoroTokens.minTapTarget,
                    ),
                    child: OutlinedButton.icon(
                      key: const Key('composer-stylus-button'),
                      onPressed: _handleStylusToggle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isStylusPadOpen
                            ? SoroTokens.sky
                            : SoroTokens.paper,
                        foregroundColor: SoroTokens.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: SoroTokens.s16,
                          vertical: SoroTokens.s12,
                        ),
                        side: BorderSide(
                          color: _isStylusPadOpen
                              ? SoroTokens.studentBlue
                              : SoroTokens.control,
                          width: _isStylusPadOpen ? 2.0 : 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(SoroTokens.rPill),
                        ),
                      ),
                      icon: const Icon(
                        Icons.draw_rounded,
                        color: SoroTokens.studentBlue,
                        size: 20,
                      ),
                      label: SoroLocalizedText(
                        _isStylusPadOpen
                            ? SoroStrings.tr(lang, 'composerStylusActive')
                            : SoroStrings.tr(lang, 'composerStylusBtn'),
                        language: lang,
                        style: SoroTokens.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SoroTokens.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Primary Submit / Ask CTA (opens the board session)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: ElevatedButton.icon(
                  key: const Key('composer-submit-button'),
                  onPressed: _handleTextSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SoroTokens.crimson,
                    foregroundColor: SoroTokens.paper,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SoroTokens.s24,
                      vertical: SoroTokens.s12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                  label: SoroLocalizedText(
                    SoroStrings.tr(lang, 'composerAskBtn'),
                    language: lang,
                    style: SoroTokens.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.paper,
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

  Widget _buildStylusHandwritingPad(SoroLanguage lang) {
    return Container(
      key: const Key('stylus-handwriting-pad'),
      padding: const EdgeInsets.all(SoroTokens.s16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(SoroTokens.rMd),
        border: Border.all(
          color: SoroTokens.studentBlue,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SoroTokens.s8,
            runSpacing: SoroTokens.s8,
            children: [
              SoroLocalizedText(
                SoroStrings.tr(lang, 'stylusPadTitle'),
                language: lang,
                style: SoroTokens.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SoroTokens.studentBlue,
                ),
              ),
              Text(
                'Ink: Student Royal Blue (#1B56D0) · Pointer: ${_lastPointerKind.name}',
                style: SoroTokens.sans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: SoroTokens.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: SoroTokens.s4),
          SoroLocalizedText(
            SoroStrings.tr(lang, 'stylusPadHint'),
            language: lang,
            style: SoroTokens.sans(
              fontSize: 13,
              color: SoroTokens.ink2,
            ),
          ),
          const SizedBox(height: SoroTokens.s12),
          Semantics(
            label: 'Interactive stylus handwriting canvas',
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFA),
                borderRadius: BorderRadius.circular(SoroTokens.rSm),
                border: Border.all(color: SoroTokens.control),
              ),
              clipBehavior: Clip.hardEdge,
              child: Listener(
                key: const Key('stylus-pointer-listener'),
                onPointerDown: (PointerDownEvent event) {
                  setState(() {
                    _lastPointerKind = event.kind;
                    _activeStroke = StylusStroke(
                      points: <Offset>[event.localPosition],
                      widths: <double>[_strokeWidthForEvent(event)],
                      deviceKind: event.kind,
                    );
                    _strokes.add(_activeStroke!);
                  });
                },
                onPointerMove: (PointerMoveEvent event) {
                  if (_activeStroke == null) return;
                  setState(() {
                    _activeStroke!.points.add(event.localPosition);
                    _activeStroke!.widths.add(_strokeWidthForEvent(event));
                  });
                },
                onPointerUp: (PointerUpEvent event) {
                  setState(() {
                    _activeStroke = null;
                  });
                },
                onPointerCancel: (PointerCancelEvent event) {
                  setState(() {
                    _activeStroke = null;
                  });
                },
                child: CustomPaint(
                  painter: _StylusPadPainter(strokes: _strokes),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: SoroTokens.s12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: SoroTokens.s12,
            runSpacing: SoroTokens.s8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: OutlinedButton.icon(
                  key: const Key('stylus-clear-button'),
                  onPressed: () {
                    setState(() {
                      _strokes.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SoroTokens.ink,
                    side: const BorderSide(color: SoroTokens.control),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: SoroLocalizedText(
                    SoroStrings.tr(lang, 'stylusClearBtn'),
                    language: lang,
                    style: SoroTokens.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: ElevatedButton.icon(
                  key: const Key('stylus-use-button'),
                  onPressed: _handleSubmitFromStylus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SoroTokens.studentBlue,
                    foregroundColor: SoroTokens.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: SoroLocalizedText(
                    SoroStrings.tr(lang, 'stylusUseBtn'),
                    language: lang,
                    style: SoroTokens.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SoroTokens.paper,
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

  Widget _buildSuggestedTopicsSection(
    BuildContext context,
    SoroLanguage lang,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SoroTokens.s4),
          child: SoroLocalizedText(
            SoroStrings.tr(lang, 'suggestedTopicsHeading'),
            language: lang,
            style: SoroTokens.sans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: SoroTokens.ink2,
            ),
          ),
        ),
        const SizedBox(height: SoroTokens.s12),
        Wrap(
          spacing: SoroTokens.s12,
          runSpacing: SoroTokens.s12,
          children: [
            for (final SuggestedTopic topic in _suggestedTopics)
              _SuggestedTopicChip(
                key: Key('topic-chip-${topic.id}'),
                topic: topic,
                language: lang,
                onTap: () {
                  final String prompt =
                      SoroStrings.tr(lang, topic.promptKey);
                  widget.onSubmitQuestion(
                    prompt,
                    inputMethodLabel: 'Topic chip',
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LanguageOptionButton extends StatelessWidget {
  const _LanguageOptionButton({
    required this.buttonKey,
    required this.label,
    required this.isSelected,
    required this.locale,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool isSelected;
  final SoroLanguage locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: locale.needsNativeCheck
          ? '$label (needs native check)'
          : label,
      child: Material(
        color: isSelected ? SoroTokens.crimson : Colors.transparent,
        borderRadius: BorderRadius.circular(SoroTokens.rPill),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(SoroTokens.rPill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SoroTokens.s16,
              vertical: 8,
            ),
            child: SoroLocalizedText(
              label,
              language: locale,
              style: SoroTokens.sans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? SoroTokens.paper : SoroTokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTurnBubble extends StatelessWidget {
  const _ChatTurnBubble({
    required this.message,
    required this.currentLanguage,
    required this.onOpenBoard,
  });

  final ChatMessage message;
  final SoroLanguage currentLanguage;
  final VoidCallback onOpenBoard;

  @override
  Widget build(BuildContext context) {
    final bool isTutor = message.sender == ChatSender.tutor;

    return Container(
      padding: const EdgeInsets.all(SoroTokens.s16),
      decoration: BoxDecoration(
        color: isTutor ? SoroTokens.paper : SoroTokens.skyDeep,
        borderRadius: BorderRadius.circular(SoroTokens.rMd),
        border: Border.all(
          color: isTutor ? SoroTokens.line : SoroTokens.studentBlue,
          width: isTutor ? 1.0 : 1.5,
        ),
        boxShadow: SoroTokens.e1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SoroTokens.s8,
            runSpacing: SoroTokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color:
                      isTutor ? SoroTokens.crimson : SoroTokens.studentBlue,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isTutor) ...[
                      ExcludeSemantics(
                        child: SvgPicture.asset(
                          'assets/mascot/soro-ilu-icon.svg',
                          width: 15,
                          height: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: SoroLocalizedText(
                        isTutor
                            ? SoroStrings.tr(currentLanguage, 'chatTutorRole')
                            : SoroStrings.tr(
                                currentLanguage,
                                'chatStudentRole',
                              ),
                        language: currentLanguage,
                        style: SoroTokens.sans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: SoroTokens.paper,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.inputMethodLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SoroTokens.paper,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    border: Border.all(color: SoroTokens.control),
                  ),
                  child: Text(
                    message.inputMethodLabel!,
                    style: SoroTokens.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SoroTokens.ink2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SoroTokens.s8),
          SoroLocalizedText(
            message.text,
            language: message.language,
            style: SoroTokens.sans(
              fontSize: 15.5,
              fontWeight: isTutor ? FontWeight.w400 : FontWeight.w600,
              color: SoroTokens.ink,
            ),
          ),
          if (message.bilingualNote != null) ...[
            const SizedBox(height: SoroTokens.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SoroTokens.s12,
                vertical: SoroTokens.s8,
              ),
              decoration: BoxDecoration(
                color: SoroTokens.cream,
                borderRadius: BorderRadius.circular(SoroTokens.rSm),
                border: Border.all(color: SoroTokens.line),
              ),
              child: SoroLocalizedText(
                message.bilingualNote!,
                language: SoroLanguage.yo,
                style: SoroTokens.sans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: SoroTokens.ink2,
                ),
              ),
            ),
          ],
          if (message.opensBoard) ...[
            const SizedBox(height: SoroTokens.s12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: SoroTokens.minTapTarget,
              ),
              child: OutlinedButton.icon(
                onPressed: onOpenBoard,
                style: OutlinedButton.styleFrom(
                  backgroundColor: SoroTokens.paper,
                  foregroundColor: SoroTokens.crimsonDeep,
                  side: const BorderSide(
                    color: SoroTokens.crimson,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  ),
                ),
                icon: const Icon(
                  Icons.dashboard_customize_rounded,
                  size: 18,
                  color: SoroTokens.crimson,
                ),
                label: SoroLocalizedText(
                  SoroStrings.tr(currentLanguage, 'chatOpenBoardAction'),
                  language: currentLanguage,
                  style: SoroTokens.sans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.crimsonDeep,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestedTopicChip extends StatelessWidget {
  const _SuggestedTopicChip({
    super.key,
    required this.topic,
    required this.language,
    required this.onTap,
  });

  final SuggestedTopic topic;
  final SoroLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title = SoroStrings.tr(language, topic.titleKey);
    final String tag = SoroStrings.tr(language, topic.tagKey);

    return Semantics(
      button: true,
      label: '$title ($tag)',
      child: Material(
        color: SoroTokens.paper,
        borderRadius: BorderRadius.circular(SoroTokens.rMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(SoroTokens.rMd),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: SoroTokens.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: SoroTokens.s16,
              vertical: SoroTokens.s12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SoroTokens.rMd),
              border: Border.all(color: SoroTokens.control, width: 1.5),
              boxShadow: SoroTokens.e1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SoroTokens.sand,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  ),
                  child: SoroLocalizedText(
                    tag,
                    language: language,
                    style: SoroTokens.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.ink2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SoroLocalizedText(
                  title,
                  language: language,
                  style: SoroTokens.sans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StylusPadPainter extends CustomPainter {
  const _StylusPadPainter({required this.strokes});

  final List<StylusStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw ruled notebook blue lines & red margin line inside the stylus pad
    final rulePaint = Paint()
      ..color = const Color(0xFFC4D6EC)
      ..strokeWidth = 1.1;
    for (double y = 32; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
    }

    final marginPaint = Paint()
      ..color = const Color(0xFFE4ACAB)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(42, 0), Offset(42, size.height), marginPaint);

    // Draw student strokes in CVD-safe Royal Blue (#1B56D0)
    for (final StylusStroke stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = SoroTokens.studentBlue
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        strokePaint.strokeWidth = stroke.widths.first;
        canvas.drawCircle(
          stroke.points.first,
          stroke.widths.first / 2,
          strokePaint..style = PaintingStyle.fill,
        );
        continue;
      }

      for (int i = 0; i < stroke.points.length - 1; i++) {
        strokePaint.strokeWidth = stroke.widths[i];
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StylusPadPainter oldDelegate) => true;
}
