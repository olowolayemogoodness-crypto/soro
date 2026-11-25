import 'package:flutter/material.dart';
import 'canvas_bridge.dart';
import 'friction_illustration_card.dart';
import 'graph_friction_strings.dart';
import 'parabola_graph_card.dart';

export 'canvas_bridge.dart';
export 'friction_illustration_card.dart';
export 'graph_friction_strings.dart';
export 'parabola_graph_card.dart';

/// Route path constant for the A4 Graph & Friction screen.
const String kGraphFrictionRoute = '/graph-friction';

/// Public widget for task A4:
/// - Supporting parabola with draggable a, b, and c where roots and vertex stay
///   as '?' markers until the student finds them (then shown in royal blue #1B56D0).
/// - Friction illustration: PhET Forces and Motion: Basics (friction section)
///   with verified Yoruba HTML5 build, driven by `canvas_cmd`.
/// - Throttles outgoing `student_action` events to at most 5 per second.
class GraphFrictionScreen extends StatefulWidget {
  static const String routePath = kGraphFrictionRoute;

  final CanvasBridgeController? controller;
  final void Function(StudentAction action)? onStudentAction;

  const GraphFrictionScreen({
    super.key,
    this.controller,
    this.onStudentAction,
  });

  @override
  State<GraphFrictionScreen> createState() => _GraphFrictionScreenState();
}

class _GraphFrictionScreenState extends State<GraphFrictionScreen> {
  late CanvasBridgeController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = CanvasBridgeController(
        onStudentAction: widget.onStudentAction,
      );
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(covariant GraphFrictionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller!;
      _ownsController = false;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? _) {
        final showYo = _controller.showYoruba;
        final lastAction = _controller.lastStudentAction;
        final lastCmd = _controller.lastCanvasCmd;

        return Scaffold(
          backgroundColor: ParabolaGraphCard.kCream,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(62),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xEBFAF5E6),
                border: Border(
                  bottom: BorderSide(color: ParabolaGraphCard.kLine),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      // Soro brand pill
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: ParabolaGraphCard.kTutorCrimson,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'S',
                          style: TextStyle(
                            fontFamily: 'Source Serif 4',
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'Sọ̀rọ̀ · ${GraphFrictionStrings.screenTitle.en}',
                              style: const TextStyle(
                                fontFamily: 'Source Serif 4',
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: ParabolaGraphCard.kInk,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (showYo)
                              Text(
                                GraphFrictionStrings.screenTitle.yo,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ParabolaGraphCard.kInk2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Language Slot Selector (English + Yoruba)
                      InkWell(
                        key: const Key('lang_slot_toggle_btn'),
                        onTap: _controller.toggleLanguageSlot,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ParabolaGraphCard.kPaper,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: ParabolaGraphCard.kControl,
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1D7A48),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                showYo ? 'EN + Yorùbá ▾' : 'EN only ▾',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: ParabolaGraphCard.kInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final isWideTablet = constraints.maxWidth >= 900;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideTablet ? 24 : 14,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Live Canvas Bridge Status Bar (`canvas_cmd` & 5/s `student_action` throttle)
                          Container(
                            key: const Key('canvas_bridge_status_bar'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ParabolaGraphCard.kPaper,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ParabolaGraphCard.kLine),
                            ),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 6,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ParabolaGraphCard.kMint,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Bridge: ≤ 5 student_action/s',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: ParabolaGraphCard.kInk,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Sent: ${_controller.emittedActions.length} · Throttled: ${_controller.throttledDropCount}',
                                      key: const Key('bridge_action_counts'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ParabolaGraphCard.kInk2,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  lastCmd != null
                                      ? 'Last canvas_cmd: ${lastCmd.cmd} (${lastCmd.target})'
                                      : lastAction != null
                                          ? 'Last student_action: ${lastAction.action} (${lastAction.target})'
                                          : 'Ready: drag b on the parabola or push the crate',
                                  key: const Key('bridge_last_event_text'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ParabolaGraphCard.kInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Responsive Tablet (2-column 1280x800) vs Phone (stacked 390x844)
                          if (isWideTablet)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 10,
                                  child: ParabolaGraphCard(
                                    controller: _controller,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 11,
                                  child: FrictionIllustrationCard(
                                    controller: _controller,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                ParabolaGraphCard(
                                  controller: _controller,
                                ),
                                const SizedBox(height: 16),
                                FrictionIllustrationCard(
                                  controller: _controller,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
