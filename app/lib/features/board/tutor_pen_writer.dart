import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pen_font.dart';

/// Hand-drawn marks the tutor can add after writing a line.
enum PenMarkKind { circleRoots, underline, tick }

/// One pen stroke: a dense polyline plus when (as a 0..1 fraction of the
/// layout's timeline) the pen starts and finishes it.
class PenStroke {
  PenStroke(this.points, {this.widthScale = 1.0})
    : cumulative = _cumulative(points);

  final List<Offset> points;
  final List<double> cumulative;
  final double widthScale;
  double t0 = 0;
  double t1 = 0;

  double get length => cumulative.last;

  static List<double> _cumulative(List<Offset> pts) {
    final List<double> out = <double>[0];
    for (int i = 1; i < pts.length; i++) {
      out.add(out.last + (pts[i] - pts[i - 1]).distance);
    }
    return out;
  }
}

/// A typeset line (or mark) of tutor handwriting, ready to be animated.
class PenLayout {
  PenLayout({
    required this.strokes,
    required this.size,
    required this.seconds,
    required this.rule,
    this.blanks = const <Rect>[],
    this.clusterRects = const <Rect>[],
    this.clusterChars = const <String>[],
    this.rows = 1,
  });

  final List<PenStroke> strokes;
  final Size size;

  /// How long the pen takes to write this layout, in seconds.
  final double seconds;
  final double rule;
  final int rows;

  /// Hand-drawn blank boxes (`▢`) in layout coordinates, in reading order.
  final List<Rect> blanks;
  final List<Rect> clusterRects;
  final List<String> clusterChars;
}

/// Anything that can put tutor ink on the page. The scripted tutor drives it
/// today; a live worker's `write_step` messages can drive the same calls.
abstract interface class TutorPenWriter {
  /// Lays out [text] as handwriting on ruled rows [rule] pixels tall, spread
  /// over [duration] so the pen finishes exactly when the voice (or the
  /// planned time) does.
  PenLayout writeText(
    String text, {
    required double maxWidth,
    required double rule,
    required Duration duration,
  });

  /// Lays out a hand-drawn [kind] mark for an already written [line].
  PenLayout writeMark(PenMarkKind kind, PenLayout line);
}

/// Default pen: single-line stroke font with a natural hand - gentle slant,
/// baseline wobble, size and spacing jitter, pressure-shaped width.
class HandwritingPen implements TutorPenWriter {
  const HandwritingPen({this.slantDegrees = 8});

  final double slantDegrees;

  static const double _blankUnits = 20;

  @override
  PenLayout writeText(
    String text, {
    required double maxWidth,
    required double rule,
    required Duration duration,
  }) {
    final double s = rule / 17;
    final double slant = math.tan(slantDegrees * math.pi / 180);
    final math.Random rnd = math.Random(text.hashCode);
    final List<PenCluster> clusters = PenFont.clusters(text);

    double unitsOf(PenCluster c) {
      if (c.base == ' ') return 4.6;
      if (c.base == '▢') return _blankUnits;
      if (c.base == '²' || c.base == '³') return 3.2;
      if (c.base == '✓') return 7;
      return PenFont.glyph(c.base)?.width ?? 4;
    }

    // Break into words so lines wrap on the page like a person would write.
    final List<List<int>> words = <List<int>>[];
    List<int> current = <int>[];
    for (int i = 0; i < clusters.length; i++) {
      if (clusters[i].base == ' ') {
        if (current.isNotEmpty) words.add(current);
        current = <int>[];
      } else {
        current.add(i);
      }
    }
    if (current.isNotEmpty) words.add(current);

    final List<PenStroke> strokes = <PenStroke>[];
    final List<bool> wordStart = <bool>[];
    final List<Rect> blanks = <Rect>[];
    final List<Rect> rects = List<Rect>.filled(clusters.length, Rect.zero);
    double x = 0;
    int row = 0;
    double usedWidth = 0;
    final double gap = 1.5 * s;
    final double space = 4.6 * s;
    final double phase = rnd.nextDouble() * 6;

    for (final List<int> word in words) {
      double wordW = 0;
      for (final int i in word) {
        wordW += unitsOf(clusters[i]) * s + gap;
      }
      if (x > 0 && x + wordW > maxWidth) {
        row++;
        x = 0;
      }
      bool first = true;
      for (final int i in word) {
        final PenCluster c = clusters[i];
        final double w = unitsOf(c) * s;
        final double scaleC = 1 + (rnd.nextDouble() - 0.5) * 0.12;
        final double dy = (rnd.nextDouble() - 0.5) * 1.1;
        final double wob = math.sin((x * 0.012) + phase + row) * 0.9;
        final double baseline = row * rule + rule - 3.0 * s - 2 + wob + dy;
        final double top = baseline - 10 * s;
        rects[i] = Rect.fromLTWH(x, row * rule, w, rule);

        Offset map(Offset g, {double scale = 1, double ox = 0, double oy = 0}) {
          return Offset(
            x + (g.dx * scale + ox) * s * scaleC + g.dy * s * slant,
            baseline - (g.dy * scale + oy) * s * scaleC,
          );
        }

        void addStroke(
          List<Offset> pts, {
          bool smooth = true,
          double width = 1,
        }) {
          final PenStroke st = PenStroke(
            smooth ? _smooth(pts) : _densify(pts),
            widthScale: width,
          );
          strokes.add(st);
          wordStart.add(first);
          first = false;
        }

        if (c.base == '▢') {
          final Rect box = Rect.fromLTRB(
            x,
            top + 2.5 * s,
            x + w,
            baseline + 1.5 * s,
          );
          blanks.add(box);
          addStroke(_boxPoints(box, rnd), smooth: false);
        } else if (c.base == '²' || c.base == '³') {
          final PenGlyph? g = PenFont.glyph(c.base == '²' ? '2' : '3');
          if (g != null) {
            for (final List<Offset> st in g.strokes) {
              addStroke(
                st.map((Offset p) => map(p, scale: 0.55, oy: 5.6)).toList(),
                width: 0.85,
              );
            }
          }
        } else if (c.base == '✓') {
          addStroke(
            <Offset>[
              map(const Offset(0, 5)),
              map(const Offset(2, 1.5)),
              map(const Offset(6.8, 10)),
            ],
            smooth: false,
            width: 1.15,
          );
        } else {
          final PenGlyph? g = PenFont.glyph(c.base);
          if (g != null) {
            for (final List<Offset> st in g.strokes) {
              addStroke(st.map((Offset p) => map(p)).toList());
            }
            final bool tall =
                'bdfhklt'.contains(c.base) ||
                c.base.toUpperCase() == c.base &&
                    c.base != c.base.toLowerCase();
            for (final String m in c.marks) {
              final double markTop = tall ? 10.0 : 6.0;
              for (final List<Offset> ms in PenFont.markStrokes(
                m,
                g.width,
                markTop,
                0,
              )) {
                addStroke(
                  ms.map((Offset p) => map(p)).toList(),
                  smooth: false,
                  width: 1.1,
                );
              }
            }
          }
        }
        x += w + gap;
        usedWidth = math.max(usedWidth, x);
      }
      x += space - gap;
    }

    // Timeline: each stroke costs its length plus a pen-lift, words a pause.
    final double seconds = duration.inMilliseconds / 1000.0;
    double totalCost = 0;
    final List<double> costs = <double>[];
    for (int i = 0; i < strokes.length; i++) {
      final double cost = strokes[i].length + 7 + (wordStart[i] ? 14 : 0);
      costs.add(cost);
      totalCost += cost;
    }
    double acc = 0;
    for (int i = 0; i < strokes.length; i++) {
      final double pause = wordStart[i] ? 14 : 0;
      strokes[i].t0 = (acc + pause) / totalCost;
      acc += costs[i];
      strokes[i].t1 = acc / totalCost;
    }

    return PenLayout(
      strokes: strokes,
      size: Size(math.max(usedWidth, 1), (row + 1) * rule),
      seconds: seconds,
      rule: rule,
      blanks: blanks,
      clusterRects: rects,
      clusterChars: clusters.map((PenCluster c) => c.base).toList(),
      rows: row + 1,
    );
  }

  @override
  PenLayout writeMark(PenMarkKind kind, PenLayout line) {
    final math.Random rnd = math.Random(kind.index * 31 + line.strokes.length);
    final double rule = line.rule;
    final List<PenStroke> strokes = <PenStroke>[];
    final List<Rect> rects = line.clusterRects;
    final List<String> chars = line.clusterChars;
    int lastInk = -1;
    int firstInkOfLastRow = -1;
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] == ' ') continue;
      lastInk = i;
    }
    if (lastInk < 0) {
      return PenLayout(
        strokes: strokes,
        size: line.size,
        seconds: 0.1,
        rule: rule,
      );
    }
    for (int i = 0; i < chars.length; i++) {
      if (chars[i] != ' ' && rects[i].top == rects[lastInk].top) {
        firstInkOfLastRow = i;
        break;
      }
    }

    switch (kind) {
      case PenMarkKind.circleRoots:
        final List<int> digits = <int>[
          for (int i = 0; i < chars.length; i++)
            if (RegExp(r'[0-9]').hasMatch(chars[i])) i,
        ];
        for (final int i in digits.reversed.take(2)) {
          final Rect r = rects[i];
          strokes.add(
            PenStroke(
              _loop(
                Offset(r.center.dx, r.top + rule * 0.52),
                rx: r.width / 2 + 7,
                ry: rule * 0.42,
                rnd: rnd,
              ),
              widthScale: 1.1,
            ),
          );
        }
      case PenMarkKind.underline:
        final double y = rects[lastInk].top + rule - 2;
        final double x0 = rects[firstInkOfLastRow].left;
        final double x1 = rects[lastInk].right;
        strokes.add(
          PenStroke(
            _wavyLine(Offset(x0, y), Offset(x1, y - 1), rnd),
            widthScale: 1.05,
          ),
        );
        strokes.add(
          PenStroke(
            _wavyLine(
              Offset(x0 + (x1 - x0) * 0.08, y + 3),
              Offset(x1 - (x1 - x0) * 0.1, y + 2),
              rnd,
            ),
            widthScale: 0.9,
          ),
        );
      case PenMarkKind.tick:
        final Rect r = rects[lastInk];
        final double x = r.right + 14;
        final double top = r.top + rule * 0.12;
        strokes.add(
          PenStroke(
            _densify(<Offset>[
              Offset(x, top + rule * 0.5),
              Offset(x + 7, top + rule * 0.78),
              Offset(x + 26, top - rule * 0.02),
            ]),
            widthScale: 1.5,
          ),
        );
    }

    double total = 0;
    for (final PenStroke st in strokes) {
      total += st.length + 8;
    }
    double acc = 0;
    for (final PenStroke st in strokes) {
      st.t0 = acc / math.max(total, 1);
      acc += st.length + 8;
      st.t1 = acc / math.max(total, 1);
    }
    return PenLayout(
      strokes: strokes,
      size: line.size,
      seconds: 0.55,
      rule: rule,
    );
  }

  static List<Offset> _boxPoints(Rect b, math.Random rnd) {
    double j() => (rnd.nextDouble() - 0.5) * 1.6;
    final List<Offset> pts = <Offset>[
      Offset(b.left + j(), b.bottom + j()),
      Offset(b.left - 1 + j(), b.top + 3),
      Offset(b.left + 1, b.top + j()),
      Offset(b.right + j(), b.top - 0.5 + j()),
      Offset(b.right + 1 + j(), b.top + 3),
      Offset(b.right + j(), b.bottom + 1 + j()),
      Offset(b.left + 3, b.bottom + j()),
      Offset(b.left + 1, b.bottom - 4),
    ];
    return _densify(pts);
  }

  static List<Offset> _loop(
    Offset c, {
    required double rx,
    required double ry,
    required math.Random rnd,
  }) {
    final List<Offset> pts = <Offset>[];
    final double start = -2.3 + (rnd.nextDouble() - 0.5) * 0.4;
    const int n = 34;
    for (int i = 0; i <= n; i++) {
      final double a = start + (i / n) * math.pi * 2.2;
      final double wob = 1 + math.sin(a * 2 + 1) * 0.05 + (i / n) * 0.07;
      pts.add(
        Offset(c.dx + math.cos(a) * rx * wob, c.dy + math.sin(a) * ry * wob),
      );
    }
    return pts;
  }

  static List<Offset> _wavyLine(Offset a, Offset b, math.Random rnd) {
    final List<Offset> pts = <Offset>[];
    final int n = math.max(4, ((b - a).distance / 14).round());
    for (int i = 0; i <= n; i++) {
      final double t = i / n;
      pts.add(
        Offset(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t + math.sin(t * 5 + rnd.nextDouble()) * 0.9,
        ),
      );
    }
    return _smooth(pts);
  }

  /// Adds points along straight segments so the pen reveals them smoothly.
  static List<Offset> _densify(List<Offset> pts) {
    final List<Offset> out = <Offset>[pts.first];
    for (int i = 1; i < pts.length; i++) {
      final Offset a = pts[i - 1];
      final Offset b = pts[i];
      final int n = math.max(1, ((b - a).distance / 2.5).ceil());
      for (int k = 1; k <= n; k++) {
        out.add(Offset.lerp(a, b, k / n)!);
      }
    }
    return out;
  }

  /// Catmull-Rom spline through [pts], sampled every few pixels.
  static List<Offset> _smooth(List<Offset> pts) {
    if (pts.length < 3) return _densify(pts);
    final List<Offset> out = <Offset>[pts.first];
    for (int i = 0; i < pts.length - 1; i++) {
      final Offset p0 = i == 0 ? pts[0] : pts[i - 1];
      final Offset p1 = pts[i];
      final Offset p2 = pts[i + 1];
      final Offset p3 = i + 2 < pts.length ? pts[i + 2] : pts[i + 1];
      final int n = math.max(2, ((p2 - p1).distance / 2.5).ceil());
      for (int k = 1; k <= n; k++) {
        final double t = k / n;
        final double t2 = t * t;
        final double t3 = t2 * t;
        out.add(
          Offset(
            0.5 *
                ((2 * p1.dx) +
                    (-p0.dx + p2.dx) * t +
                    (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                    (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
            0.5 *
                ((2 * p1.dy) +
                    (-p0.dy + p2.dy) * t +
                    (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                    (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
          ),
        );
      }
    }
    return out;
  }
}

/// Paints a [PenLayout] up to [progress] (0..1 of its timeline) with width that
/// swells mid-stroke, round caps, and a visible nib at the pen tip.
class PenInkPainter extends CustomPainter {
  const PenInkPainter({
    required this.layout,
    required this.progress,
    required this.color,
    this.showNib = true,
  });

  final PenLayout layout;
  final double progress;
  final Color color;
  final bool showNib;

  @override
  void paint(Canvas canvas, Size size) {
    final double base = layout.rule / 17 * 0.98;
    final Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Offset? tip;
    for (final PenStroke st in layout.strokes) {
      if (progress <= st.t0) break;
      final double span = st.t1 - st.t0;
      final double frac = span <= 0
          ? 1
          : ((progress - st.t0) / span).clamp(0.0, 1.0);
      final double reach = st.length * frac;
      final int n = st.points.length;
      if (n == 1) {
        canvas.drawCircle(
          st.points.first,
          base * st.widthScale * 0.55,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        tip = st.points.first;
        continue;
      }
      for (int i = 1; i < n; i++) {
        if (st.cumulative[i - 1] >= reach) break;
        Offset b = st.points[i];
        if (st.cumulative[i] > reach) {
          final double seg = st.cumulative[i] - st.cumulative[i - 1];
          b = Offset.lerp(
            st.points[i - 1],
            b,
            seg <= 0 ? 1 : (reach - st.cumulative[i - 1]) / seg,
          )!;
        }
        final double u = st.length <= 0 ? 0.5 : st.cumulative[i] / st.length;
        paint.strokeWidth =
            base *
            st.widthScale *
            (0.62 + 0.55 * math.sin(math.pi * u.clamp(0.0, 1.0)));
        canvas.drawLine(st.points[i - 1], b, paint);
        tip = b;
      }
      if (frac < 1) break;
    }
    if (showNib && tip != null && progress < 1) {
      canvas.drawCircle(tip, base * 2.3, Paint()..color = Colors.white);
      canvas.drawCircle(tip, base * 1.7, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant PenInkPainter old) =>
      old.progress != progress || old.layout != layout || old.color != color;
}

/// Animates a [PenLayout] being written. Shows the finished ink at once when
/// the system asks for reduced motion.
class PenInk extends StatefulWidget {
  const PenInk({
    super.key,
    required this.layout,
    required this.color,
    this.onDone,
    this.onStart,
  });

  final PenLayout layout;
  final Color color;
  final VoidCallback? onDone;
  final VoidCallback? onStart;

  @override
  State<PenInk> createState() => _PenInkState();
}

class _PenInkState extends State<PenInk> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.layout.seconds * 1000).round()),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    widget.onStart?.call();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
      widget.onDone?.call();
    } else {
      _c.forward().whenComplete(() => widget.onDone?.call());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: widget.layout.size,
          painter: PenInkPainter(
            layout: widget.layout,
            progress: _c.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}
