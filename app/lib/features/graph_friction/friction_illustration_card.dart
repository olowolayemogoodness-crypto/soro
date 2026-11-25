import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'canvas_bridge.dart';
import 'graph_friction_strings.dart';
import 'parabola_graph_card.dart';
import 'phet_iframe_view.dart';

/// Friction Physics Illustration Card:
/// - Embeds PhET "Forces and Motion: Basics" (Friction section) in an iframe/WebView
///   using the verified Yoruba HTML5 build (`forces-and-motion-basics_yo.html?screens=3`)
///   or English build (`forces-and-motion-basics_en.html?screens=3`).
/// - Driven by `canvas_cmd` (tutor pushes crate, changes surface, asks why it slowed down).
/// - Student drags on the crate or force slider emit `student_action` throttled to 5/sec.
class FrictionIllustrationCard extends StatefulWidget {
  final CanvasBridgeController controller;

  const FrictionIllustrationCard({
    super.key,
    required this.controller,
  });

  @override
  State<FrictionIllustrationCard> createState() =>
      _FrictionIllustrationCardState();
}

class _FrictionIllustrationCardState extends State<FrictionIllustrationCard> {
  // View modes: 'split' (both interactive canvas + PhET iframe), 'canvas', 'iframe'
  String _viewMode = 'split';

  CanvasBridgeController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final showYo = controller.showYoruba;
        final surface = controller.surface;
        final phetUrl = controller.useYorubaPhetBuild
            ? GraphFrictionStrings.phetYorubaUrl
            : GraphFrictionStrings.phetEnglishUrl;

        return Container(
          key: const Key('friction_illustration_card'),
          decoration: BoxDecoration(
            color: ParabolaGraphCard.kPaper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ParabolaGraphCard.kLine, width: 1.5),
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
              // Top badge row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0BE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PHYSICS ILLUSTRATION · FRICTION (AFTER MATHS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: ParabolaGraphCard.kInk,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ParabolaGraphCard.kMint,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF1D7A48)),
                    ),
                    child: Text(
                      controller.useYorubaPhetBuild
                          ? '✓ PhET Yorùbá build active (_yo.html)'
                          : 'PhET English build active (_en.html)',
                      key: const Key('phet_build_badge'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ParabolaGraphCard.kInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                GraphFrictionStrings.frictionHeader.en,
                style: const TextStyle(
                  fontFamily: 'Source Serif 4',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ParabolaGraphCard.kInk,
                  height: 1.25,
                ),
              ),
              if (showYo) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  GraphFrictionStrings.frictionHeader.yo,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ParabolaGraphCard.kTutorDeep,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Tutor Question Prompt for Friction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParabolaGraphCard.kCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ParabolaGraphCard.kLine),
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
                            color: ParabolaGraphCard.kTutorCrimson,
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
                        const Expanded(
                          child: Text(
                            'One guiding question · Never gives the answer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ParabolaGraphCard.kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.askingWhySlowed
                          ? GraphFrictionStrings.frictionTutorAskWhyPrompt.en
                          : GraphFrictionStrings.frictionTutorPushPrompt.en,
                      key: const Key('friction_tutor_prompt_en'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ParabolaGraphCard.kInk,
                      ),
                    ),
                    if (showYo) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        controller.askingWhySlowed
                            ? GraphFrictionStrings.frictionTutorAskWhyPrompt.yo
                            : GraphFrictionStrings.frictionTutorPushPrompt.yo,
                        key: const Key('friction_tutor_prompt_yo'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ParabolaGraphCard.kInk2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tutor `canvas_cmd` Driver Controls (simulates incoming tutor commands)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParabolaGraphCard.kSand,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParabolaGraphCard.kLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        const Text(
                          'Tutor canvas_cmd driver:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ParabolaGraphCard.kInk,
                          ),
                        ),
                        Text(
                          'Sim moves: ${controller.simMoveCount}',
                          key: const Key('friction_sim_move_count'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ParabolaGraphCard.kTutorDeep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _buildCmdButton(
                          key: const Key('cmd_push_crate'),
                          label: '▶ Push crate (180 N)',
                          isPrimary: true,
                          onTap: () => controller.handleCanvasCmd(
                            <String, dynamic>{
                              'cmd': 'push_crate',
                              'target': 'friction',
                              'force_n': 180.0,
                            },
                          ),
                        ),
                        _buildCmdButton(
                          key: const Key('cmd_surface_wet'),
                          label: 'Surface: Wet Road (μ=0.22)',
                          onTap: () => controller.handleCanvasCmd(
                            <String, dynamic>{
                              'cmd': 'set_surface',
                              'target': 'friction',
                              'surface': 'wet_road',
                              'force_n': 160.0,
                            },
                          ),
                        ),
                        _buildCmdButton(
                          key: const Key('cmd_surface_rough'),
                          label: 'Surface: Rough Gravel (μ=0.72)',
                          onTap: () => controller.handleCanvasCmd(
                            <String, dynamic>{
                              'cmd': 'set_surface',
                              'target': 'friction',
                              'surface': 'gravel',
                              'force_n': 160.0,
                            },
                          ),
                        ),
                        _buildCmdButton(
                          key: const Key('cmd_surface_ice'),
                          label: 'Surface: Ice (μ=0.08)',
                          onTap: () => controller.handleCanvasCmd(
                            <String, dynamic>{
                              'cmd': 'set_surface',
                              'target': 'friction',
                              'surface': 'ice',
                              'force_n': 140.0,
                            },
                          ),
                        ),
                        _buildCmdButton(
                          key: const Key('cmd_ask_why'),
                          label: '? Ask why it slowed down',
                          onTap: () => controller.handleCanvasCmd(
                            <String, dynamic>{
                              'cmd': 'ask_why_slowed',
                              'target': 'friction',
                            },
                          ),
                        ),
                        _buildCmdButton(
                          key: const Key('cmd_reset_friction'),
                          label: '↻ Reset sim',
                          onTap: () => controller.handleCanvasCmd(
                            <String, dynamic>{
                              'cmd': 'reset_friction',
                              'target': 'friction',
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Interactive Soro Friction Physics Canvas (responds to canvas_cmd & student drags)
              if (_viewMode == 'split' || _viewMode == 'canvas') ...<Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: ParabolaGraphCard.kNotebookSheet,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ParabolaGraphCard.kWoodBorder,
                      width: 3.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'Surface: ${surface.labelEn}${showYo ? ' · ${surface.labelYo}' : ''} (μ = ${surface.mu.toStringAsFixed(2)})',
                            key: const Key('friction_surface_readout'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ParabolaGraphCard.kInk,
                            ),
                          ),
                          Text(
                            'Crate pos: ${controller.cratePositionM.toStringAsFixed(2)} m · Friction: ${controller.frictionForceN.toStringAsFixed(0)} N',
                            key: const Key('friction_position_readout'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: ParabolaGraphCard.kStudentBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        key: const Key('friction_crate_drag_area'),
                        onHorizontalDragUpdate: (DragUpdateDetails details) {
                          final dx = details.primaryDelta ?? 0.0;
                          if (dx.abs() < 0.1) return;
                          controller.studentDragFriction(
                            positionDeltaM: dx / 36.0,
                          );
                        },
                        onHorizontalDragEnd: (_) {
                          controller.releasePushAndCoast();
                        },
                        child: SizedBox(
                          height: 158,
                          width: double.infinity,
                          child: CustomPaint(
                            key: const Key('friction_custom_paint'),
                            painter: FrictionSimPainter(
                              surface: surface,
                              cratePositionM: controller.cratePositionM,
                              appliedForceN: controller.appliedForceN,
                              frictionForceN: controller.frictionForceN,
                              crateDidSlowDown: controller.crateDidSlowDown,
                              showYoruba: showYo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Student Push Force Slider (throttled to <= 5 student_action / sec)
                      Row(
                        children: <Widget>[
                          const Text(
                            'Student push:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ParabolaGraphCard.kStudentBlue,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: ParabolaGraphCard.kStudentBlue,
                                inactiveTrackColor: ParabolaGraphCard.kLine,
                                thumbColor: ParabolaGraphCard.kStudentBlue,
                              ),
                              child: Slider(
                                key: const Key('student_force_slider'),
                                min: -250.0,
                                max: 250.0,
                                value: controller.appliedForceN.clamp(
                                  -250.0,
                                  250.0,
                                ),
                                onChanged: (double val) {
                                  controller.studentDragFriction(forceN: val);
                                },
                                onChangeEnd: (_) {
                                  controller.releasePushAndCoast();
                                },
                              ),
                            ),
                          ),
                          Text(
                            '${controller.appliedForceN.toStringAsFixed(0)} N',
                            key: const Key('applied_force_label'),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ParabolaGraphCard.kInk,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // PhET HTML5 WebView / Iframe header & locale toggle
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Text(
                    'PhET WebView / Iframe (Forces & Motion: Basics · Friction)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ParabolaGraphCard.kInk,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      InkWell(
                        key: const Key('toggle_phet_locale_btn'),
                        onTap: () => controller.setPhetLocale(
                          yoruba: !controller.useYorubaPhetBuild,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ParabolaGraphCard.kSky,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: ParabolaGraphCard.kControl,
                            ),
                          ),
                          child: Text(
                            controller.useYorubaPhetBuild
                                ? 'Locale: Yorùbá (_yo.html) ▾'
                                : 'Locale: English (_en.html) ▾',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: ParabolaGraphCard.kInk,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        key: const Key('toggle_friction_view_mode_btn'),
                        onTap: () {
                          setState(() {
                            _viewMode = _viewMode == 'split'
                                ? 'iframe'
                                : _viewMode == 'iframe'
                                    ? 'canvas'
                                    : 'split';
                          });
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ParabolaGraphCard.kPaper,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: ParabolaGraphCard.kControl,
                            ),
                          ),
                          child: Text(
                            'View: $_viewMode',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: ParabolaGraphCard.kInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              if (_viewMode == 'split' || _viewMode == 'iframe')
                buildPlatformPhetIframe(
                  url: phetUrl,
                  lastCmd: controller.lastCanvasCmd,
                  height: _viewMode == 'iframe' ? 300 : 185,
                ),

              // Everyday Nigerian Analogy Card (Handoff Note #5: danfo on a wet Lagos road)
              if (controller.showFrictionAnalogy) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  key: const Key('friction_analogy_card'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0BE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ParabolaGraphCard.kLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.directions_bus_outlined,
                            size: 16,
                            color: ParabolaGraphCard.kInk,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Local Analogy · Danfo on a Wet Road',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: ParabolaGraphCard.kInk,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('drop_friction_analogy_btn'),
                            onPressed: () =>
                                controller.setFrictionAnalogyVisible(false),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                            ),
                            child: const Text(
                              'Drop analogy',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: ParabolaGraphCard.kTutorDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        GraphFrictionStrings.frictionAnalogyDanfo.en,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ParabolaGraphCard.kInk,
                        ),
                      ),
                      if (showYo) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          GraphFrictionStrings.frictionAnalogyDanfo.yo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ParabolaGraphCard.kInk2,
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

  Widget _buildCmdButton({
    required Key key,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? ParabolaGraphCard.kTutorCrimson
              : ParabolaGraphCard.kPaper,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPrimary
                ? ParabolaGraphCard.kTutorCrimson
                : ParabolaGraphCard.kControl,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isPrimary ? Colors.white : ParabolaGraphCard.kInk,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for the interactive Friction Physics stage.
class FrictionSimPainter extends CustomPainter {
  final FrictionSurface surface;
  final double cratePositionM;
  final double appliedForceN;
  final double frictionForceN;
  final bool crateDidSlowDown;
  final bool showYoruba;

  const FrictionSimPainter({
    required this.surface,
    required this.cratePositionM,
    required this.appliedForceN,
    required this.frictionForceN,
    required this.crateDidSlowDown,
    required this.showYoruba,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.72;

    // 1. Sky / warm study table backdrop
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFFBF8EE),
    );

    // 2. Ground surface band styled by friction coefficient
    Color groundColor;
    switch (surface) {
      case FrictionSurface.ice:
        groundColor = const Color(0xFFD2E8F8);
        break;
      case FrictionSurface.wetRoad:
        groundColor = const Color(0xFFB8C7D6);
        break;
      case FrictionSurface.wood:
        groundColor = const Color(0xFFD6B588);
        break;
      case FrictionSurface.gravel:
        groundColor = const Color(0xFF9C9284);
        break;
    }

    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = groundColor,
    );
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = ParabolaGraphCard.kInk
        ..strokeWidth = 2.2,
    );

    // Surface roughness texture ticks
    final step = surface == FrictionSurface.ice
        ? 38.0
        : surface == FrictionSurface.wetRoad
            ? 24.0
            : surface == FrictionSurface.wood
                ? 14.0
                : 8.0;
    final tickPaint = Paint()
      ..color = ParabolaGraphCard.kInk.withValues(alpha: 0.35)
      ..strokeWidth = surface == FrictionSurface.gravel ? 2.2 : 1.3;
    for (double x = 10; x < size.width - 10; x += step) {
      canvas.drawLine(
        Offset(x, groundY + 2),
        Offset(x - 4, groundY + 9),
        tickPaint,
      );
    }

    // Distance ruler ticks (0m .. 10m)
    for (int m = 1; m <= 9; m += 2) {
      final mx = (m / 10.0) * (size.width - 40) + 20;
      canvas.drawLine(
        Offset(mx, groundY),
        Offset(mx, groundY + 6),
        Paint()
          ..color = ParabolaGraphCard.kInk
          ..strokeWidth = 1.4,
      );
      _drawText(
        canvas,
        text: '${m}m',
        offset: Offset(mx - 8, groundY + 10),
        color: ParabolaGraphCard.kInk,
        fontSize: 10.5,
      );
    }

    // 3. Wooden Crate at cratePositionM (0..10m)
    final crateW = 64.0;
    final crateH = 54.0;
    final normX = (cratePositionM.clamp(0.4, 9.6) / 10.0);
    final crateCenterX = 28 + normX * (size.width - 56);
    final crateRect = Rect.fromLTWH(
      crateCenterX - crateW / 2,
      groundY - crateH,
      crateW,
      crateH,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(crateRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFFE6B16A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(crateRect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0xFF593314)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    // Crate cross braces
    canvas.drawLine(
      crateRect.topLeft + const Offset(6, 6),
      crateRect.bottomRight - const Offset(6, 6),
      Paint()
        ..color = const Color(0x55593314)
        ..strokeWidth = 1.6,
    );
    _drawText(
      canvas,
      text: '50 kg',
      offset: Offset(crateCenterX - 16, groundY - crateH / 2 - 7),
      color: ParabolaGraphCard.kInk,
      fontSize: 12,
    );

    // 4. Applied Push Force Arrow (Crimson/Blue)
    if (appliedForceN.abs() > 1.0) {
      final dir = appliedForceN.sign;
      final len = (appliedForceN.abs() / 250.0).clamp(0.18, 1.0) * 78.0;
      final start = Offset(
        crateCenterX + dir * (crateW / 2 + 4),
        groundY - crateH * 0.55,
      );
      final end = Offset(start.dx + dir * len, start.dy);
      _drawForceArrow(
        canvas,
        start: start,
        end: end,
        color: ParabolaGraphCard.kStudentBlue,
        label: 'Push ${appliedForceN.abs().toStringAsFixed(0)} N',
      );
    }

    // 5. Opposing Friction Force Arrow (Logo Orange #F38F1D)
    final activeFriction = frictionForceN > 1.0
        ? frictionForceN
        : (crateDidSlowDown ? surface.mu * 50 * 9.8 : 0.0);
    if (activeFriction > 1.0) {
      final pushSign = appliedForceN != 0 ? appliedForceN.sign : 1.0;
      final oppDir = -pushSign;
      final len = (activeFriction / 360.0).clamp(0.2, 1.0) * 74.0;
      final start = Offset(
        crateCenterX + oppDir * (crateW / 2 + 4),
        groundY - 14,
      );
      final end = Offset(start.dx + oppDir * len, start.dy);
      _drawForceArrow(
        canvas,
        start: start,
        end: end,
        color: ParabolaGraphCard.kLogoOrange,
        label: showYoruba
            ? 'Friction / Ipá ìfaraṣẹ́ (${activeFriction.toStringAsFixed(0)} N)'
            : 'Friction (${activeFriction.toStringAsFixed(0)} N)',
      );
    }

    // 6. Question-mark conceptual callout (never leaks the answer)
    if (crateDidSlowDown) {
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 10, math.min(248, size.width - 24), 26),
        const Radius.circular(13),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()..color = ParabolaGraphCard.kSticky,
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = ParabolaGraphCard.kInk
          ..style = PaintingStyle.stroke,
      );
      _drawText(
        canvas,
        text: '? Why did the crate slow down on this surface?',
        offset: const Offset(20, 16),
        color: ParabolaGraphCard.kInk,
        fontSize: 11,
      );
    }
  }

  void _drawForceArrow(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required Color color,
    required String label,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);

    final dir = (end.dx - start.dx).sign;
    final head1 = Offset(end.dx - dir * 8, end.dy - 5);
    final head2 = Offset(end.dx - dir * 8, end.dy + 5);
    canvas.drawLine(end, head1, paint);
    canvas.drawLine(end, head2, paint);

    final labelX = math.max(8.0, math.min(start.dx, end.dx) - 4);
    _drawText(
      canvas,
      text: label,
      offset: Offset(labelX, end.dy - 18),
      color: color == ParabolaGraphCard.kLogoOrange
          ? ParabolaGraphCard.kTutorDeep
          : color,
      fontSize: 11,
    );
  }

  void _drawText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required Color color,
    required double fontSize,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant FrictionSimPainter oldDelegate) {
    return oldDelegate.surface != surface ||
        oldDelegate.cratePositionM != cratePositionM ||
        oldDelegate.appliedForceN != appliedForceN ||
        oldDelegate.frictionForceN != frictionForceN ||
        oldDelegate.crateDidSlowDown != crateDidSlowDown ||
        oldDelegate.showYoruba != showYoruba;
  }
}
