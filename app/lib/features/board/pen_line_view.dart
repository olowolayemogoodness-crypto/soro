import 'package:flutter/material.dart';

import 'pen_timing.dart';
import 'tutor_pen_writer.dart';

/// One line of tutor handwriting on the notebook page: written stroke by
/// stroke, then any hand-drawn marks. Blank boxes drawn by the pen can host
/// real text fields through [blankBuilder].
class PenLineView extends StatefulWidget {
  const PenLineView({
    super.key,
    required this.text,
    required this.color,
    required this.rule,
    this.marks = const <PenMarkKind>[],
    this.audioMs,
    this.spoken = true,
    this.onStart,
    this.blankBuilder,
    this.pen = const HandwritingPen(),
  });

  final String text;
  final Color color;
  final double rule;
  final List<PenMarkKind> marks;

  /// Real length of the spoken audio for this line, when known.
  final int? audioMs;

  /// False for working lines the tutor writes without saying them.
  final bool spoken;

  /// Called the moment the pen touches down: start audio and caption here so
  /// the voice and the writing begin together.
  final VoidCallback? onStart;
  final Widget Function(int index, Rect rect)? blankBuilder;
  final TutorPenWriter pen;

  @override
  State<PenLineView> createState() => _PenLineViewState();
}

class _PenLineViewState extends State<PenLineView> {
  PenLayout? _layout;
  double _width = -1;
  final Map<PenMarkKind, PenLayout> _markLayouts = <PenMarkKind, PenLayout>{};

  PenLayout _layoutFor(double width) {
    if (_layout == null || (width - _width).abs() > 0.5) {
      _width = width;
      _layout = widget.pen.writeText(
        widget.text,
        maxWidth: width,
        rule: widget.rule,
        duration: penDurationFor(
          widget.text,
          audioMs: widget.audioMs,
          spoken: widget.spoken,
        ),
      );
      _markLayouts.clear();
    }
    return _layout!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final PenLayout layout = _layoutFor(c.maxWidth);
        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: SizedBox(
              width: c.maxWidth,
              height: layout.size.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: PenInk(
                        layout: layout,
                        color: widget.color,
                        onStart: widget.onStart,
                      ),
                    ),
                  ),
                  for (final PenMarkKind kind in widget.marks)
                    Positioned.fill(
                      key: ValueKey<PenMarkKind>(kind),
                      child: IgnorePointer(
                        child: PenInk(
                          layout: _markLayouts.putIfAbsent(
                            kind,
                            () => widget.pen.writeMark(kind, layout),
                          ),
                          color: widget.color,
                        ),
                      ),
                    ),
                  if (widget.blankBuilder != null)
                    for (int i = 0; i < layout.blanks.length; i++)
                      Positioned.fromRect(
                        rect: layout.blanks[i],
                        child: widget.blankBuilder!(i, layout.blanks[i]),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
