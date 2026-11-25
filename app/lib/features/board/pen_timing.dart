/// Pen speed settings. The pen finishes when the voice finishes, so a spoken
/// line is written over its spoken length; a silent working line is written at
/// a calm hand speed.
const double kPenWordsPerSecond = 2.6;
const int kPenSpeechPaddingMs = 250;
const double kPenSilentCharsPerSecond = 8;

/// How long the pen should take for [text].
///
/// With [audioMs] (the real length of the spoken audio) that exact length is
/// used. Otherwise a spoken line is estimated from its words, and a silent
/// line from its characters.
Duration penDurationFor(String text, {int? audioMs, bool spoken = true}) {
  if (audioMs != null && audioMs > 0) return Duration(milliseconds: audioMs);
  if (spoken) {
    final int words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .length;
    return Duration(
      milliseconds:
          (words / kPenWordsPerSecond * 1000).round() + kPenSpeechPaddingMs,
    );
  }
  final int chars = text.replaceAll(' ', '').length;
  return Duration(
    milliseconds: (chars / kPenSilentCharsPerSecond * 1000).round().clamp(
      400,
      60000,
    ),
  );
}
