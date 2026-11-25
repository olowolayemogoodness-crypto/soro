import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/soro_strings.dart';
import '../models/chat_models.dart';
import '../features/graph_friction/graph_friction_screen.dart';
import '../features/progress/progress_data.dart';
import '../theme/soro_theme.dart';
import '../widgets/soro_empty_state.dart';
import 'home_dashboard.dart';

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

  late final int _streak = ProgressData.sample().streak;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _askCardKey = GlobalKey();
  int _navIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
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
      inputMethodLabel: 'Handwriting',
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
    final bool onDashboard = _navIndex == 0 || _navIndex == 3;

    return Scaffold(
      backgroundColor: SoroTokens.paper,
      bottomNavigationBar: SoroBottomNav(
        language: lang,
        selected: _navIndex,
        onSelect: _handleNavSelect,
      ),
      body: SoroDottedPaperBackground(
        child: SafeArea(
          bottom: false,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: _buildAppShellHeader(context, lang, reducedMotion),
                ),
                Expanded(
                  child: onDashboard
                      ? _buildDashboard(context, lang, reducedMotion)
                      : _buildComingSoon(lang),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavSelect(int index) {
    setState(() => _navIndex = index);
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } else if (index == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? target = _askCardKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : SoroTokens.mBase,
            alignment: 0.05,
          );
        }
        _composerFocusNode.requestFocus();
      });
    }
  }

  void _openDefaultProblem() =>
      widget.onOpenBoard(SoroStrings.tr(widget.language, 'chipQuadraticPrompt'));

  Widget _buildComingSoon(SoroLanguage lang) {
    return Center(
      child: SoroEmptyState(
        key: const Key('coming-soon-state'),
        title: SoroStrings.tr(lang, 'soonTitle'),
        message: SoroStrings.tr(lang, 'soonMessage'),
        actionLabel: SoroStrings.tr(lang, 'soonAction'),
        onAction: () => _handleNavSelect(0),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        final Widget hero = SoroHeroCard(
          language: lang,
          onStart: _openDefaultProblem,
        );
        final Widget ask = KeyedSubtree(
          key: _askCardKey,
          child: _buildAskSoroCard(context, lang, reducedMotion),
        );
        final Widget learn = _buildContinueLearning(lang);
        final Widget quick = _buildQuickLinks(lang, wide);
        final Widget today = _buildTodaySection(lang);
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            SoroTokens.s16,
            SoroTokens.s16,
            SoroTokens.s16,
            SoroTokens.s24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  const SizedBox(height: SoroTokens.s20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: ask),
                        const SizedBox(width: SoroTokens.s20),
                        Expanded(flex: 5, child: learn),
                      ],
                    )
                  else ...[
                    ask,
                    const SizedBox(height: SoroTokens.s20),
                    learn,
                  ],
                  const SizedBox(height: SoroTokens.s24),
                  quick,
                  const SizedBox(height: SoroTokens.s24),
                  today,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeading(SoroLanguage lang, String key) {
    return Padding(
      padding: const EdgeInsets.only(
        left: SoroTokens.s4,
        bottom: SoroTokens.s12,
      ),
      child: Semantics(
        header: true,
        child: SoroLocalizedText(
          SoroStrings.tr(lang, key),
          language: lang,
          style: SoroTokens.serif(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAskSoroCard(
    BuildContext context,
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    return Container(
      key: const Key('ask-soro-card'),
      padding: const EdgeInsets.all(SoroTokens.s20),
      decoration: BoxDecoration(
        color: SoroTokens.skyDeep,
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        border: Border.all(color: SoroTokens.sky, width: 1.5),
        boxShadow: SoroTokens.e2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: SoroTokens.paper,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: SvgPicture.asset(
                    _isMicListening
                        ? 'assets/mascot/soro-ilu-listening.svg'
                        : 'assets/mascot/soro-ilu-icon.svg',
                  ),
                ),
              ),
              const SizedBox(width: SoroTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: SoroLocalizedText(
                        SoroStrings.tr(lang, 'askCardTitle'),
                        language: lang,
                        style: SoroTokens.serif(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SoroLocalizedText(
                      SoroStrings.tr(lang, 'askCardSubtitle'),
                      language: lang,
                      style: SoroTokens.sans(
                        fontSize: 14,
                        color: SoroTokens.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SoroTokens.s16),
          FocusTraversalOrder(
            order: const NumericFocusOrder(3),
            child: _buildCalmChatSection(context, lang),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(4),
            child: _buildAskAnythingComposer(context, lang, reducedMotion),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueLearning(SoroLanguage lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(lang, 'continueHeading'),
        SoroLearnCard(
          key: const Key('learn-card-quadratic'),
          language: lang,
          tint: SoroTokens.peach,
          accent: SoroTokens.orange,
          icon: Icons.functions_rounded,
          tag: SoroStrings.tr(lang, 'chipQuadraticTag'),
          title: SoroStrings.tr(lang, 'chipQuadraticTitle'),
          line: SoroStrings.tr(lang, 'learnQuadraticLine'),
          onTap: _openDefaultProblem,
        ),
        const SizedBox(height: SoroTokens.s12),
        SoroLearnCard(
          key: const Key('learn-card-friction'),
          language: lang,
          tint: SoroTokens.mint,
          accent: SoroTokens.success,
          icon: Icons.speed_rounded,
          tag: SoroStrings.tr(lang, 'chipFrictionTag'),
          title: SoroStrings.tr(lang, 'chipFrictionTitle'),
          line: SoroStrings.tr(lang, 'learnFrictionLine'),
          onTap: () => widget
              .onOpenBoard(SoroStrings.tr(lang, 'chipFrictionPrompt')),
        ),
      ],
    );
  }

  Widget _buildQuickLinks(SoroLanguage lang, bool wide) {
    final List<Widget> tiles = [
      SoroQuickTile(
        key: const Key('quick-progress'),
        label: SoroStrings.tr(lang, 'myProgressEntry'),
        icon: Icons.auto_graph_rounded,
        tint: SoroTokens.blush,
        accent: SoroTokens.crimson,
        onTap: widget.onOpenMyProgress,
      ),
      SoroQuickTile(
        key: const Key('quick-glossary'),
        label: SoroStrings.tr(lang, 'qlGlossary'),
        icon: Icons.translate_rounded,
        tint: SoroTokens.lilac,
        accent: const Color(0xFF6B3FA0),
        onTap: () => _showGlossary(lang),
      ),
      SoroQuickTile(
        key: const Key('quick-graph-friction'),
        label: SoroStrings.tr(lang, 'qlGraphFriction'),
        icon: Icons.show_chart_rounded,
        tint: SoroTokens.sky,
        accent: SoroTokens.studentBlue,
        onTap: () => Navigator.of(context).pushNamed(kGraphFrictionRoute),
      ),
      SoroQuickTile(
        key: const Key('quick-pdf'),
        label: SoroStrings.tr(lang, 'chipPdfTitle'),
        icon: Icons.picture_as_pdf_rounded,
        tint: SoroTokens.sand,
        accent: SoroTokens.control,
        soonNote: SoroStrings.tr(lang, 'qlSoon'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(lang, 'quickHeading'),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final int cols = wide ? 4 : 2;
            const double gap = SoroTokens.s12;
            final double w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final Widget t in tiles) SizedBox(width: w, child: t),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showGlossary(SoroLanguage lang) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SoroTokens.paper,
      isScrollControlled: true,
      builder: (BuildContext ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SoroTokens.s24),
          child: Column(
            key: const Key('glossary-sheet'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SoroLocalizedText(
                SoroStrings.tr(lang, 'glossaryTitle'),
                language: lang,
                style: SoroTokens.serif(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: SoroTokens.s12),
              for (final String k in const [
                'glossaryTerm1',
                'glossaryTerm2',
                'glossaryTerm3',
                'glossaryTerm4',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    SoroStrings.tr(lang, k),
                    style: SoroTokens.sans(fontSize: 16),
                  ),
                ),
              const SizedBox(height: SoroTokens.s12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      SoroTokens.minTapTarget,
                      SoroTokens.minTapTarget,
                    ),
                  ),
                  child: Text(SoroStrings.tr(lang, 'glossaryClose')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySection(SoroLanguage lang) {
    final Widget streak = Container(
      key: const Key('today-streak-card'),
      padding: const EdgeInsets.all(SoroTokens.s20),
      decoration: BoxDecoration(
        color: SoroTokens.sun.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        boxShadow: SoroTokens.e1,
      ),
      child: Semantics(
        label: '$_streak ${SoroStrings.tr(lang, 'streakLabel')}',
        excludeSemantics: true,
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              color: SoroTokens.crimson,
              size: 40,
            ),
            const SizedBox(width: SoroTokens.s12),
            Text(
              '$_streak',
              style: SoroTokens.serif(fontSize: 40, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: SoroTokens.s12),
            Expanded(
              child: Text(
                SoroStrings.tr(lang, 'streakLabel'),
                style: SoroTokens.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final Widget plan = Container(
      key: const Key('today-plan-card'),
      padding: const EdgeInsets.all(SoroTokens.s8),
      decoration: BoxDecoration(
        color: SoroTokens.paper,
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        border: Border.all(color: SoroTokens.line),
        boxShadow: SoroTokens.e1,
      ),
      child: SoroEmptyState(
        title: SoroStrings.tr(lang, 'planEmptyTitle'),
        message: SoroStrings.tr(lang, 'planEmptyMessage'),
        actionLabel: SoroStrings.tr(lang, 'heroCta'),
        onAction: _openDefaultProblem,
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeading(lang, 'todayHeading'),
            if (c.maxWidth >= 700)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: streak),
                  const SizedBox(width: SoroTokens.s16),
                  Expanded(flex: 3, child: plan),
                ],
              )
            else ...[
              streak,
              const SizedBox(height: SoroTokens.s12),
              plan,
            ],
          ],
        );
      },
    );
  }

  Widget _buildAppShellHeader(
    BuildContext context,
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SoroTokens.s16,
        vertical: SoroTokens.s8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SoroTokens.s12,
            runSpacing: SoroTokens.s8,
            children: [
              Wrap(
                spacing: SoroTokens.s16,
                runSpacing: SoroTokens.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    label: 'Sọ̀rọ̀ primary colour logo with Yorùbá under-dots',
                    image: true,
                    child: SvgPicture.asset(
                      'assets/brand/soro-logo-colour.svg',
                      key: const Key('soro-header-logo'),
                      height: 32,
                    ),
                  ),
                  SoroLocalizedText(
                    SoroStrings.tr(lang, 'helloName'),
                    key: const Key('greeting-headline'),
                    language: lang,
                    style: SoroTokens.serif(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
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
                        borderRadius: BorderRadius.circular(SoroTokens.rPill),
                        border: Border.all(color: SoroTokens.control),
                      ),
                      child: Text(
                        SoroStrings.tr(lang, 'nativeCheckFlag'),
                        style: SoroTokens.sans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
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
        ),
      ),
    );
  }

  /// Round My progress button with a small flame badge carrying the streak.
  Widget _buildMyProgressEntry(
    SoroLanguage lang,
    bool reducedMotion,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6),
      child: Semantics(
        button: true,
        label:
            '${SoroStrings.tr(lang, 'myProgressEntry')}, $_streak ${SoroStrings.tr(lang, 'streakLabel')}',
        excludeSemantics: true,
        onTap: widget.onOpenMyProgress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: SoroTokens.paper,
              shape: const CircleBorder(
                side: BorderSide(color: SoroTokens.crimson, width: 1.5),
              ),
              elevation: 2,
              shadowColor: const Color.fromRGBO(92, 74, 42, 0.3),
              child: InkWell(
                key: const Key('my-progress-entry-button'),
                customBorder: const CircleBorder(),
                onTap: widget.onOpenMyProgress,
                child: const SizedBox(
                  width: SoroTokens.minTapTarget,
                  height: SoroTokens.minTapTarget,
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: SoroTokens.crimson,
                    size: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: IgnorePointer(
                child: Container(
                  key: const Key('streak-badge'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: SoroTokens.orange,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    border: Border.all(color: SoroTokens.paper, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 12,
                        color: SoroTokens.ink,
                      ),
                      Text(
                        '$_streak',
                        style: SoroTokens.sans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildCalmChatSection(BuildContext context, SoroLanguage lang) {
    final ChatMessage? last = widget.messages
        .cast<ChatMessage?>()
        .lastWhere((m) => m!.sender == ChatSender.tutor, orElse: () => null);
    return Semantics(
      container: true,
      liveRegion: true,
      label: SoroStrings.tr(lang, 'chatSectionLabel'),
      child: Column(
        key: const Key('calm-chat-area'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SoroTokens.s12),
              child: _ChatTurnBubble(
                message: last,
                currentLanguage: lang,
                onOpenBoard: () => widget.onOpenBoard(last.text),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              fillColor: SoroTokens.paper,
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
