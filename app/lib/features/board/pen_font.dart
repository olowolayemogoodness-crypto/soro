import 'dart:ui' show Offset;

/// A single-line (centre-line) stroke font used by the tutor's pen.
///
/// Glyph coordinates: x runs right from 0, y runs UP from the baseline, the
/// x-height is 6, capitals and ascenders reach 10, descenders reach -3. Each
/// glyph is a list of strokes; each stroke is a list of points that the writer
/// smooths with a Catmull-Rom spline so the pen draws curves, not polylines.
class PenGlyph {
  const PenGlyph(this.width, this.strokes);

  final double width;
  final List<List<Offset>> strokes;
}

List<List<Offset>> _parse(String s) {
  return s.split(';').map((String stroke) {
    return stroke.trim().split(RegExp(r'\s+')).map((String p) {
      final List<String> xy = p.split(',');
      return Offset(double.parse(xy[0]), double.parse(xy[1]));
    }).toList();
  }).toList();
}

const Map<String, (double, String)> _raw = <String, (double, String)>{
  // lowercase
  'a': (5.4, '5,5 3.5,6 1.5,5.2 0.5,3 1.5,0.8 3.5,0 5,1.5; 5,6 5,0.4 5.6,0'),
  'b': (5, '0,10 0,0; 0,3.5 1.5,5.8 3.5,6 5,4.5 5,1.5 3.5,0 1.5,0.2 0,2.5'),
  'c': (4.8, '4.8,5 3.5,6 1.5,5.5 0.3,3.5 1,1 3,0 4.8,1'),
  'd': (
    5.4,
    '5,10 5,0.4 5.6,0; 5,3.5 3.5,5.8 1.5,6 0,4.5 0,1.5 1.5,0 3.5,0.2 5,2.5',
  ),
  'e': (5, '0.3,3 5,3.4 4.8,5 3,6 1,5.2 0,3 0.8,1 2.8,0 4.8,1'),
  'f': (4.2, '4.4,9.6 3.4,10 2.6,9 2.4,7 2.4,0; 0.4,6 4.2,6'),
  'g': (
    5.2,
    '5,5 3.5,6 1.5,5.2 0.5,3.5 1.5,1.5 3.5,1 5,2.5; 5,6 5,-1.5 3.8,-3 1.5,-2.8 0.5,-1.5',
  ),
  'h': (5, '0,10 0,0; 0,4 1.5,5.8 3.5,6 4.8,4.5 4.8,0'),
  'i': (2, '1,6 1,0; 1,8.2 1,8.3'),
  'j': (2.6, '1.5,6 1.5,-1.5 0.6,-3 -0.5,-2.8; 1.5,8.2 1.5,8.3'),
  'k': (4.8, '0,10 0,0; 4.4,6 0,2.4; 1.4,3.6 4.8,0'),
  'l': (3, '1,10 1,1 2,0 3,0.5'),
  'm': (
    7.6,
    '0,6 0,0; 0,4 1,5.8 2.5,6 3.5,4.5 3.5,0; 3.5,4.5 4.5,5.8 6,6 7,4.5 7,0',
  ),
  'n': (5, '0,6 0,0; 0,4 1.5,5.8 3.5,6 4.8,4.5 4.8,0'),
  'o': (5, '2.5,6 0.8,5 0,3 0.8,1 2.5,0 4.2,1 5,3 4.2,5 2.5,6'),
  'p': (5, '0,6 0,-3; 0,3.5 1.5,5.8 3.5,6 5,4.5 5,1.5 3.5,0 1.5,0.2 0,2.5'),
  'q': (5.2, '5,6 5,-3; 5,3.5 3.5,5.8 1.5,6 0,4.5 0,1.5 1.5,0 3.5,0.2 5,2.5'),
  'r': (4, '0,6 0,0; 0,3.5 1.2,5.5 2.5,6 3.8,5.6'),
  's': (4.6, '4.4,5 3,6 1,5.5 0.5,4 2,3 3.5,2.2 4.3,1 3.2,0 1,0.3 0,1.5'),
  't': (4.4, '2,9 2,1 3,0 4,0.5; 0.2,6 4,6'),
  'u': (5, '0,6 0,2 1.2,0.2 3,0 4.8,1.5; 4.8,6 4.8,0'),
  'v': (5, '0,6 2.5,0 5,6'),
  'w': (7.2, '0,6 1.5,0 3.5,5 5.5,0 7,6'),
  'x': (5, '0,6 5,0; 5,6 0,0'),
  'y': (5, '0,6 2.5,0.4; 5,6 2.3,0 1.5,-2 0.3,-3'),
  'z': (5, '0,6 5,6 0,0 5,0'),
  // capitals
  'A': (6, '0,0 3,10 6,0; 1,3.5 5,3.5'),
  'B': (
    5.8,
    '0,0 0,10 3.5,10 5,8.5 3.5,5.3 0,5.2; 3.5,5.2 5.5,3.5 4.5,0.5 0,0',
  ),
  'C': (6, '6,8.5 4,10 1.5,9 0.3,5 1.5,1 4,0 6,1.5'),
  'D': (5.8, '0,0 0,10 3,10 5.5,7 5.5,3 3,0 0,0'),
  'E': (5.5, '5.5,10 0,10 0,0 5.5,0; 0,5.3 4,5.3'),
  'F': (5.2, '5.5,10 0,10 0,0; 0,5.3 4,5.3'),
  'G': (6.2, '6,8.5 4,10 1.5,9 0.3,5 1.5,1 4,0 6,1.5 6,4.5 3.5,4.5'),
  'H': (6, '0,0 0,10; 6,0 6,10; 0,5 6,5'),
  'I': (2, '1,0 1,10'),
  'J': (4.5, '4,10 4,2 3,0 1,0 0,1.5'),
  'K': (5.6, '0,0 0,10; 5.5,10 0,4; 1.5,5.5 5.5,0'),
  'L': (5, '0,10 0,0 5,0'),
  'M': (7, '0,0 0,10 3.5,2 7,10 7,0'),
  'N': (6, '0,0 0,10 6,0 6,10'),
  'O': (6.2, '3,10 0.8,8.5 0,5 0.8,1.5 3,0 5.2,1.5 6,5 5.2,8.5 3,10'),
  'P': (5.6, '0,0 0,10 3.5,10 5.5,8.5 4.5,5.5 0,5'),
  'Q': (
    6.2,
    '3,10 0.8,8.5 0,5 0.8,1.5 3,0 5.2,1.5 6,5 5.2,8.5 3,10; 3.5,2.5 6,-1',
  ),
  'R': (5.8, '0,0 0,10 3.5,10 5.5,8.5 4.5,5.5 0,5; 2.5,5 5.5,0'),
  'S': (
    5.6,
    '5.5,8.5 4,10 1.5,9.5 0.5,7.5 2.5,5.5 4.5,4.5 5.5,2.5 4.5,0.5 2,0 0,1.5',
  ),
  'T': (6, '0,10 6,10; 3,10 3,0'),
  'U': (5.8, '0,10 0,2.5 1.5,0.3 3.5,0 5.5,2 5.5,10'),
  'V': (6, '0,10 3,0 6,10'),
  'W': (7.4, '0,10 1.7,0 3.5,8 5.3,0 7,10'),
  'X': (6, '0,10 6,0; 6,10 0,0'),
  'Y': (6, '0,10 3,5 6,10; 3,5 3,0'),
  'Z': (6, '0,10 6,10 0,0 6,0'),
  // digits
  '0': (5, '2.5,10 0.5,8 0,5 0.5,2 2.5,0 4.5,2 5,5 4.5,8 2.5,10'),
  '1': (3.4, '0.3,8 2.5,10 2.5,0'),
  '2': (5, '0.3,8 1.5,10 3.5,10 5,8.3 4.5,6 0,0 5,0'),
  '3': (
    5,
    '0.3,9 2,10 4,9.8 4.8,8 3.5,5.8 2,5.3; 3.5,5.8 5,4 4.5,1.2 2.5,0 0.3,1',
  ),
  '4': (5.4, '4,0 4,10 0,3 5.4,3'),
  '5': (5, '4.8,10 0.8,10 0.5,5.5 2.5,6.2 4.5,5 5,2.8 3.8,0.5 2,0 0,1'),
  '6': (5, '4.5,9 3,10 1,8.5 0,5 0.5,1.5 2.5,0 4.5,1.5 4.5,4 2.5,5.2 0.5,4.2'),
  '7': (5, '0,10 5,10 1.8,0'),
  '8': (
    5,
    '2.5,5.2 0.7,6.5 0.8,8.8 2.5,10 4.2,8.8 4.3,6.5 2.5,5.2 0.5,3.8 0.3,1.3 2.5,0 4.7,1.3 4.5,3.8 2.5,5.2',
  ),
  '9': (5, '0.5,1 2,0 4,1.5 5,5 4.2,8.5 2.5,10 0.5,8.5 0.5,6 2.5,4.8 4.7,5.8'),
  // punctuation and maths
  '.': (1.4, '0.6,0 0.6,0.15'),
  ',': (1.6, '0.9,0.6 0.5,-1.6'),
  ':': (1.4, '0.6,0 0.6,0.15; 0.6,5.5 0.6,5.65'),
  ';': (1.6, '0.9,0.6 0.5,-1.6; 0.9,5.5 0.9,5.65'),
  '!': (1.4, '0.7,10 0.7,3; 0.7,0 0.7,0.15'),
  '?': (4.6, '0,8 1,10 3,10 4.2,8 3.6,6 2.2,5 2.2,3; 2.2,0 2.2,0.15'),
  "'": (1.2, '0.6,10 0.4,7.6'),
  '-': (4, '0,3.6 4,3.4'),
  '+': (5, '0,5 5,5; 2.5,7.6 2.5,2.4'),
  '=': (5, '0,3 5,3.1; 0,6.2 5,6.1'),
  '×': (4.6, '0.3,7 4.3,2.6; 4.3,7 0.3,2.6'),
  '/': (3.4, '3.4,10 0,-1'),
  '(': (3, '2.6,10 0.9,6.5 0.9,2.5 2.6,-1.5'),
  ')': (3, '0.4,10 2.1,6.5 2.1,2.5 0.4,-1.5'),
  '→': (6.4, '0,4.5 6.2,4.5; 4,7 6.4,4.5 4,2'),
  '⇒': (7, '0,3 6.4,3; 0,6 6.4,6; 4.5,8.5 7,4.5 4.5,0.5'),
};

const Map<String, String> _aliases = <String, String>{
  '−': '-',
  '–': '-',
  '—': '-',
  '’': "'",
  '‘': "'",
  '“': "'",
  '”': "'",
  '·': '.',
  '…': '.',
  '[': '(',
  ']': ')',
};

/// Precomposed Latin letters used in Yorùbá: base letter plus marks.
const Map<String, (String, List<String>)> _decomposed =
    <String, (String, List<String>)>{
      'à': ('a', ['̀']),
      'á': ('a', ['́']),
      'è': ('e', ['̀']),
      'é': ('e', ['́']),
      'ì': ('i', ['̀']),
      'í': ('i', ['́']),
      'ò': ('o', ['̀']),
      'ó': ('o', ['́']),
      'ù': ('u', ['̀']),
      'ú': ('u', ['́']),
      'ń': ('n', ['́']),
      'ǹ': ('n', ['̀']),
      'ẹ': ('e', ['̣']),
      'ọ': ('o', ['̣']),
      'ṣ': ('s', ['̣']),
      'Ẹ': ('E', ['̣']),
      'Ọ': ('O', ['̣']),
      'Ṣ': ('S', ['̣']),
      'ẹ̀': ('e', ['̣', '̀']),
      'ẹ́': ('e', ['̣', '́']),
      'ọ̀': ('o', ['̣', '̀']),
      'ọ́': ('o', ['̣', '́']),
    };

/// One drawable unit of text: a glyph plus the combining marks on it.
class PenCluster {
  const PenCluster(this.base, this.marks);

  final String base;
  final List<String> marks;
}

class PenFont {
  PenFont._();

  static final Map<String, PenGlyph> _glyphs = <String, PenGlyph>{
    for (final MapEntry<String, (double, String)> e in _raw.entries)
      e.key: PenGlyph(e.value.$1, _parse(e.value.$2)),
  };

  /// Looks up a glyph for a plain character, or null when the pen has none.
  static PenGlyph? glyph(String ch) => _glyphs[_aliases[ch] ?? ch];

  /// Splits [text] into clusters, folding combining marks and precomposed
  /// Yorùbá letters into a base glyph plus marks. Spaces are their own cluster.
  static List<PenCluster> clusters(String text) {
    final List<PenCluster> out = <PenCluster>[];
    final List<String> chars = text.runes.map(String.fromCharCode).toList();
    for (int i = 0; i < chars.length; i++) {
      final String c = chars[i];
      if (c == '̀' || c == '́' || c == '̄' || c == '̣') {
        if (out.isNotEmpty) {
          out[out.length - 1] = PenCluster(out.last.base, <String>[
            ...out.last.marks,
            c,
          ]);
        }
        continue;
      }
      final (String, List<String>)? d = _decomposed[c];
      if (d != null) {
        out.add(PenCluster(d.$1, List<String>.of(d.$2)));
      } else {
        out.add(PenCluster(c, <String>[]));
      }
    }
    return out;
  }

  /// Marks drawn above (grave, acute) or below (dot) a glyph, as strokes in
  /// glyph coordinates for a glyph of the given [width] and [top] height.
  static List<List<Offset>> markStrokes(
    String mark,
    double width,
    double top,
    double ox,
  ) {
    final double cx = ox + width / 2;
    switch (mark) {
      case '̀':
        return <List<Offset>>[
          <Offset>[Offset(cx - 1.2, top + 2.2), Offset(cx + 0.8, top + 0.6)],
        ];
      case '́':
        return <List<Offset>>[
          <Offset>[Offset(cx - 0.8, top + 0.6), Offset(cx + 1.2, top + 2.2)],
        ];
      case '̄':
        return <List<Offset>>[
          <Offset>[Offset(cx - 1.4, top + 1.4), Offset(cx + 1.4, top + 1.4)],
        ];
      case '̣':
        return <List<Offset>>[
          <Offset>[Offset(cx, -1.8), Offset(cx, -1.7)],
        ];
    }
    return const <List<Offset>>[];
  }
}
