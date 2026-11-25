import 'dart:async';
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

/// Ink tools on the notebook page.
enum BoardInkTool { pen, eraser }

/// A single freehand stroke written on the notebook page.
class BoardInkStroke {
  BoardInkStroke({
    required this.color,
    required this.points,
    required this.widths,
  });

  final Color color;
  final List<Offset> points;
  final List<double> widths;
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
  String _currentCaptionEn = BoardStrings.tr(SoroLanguage.en, 'step1Prompt');
  String _currentCaptionYo = BoardStrings.tr(SoroLanguage.en, 'step1Yo');

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

  // Free ink on the page
  final List<BoardInkStroke> _strokes = <BoardInkStroke>[];
  final List<List<BoardInkStroke>> _undoStack = <List<BoardInkStroke>>[];
  final List<List<BoardInkStroke>> _redoStack = <List<BoardInkStroke>>[];
  BoardInkStroke? _activeStroke;
  BoardInkTool _tool = BoardInkTool.pen;
  Color _inkColor = SoroTokens.studentBlue;
  bool _erasedInGesture = false;
  bool _graphOpen = true;
  int? _inkPointerId;
  int? _activeStylusPointerId;
  DateTime? _lastStylusEventTime;

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
      final bool busy =
          _isPinned ||
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

  // --- Free ink on the notebook page ---
  bool _isStylus(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  /// Ignores touch while a stylus is down or was down in the last 800 ms, and
  /// any touch with a large contact radius (a palm resting on the glass).
  bool _shouldRejectPalm(PointerEvent event) {
    if (_isStylus(event)) return false;
    if (event.kind == PointerDeviceKind.touch) {
      if (_activeStylusPointerId != null) return true;
      final DateTime? last = _lastStylusEventTime;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(milliseconds: 800)) {
        return true;
      }
      if (event.radiusMajor > 28.0) return true;
    }
    return false;
  }

  double _strokeWidthForEvent(PointerEvent event, double? previous) {
    if (!_isStylus(event)) return 3.0;
    final double range = event.pressureMax - event.pressureMin;
    final double norm = range > 0
        ? ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0)
        : 0.5;
    final double target = 1.8 + norm * 3.4;
    return previous == null ? target : previous * 0.6 + target * 0.4;
  }

  void _trackStylus(PointerEvent event, {required bool isUp}) {
    if (!_isStylus(event)) return;
    if (isUp) {
      if (event.pointer == _activeStylusPointerId) {
        _activeStylusPointerId = null;
      }
    } else {
      _activeStylusPointerId = event.pointer;
    }
    _lastStylusEventTime = DateTime.now();
  }

  void _pushHistory() {
    _undoStack.add(List<BoardInkStroke>.of(_strokes));
    _redoStack.clear();
  }

  void _eraseAt(Offset p) {
    final int before = _strokes.length;
    _strokes.removeWhere((BoardInkStroke s) {
      for (final Offset q in s.points) {
        if ((q - p).distance < 16) return true;
      }
      return false;
    });
    if (_strokes.length != before) _erasedInGesture = true;
  }

  void _onInkDown(PointerDownEvent event) {
    if (_shouldRejectPalm(event)) return;
    if (_inkPointerId != null) return;
    _inkPointerId = event.pointer;
    setState(() {
      _isDrawing = true;
      if (_tool == BoardInkTool.eraser) {
        _pushHistory();
        _erasedInGesture = false;
        _eraseAt(event.localPosition);
      } else {
        _pushHistory();
        _activeStroke = BoardInkStroke(
          color: _inkColor,
          points: <Offset>[event.localPosition],
          widths: <double>[_strokeWidthForEvent(event, null)],
        );
        _strokes.add(_activeStroke!);
      }
    });
    _resetIdleTimer();
  }

  void _onInkMove(PointerMoveEvent event) {
    if (event.pointer != _inkPointerId) return;
    setState(() {
      if (_tool == BoardInkTool.eraser) {
        _eraseAt(event.localPosition);
      } else {
        final BoardInkStroke? s = _activeStroke;
        if (s == null) return;
        s.points.add(event.localPosition);
        s.widths.add(_strokeWidthForEvent(event, s.widths.last));
      }
    });
    _resetIdleTimer();
  }

  void _endInk(PointerEvent event) {
    if (event.pointer != _inkPointerId) return;
    _inkPointerId = null;
    setState(() {
      _isDrawing = false;
      _activeStroke = null;
      if (_tool == BoardInkTool.eraser && !_erasedInGesture) {
        _undoStack.removeLast();
      }
    });
    _resetIdleTimer();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(List<BoardInkStroke>.of(_strokes));
      _strokes
        ..clear()
        ..addAll(_undoStack.removeLast());
    });
    _resetIdleTimer();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(List<BoardInkStroke>.of(_strokes));
      _strokes
        ..clear()
        ..addAll(_redoStack.removeLast());
    });
    _resetIdleTimer();
  }

  void _clearPage() {
    if (_strokes.isEmpty) return;
    setState(() {
      _pushHistory();
      _strokes.clear();
    });
    _resetIdleTimer();
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
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isPhone = constraints.maxWidth < 600;

              return Column(
                children: [
                  _buildTopShellBar(lang, isPhone),
                  Expanded(
                    child: _isBoardVisible
                        ? _buildBoardStage(context, lang, isPhone: isPhone)
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
        border: const Border(bottom: BorderSide(color: SoroTokens.line)),
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
                    backgroundColor: _isPinned
                        ? SoroTokens.sun
                        : SoroTokens.paper,
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
                    backgroundColor:
                        widget.networkStatus ==
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

  /// Wooden board frame holding the tool row and the writable notebook page.
  Widget _buildBoardStage(
    BuildContext context,
    SoroLanguage lang, {
    required bool isPhone,
  }) {
    final double woodFrameThickness = isPhone ? 5.0 : 10.0;
    final double marginLineX = isPhone ? 34.0 : 54.0;
    final double ruleSpacing = isPhone ? 32.0 : 36.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isPhone ? SoroTokens.s8 : SoroTokens.s16,
        isPhone ? SoroTokens.s8 : SoroTokens.s12,
        isPhone ? SoroTokens.s8 : SoroTokens.s16,
        isPhone ? SoroTokens.s8 : SoroTokens.s12,
      ),
      child: Container(
        key: const Key('wooden-board-frame'),
        padding: EdgeInsets.all(woodFrameThickness),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA96C38), Color(0xFF8D5527), Color(0xFF70411B)],
          ),
          borderRadius: BorderRadius.circular(isPhone ? 18 : 22),
          border: Border.all(color: const Color(0xFF4E2B0F), width: 2.5),
          boxShadow: SoroTokens.e2,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF593314), width: 2.0),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              _buildToolRow(lang, isPhone),
              const Divider(height: 1, thickness: 1, color: Color(0xFFC4D6EC)),
              Expanded(
                child: _buildInkPage(
                  lang,
                  isPhone: isPhone,
                  marginLineX: marginLineX,
                  ruleSpacing: ruleSpacing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: selected ? SoroTokens.skyDeep : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? SoroTokens.studentBlue : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: InkResponse(
              key: key,
              onTap: onPressed,
              radius: 26,
              child: Icon(
                icon,
                size: 24,
                color: onPressed == null
                    ? SoroTokens.control
                    : (selected ? SoroTokens.studentBlue : SoroTokens.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorButton(String name, Color color) {
    final bool selected = _inkColor == color;
    return Tooltip(
      message: 'Ink colour: $name',
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Ink colour: $name',
        child: InkResponse(
          key: Key('ink-color-$name'),
          onTap: () {
            setState(() {
              _inkColor = color;
              _tool = BoardInkTool.pen;
            });
            _resetIdleTimer();
          },
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: selected ? 30 : 26,
                height: selected ? 30 : 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? SoroTokens.ink : Colors.white,
                    width: selected ? 2.4 : 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolRow(SoroLanguage lang, bool isPhone) {
    final bool canSend = _activeBlankRow != null && !_unaidedCompleted;
    return Container(
      color: const Color(0xFFFFFEFA),
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: isPhone ? 4 : 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolButton(
              key: const Key('tool-pen'),
              icon: Icons.edit_rounded,
              tooltip: 'Pen',
              selected: _tool == BoardInkTool.pen,
              onPressed: () {
                setState(() => _tool = BoardInkTool.pen);
                _resetIdleTimer();
              },
            ),
            _toolButton(
              key: const Key('tool-eraser'),
              icon: Icons.cleaning_services_rounded,
              tooltip: 'Eraser',
              selected: _tool == BoardInkTool.eraser,
              onPressed: () {
                setState(() => _tool = BoardInkTool.eraser);
                _resetIdleTimer();
              },
            ),
            const SizedBox(width: 6),
            _colorButton('blue', SoroTokens.studentBlue),
            _colorButton('black', SoroTokens.ink),
            _colorButton('green', const Color(0xFF1E8E4A)),
            const SizedBox(width: 6),
            _toolButton(
              key: const Key('tool-undo'),
              icon: Icons.undo_rounded,
              tooltip: 'Undo',
              onPressed: _undoStack.isEmpty ? null : _undo,
            ),
            _toolButton(
              key: const Key('tool-redo'),
              icon: Icons.redo_rounded,
              tooltip: 'Redo',
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
            _toolButton(
              key: const Key('tool-clear'),
              icon: Icons.delete_outline_rounded,
              tooltip: 'Clear page',
              onPressed: _strokes.isEmpty ? null : _clearPage,
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('send-work-button'),
                onPressed: canSend ? () => _handleSubmitCurrentBlanks() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SoroTokens.studentBlue,
                  foregroundColor: SoroTokens.paper,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  BoardStrings.tr(lang, 'sendWorkBtn'),
                  style: SoroTokens.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.paper,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The writable page: ruled paper, tutor lines on top, ink drawn over all of
  /// it. Ink listens underneath the content so buttons and blanks stay usable.
  Widget _buildInkPage(
    SoroLanguage lang, {
    required bool isPhone,
    required double marginLineX,
    required double ruleSpacing,
  }) {
    final int shown = isPhone ? 4 : 6;
    final int start = _entries.length > shown ? _entries.length - shown : 0;

    return Listener(
      key: const Key('board-ink-page'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent e) => _trackStylus(e, isUp: false),
      onPointerMove: (PointerMoveEvent e) => _trackStylus(e, isUp: false),
      onPointerUp: (PointerUpEvent e) => _trackStylus(e, isUp: true),
      onPointerCancel: (PointerCancelEvent e) => _trackStylus(e, isUp: true),
      child: CustomPaint(
        key: const Key('ruled-notebook-page'),
        painter: _RuledNotebookPaperPainter(
          marginLineX: marginLineX,
          ruleSpacing: ruleSpacing,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              key: const Key('board-ink-input'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onInkDown,
              onPointerMove: _onInkMove,
              onPointerUp: _endInk,
              onPointerCancel: _endInk,
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: marginLineX + (isPhone ? 10 : 16),
              right: isPhone ? 10 : 20,
              top: 0,
              bottom: 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNotebookTitleHeader(lang, isPhone, ruleSpacing),
                      for (int i = start; i < _entries.length; i++)
                        _buildNotebookEntryRow(
                          _entries[i],
                          lang,
                          i,
                          ruleSpacing,
                        ),
                      if (_activeBlankRow != null && !_unaidedCompleted)
                        _buildActiveBlankRow(
                          _activeBlankRow!,
                          lang,
                          isPhone,
                          ruleSpacing,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: isPhone ? 8 : 16,
              bottom: isPhone ? 8 : 16,
              child: _buildGraphPanel(lang, isPhone),
            ),
            IgnorePointer(
              child: CustomPaint(
                key: const Key('board-ink-layer'),
                painter: BoardInkPainter(strokes: _strokes),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphPanel(SoroLanguage lang, bool isPhone) {
    if (!_graphOpen) {
      return Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('graph-toggle-button'),
            onPressed: () {
              setState(() => _graphOpen = true);
              _resetIdleTimer();
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFEFA),
              foregroundColor: SoroTokens.ink,
              side: const BorderSide(color: SoroTokens.control),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SoroTokens.rPill),
              ),
            ),
            icon: const Icon(Icons.show_chart_rounded, size: 18),
            label: Text(
              'Graph',
              style: SoroTokens.sans(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: isPhone ? 200 : 250,
      child: Stack(
        children: [
          _buildSupportingParabolaCard(lang, isPhone),
          Positioned(
            right: 0,
            top: 0,
            child: InkResponse(
              key: const Key('graph-toggle-button'),
              onTap: () {
                setState(() => _graphOpen = false);
                _resetIdleTimer();
              },
              radius: 24,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.expand_more_rounded, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookTitleHeader(
    SoroLanguage lang,
    bool isPhone,
    double ruleSpacing,
  ) {
    final String activeQ = widget.activeQuestion.trim();
    final String title = BoardStrings.tr(lang, 'problemTitle');
    final bool showQ = activeQ.isNotEmpty && activeQ != title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: SoroTokens.s8,
          children: [
            IgnorePointer(
              child: SoroLocalizedText(
                title,
                key: const Key('board-problem-title'),
                language: lang,
                style: SoroTokens.serif(
                  fontSize: isPhone ? 20 : 24,
                  fontWeight: FontWeight.w600,
                  color: SoroTokens.ink,
                ).copyWith(height: ruleSpacing / (isPhone ? 20 : 24)),
              ),
            ),
            if (_factoringCompleted || _rootsRevealed || _unaidedCompleted)
              Container(
                key: const Key('correct-badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: SoroTokens.mint,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                  border: Border.all(color: SoroTokens.successDeep, width: 1.5),
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
          ],
        ),
        if (showQ)
          IgnorePointer(
            child: SoroLocalizedText(
              activeQ,
              key: const Key('board-active-question'),
              language: lang,
              style: SoroTokens.sans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SoroTokens.ink2,
              ).copyWith(height: ruleSpacing / 14),
            ),
          )
        else
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0,
              child: Text(
                activeQ.isEmpty ? title : activeQ,
                key: const Key('board-active-question'),
              ),
            ),
          ),
      ],
    );
  }

  /// One line of the worked log, written straight onto the page: the tutor in
  /// crimson, the student in royal blue.
  Widget _buildNotebookEntryRow(
    _NotebookEntry entry,
    SoroLanguage lang,
    int index,
    double ruleSpacing,
  ) {
    final bool isTutor = entry.author == ScriptAuthor.tutor;
    final double size = isTutor ? 17 : 20;
    final TextStyle style = entry.isAnalogy
        ? SoroTokens.serif(
            fontSize: size,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: SoroTokens.crimsonDeep,
          )
        : isTutor
        ? SoroTokens.sans(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: SoroTokens.crimsonDeep,
          )
        : SoroTokens.serif(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: SoroTokens.studentBlue,
          );

    return IgnorePointer(
      key: entry.isAnalogy ? const Key('board-analogy-line') : null,
      child: Column(
        key: Key('notebook-entry-$index'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SoroLocalizedText(
            entry.text,
            language: SoroLanguage.en,
            style: style.copyWith(height: ruleSpacing / size),
          ),
          if (isTutor &&
              lang == SoroLanguage.yo &&
              entry.textYo != null &&
              entry.textYo!.isNotEmpty)
            SoroLocalizedText(
              entry.textYo!,
              language: SoroLanguage.yo,
              style: SoroTokens.sans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SoroTokens.ink2,
              ).copyWith(height: ruleSpacing / 14),
            ),
        ],
      ),
    );
  }

  /// The tutor's step template as a crimson line with the blanks as inline
  /// boxes the student can type into (or write beside).
  Widget _buildActiveBlankRow(
    TutorBlankRowPayload row,
    SoroLanguage lang,
    bool isPhone,
    double ruleSpacing,
  ) {
    final bool isFactorStep = row.stepId == QuadraticStepIds.factors;
    final List<String> parts = row.templateText.split('▢');
    final TextStyle lineStyle = SoroTokens.serif(
      fontSize: isPhone ? 19 : 22,
      fontWeight: FontWeight.w600,
      color: SoroTokens.crimsonDeep,
    );

    final List<Widget> inline = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        inline.add(IgnorePointer(child: Text(parts[i], style: lineStyle)));
      }
      if (i < parts.length - 1 && i < row.blanks.length) {
        final BlankSpec blank = row.blanks[i];
        inline.add(
          SizedBox(
            width: isPhone ? 54 : 64,
            height: ruleSpacing - 4,
            child: TextField(
              key: Key('blank-input-${blank.id}'),
              controller: _blankControllers[blank.id],
              focusNode: _blankFocusNodes[blank.id],
              onChanged: (_) => _notifyStudentTyping(),
              onSubmitted: (_) => _handleSubmitCurrentBlanks(),
              textAlign: TextAlign.center,
              style: SoroTokens.serif(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: SoroTokens.studentBlue,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: blank.label,
                hintStyle: SoroTokens.sans(
                  fontSize: 13,
                  color: SoroTokens.studentBlue.withValues(alpha: 0.55),
                ),
                filled: true,
                fillColor: SoroTokens.skyDeep.withValues(alpha: 0.7),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: SoroTokens.studentBlue,
                    width: 1.4,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: SoroTokens.studentBlue,
                    width: 2.2,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      key: Key('active-blank-row-${row.stepId}'),
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: const Key('active-blank-template'),
            label: row.templateText,
            child: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: inline,
            ),
          ),
          if (isFactorStep)
            SizedBox(
              height: 48,
              child: TextButton(
                key: const Key('demo-wrong-sign-button'),
                onPressed: () => _handleSubmitCurrentBlanks(
                  inputMethod: 'Typed (sign error)',
                  overrideValues: const {
                    'f1': '+2',
                    'f2': '+3',
                    'sign_error': 'true',
                  },
                ),
                child: Text(
                  BoardStrings.tr(lang, 'trySignErrorBtn'),
                  style: SoroTokens.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SoroTokens.ink2,
                  ),
                ),
              ),
            ),
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
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: Text(
              BoardStrings.tr(lang, 'graphSupportHeading'),
              style: SoroTokens.sans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: SoroTokens.ink2,
              ),
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
                              borderRadius: BorderRadius.circular(
                                SoroTokens.rPill,
                              ),
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

/// Paints the student's freehand strokes as smooth, pressure-width curves.
class BoardInkPainter extends CustomPainter {
  const BoardInkPainter({required this.strokes});

  final List<BoardInkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final BoardInkStroke stroke in strokes) {
      final List<Offset> pts = stroke.points;
      if (pts.isEmpty) continue;
      final Paint paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (pts.length < 3) {
        paint.strokeWidth = stroke.widths.first;
        if (pts.length == 1) {
          canvas.drawCircle(
            pts.first,
            stroke.widths.first / 2,
            paint..style = PaintingStyle.fill,
          );
        } else {
          canvas.drawLine(pts.first, pts.last, paint);
        }
        continue;
      }
      Offset prevMid = pts.first;
      for (int i = 1; i < pts.length - 1; i++) {
        final Offset mid = (pts[i] + pts[i + 1]) / 2;
        paint.strokeWidth = stroke.widths[i];
        canvas.drawPath(
          Path()
            ..moveTo(prevMid.dx, prevMid.dy)
            ..quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy),
          paint,
        );
        prevMid = mid;
      }
      paint.strokeWidth = stroke.widths.last;
      canvas.drawLine(prevMid, pts.last, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardInkPainter oldDelegate) => true;
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
    canvas.drawLine(
      Offset(12, axisY),
      Offset(size.width - 12, axisY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(axisX, 10),
      Offset(axisX, size.height - 10),
      axisPaint,
    );

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
