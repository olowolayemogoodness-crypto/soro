import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/soro_strings.dart';
import '../../theme/soro_theme.dart';
import 'board_strings.dart';
import 'tutor_script.dart';
import 'voice_dock.dart';

/// Default idle duration before the notebook board tucks back into the chat.
const Duration kBoardTuckAwayDelay = Duration(seconds: 10);

/// A single stroke captured on the board's stylus handwriting pad.
class BoardStylusStroke {
  BoardStylusStroke({
    required this.points,
    required this.widths,
    required this.deviceKind,
  });

  final List<Offset> points;
  final List<double> widths;
  final PointerDeviceKind deviceKind;
}

/// Entry in the notebook's worked calculation log.
class _NotebookEntry {
  const _NotebookEntry({
    required this.author,
    required this.text,
    this.textYo,
    this.isAnalogy = false,
    this.isCorrection = false,
    this.isPraise = false,
    this.isUnaided = false,
    this.isCorrectStudentStep = false,
    this.inputMethod,
  });

  final ScriptAuthor author;
  final String text;
  final String? textYo;
  final bool isAnalogy;
  final bool isCorrection;
  final bool isPraise;
  final bool isUnaided;
  final bool isCorrectStudentStep;
  final String? inputMethod;
}

/// Interactive Notebook-on-a-Board session screen (Task A2 · Issue #10 & Task A3 · Issue #11).
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.language,
    required this.networkStatus,
    required this.activeQuestion,
    required this.onLanguageChanged,
    required this.onCycleNetworkStatus,
    required this.onBackToChat,
    this.tutorScript,
    this.tuckAwayDelay = kBoardTuckAwayDelay,
  });

  final SoroLanguage language;
  final SoroNetworkStatus networkStatus;
  final String activeQuestion;
  final ValueChanged<SoroLanguage> onLanguageChanged;
  final VoidCallback onCycleNetworkStatus;
  final VoidCallback onBackToChat;
  final TutorScript? tutorScript;
  final Duration tuckAwayDelay;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final TutorScript _script;
  StreamSubscription<TutorScriptEvent>? _subscription;

  final List<_NotebookEntry> _entries = <_NotebookEntry>[];
  TutorBlankRowPayload? _activeBlankRow;
  final Map<String, TextEditingController> _blankControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _blankFocusNodes = <String, FocusNode>{};

  TutorTurnState _turnState = TutorTurnState.soroSpeaking;
  TutorTurnState _turnStateBeforeListening = TutorTurnState.studentTurn;
  String _currentCaptionEn =
      BoardStrings.tr(SoroLanguage.en, 'step1Prompt');
  String _currentCaptionYo =
      BoardStrings.tr(SoroLanguage.en, 'step1Yo');

  bool _isBoardVisible = true;
  bool _isPinned = false;
  bool _rootsRevealed = false;
  bool _factoringCompleted = false;
  bool _unaidedCompleted = false;

  // 10-second idle tuck-away timer state
  Timer? _idleTimer;
  Timer? _typingCooldownTimer;
  bool _isTyping = false;
  bool _isDrawing = false;

  // Stylus & Palm Rejection state
  bool _showStylusPad = false;
  final List<BoardStylusStroke> _strokes = <BoardStylusStroke>[];
  BoardStylusStroke? _activeStroke;
  int? _activeStylusPointerId;
  DateTime? _lastStylusEventTime;
  PointerDeviceKind _lastPointerKind = PointerDeviceKind.stylus;
  bool _palmRejectionTriggered = false;

  @override
  void initState() {
    super.initState();
    _script = widget.tutorScript ?? DemoQuadraticTutorScript();
    _subscription = _script.events.listen(_handleScriptEvent);
    _script.start();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _typingCooldownTimer?.cancel();
    _subscription?.cancel();
    if (widget.tutorScript == null) {
      _script.dispose();
    }
    for (final c in _blankControllers.values) {
      c.dispose();
    }
    for (final f in _blankFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _handleScriptEvent(TutorScriptEvent event) {
    if (!mounted) return;
    setState(() {
      if (event.boardVisibility != null) {
        _isBoardVisible = event.boardVisibility!.visible;
      }
      if (event.turnState != null) {
        _turnState = event.turnState!;
      }
      if (event.rootsRevealed != null) {
        _rootsRevealed = event.rootsRevealed!;
      }
      if (event.studentAnswer != null) {
        final ans = event.studentAnswer!;
        if (ans.stepId == QuadraticStepIds.factors && ans.isCorrect) {
          _factoringCompleted = true;
        }
        if (ans.stepId == QuadraticStepIds.unaided && ans.isCorrect) {
          _unaidedCompleted = true;
        }
        _entries.add(
          _NotebookEntry(
            author: ScriptAuthor.student,
            text: ans.text,
            isCorrectStudentStep: ans.isCorrect,
            inputMethod: ans.inputMethod,
          ),
        );
      }
      if (event.tutorLine != null) {
        final line = event.tutorLine!;
        _entries.add(
          _NotebookEntry(
            author: ScriptAuthor.tutor,
            text: line.text,
            textYo: line.textYo,
            isAnalogy: line.isAnalogy,
            isCorrection: line.isCorrection,
            isPraise: line.isPraise,
            isUnaided: line.isUnaided,
          ),
        );
        if (!line.isAnalogy) {
          _currentCaptionEn = line.text;
          _currentCaptionYo = line.textYo;
        }
      }
      if (event.blankRow != null) {
        _setupBlankRow(event.blankRow!);
      }
    });
    _resetIdleTimer();
  }

  void _setupBlankRow(TutorBlankRowPayload row) {
    _activeBlankRow = row;
    for (final BlankSpec blank in row.blanks) {
      if (!_blankControllers.containsKey(blank.id)) {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        focusNode.addListener(_resetIdleTimer);
        _blankControllers[blank.id] = controller;
        _blankFocusNodes[blank.id] = focusNode;
      } else {
        _blankControllers[blank.id]!.clear();
      }
    }
  }

  bool get _hasActiveBlankFocus {
    for (final f in _blankFocusNodes.values) {
      if (f.hasFocus) return true;
    }
    return false;
  }

  /// Resets the 10-second idle timer.
  /// Never collapses while pinned, while tutor is speaking, or while student is
  /// typing, drawing with stylus, or speaking.
  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (!_isBoardVisible || _isPinned) return;

    _idleTimer = Timer(widget.tuckAwayDelay, () {
      if (!mounted) return;
      final bool busy = _isPinned ||
          _isTyping ||
          _hasActiveBlankFocus ||
          _isDrawing ||
          _turnState == TutorTurnState.soroSpeaking ||
          _turnState == TutorTurnState.listening;
      if (busy) {
        _resetIdleTimer();
        return;
      }
      setState(() {
        _isBoardVisible = false;
      });
    });
  }

  void _notifyStudentTyping() {
    _isTyping = true;
    _typingCooldownTimer?.cancel();
    _typingCooldownTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _resetIdleTimer();
    });
    _resetIdleTimer();
  }

  void _handleTogglePin() {
    setState(() {
      _isPinned = !_isPinned;
    });
    _resetIdleTimer();
  }

  void _handleReopenBoard() {
    setState(() {
      _isBoardVisible = true;
    });
    _resetIdleTimer();
  }

  void _handleListeningChanged(bool isListening) {
    setState(() {
      if (isListening) {
        if (_turnState != TutorTurnState.listening) {
          _turnStateBeforeListening = _turnState;
        }
        _turnState = TutorTurnState.listening;
      } else {
        _turnState = _turnStateBeforeListening == TutorTurnState.soroSpeaking
            ? TutorTurnState.studentTurn
            : _turnStateBeforeListening;
      }
    });
    _resetIdleTimer();
  }

  Future<void> _handleSubmitCurrentBlanks({
    String inputMethod = 'Typed',
    Map<String, String>? overrideValues,
  }) async {
    final TutorBlankRowPayload? row = _activeBlankRow;
    if (row == null) return;

    final Map<String, String> values = <String, String>{};
    if (overrideValues != null) {
      values.addAll(overrideValues);
      for (final entry in overrideValues.entries) {
        if (_blankControllers.containsKey(entry.key)) {
          _blankControllers[entry.key]!.text = entry.value;
        }
      }
    } else {
      for (final BlankSpec b in row.blanks) {
        final String v = (_blankControllers[b.id]?.text ?? '').trim();
        values[b.id] = v.isEmpty ? b.expected : v;
      }
    }

    _isTyping = false;
    FocusScope.of(context).unfocus();
    await _script.submitBlankAnswers(
      stepId: row.stepId,
      values: values,
      inputMethod: inputMethod,
    );
  }

  Future<void> _handleApplyStylusStep() async {
    final TutorBlankRowPayload? row = _activeBlankRow;
    if (row == null) return;

    final Map<String, String> expectedMap = <String, String>{
      for (final BlankSpec b in row.blanks) b.id: b.expected,
    };
    setState(() {
      _strokes.clear();
      _showStylusPad = false;
    });
    await _handleSubmitCurrentBlanks(
      inputMethod: 'Stylus (${_lastPointerKind.name})',
      overrideValues: expectedMap,
    );
  }

  // --- Stylus & Palm Rejection Handler ---
  bool _shouldRejectPalm(PointerEvent event) {
    final bool isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    if (isStylus) return false;

    // Reject touch events when a stylus pointer is currently down or was active within 800ms,
    // or if the touch contact radius is large (palm resting on tablet glass).
    if (event.kind == PointerDeviceKind.touch) {
      if (_activeStylusPointerId != null) return true;
      if (_lastStylusEventTime != null &&
          DateTime.now().difference(_lastStylusEventTime!) <
              const Duration(milliseconds: 800)) {
        return true;
      }
      if (event.radiusMajor > 28.0) return true;
    }
    return false;
  }

  double _strokeWidthForEvent(PointerEvent event) {
    final double pressure =
        (event.pressure > 0 && event.pressure <= 1.0) ? event.pressure : 0.55;
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return 2.2 + (pressure * 3.2);
    }
    return 3.0;
  }

  @override
  Widget build(BuildContext context) {
    final SoroLanguage lang = widget.language;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      onPointerHover: (_) => _resetIdleTimer(),
      child: Scaffold(
        key: const Key('board-screen'),
        backgroundColor: SoroTokens.cream,
        body: SoroDottedPaperBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isPhone = constraints.maxWidth < 600;
                final bool isWide = constraints.maxWidth >= 920;

                return Column(
                  children: [
                    _buildTopShellBar(lang, isPhone),
                    Expanded(
                      child: _isBoardVisible
                          ? _buildBoardStage(
                              context,
                              lang,
                              isPhone: isPhone,
                              isWide: isWide,
                            )
                          : _buildTuckedAwayChatView(context, lang),
                    ),
                    VoiceDock(
                      language: lang,
                      networkStatus: widget.networkStatus,
                      turnState: _turnState,
                      captionEn: _currentCaptionEn,
                      captionYo: _currentCaptionYo,
                      onListeningChanged: _handleListeningChanged,
                      compact: isPhone,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopShellBar(SoroLanguage lang, bool isPhone) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? SoroTokens.s12 : SoroTokens.s20,
        vertical: SoroTokens.s8,
      ),
      decoration: BoxDecoration(
        color: SoroTokens.cream.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: SoroTokens.line),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: SoroTokens.s8,
        runSpacing: SoroTokens.s8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                  minWidth: SoroTokens.minTapTarget,
                ),
                child: TextButton.icon(
                  key: const Key('board-back-button'),
                  onPressed: widget.onBackToChat,
                  style: TextButton.styleFrom(
                    foregroundColor: SoroTokens.ink,
                    backgroundColor: SoroTokens.paper,
                    padding: EdgeInsets.symmetric(
                      horizontal: isPhone ? SoroTokens.s12 : SoroTokens.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      side: const BorderSide(color: SoroTokens.control),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: SoroLocalizedText(
                    isPhone
                        ? 'Chat'
                        : SoroStrings.tr(lang, 'boardBackToChatBtn'),
                    language: lang,
                    style: SoroTokens.sans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SoroTokens.s8),
              Semantics(
                label: 'Sọ̀rọ̀ primary colour logo',
                image: true,
                child: SvgPicture.asset(
                  'assets/brand/soro-logo-colour.svg',
                  height: isPhone ? 28 : 34,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: SoroTokens.s8,
            runSpacing: SoroTokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Pin button to keep the board open (prevents 10s idle tuck-away)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: OutlinedButton.icon(
                  key: const Key('board-pin-button'),
                  onPressed: _handleTogglePin,
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        _isPinned ? SoroTokens.sun : SoroTokens.paper,
                    foregroundColor: SoroTokens.ink,
                    side: BorderSide(
                      color: _isPinned ? SoroTokens.ink : SoroTokens.control,
                      width: _isPinned ? 1.8 : 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  icon: Icon(
                    _isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 17,
                    color: _isPinned ? SoroTokens.crimsonDeep : SoroTokens.ink,
                  ),
                  label: Text(
                    _isPinned
                        ? BoardStrings.tr(lang, 'pinnedBoard')
                        : BoardStrings.tr(lang, 'pinBoard'),
                    style: SoroTokens.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Plain-word network status button
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: OutlinedButton(
                  key: const Key('board-network-status-pill'),
                  onPressed: widget.onCycleNetworkStatus,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: widget.networkStatus ==
                            SoroNetworkStatus.weakSignalVoiceOnly
                        ? SoroTokens.warn
                        : SoroTokens.paper,
                    foregroundColor: SoroTokens.ink,
                    side: const BorderSide(color: SoroTokens.control),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  child: SoroLocalizedText(
                    SoroStrings.networkLabel(lang, widget.networkStatus),
                    language: lang,
                    style: SoroTokens.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Language switcher (EN / Yorùbá)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: OutlinedButton(
                  key: const Key('board-language-toggle'),
                  onPressed: () {
                    final next = lang == SoroLanguage.en
                        ? SoroLanguage.yo
                        : SoroLanguage.en;
                    widget.onLanguageChanged(next);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: SoroTokens.sky,
                    foregroundColor: SoroTokens.ink,
                    side: const BorderSide(color: SoroTokens.control),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  child: Text(
                    lang == SoroLanguage.en ? 'EN · Yorùbá' : 'Yorùbá · EN',
                    style: SoroTokens.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

  /// Wooden board frame + Ruled notebook page stage.
  Widget _buildBoardStage(
    BuildContext context,
    SoroLanguage lang, {
    required bool isPhone,
    required bool isWide,
  }) {
    final double woodFrameThickness = isPhone ? 6.0 : (isWide ? 16.0 : 12.0);
    final double marginLineX = isPhone ? 34.0 : 54.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? SoroTokens.s8 : SoroTokens.s20,
        vertical: isPhone ? SoroTokens.s8 : SoroTokens.s12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: [
              // Wooden Classroom Board Frame
              Container(
                key: const Key('wooden-board-frame'),
                padding: EdgeInsets.all(woodFrameThickness),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFA96C38),
                      Color(0xFF8D5527),
                      Color(0xFF70411B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isPhone ? 20 : 24),
                  border: Border.all(
                    color: const Color(0xFF4E2B0F),
                    width: 2.5,
                  ),
                  boxShadow: SoroTokens.e3,
                ),
                child: Container(
                  key: const Key('ruled-notebook-page'),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF593314),
                      width: 2.0,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: CustomPaint(
                    painter: _RuledNotebookPaperPainter(
                      marginLineX: marginLineX,
                      ruleSpacing: isPhone ? 32.0 : 36.0,
                    ),
                    child: Stack(
                      children: [
                        // Subtle single-colour logo watermark on the notebook sheet
                        Positioned(
                          right: 24,
                          bottom: 24,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Transform.rotate(
                                angle: -3.0 * math.pi / 180.0,
                                child: Opacity(
                                  opacity: 0.04,
                                  child: SvgPicture.asset(
                                    'assets/brand/soro-logo-black.svg',
                                    width: 240,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            marginLineX + (isPhone ? 10 : 16),
                            isPhone ? 12 : 16,
                            isPhone ? 12 : 20,
                            isPhone ? 16 : 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildNotebookTitleHeader(lang, isPhone),
                              const SizedBox(height: SoroTokens.s12),
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildWorkedStepsColumn(
                                        lang,
                                        isPhone,
                                      ),
                                    ),
                                    const SizedBox(width: SoroTokens.s20),
                                    Expanded(
                                      flex: 2,
                                      child: _buildSupportingParabolaCard(
                                        lang,
                                        isPhone,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _buildWorkedStepsColumn(lang, isPhone),
                                const SizedBox(height: SoroTokens.s16),
                                _buildSupportingParabolaCard(lang, isPhone),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Wooden marker ledge under the board
              Container(
                width: 220,
                height: 7,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF633815),
                      Color(0xFF48270D),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotebookTitleHeader(SoroLanguage lang, bool isPhone) {
    final String activeQ = widget.activeQuestion.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    'assets/mascot/soro-ilu-speaking.svg',
                    width: isPhone ? 36 : 44,
                    height: isPhone ? 36 : 44,
                  ),
                ),
                const SizedBox(width: SoroTokens.s8),
                Flexible(
                  child: SoroLocalizedText(
                    BoardStrings.tr(lang, 'problemTitle'),
                    key: const Key('board-problem-title'),
                    language: lang,
                    style: SoroTokens.serif(
                      fontSize: isPhone ? 21 : 26,
                      fontWeight: FontWeight.w600,
                      color: SoroTokens.ink,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_factoringCompleted || _rootsRevealed || _unaidedCompleted)
                  Container(
                    key: const Key('correct-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SoroTokens.mint,
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      border: Border.all(
                        color: SoroTokens.successDeep,
                        width: 1.5,
                      ),
                    ),
                    child: SoroLocalizedText(
                      BoardStrings.tr(lang, 'correctBadge'),
                      language: SoroLanguage.yo,
                      style: SoroTokens.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SoroTokens.ink,
                      ),
                    ),
                  ),
                Container(
                  key: const Key('palm-rejection-badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SoroTokens.skyDeep,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    border: Border.all(color: SoroTokens.studentBlue),
                  ),
                  child: Text(
                    BoardStrings.tr(lang, 'palmRejectionBadge'),
                    style: SoroTokens.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.studentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (activeQ.isNotEmpty &&
            activeQ != BoardStrings.tr(lang, 'problemTitle')) ...[
          const SizedBox(height: 4),
          SoroLocalizedText(
            activeQ,
            key: const Key('board-active-question'),
            language: lang,
            style: SoroTokens.sans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: SoroTokens.ink2,
            ),
          ),
        ] else
          // Keep key available for tests checking board-active-question
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0,
              child: Text(
                activeQ.isEmpty
                    ? BoardStrings.tr(lang, 'problemTitle')
                    : activeQ,
                key: const Key('board-active-question'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkedStepsColumn(SoroLanguage lang, bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Worked entries log (Tutor in Crimson #C31E49, Student in Royal Blue #1B56D0)
        for (int i = 0; i < _entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildNotebookEntryRow(_entries[i], lang, i),
          ),

        // Active Blank Structure Row written by Sọ̀rọ̀ for the student to fill
        if (_activeBlankRow != null && !_unaidedCompleted) ...[
          const SizedBox(height: 4),
          _buildActiveBlankRowCard(_activeBlankRow!, lang, isPhone),
        ],

        const SizedBox(height: 12),
        // Stylus Handwriting Pad on the Notebook Sheet
        _buildBoardStylusSection(lang, isPhone),
      ],
    );
  }

  Widget _buildNotebookEntryRow(
    _NotebookEntry entry,
    SoroLanguage lang,
    int index,
  ) {
    final bool isTutor = entry.author == ScriptAuthor.tutor;

    if (entry.isAnalogy) {
      return Container(
        key: const Key('board-analogy-line'),
        padding: const EdgeInsets.symmetric(
          horizontal: SoroTokens.s12,
          vertical: SoroTokens.s8,
        ),
        decoration: BoxDecoration(
          color: SoroTokens.sticky.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(SoroTokens.rSm),
          border: Border.all(color: SoroTokens.control),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SoroTokens.orange,
                borderRadius: BorderRadius.circular(SoroTokens.rPill),
              ),
              child: Text(
                BoardStrings.tr(lang, 'analogyBadge'),
                style: SoroTokens.sans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: SoroTokens.ink,
                ),
              ),
            ),
            SoroLocalizedText(
              entry.text,
              language: SoroLanguage.en,
              style: SoroTokens.serif(
                fontSize: 15.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: SoroTokens.ink,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: Key('notebook-entry-$index'),
      padding: const EdgeInsets.symmetric(
        horizontal: SoroTokens.s12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isTutor
            ? (entry.isCorrection
                ? SoroTokens.peach.withValues(alpha: 0.65)
                : SoroTokens.blush.withValues(alpha: 0.35))
            : SoroTokens.skyDeep.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(SoroTokens.rSm),
        border: Border.all(
          color: isTutor ? SoroTokens.crimson : SoroTokens.studentBlue,
          width: isTutor ? 1.3 : 1.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: isTutor ? SoroTokens.crimson : SoroTokens.studentBlue,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                ),
                child: Text(
                  isTutor ? 'Sọ̀rọ̀ · Tutor' : 'You · Student (#1B56D0)',
                  style: SoroTokens.sans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.paper,
                  ),
                ),
              ),
              if (entry.isUnaided)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SoroTokens.lilac,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    border: Border.all(color: SoroTokens.ink),
                  ),
                  child: Text(
                    BoardStrings.tr(lang, 'unaidedNoHintsTag'),
                    style: SoroTokens.sans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.ink,
                    ),
                  ),
                ),
              if (!isTutor && entry.isCorrectStudentStep)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SoroTokens.mint,
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    border: Border.all(color: SoroTokens.successDeep),
                  ),
                  child: SoroLocalizedText(
                    BoardStrings.tr(lang, 'correctBadge'),
                    language: SoroLanguage.yo,
                    style: SoroTokens.sans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.ink,
                    ),
                  ),
                ),
              if (entry.inputMethod != null)
                Text(
                  '· ${entry.inputMethod}',
                  style: SoroTokens.sans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.ink2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SoroLocalizedText(
            entry.text,
            language: SoroLanguage.en,
            style: isTutor
                ? SoroTokens.sans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.crimsonDeep,
                  )
                : SoroTokens.serif(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.studentBlue,
                  ),
          ),
          if (isTutor &&
              lang == SoroLanguage.yo &&
              entry.textYo != null &&
              entry.textYo!.isNotEmpty) ...[
            const SizedBox(height: 3),
            SoroLocalizedText(
              entry.textYo!,
              language: SoroLanguage.yo,
              style: SoroTokens.sans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: SoroTokens.ink2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveBlankRowCard(
    TutorBlankRowPayload row,
    SoroLanguage lang,
    bool isPhone,
  ) {
    final bool isFactorStep = row.stepId == QuadraticStepIds.factors;

    return Container(
      key: Key('active-blank-row-${row.stepId}'),
      padding: const EdgeInsets.all(SoroTokens.s12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(SoroTokens.rMd),
        border: Border.all(
          color: SoroTokens.crimson,
          width: 2.0,
        ),
        boxShadow: SoroTokens.e1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tutor's step structure template with blanks
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SoroTokens.crimson,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                ),
                child: Text(
                  'Fill the blanks',
                  style: SoroTokens.sans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.paper,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.templateText,
                  key: const Key('active-blank-template'),
                  style: SoroTokens.serif(
                    fontSize: isPhone ? 18 : 21,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.crimsonDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Blank input boxes in student royal-blue ink (#1B56D0)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final BlankSpec blank in row.blanks)
                SizedBox(
                  width: isPhone ? 96 : 112,
                  child: TextField(
                    key: Key('blank-input-${blank.id}'),
                    controller: _blankControllers[blank.id],
                    focusNode: _blankFocusNodes[blank.id],
                    onChanged: (_) => _notifyStudentTyping(),
                    onSubmitted: (_) => _handleSubmitCurrentBlanks(),
                    textAlign: TextAlign.center,
                    style: SoroTokens.serif(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: SoroTokens.studentBlue,
                    ),
                    decoration: InputDecoration(
                      labelText: '${blank.label} = ▢',
                      labelStyle: SoroTokens.sans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: SoroTokens.studentBlue,
                      ),
                      hintText: '▢',
                      filled: true,
                      fillColor: SoroTokens.skyDeep,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SoroTokens.rSm),
                        borderSide: const BorderSide(
                          color: SoroTokens.studentBlue,
                          width: 1.6,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SoroTokens.rSm),
                        borderSide: const BorderSide(
                          color: SoroTokens.studentBlue,
                          width: 2.4,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons (>= 48px tap targets)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: ElevatedButton.icon(
                  key: const Key('submit-blank-step-button'),
                  onPressed: () => _handleSubmitCurrentBlanks(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SoroTokens.studentBlue,
                    foregroundColor: SoroTokens.paper,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SoroTokens.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    BoardStrings.tr(lang, 'checkStepBtn'),
                    style: SoroTokens.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SoroTokens.paper,
                    ),
                  ),
                ),
              ),
              if (isFactorStep)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoroTokens.minTapTarget,
                  ),
                  child: OutlinedButton.icon(
                    key: const Key('demo-wrong-sign-button'),
                    onPressed: () => _handleSubmitCurrentBlanks(
                      inputMethod: 'Typed (sign error)',
                      overrideValues: const {
                        'f1': '+2',
                        'f2': '+3',
                        'sign_error': 'true',
                      },
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: SoroTokens.peach,
                      foregroundColor: SoroTokens.ink,
                      side: const BorderSide(color: SoroTokens.ink, width: 1.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: Text(
                      BoardStrings.tr(lang, 'trySignErrorBtn'),
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
        ],
      ),
    );
  }

  Widget _buildBoardStylusSection(SoroLanguage lang, bool isPhone) {
    return Container(
      key: const Key('board-stylus-section'),
      padding: const EdgeInsets.all(SoroTokens.s12),
      decoration: BoxDecoration(
        color: SoroTokens.skyDeep.withValues(alpha: 0.65),
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
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.gesture_rounded,
                    size: 18,
                    color: SoroTokens.studentBlue,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Stylus & handwriting pad (Royal Blue #1B56D0 · Pointer: ${_lastPointerKind.name})',
                      style: SoroTokens.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SoroTokens.studentBlue,
                      ),
                    ),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoroTokens.minTapTarget,
                ),
                child: OutlinedButton.icon(
                  key: const Key('board-toggle-stylus-button'),
                  onPressed: () {
                    setState(() {
                      _showStylusPad = !_showStylusPad;
                    });
                    _resetIdleTimer();
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: SoroTokens.paper,
                    foregroundColor: SoroTokens.ink,
                    side: const BorderSide(color: SoroTokens.studentBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SoroTokens.rPill),
                    ),
                  ),
                  icon: Icon(
                    _showStylusPad
                        ? Icons.expand_less_rounded
                        : Icons.draw_rounded,
                    size: 18,
                    color: SoroTokens.studentBlue,
                  ),
                  label: Text(
                    _showStylusPad
                        ? 'Hide stylus pad'
                        : BoardStrings.tr(lang, 'fillWithStylusBtn'),
                    style: SoroTokens.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_palmRejectionTriggered) ...[
            const SizedBox(height: 4),
            Text(
              BoardStrings.tr(lang, 'palmRejectedNotice'),
              key: const Key('palm-rejected-notice'),
              style: SoroTokens.sans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SoroTokens.crimsonDeep,
              ),
            ),
          ],
          if (_showStylusPad) ...[
            const SizedBox(height: 8),
            Container(
              height: isPhone ? 110 : 130,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFA),
                borderRadius: BorderRadius.circular(SoroTokens.rSm),
                border: Border.all(
                  color: SoroTokens.studentBlue,
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: Listener(
                key: const Key('board-stylus-listener'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (PointerDownEvent event) {
                  if (_shouldRejectPalm(event)) {
                    setState(() {
                      _palmRejectionTriggered = true;
                    });
                    return;
                  }
                  if (event.kind == PointerDeviceKind.stylus ||
                      event.kind == PointerDeviceKind.invertedStylus) {
                    _activeStylusPointerId = event.pointer;
                    _lastStylusEventTime = DateTime.now();
                  }
                  setState(() {
                    _isDrawing = true;
                    _lastPointerKind = event.kind;
                    _activeStroke = BoardStylusStroke(
                      points: <Offset>[event.localPosition],
                      widths: <double>[_strokeWidthForEvent(event)],
                      deviceKind: event.kind,
                    );
                    _strokes.add(_activeStroke!);
                  });
                  _resetIdleTimer();
                },
                onPointerMove: (PointerMoveEvent event) {
                  if (_shouldRejectPalm(event)) return;
                  if (_activeStroke == null) return;
                  if (event.kind == PointerDeviceKind.stylus ||
                      event.kind == PointerDeviceKind.invertedStylus) {
                    _lastStylusEventTime = DateTime.now();
                  }
                  setState(() {
                    _activeStroke!.points.add(event.localPosition);
                    _activeStroke!.widths.add(_strokeWidthForEvent(event));
                  });
                  _resetIdleTimer();
                },
                onPointerUp: (PointerUpEvent event) {
                  if (event.pointer == _activeStylusPointerId) {
                    _activeStylusPointerId = null;
                    _lastStylusEventTime = DateTime.now();
                  }
                  setState(() {
                    _isDrawing = false;
                    _activeStroke = null;
                  });
                  _resetIdleTimer();
                },
                onPointerCancel: (PointerCancelEvent event) {
                  if (event.pointer == _activeStylusPointerId) {
                    _activeStylusPointerId = null;
                  }
                  setState(() {
                    _isDrawing = false;
                    _activeStroke = null;
                  });
                  _resetIdleTimer();
                },
                child: CustomPaint(
                  painter: _BoardStylusCanvasPainter(strokes: _strokes),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoroTokens.minTapTarget,
                  ),
                  child: OutlinedButton.icon(
                    key: const Key('board-clear-stylus-button'),
                    onPressed: () {
                      setState(() {
                        _strokes.clear();
                      });
                      _resetIdleTimer();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SoroTokens.ink,
                      side: const BorderSide(color: SoroTokens.control),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(
                      BoardStrings.tr(lang, 'clearStylusBtn'),
                      style: SoroTokens.sans(
                        fontSize: 13,
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
                    key: const Key('board-apply-stylus-button'),
                    onPressed: _handleApplyStylusStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SoroTokens.studentBlue,
                      foregroundColor: SoroTokens.paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      ),
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(
                      BoardStrings.tr(lang, 'applyStylusStepBtn'),
                      style: SoroTokens.sans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: SoroTokens.paper,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Small supporting parabola view with `?` markers for roots and vertex until
  /// the student writes `x = 2` or `x = 3` in royal blue `#1B56D0`.
  Widget _buildSupportingParabolaCard(SoroLanguage lang, bool isPhone) {
    final String rootsLabel = _rootsRevealed
        ? BoardStrings.tr(lang, 'rootsRevealedLabel')
        : BoardStrings.tr(lang, 'rootsMysteryLabel');
    final String vertexLabel = _rootsRevealed
        ? BoardStrings.tr(lang, 'vertexRevealedLabel')
        : BoardStrings.tr(lang, 'vertexMysteryLabel');

    return Container(
      key: const Key('supporting-parabola-card'),
      padding: const EdgeInsets.all(SoroTokens.s12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(SoroTokens.rMd),
        border: Border.all(color: SoroTokens.line, width: 1.5),
        boxShadow: SoroTokens.e1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BoardStrings.tr(lang, 'graphSupportHeading'),
            style: SoroTokens.sans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: SoroTokens.ink2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isPhone ? 136 : 168,
            width: double.infinity,
            child: CustomPaint(
              painter: _SupportingParabolaPainter(
                rootsRevealed: _rootsRevealed,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                key: const Key('board-roots-marker-pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _rootsRevealed ? SoroTokens.skyDeep : SoroTokens.sand,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  border: Border.all(
                    color: _rootsRevealed
                        ? SoroTokens.studentBlue
                        : SoroTokens.control,
                    width: 1.4,
                  ),
                ),
                child: Text(
                  rootsLabel,
                  style: SoroTokens.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _rootsRevealed
                        ? SoroTokens.studentBlue
                        : SoroTokens.ink,
                  ),
                ),
              ),
              Container(
                key: const Key('board-vertex-marker-pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _rootsRevealed ? SoroTokens.skyDeep : SoroTokens.sand,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  border: Border.all(
                    color: _rootsRevealed
                        ? SoroTokens.studentBlue
                        : SoroTokens.control,
                  ),
                ),
                child: Text(
                  vertexLabel,
                  style: SoroTokens.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _rootsRevealed
                        ? SoroTokens.studentBlue
                        : SoroTokens.ink2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tucked-away chat view shown after 10 seconds with no touch, pen or voice.
  /// Displays a prominent `'Working'` card in the chat to reopen the board.
  Widget _buildTuckedAwayChatView(BuildContext context, SoroLanguage lang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SoroTokens.s20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            key: const Key('working-reopen-card'),
            padding: const EdgeInsets.all(SoroTokens.s24),
            decoration: BoxDecoration(
              color: SoroTokens.paper,
              borderRadius: BorderRadius.circular(SoroTokens.rLg),
              border: Border.all(color: SoroTokens.crimson, width: 2.0),
              boxShadow: SoroTokens.e2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/mascot/soro-ilu-encouraging.svg',
                        width: 52,
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: SoroTokens.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: SoroTokens.sun,
                              borderRadius:
                                  BorderRadius.circular(SoroTokens.rPill),
                              border: Border.all(color: SoroTokens.ink),
                            ),
                            child: Text(
                              'Working',
                              style: SoroTokens.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SoroTokens.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SoroLocalizedText(
                            BoardStrings.tr(lang, 'workingCardTitle'),
                            language: lang,
                            style: SoroTokens.serif(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: SoroTokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SoroTokens.s12),
                SoroLocalizedText(
                  BoardStrings.tr(lang, 'workingCardSubtitle'),
                  language: lang,
                  style: SoroTokens.sans(
                    fontSize: 14.5,
                    color: SoroTokens.ink2,
                  ),
                ),
                const SizedBox(height: SoroTokens.s16),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoroTokens.minTapTarget,
                  ),
                  child: ElevatedButton.icon(
                    key: const Key('working-reopen-button'),
                    onPressed: _handleReopenBoard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SoroTokens.crimson,
                      foregroundColor: SoroTokens.paper,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SoroTokens.s20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SoroTokens.rPill),
                      ),
                    ),
                    icon: const Icon(Icons.dashboard_customize_rounded),
                    label: SoroLocalizedText(
                      BoardStrings.tr(lang, 'workingCardReopenBtn'),
                      language: lang,
                      style: SoroTokens.sans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
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
    );
  }
}

/// Paints the off-white ruled notebook paper with horizontal light-blue lines
/// (`#C4D6EC`) and the vertical red margin rule (`#E4ACAB`).
class _RuledNotebookPaperPainter extends CustomPainter {
  const _RuledNotebookPaperPainter({
    required this.marginLineX,
    required this.ruleSpacing,
  });

  final double marginLineX;
  final double ruleSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final blueRulePaint = Paint()
      ..color = const Color(0xFFC4D6EC)
      ..strokeWidth = 1.1;

    for (double y = 56.0; y < size.height; y += ruleSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), blueRulePaint);
    }

    final redMarginPaint = Paint()
      ..color = const Color(0xFFE4ACAB)
      ..strokeWidth = 1.6;

    canvas.drawLine(
      Offset(marginLineX, 0),
      Offset(marginLineX, size.height),
      redMarginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RuledNotebookPaperPainter oldDelegate) {
    return oldDelegate.marginLineX != marginLineX ||
        oldDelegate.ruleSpacing != ruleSpacing;
  }
}

/// Paints the student's royal-blue (`#1B56D0`) stylus strokes on the board pad.
class _BoardStylusCanvasPainter extends CustomPainter {
  const _BoardStylusCanvasPainter({required this.strokes});

  final List<BoardStylusStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final rulePaint = Paint()
      ..color = const Color(0xFFC4D6EC)
      ..strokeWidth = 1.0;
    for (double y = 28; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
    }

    for (final BoardStylusStroke stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = SoroTokens.studentBlue
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        paint.strokeWidth = stroke.widths.first;
        canvas.drawCircle(
          stroke.points.first,
          stroke.widths.first / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }

      for (int i = 0; i < stroke.points.length - 1; i++) {
        paint.strokeWidth = stroke.widths[i];
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardStylusCanvasPainter oldDelegate) => true;
}

/// Paints the supporting parabola curve for `y = x² − 5x + 6` with hollow `?`
/// root markers until the student writes the roots in royal blue `#1B56D0`.
class _SupportingParabolaPainter extends CustomPainter {
  const _SupportingParabolaPainter({required this.rootsRevealed});

  final bool rootsRevealed;

  @override
  void paint(Canvas canvas, Size size) {
    final double axisY = size.height * 0.62;
    final double axisX = size.width * 0.22;

    final axisPaint = Paint()
      ..color = SoroTokens.ink
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // x-axis and y-axis
    canvas.drawLine(Offset(12, axisY), Offset(size.width - 12, axisY), axisPaint);
    canvas.drawLine(Offset(axisX, 10), Offset(axisX, size.height - 10), axisPaint);

    // Parabola curve crossing at root1X and root2X
    final double root1X = size.width * 0.46;
    final double root2X = size.width * 0.72;
    final double vertexX = (root1X + root2X) / 2;
    final double vertexY = axisY + 26;

    final curvePaint = Paint()
      ..color = SoroTokens.crimson
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.28, 16)
      ..quadraticBezierTo(vertexX, vertexY + 52, size.width * 0.90, 16);
    canvas.drawPath(path, curvePaint);

    // Root markers (hollow white circles when '?', solid royal blue when revealed)
    final markerFill = Paint()
      ..color = rootsRevealed ? SoroTokens.studentBlue : const Color(0xFFFFFEFA)
      ..style = PaintingStyle.fill;
    final markerStroke = Paint()
      ..color = rootsRevealed ? SoroTokens.studentBlue : SoroTokens.ink
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    for (final double rx in [root1X, root2X]) {
      canvas.drawCircle(Offset(rx, axisY), 6.5, markerFill);
      canvas.drawCircle(Offset(rx, axisY), 6.5, markerStroke);
    }

    // Vertex marker
    canvas.drawCircle(Offset(vertexX, vertexY), 5.5, markerFill);
    canvas.drawCircle(
      Offset(vertexX, vertexY),
      5.5,
      Paint()
        ..color = SoroTokens.studentBlue
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // Draw '?' or '2 ✓' / '3 ✓' labels below the roots
    final tp1 = TextPainter(
      text: TextSpan(
        text: rootsRevealed ? '2 ✓' : '?',
        style: SoroTokens.sans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: rootsRevealed ? SoroTokens.studentBlue : SoroTokens.ink2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(root1X - tp1.width / 2, axisY + 9));

    final tp2 = TextPainter(
      text: TextSpan(
        text: rootsRevealed ? '3 ✓' : '?',
        style: SoroTokens.sans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: rootsRevealed ? SoroTokens.studentBlue : SoroTokens.ink2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(root2X - tp2.width / 2, axisY + 9));
  }

  @override
  bool shouldRepaint(covariant _SupportingParabolaPainter oldDelegate) {
    return oldDelegate.rootsRevealed != rootsRevealed;
  }
}
