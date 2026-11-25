import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/soro_theme.dart';
import 'canvas_bridge.dart';
import 'graph_friction_strings.dart';

/// Supporting Parabola Graph Card with draggable a, b, c coefficients.
/// Roots and vertex remain as '?' markers until the student finds them
/// (then shown in student royal-blue ink #1B56D0).
class ParabolaGraphCard extends StatelessWidget {
  final CanvasBridgeController controller;

  const ParabolaGraphCard({
    super.key,
    required this.controller,
  });

  // Soro design tokens bridged from SoroTokens (app/lib/theme/soro_theme.dart)
  static const Color kTutorCrimson = SoroTokens.crimson;
  static const Color kTutorDeep = SoroTokens.crimsonDeep;
  static const Color kStudentBlue = SoroTokens.studentBlue;
  static const Color kLogoOrange = SoroTokens.orange;
  static const Color kInk = SoroTokens.ink;
  static const Color kInk2 = SoroTokens.ink2;
  static const Color kCream = SoroTokens.cream;
  static const Color kPaper = SoroTokens.paper;
  static const Color kNotebookSheet = Color(0xFFFFFEFA);
  static const Color kSand = SoroTokens.sand;
  static const Color kLine = SoroTokens.line;
  static const Color kControl = SoroTokens.control;
  static const Color kWoodBorder = Color(0xFF8D5527);
  static const Color kSky = SoroTokens.sky;
  static const Color kSun = SoroTokens.sun;
  static const Color kMint = SoroTokens.mint;
  static const Color kSticky = SoroTokens.sticky;
  static const Color kStickyCurl = SoroTokens.stickyCurl;
  static const Color kBlush = SoroTokens.blush;

  static String formatNumber(double n) {
    final rounded = (n * 10).round() / 10.0;
    final isInt = (rounded - rounded.roundToDouble()).abs() < 0.01;
    final absStr =
        isInt ? rounded.abs().round().toString() : rounded.abs().toStringAsFixed(1);
    return rounded < 0 ? '−$absStr' : absStr;
  }

  String _buildSpokenGraphSummary() {
    final dirWord = controller.a > 0 ? 'opens upward' : 'opens downward';
    final vx = controller.vertexX;
    final vy = controller.vertexY;
    final sideWord = vx > 0.1
        ? 'right of the y-axis'
        : vx < -0.1
            ? 'left of the y-axis'
            : 'on the y-axis';
    final roots = controller.realRoots;

    if (roots.isNotEmpty) {
      if (controller.rootsRevealed && controller.vertexRevealed) {
        return 'Parabola $dirWord. Student placed roots at x = ${formatNumber(roots.first)} and x = ${formatNumber(roots.last)}, and turning point at (${formatNumber(vx)}, ${formatNumber(vy)}).';
      }
      return 'Parabola $dirWord. Crosses the x-axis at two unknown points marked with hollow ? markers. Turning point is $sideWord and marked vertex: ?.';
    } else {
      return 'Parabola $dirWord and does not cross the x-axis. Turning point is $sideWord and marked vertex: ?.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final a = controller.a;
        final b = controller.b;
        final c = controller.c;
        final active = controller.activeCoeff;
        final showYo = controller.showYoruba;
        final roots = controller.realRoots;
        final vx = controller.vertexX;
        final vy = controller.vertexY;
        final revealed = controller.rootsRevealed && controller.vertexRevealed;

        final sliderMin = active == 'a' ? -3.0 : -6.0;
        final sliderMax = active == 'a' ? 3.0 : 6.0;
        final currentVal = active == 'a'
            ? a
            : active == 'b'
                ? b
                : c;

        return Container(
          key: const Key('parabola_graph_card'),
          decoration: BoxDecoration(
            color: kPaper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kLine, width: 1.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x185C4A2A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Section Kicker & Header
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSky,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'STEP 2 OF 4 · SUPPORTING GRAPH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: kTutorDeep,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: revealed ? kMint : kSun,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kInk, width: 1),
                    ),
                    child: Text(
                      revealed
                          ? '✓ Student values in blue'
                          : '? Markers active (no answer leak)',
                      key: const Key('parabola_marker_status_pill'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                GraphFrictionStrings.parabolaHeader.en,
                style: const TextStyle(
                  fontFamily: 'Source Serif 4',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: kInk,
                  height: 1.25,
                ),
              ),
              if (showYo) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  GraphFrictionStrings.parabolaHeader.yo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: kTutorDeep,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Pinned Tutor Prompt Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kTutorCrimson,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Sọ̀rọ̀',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            GraphFrictionStrings.turnCueStudent.en,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      revealed
                          ? GraphFrictionStrings.parabolaSolvedPrompt.en
                          : GraphFrictionStrings.parabolaTutorPrompt.en,
                      key: const Key('parabola_tutor_prompt_en'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                      ),
                    ),
                    if (showYo) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        revealed
                            ? GraphFrictionStrings.parabolaSolvedPrompt.yo
                            : GraphFrictionStrings.parabolaTutorPrompt.yo,
                        key: const Key('parabola_tutor_prompt_yo'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kInk2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Wooden Classroom Board Frame surrounding the Notebook Graph Canvas
              Container(
                decoration: BoxDecoration(
                  color: kNotebookSheet,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kWoodBorder, width: 4.5),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1E5C4A2A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Equation Bar with Draggable / Selectable a, b, c pills
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kSand,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: <Widget>[
                              const Text(
                                'y =',
                                style: TextStyle(
                                  fontFamily: 'Source Serif 4',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kInk,
                                ),
                              ),
                              _buildCoeffPill(
                                key: const Key('pill_a'),
                                coeff: 'a',
                                label: formatNumber(a),
                                bgColor: kSky,
                                isSelected: active == 'a',
                              ),
                              const Text(
                                'x²',
                                style: TextStyle(
                                  fontFamily: 'Source Serif 4',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kInk,
                                ),
                              ),
                              Text(
                                b < 0 ? '−' : '+',
                                key: const Key('sign_b'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kInk,
                                ),
                              ),
                              _buildCoeffPill(
                                key: const Key('pill_b'),
                                coeff: 'b',
                                label: formatNumber(b.abs()),
                                bgColor: kSun,
                                isSelected: active == 'b',
                              ),
                              const Text(
                                'x',
                                style: TextStyle(
                                  fontFamily: 'Source Serif 4',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kInk,
                                ),
                              ),
                              Text(
                                c < 0 ? '−' : '+',
                                key: const Key('sign_c'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kInk,
                                ),
                              ),
                              _buildCoeffPill(
                                key: const Key('pill_c'),
                                coeff: 'c',
                                label: formatNumber(c.abs()),
                                bgColor: kMint,
                                isSelected: active == 'c',
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            children: <Widget>[
                              OutlinedButton(
                                key: const Key('preset_pack_btn'),
                                onPressed: () => controller.applyQuadraticPreset(
                                  a: 1.0,
                                  b: -5.0,
                                  c: 6.0,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 28),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  side: const BorderSide(color: kControl),
                                ),
                                child: const Text(
                                  'Pack: x²−5x+6',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: kInk,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                key: const Key('reset_quad_btn'),
                                onPressed: () => controller.applyQuadraticPreset(
                                  a: 1.0,
                                  b: -2.0,
                                  c: -3.0,
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 28),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  side: const BorderSide(color: kControl),
                                ),
                                child: const Text(
                                  '↻ Reset',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: kInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Screen-reader / spoken description (never leaks answers!)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kLine),
                      ),
                      child: Text(
                        _buildSpokenGraphSummary(),
                        key: const Key('graph_spoken_description'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: kInk2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // CustomPainted Parabola Graph with '?' markers (or blue revealed labels)
                    // Also supports direct horizontal drag to scrub the active coefficient!
                    GestureDetector(
                      key: const Key('parabola_canvas_drag_area'),
                      onHorizontalDragUpdate: (DragUpdateDetails details) {
                        final delta = details.primaryDelta ?? 0.0;
                        if (delta.abs() < 0.2) return;
                        final cur = active == 'a'
                            ? a
                            : active == 'b'
                                ? b
                                : c;
                        controller.dragCoefficient(
                          active,
                          cur + (delta / 28.0),
                        );
                      },
                      child: SizedBox(
                        height: 224,
                        width: double.infinity,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: CustomPaint(
                                key: const Key('parabola_custom_paint'),
                                painter: ParabolaCanvasPainter(
                                  a: a,
                                  b: b,
                                  c: c,
                                  rootsRevealed: controller.rootsRevealed,
                                  vertexRevealed: controller.vertexRevealed,
                                  showYoruba: showYo,
                                ),
                              ),
                            ),
                            // Semantic / widget-test accessible marker overlay badges
                            Positioned(
                              left: 10,
                              bottom: 8,
                              right: 10,
                              child: IgnorePointer(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    if (roots.isNotEmpty) ...<Widget>[
                                      _buildMarkerReadoutChip(
                                        key: const Key('root_1_marker_label'),
                                        text: controller.rootsRevealed
                                            ? 'root 1: ${formatNumber(roots.first)} ✓'
                                            : 'root 1: ?',
                                        isRevealed: controller.rootsRevealed,
                                      ),
                                      _buildMarkerReadoutChip(
                                        key: const Key('root_2_marker_label'),
                                        text: controller.rootsRevealed
                                            ? 'root 2: ${formatNumber(roots.last)} ✓'
                                            : 'root 2: ?',
                                        isRevealed: controller.rootsRevealed,
                                      ),
                                    ] else
                                      _buildMarkerReadoutChip(
                                        key: const Key('no_real_roots_label'),
                                        text: 'No real x-roots',
                                        isRevealed: false,
                                      ),
                                    _buildMarkerReadoutChip(
                                      key: const Key('vertex_marker_label'),
                                      text: controller.vertexRevealed
                                          ? 'vertex: (${formatNumber(vx)}, ${formatNumber(vy)}) ✓'
                                          : 'vertex: ?',
                                      isRevealed: controller.vertexRevealed,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Coefficient Scrub Row (drag a, b, or c)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kPaper,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kLine),
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            'drag $active',
                            key: const Key('active_coeff_label'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStepCircleButton(
                            key: const Key('coeff_minus_btn'),
                            label: '−',
                            onTap: () => controller.stepActiveCoefficient(-1.0),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: kTutorCrimson,
                                inactiveTrackColor: kLine,
                                thumbColor: kTutorCrimson,
                                overlayColor: const Color(0x22C31E49),
                              ),
                              child: Slider(
                                key: const Key('coeff_slider'),
                                min: sliderMin,
                                max: sliderMax,
                                value: currentVal.clamp(sliderMin, sliderMax),
                                onChanged: (double val) {
                                  controller.dragCoefficient(active, val);
                                },
                              ),
                            ),
                          ),
                          _buildStepCircleButton(
                            key: const Key('coeff_plus_btn'),
                            label: '+',
                            onTap: () => controller.stepActiveCoefficient(1.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Student Answer Reveal Toggle Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('reveal_answers_btn'),
                        onPressed: () {
                          controller.setStudentFoundAnswers(
                            revealed: !revealed,
                          );
                        },
                        icon: Icon(
                          revealed ? Icons.replay : Icons.edit,
                          size: 16,
                          color: revealed ? kInk : kStudentBlue,
                        ),
                        label: Text(
                          revealed
                              ? '↺ Hide student values (return to ? markers)'
                              : '✎ Student found roots & vertex (show in blue #1B56D0)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: revealed ? kInk : kStudentBlue,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              revealed ? kSand : const Color(0xFFEBF4FC),
                          side: BorderSide(
                            color: revealed ? kControl : kStudentBlue,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Equal-Weight Bilingual Term Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  _buildBilingualTermChip(
                    term: GraphFrictionStrings.termRoots,
                    bgColor: kSticky,
                    showYo: showYo,
                  ),
                  _buildBilingualTermChip(
                    term: GraphFrictionStrings.termVertex,
                    bgColor: kBlush,
                    showYo: showYo,
                  ),
                  _buildBilingualTermChip(
                    term: GraphFrictionStrings.termAxisOfSymmetry,
                    bgColor: kSky,
                    showYo: showYo,
                  ),
                ],
              ),

              // Everyday Analogy Card (Handoff Note #5: thrown ball meeting the ground)
              if (controller.showParabolaAnalogy) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  key: const Key('parabola_analogy_card'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0BE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: kInk,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Everyday Analogy (explains idea, never gives answer)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: kInk,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('drop_parabola_analogy_btn'),
                            onPressed: () =>
                                controller.setParabolaAnalogyVisible(false),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                            ),
                            child: const Text(
                              'Skip analogy',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: kTutorDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        GraphFrictionStrings.parabolaAnalogy.en,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                        ),
                      ),
                      if (showYo) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          GraphFrictionStrings.parabolaAnalogy.yo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kInk2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoeffPill({
    required Key key,
    required String coeff,
    required String label,
    required Color bgColor,
    required bool isSelected,
  }) {
    return GestureDetector(
      key: key,
      onTap: () => controller.selectCoefficient(coeff),
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        final delta = details.primaryDelta ?? 0.0;
        if (delta.abs() < 0.2) return;
        final current = coeff == 'a'
            ? controller.a
            : coeff == 'b'
                ? controller.b
                : controller.c;
        controller.dragCoefficient(coeff, current + (delta / 16.0));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? kInk : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        ),
      ),
    );
  }

  Widget _buildStepCircleButton({
    required Key key,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: kSand,
          shape: BoxShape.circle,
          border: Border.all(color: kControl),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkerReadoutChip({
    required Key key,
    required String text,
    required bool isRevealed,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRevealed ? const Color(0xFFEBF4FC) : const Color(0xEBFFFEFA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isRevealed ? kStudentBlue : kInk,
          width: 1.2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isRevealed ? kStudentBlue : kInk2,
        ),
      ),
    );
  }

  Widget _buildBilingualTermChip({
    required BilingualText term,
    required Color bgColor,
    required bool showYo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x24292927)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'EN: ${term.en} ▶',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          if (showYo)
            Text(
              'YO: ${term.yo}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kTutorDeep,
              ),
            ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering the Parabola curve, axes, dashed symmetry line,
/// hollow '?' root and vertex markers (or student royal-blue #1B56D0 markers
/// when found), tutor crimson overshoot circle, and pinned sticky note.
class ParabolaCanvasPainter extends CustomPainter {
  final double a;
  final double b;
  final double c;
  final bool rootsRevealed;
  final bool vertexRevealed;
  final bool showYoruba;

  const ParabolaCanvasPainter({
    required this.a,
    required this.b,
    required this.c,
    required this.rootsRevealed,
    required this.vertexRevealed,
    required this.showYoruba,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final originX = size.width * 0.44;
    final originY = size.height * 0.52;
    final scaleX = size.width / 12.5;

    final vx = -b / (2 * a);
    final vy = a * vx * vx + b * vx + c;
    final scaleY = math.min(
      18.0,
      math.max(9.0, (size.height * 0.36) / math.max(4.0, vy.abs() + 0.8)),
    );

    double toX(double x) => originX + x * scaleX;
    double toY(double y) => originY - y * scaleY;

    // 1. Axes
    final axisPaint = Paint()
      ..color = ParabolaGraphCard.kInk
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(12, originY),
      Offset(size.width - 14, originY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(originX, 10),
      Offset(originX, size.height - 14),
      axisPaint,
    );

    // Axis labels 'x' and 'y'
    _drawLabel(
      canvas,
      text: 'x',
      offset: Offset(size.width - 12, originY - 16),
      color: ParabolaGraphCard.kInk,
      fontSize: 13,
      italic: true,
    );
    _drawLabel(
      canvas,
      text: 'y',
      offset: Offset(originX + 6, 8),
      color: ParabolaGraphCard.kInk,
      fontSize: 13,
      italic: true,
    );

    // 2. Dashed Axis of Symmetry
    final vpx = toX(vx).clamp(24.0, size.width - 24.0);
    final vpy = toY(vy).clamp(20.0, size.height - 28.0);
    final symPaint = Paint()
      ..color = ParabolaGraphCard.kTutorCrimson.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (double y = 14; y < size.height - 20; y += 8) {
      canvas.drawLine(
        Offset(vpx, y),
        Offset(vpx, math.min(y + 4, size.height - 20)),
        symPaint,
      );
    }

    // 3. Parabola curve (Tutor Crimson #C31E49)
    final curvePaint = Paint()
      ..color = ParabolaGraphCard.kTutorCrimson
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool started = false;
    for (double x = -5.5; x <= 6.5; x += 0.12) {
      final y = a * x * x + b * x + c;
      final px = toX(x);
      final py = toY(y);
      if (py < 6 || py > size.height - 16 || px < 8 || px > size.width - 8) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(px, py);
        started = true;
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, curvePaint);

    // 4. Roots markers ('?' until revealed in student royal blue #1B56D0)
    final disc = b * b - 4 * a * c;
    if (disc >= 0) {
      final sqrtD = math.sqrt(disc);
      final r1 = (-b - sqrtD) / (2 * a);
      final r2 = (-b + sqrtD) / (2 * a);
      final lo = math.min(r1, r2);
      final hi = math.max(r1, r2);
      final roots = <double>[lo, hi];

      for (int i = 0; i < roots.length; i++) {
        final rx = toX(roots[i]);
        if (rx < 14 || rx > size.width - 14) continue;
        final center = Offset(rx, originY);

        // Tutor hand-drawn crimson circle around right root
        if (i == 1) {
          final circlePaint = Paint()
            ..color = ParabolaGraphCard.kTutorCrimson
            ..strokeWidth = 2.4
            ..style = PaintingStyle.stroke;
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 34, height: 28),
            circlePaint,
          );
        }

        _drawMarkerDot(
          canvas,
          center: center,
          radius: 6.5,
          isRevealed: rootsRevealed,
          borderColor: rootsRevealed
              ? ParabolaGraphCard.kStudentBlue
              : ParabolaGraphCard.kInk,
        );

        final rootText =
            rootsRevealed ? '${ParabolaGraphCard.formatNumber(roots[i])} ✓' : '?';
        _drawLabel(
          canvas,
          text: rootText,
          offset: Offset(rx - (rootsRevealed ? 14 : 4), originY + 10),
          color: rootsRevealed
              ? ParabolaGraphCard.kStudentBlue
              : ParabolaGraphCard.kInk2,
          fontSize: 12.5,
        );
      }
    }

    // 5. Vertex marker ('vertex: ?' until revealed in student blue #1B56D0)
    final vertexCenter = Offset(vpx, vpy);
    _drawMarkerDot(
      canvas,
      center: vertexCenter,
      radius: 6.0,
      isRevealed: vertexRevealed,
      borderColor: ParabolaGraphCard.kStudentBlue,
    );

    final vertexLabel = vertexRevealed
        ? '(${ParabolaGraphCard.formatNumber(vx)}, ${ParabolaGraphCard.formatNumber(vy)}) ✓'
        : 'vertex: ?';
    _drawLabel(
      canvas,
      text: vertexLabel,
      offset: Offset(
        math.min(size.width - 110, vpx + 10),
        math.min(size.height - 42, vpy - 6),
      ),
      color: ParabolaGraphCard.kStudentBlue,
      fontSize: 12,
    );

    // 6. Pinned bilingual sticky note in top-right corner
    final stickyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 116, 8, 108, showYoruba ? 46 : 30),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      stickyRect,
      Paint()..color = ParabolaGraphCard.kSticky,
    );
    canvas.drawRRect(
      stickyRect,
      Paint()
        ..color = ParabolaGraphCard.kLine
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(size.width - 62, 13),
      2.6,
      Paint()..color = ParabolaGraphCard.kInk,
    );
    _drawLabel(
      canvas,
      text: 'roots ▶',
      offset: Offset(size.width - 108, 16),
      color: ParabolaGraphCard.kInk,
      fontSize: 11.5,
    );
    if (showYoruba) {
      _drawLabel(
        canvas,
        text: 'gbòngbò',
        offset: Offset(size.width - 108, 32),
        color: ParabolaGraphCard.kTutorDeep,
        fontSize: 11.5,
      );
    }
  }

  void _drawMarkerDot(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required bool isRevealed,
    required Color borderColor,
  }) {
    final fillPaint = Paint()
      ..color = isRevealed
          ? ParabolaGraphCard.kStudentBlue
          : ParabolaGraphCard.kNotebookSheet
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);
  }

  void _drawLabel(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required Color color,
    required double fontSize,
    bool italic = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant ParabolaCanvasPainter oldDelegate) {
    return oldDelegate.a != a ||
        oldDelegate.b != b ||
        oldDelegate.c != c ||
        oldDelegate.rootsRevealed != rootsRevealed ||
        oldDelegate.vertexRevealed != vertexRevealed ||
        oldDelegate.showYoruba != showYoruba;
  }
}
