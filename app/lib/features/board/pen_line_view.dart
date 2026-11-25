import 'package:flutter/material.dart';

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
    this.blankBuilder,
    this.pen = const HandwritingPen(),
  });

  final String text;
  final Color color;
  final double rule;
  final List<PenMarkKind> marks;
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
                      child: PenInk(layout: layout, color: widget.color),
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
