import 'package:flutter/widgets.dart';

import '../../l10n/soro_strings.dart';

/// Writes [text] onto the page one character at a time over [duration], so the
/// line appears at the pace of the voice. The full line's space is reserved up
/// front, so nothing below it jumps while it is being written.
///
/// Change [runId] to write the same text again from the start.
class TypingText extends StatelessWidget {
  const TypingText({
    super.key,
    required this.text,
    required this.duration,
    required this.runId,
    required this.language,
    required this.style,
  });

  final String text;
  final Duration duration;
  final int runId;
  final SoroLanguage language;
  final TextStyle style;

  /// How many characters of [text] show at [progress] (0 to 1).
  static int visibleCount(String text, double progress) =>
      (text.characters.length * progress.clamp(0.0, 1.0)).floor();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // The finished line, invisible, only to hold its place.
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: SoroLocalizedText(text, language: language, style: style),
          ),
        ),
        TweenAnimationBuilder<double>(
          key: ValueKey<int>(runId),
          tween: Tween<double>(begin: 0, end: 1),
          duration: duration,
          builder: (BuildContext context, double progress, Widget? _) {
            final int shown = visibleCount(text, progress);
            // Nothing is written yet: draw nothing (the space is already held).
            if (shown == 0) return const SizedBox.shrink();
            return SoroLocalizedText(
              text.characters.take(shown).toString(),
              language: language,
              style: style,
            );
          },
        ),
      ],
    );
  }
}
