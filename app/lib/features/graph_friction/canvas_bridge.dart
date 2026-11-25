import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Surface presets for the Friction Physics illustration.
enum FrictionSurface {
  ice(
    id: 'ice',
    labelEn: 'Smooth Ice',
    labelYo: 'Yìnyín Dídán', // needs native check
    mu: 0.08,
  ),
  wetRoad(
    id: 'wet_road',
    labelEn: 'Wet Road (Danfo)',
    labelYo: 'Ojú-ọ̀nà Tútù (Danfo)', // needs native check
    mu: 0.22,
  ),
  wood(
    id: 'wood',
    labelEn: 'Dry Wood Floor',
    labelYo: 'Ilẹ̀ Pákó Gbígbẹ', // needs native check
    mu: 0.45,
  ),
  gravel(
    id: 'gravel',
    labelEn: 'Rough Gravel',
    labelYo: 'Ilẹ̀ Okúta Líle', // needs native check
    mu: 0.72,
  );

  final String id;
  final String labelEn;
  final String labelYo;
  final double mu;

  const FrictionSurface({
    required this.id,
    required this.labelEn,
    required this.labelYo,
    required this.mu,
  });

  static FrictionSurface fromId(String? raw) {
    if (raw == null) return FrictionSurface.wood;
    final normalized = raw.trim().toLowerCase();
    for (final s in FrictionSurface.values) {
      if (s.id == normalized || s.name.toLowerCase() == normalized) {
        return s;
      }
    }
    if (normalized.contains('wet') || normalized.contains('danfo')) {
      return FrictionSurface.wetRoad;
    }
    if (normalized.contains('ice') || normalized.contains('smooth')) {
      return FrictionSurface.ice;
    }
    if (normalized.contains('rough') ||
        normalized.contains('gravel') ||
        normalized.contains('asphalt')) {
      return FrictionSurface.gravel;
    }
    return FrictionSurface.wood;
  }
}

/// Incoming command from the tutor agent (`canvas_cmd` contract).
class CanvasCmd {
  final String cmd;
  final String target;
  final Map<String, dynamic> params;

  const CanvasCmd({
    required this.cmd,
    required this.target,
    this.params = const <String, dynamic>{},
  });

  factory CanvasCmd.fromJson(Map<String, dynamic> json) {
    final rawCmd =
        (json['op'] ?? json['cmd'] ?? json['action'] ?? json['type'] ?? 'update')
            .toString();
    final nestedParams = json['params'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['params'] as Map<String, dynamic>)
        : json['payload'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['payload'] as Map<String, dynamic>)
            : <String, dynamic>{};

    final mergedParams = <String, dynamic>{
      ...json,
      ...nestedParams,
    };

    String rawTarget =
        (json['target'] ?? nestedParams['target'] ?? '').toString();
    final simOrVisual =
        '${json['sim'] ?? ''} ${json['visual'] ?? ''}'.toLowerCase();
    if (rawTarget.isEmpty) {
      if (simOrVisual.contains('friction') ||
          rawCmd.contains('crate') ||
          rawCmd.contains('surface') ||
          rawCmd.contains('friction') ||
          rawCmd.contains('force') ||
          rawCmd.contains('sim') ||
          rawCmd.contains('slow')) {
        rawTarget = 'friction';
      } else {
        rawTarget = 'parabola';
      }
    }

    return CanvasCmd(
      cmd: rawCmd,
      target: rawTarget,
      params: mergedParams,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'type': 'canvas_cmd',
        'op': cmd,
        'cmd': cmd,
        'target': target,
        'params': params,
      };
}

/// Outgoing action from the student (`student_action` contract).
/// Throttled to at most 5 emissions per second.
class StudentAction {
  final String action;
  final String target;
  final Map<String, dynamic> params;
  final int timestampMs;

  const StudentAction({
    required this.action,
    required this.target,
    required this.params,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'type': 'student_action',
        'action': action,
        'target': target,
        'params': params,
        'timestamp_ms': timestampMs,
      };
}

/// Controller bridging `canvas_cmd` (tutor -> canvas/PhET sim) and
/// `student_action` (student drags -> tutor agent, throttled to <= 5/sec).
class CanvasBridgeController extends ChangeNotifier {
  static const int maxActionsPerSecond = 5;
  static const Duration minActionInterval = Duration(milliseconds: 200);

  final DateTime Function() _clock;
  final void Function(StudentAction action)? onStudentAction;
  final void Function(CanvasCmd cmd)? onForwardToIframe;

  final StreamController<StudentAction> _studentActionStream =
      StreamController<StudentAction>.broadcast();
  final StreamController<CanvasCmd> _canvasCmdStream =
      StreamController<CanvasCmd>.broadcast();

  // Sliding window of emission timestamps (ms) to guarantee <= 5 per second.
  final List<int> _recentEmissionMs = <int>[];
  int _throttledDropCount = 0;
  final List<StudentAction> _emittedActions = <StudentAction>[];
  StudentAction? _lastStudentAction;
  CanvasCmd? _lastCanvasCmd;

  // Language slot state (English-first + optional Yoruba slot)
  bool _showYoruba = true;

  // --- Parabola Graph state (y = a*x^2 + b*x + c) ---
  // Default: y = 1x^2 - 2x - 3 (roots at -1 and 3, vertex at (1, -4))
  double _a = 1.0;
  double _b = -2.0;
  double _c = -3.0;
  String _activeCoeff = 'b';
  bool _rootsRevealed = false;
  bool _vertexRevealed = false;
  int _circledRootIndex = 1; // 1 = right root circled by tutor in crimson
  bool _showParabolaAnalogy = true;

  // --- Friction Illustration state ---
  FrictionSurface _surface = FrictionSurface.wood;
  double _crateMassKg = 50.0;
  double _appliedForceN = 0.0;
  double _cratePositionM = 2.0; // 0..10 m track
  double _crateVelocityMps = 0.0;
  bool _crateDidSlowDown = false;
  bool _askingWhySlowed = false;
  bool _showFrictionAnalogy = true;
  bool _useYorubaPhetBuild = true;
  int _simMoveCount = 0;

  CanvasBridgeController({
    DateTime Function()? clock,
    this.onStudentAction,
    this.onForwardToIframe,
  }) : _clock = clock ?? DateTime.now;

  // Streams & telemetry getters
  Stream<StudentAction> get studentActionStream => _studentActionStream.stream;
  Stream<CanvasCmd> get canvasCmdStream => _canvasCmdStream.stream;
  List<StudentAction> get emittedActions =>
      List<StudentAction>.unmodifiable(_emittedActions);
  StudentAction? get lastStudentAction => _lastStudentAction;
  CanvasCmd? get lastCanvasCmd => _lastCanvasCmd;
  int get throttledDropCount => _throttledDropCount;

  bool get showYoruba => _showYoruba;
  double get a => _a;
  double get b => _b;
  double get c => _c;
  String get activeCoeff => _activeCoeff;
  bool get rootsRevealed => _rootsRevealed;
  bool get vertexRevealed => _vertexRevealed;
  int get circledRootIndex => _circledRootIndex;
  bool get showParabolaAnalogy => _showParabolaAnalogy;

  FrictionSurface get surface => _surface;
  double get crateMassKg => _crateMassKg;
  double get appliedForceN => _appliedForceN;
  double get cratePositionM => _cratePositionM;
  double get crateVelocityMps => _crateVelocityMps;
  bool get crateDidSlowDown => _crateDidSlowDown;
  bool get askingWhySlowed => _askingWhySlowed;
  bool get showFrictionAnalogy => _showFrictionAnalogy;
  bool get useYorubaPhetBuild => _useYorubaPhetBuild;
  int get simMoveCount => _simMoveCount;

  /// Discriminant b^2 - 4ac
  double get discriminant => _b * _b - 4 * _a * _c;

  /// Vertex x = -b / (2a)
  double get vertexX => -_b / (2 * _a);

  /// Vertex y = a*vx^2 + b*vx + c
  double get vertexY {
    final vx = vertexX;
    return _a * vx * vx + _b * vx + _c;
  }

  /// Sorted real roots [r1, r2] when discriminant >= 0, else empty list.
  List<double> get realRoots {
    final disc = discriminant;
    if (disc < 0) return const <double>[];
    final sqrtD = math.sqrt(disc);
    final r1 = (-_b - sqrtD) / (2 * _a);
    final r2 = (-_b + sqrtD) / (2 * _a);
    return r1 <= r2 ? <double>[r1, r2] : <double>[r2, r1];
  }

  /// Opposing friction force in Newtons when pushing or sliding.
  double get frictionForceN {
    final normalN = _crateMassKg * 9.8;
    final maxStaticOrKinetic = _surface.mu * normalN;
    if (_crateVelocityMps.abs() > 0.05) {
      return maxStaticOrKinetic;
    }
    if (_appliedForceN.abs() > 0.1) {
      return math.min(_appliedForceN.abs(), maxStaticOrKinetic);
    }
    return 0.0;
  }

  /// Net horizontal force in Newtons.
  double get netForceN {
    if (_appliedForceN == 0 && _crateVelocityMps.abs() <= 0.05) {
      return 0.0;
    }
    final dir = _appliedForceN != 0
        ? _appliedForceN.sign
        : (_crateVelocityMps >= 0 ? 1.0 : -1.0);
    final rawNet = _appliedForceN - dir * frictionForceN;
    if (_crateVelocityMps.abs() <= 0.05 &&
        _appliedForceN.abs() <= frictionForceN) {
      return 0.0;
    }
    return rawNet;
  }

  void toggleLanguageSlot() {
    _showYoruba = !_showYoruba;
    _useYorubaPhetBuild = _showYoruba;
    notifyListeners();
  }

  void setPhetLocale({required bool yoruba}) {
    _useYorubaPhetBuild = yoruba;
    notifyListeners();
  }

  void selectCoefficient(String coeff) {
    if (coeff == 'a' || coeff == 'b' || coeff == 'c') {
      _activeCoeff = coeff;
      notifyListeners();
    }
  }

  /// Student drags coefficient a, b, or c.
  /// CRITICAL RULE: Dragging b (or a, c) updates the curve without printing
  /// or revealing the answers; roots and vertex stay as '?' markers!
  void dragCoefficient(String coeff, double newValue) {
    double clamped = newValue;
    if (coeff == 'a') {
      clamped = newValue.clamp(-3.0, 3.0);
      if (clamped.abs() < 0.25) {
        clamped = _a >= 0 ? -1.0 : 1.0;
      }
      _a = double.parse(clamped.toStringAsFixed(1));
    } else if (coeff == 'b') {
      clamped = newValue.clamp(-6.0, 6.0);
      _b = double.parse(clamped.toStringAsFixed(1));
    } else if (coeff == 'c') {
      clamped = newValue.clamp(-6.0, 6.0);
      _c = double.parse(clamped.toStringAsFixed(1));
    }
    _activeCoeff = coeff;
    // Never reveal answers on coefficient drag; reset to '?' markers.
    _rootsRevealed = false;
    _vertexRevealed = false;
    notifyListeners();

    _tryEmitStudentAction(
      action: 'drag_coefficient',
      target: 'parabola',
      params: <String, dynamic>{
        'coeff': coeff,
        'value': coeff == 'a'
            ? _a
            : coeff == 'b'
                ? _b
                : _c,
        'a': _a,
        'b': _b,
        'c': _c,
      },
    );
  }

  void stepActiveCoefficient(double delta) {
    final current = _activeCoeff == 'a'
        ? _a
        : _activeCoeff == 'b'
            ? _b
            : _c;
    double next = current + delta;
    if (_activeCoeff == 'a' && next.abs() < 0.25) {
      next = delta > 0 ? 1.0 : -1.0;
    }
    dragCoefficient(_activeCoeff, next);
  }

  void applyQuadraticPreset({
    required double a,
    required double b,
    required double c,
  }) {
    _a = a;
    _b = b;
    _c = c;
    _rootsRevealed = false;
    _vertexRevealed = false;
    notifyListeners();
  }

  /// Student finds and places the roots/vertex (or toggles back to '?' mode).
  void setStudentFoundAnswers({required bool revealed}) {
    _rootsRevealed = revealed;
    _vertexRevealed = revealed;
    notifyListeners();

    if (revealed) {
      _tryEmitStudentAction(
        action: 'place_roots_and_vertex',
        target: 'parabola',
        params: <String, dynamic>{
          'a': _a,
          'b': _b,
          'c': _c,
          'roots_found': true,
          'vertex_found': true,
        },
      );
    }
  }

  void setParabolaAnalogyVisible(bool visible) {
    _showParabolaAnalogy = visible;
    notifyListeners();
  }

  void setFrictionAnalogyVisible(bool visible) {
    _showFrictionAnalogy = visible;
    notifyListeners();
  }

  /// Student drags the crate or applied force slider in the Friction sim.
  /// Updates physics state immediately and emits a throttled `student_action`
  /// (at most 5 per second) to the agent.
  void studentDragFriction({
    double? forceN,
    double? positionDeltaM,
    FrictionSurface? surface,
  }) {
    if (surface != null) {
      _surface = surface;
    }
    if (forceN != null) {
      _appliedForceN = forceN.clamp(-300.0, 300.0);
      _advancePhysicsStep(dtSeconds: 0.25);
    }
    if (positionDeltaM != null) {
      _cratePositionM = (_cratePositionM + positionDeltaM).clamp(0.4, 9.6);
      // Estimate implied push force from student drag
      _appliedForceN = (positionDeltaM * 240.0).clamp(-260.0, 260.0);
      _crateVelocityMps = (positionDeltaM * 4.5).clamp(-6.0, 6.0);
      _crateDidSlowDown = true;
      _simMoveCount++;
    }
    notifyListeners();

    _tryEmitStudentAction(
      action: 'drag_friction_sim',
      target: 'friction',
      params: <String, dynamic>{
        'surface': _surface.id,
        'mu': _surface.mu,
        'applied_force_n': double.parse(_appliedForceN.toStringAsFixed(1)),
        'friction_force_n': double.parse(frictionForceN.toStringAsFixed(1)),
        'crate_position_m': double.parse(_cratePositionM.toStringAsFixed(2)),
        'crate_velocity_mps': double.parse(_crateVelocityMps.toStringAsFixed(2)),
      },
    );
  }

  /// Releases the active push so friction decelerates the crate to a stop.
  void releasePushAndCoast() {
    _appliedForceN = 0.0;
    // Simulate coasting deceleration under kinetic friction
    final decel = _surface.mu * 9.8;
    if (_crateVelocityMps.abs() > 0.05) {
      final stopDist =
          (_crateVelocityMps * _crateVelocityMps) / (2 * math.max(0.4, decel));
      final sign = _crateVelocityMps.sign;
      _cratePositionM =
          (_cratePositionM + sign * math.min(2.6, stopDist * 0.45))
              .clamp(0.4, 9.6);
      _crateVelocityMps = 0.0;
      _crateDidSlowDown = true;
      _simMoveCount++;
    }
    notifyListeners();
  }

  /// Processes an incoming `canvas_cmd` from the tutor agent.
  void handleCanvasCmd(Map<String, dynamic> rawJson) {
    final cmd = CanvasCmd.fromJson(rawJson);
    applyCanvasCmd(cmd);
  }

  void applyCanvasCmd(CanvasCmd cmd) {
    _lastCanvasCmd = cmd;
    _canvasCmdStream.add(cmd);
    onForwardToIframe?.call(cmd);

    final c = cmd.cmd.toLowerCase();
    final p = cmd.params;

    if (cmd.target == 'parabola' ||
        c.contains('quadratic') ||
        c.contains('parabola') ||
        c.contains('root') ||
        c.contains('vertex')) {
      if (p['a'] is num) _a = (p['a'] as num).toDouble();
      if (p['b'] is num) _b = (p['b'] as num).toDouble();
      if (p['c'] is num) _c = (p['c'] as num).toDouble();

      if (c == 'reveal_roots' || p['reveal_roots'] == true) {
        _rootsRevealed = true;
      } else if (c == 'reveal_vertex' || p['reveal_vertex'] == true) {
        _vertexRevealed = true;
      } else if (c == 'reveal_all' || c == 'student_solved') {
        _rootsRevealed = true;
        _vertexRevealed = true;
      } else if (c == 'hide_answers' || c == 'reset_parabola') {
        _rootsRevealed = false;
        _vertexRevealed = false;
      } else if (p.containsKey('a') || p.containsKey('b') || p.containsKey('c')) {
        // Tutor updating coefficients keeps '?' markers hidden unless specified
        if (p['reveal_roots'] != true) _rootsRevealed = false;
        if (p['reveal_vertex'] != true) _vertexRevealed = false;
      }

      if (p['circled_root'] is int) {
        _circledRootIndex = p['circled_root'] as int;
      }
      notifyListeners();
      return;
    }

    // Friction simulation commands
    if (p['surface'] != null) {
      _surface = FrictionSurface.fromId(p['surface']?.toString());
    }
    if (p['mass_kg'] is num) {
      _crateMassKg = (p['mass_kg'] as num).toDouble().clamp(10.0, 200.0);
    }

    if (c == 'push_crate' || c == 'apply_force' || p['force_n'] is num) {
      final force = (p['force_n'] is num)
          ? (p['force_n'] as num).toDouble()
          : (p['force'] is num)
              ? (p['force'] as num).toDouble()
              : 160.0;
      _appliedForceN = force;
      _advancePhysicsStep(dtSeconds: 0.65);
      // Coast after the tutor's push so the student sees friction slow it down
      if (p['hold_push'] != true) {
        _appliedForceN = force * 0.35;
        _crateDidSlowDown = true;
      }
    } else if (c == 'set_surface' || c == 'change_surface') {
      // Re-run a gentle push on the new surface so the student sees the difference
      _appliedForceN = (p['force_n'] is num)
          ? (p['force_n'] as num).toDouble()
          : 150.0;
      _advancePhysicsStep(dtSeconds: 0.55);
      _crateDidSlowDown = true;
    } else if (c == 'ask_why_slowed' || c == 'highlight_friction') {
      _askingWhySlowed = true;
      _crateDidSlowDown = true;
      _appliedForceN = 0.0;
      _crateVelocityMps = 0.0;
    } else if (c == 'reset' || c == 'reset_sim' || c == 'reset_friction') {
      _surface = FrictionSurface.wood;
      _appliedForceN = 0.0;
      _cratePositionM = 2.0;
      _crateVelocityMps = 0.0;
      _crateDidSlowDown = false;
      _askingWhySlowed = false;
      _simMoveCount++;
    } else {
      // Generic move command
      _appliedForceN = 140.0;
      _advancePhysicsStep(dtSeconds: 0.5);
    }

    notifyListeners();
  }

  void _advancePhysicsStep({required double dtSeconds}) {
    final normalN = _crateMassKg * 9.8;
    final maxFriction = _surface.mu * normalN;
    double net = 0.0;
    if (_appliedForceN.abs() > maxFriction) {
      net = _appliedForceN - _appliedForceN.sign * maxFriction;
    } else {
      // Even a sub-threshold push nudges slightly before friction arrests it
      net = _appliedForceN * (1.0 - _surface.mu) * 0.45;
    }
    final accel = net / _crateMassKg;
    _crateVelocityMps = (_crateVelocityMps + accel * dtSeconds).clamp(-6.0, 6.0);
    final displacement = _crateVelocityMps * dtSeconds +
        0.5 * accel * dtSeconds * dtSeconds +
        (_appliedForceN / 180.0) * (1.05 - _surface.mu);
    _cratePositionM = (_cratePositionM + displacement).clamp(0.5, 9.4);
    _crateDidSlowDown = true;
    _simMoveCount++;
  }

  /// Enforces the 5-per-second (`student_action`) throttle.
  bool _tryEmitStudentAction({
    required String action,
    required String target,
    required Map<String, dynamic> params,
  }) {
    final nowMs = _clock().millisecondsSinceEpoch;

    // Remove emissions older than 1000 ms
    _recentEmissionMs.removeWhere((t) => nowMs - t >= 1000);

    // Enforce both <= 5 actions per 1000ms window and >= 200ms spacing
    final tooSoon = _recentEmissionMs.isNotEmpty &&
        (nowMs - _recentEmissionMs.last) < minActionInterval.inMilliseconds;
    final windowFull = _recentEmissionMs.length >= maxActionsPerSecond;

    if (tooSoon || windowFull) {
      _throttledDropCount++;
      return false;
    }

    _recentEmissionMs.add(nowMs);
    final event = StudentAction(
      action: action,
      target: target,
      params: params,
      timestampMs: nowMs,
    );
    _lastStudentAction = event;
    _emittedActions.add(event);
    onStudentAction?.call(event);
    _studentActionStream.add(event);
    return true;
  }

  @override
  void dispose() {
    _studentActionStream.close();
    _canvasCmdStream.close();
    super.dispose();
  }
}
