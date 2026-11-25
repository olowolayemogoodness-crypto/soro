import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../l10n/soro_strings.dart';
import 'speech_player.dart';
import 'tutor_client.dart' show kSoroApiBase;

/// The review flag the app appends to unreviewed Yorùbá copy. It is for
/// reviewers to read, never for the voice to say.
final RegExp _reviewFlag = RegExp(r'\s*\[needs native check\]', caseSensitive: false);

/// What the voice should say for a Yorùbá line: no review flag, and no English
/// lead-in before a ` · ` (the analogy line carries both languages).
String spokenYoruba(String yo) {
  String text = yo.replaceAll(_reviewFlag, '').trim();
  final int dot = text.lastIndexOf(' · ');
  if (dot >= 0) text = text.substring(dot + 3).trim();
  return text;
}

String _normalise(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Finds the recording for a tutor line.
///
/// A line the server already voiced carries an `audio_url`; every other line
/// is looked up by its exact text in `assets/audio/tutor/manifest.json`
/// (`"<lang>|<text>"` to an asset path), which holds the Spitch recordings of
/// the scripted tutor lines: Funmi for Yorùbá, Lucy for English.
class SpokenClips {
  SpokenClips({Future<String> Function()? manifestLoader})
    : _loader =
          manifestLoader ??
          (() => rootBundle.loadString('assets/audio/tutor/manifest.json'));

  final Future<String> Function() _loader;
  Map<String, String> _manifest = const <String, String>{};
  Future<void>? _loading;

  /// Loads the manifest once. A missing or broken manifest means "no bundled
  /// clips", never an error.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final Object? decoded = jsonDecode(await _loader());
      if (decoded is Map<String, dynamic>) {
        _manifest = <String, String>{
          for (final MapEntry<String, dynamic> e in decoded.entries)
            if (e.value is String) e.key: e.value as String,
        };
      }
    } catch (_) {
      _manifest = const <String, String>{};
    }
  }

  static String _key(SoroLanguage language, String text) =>
      '${language == SoroLanguage.yo ? 'yo' : 'en'}|${_normalise(text)}';

  /// The clip to play for [text] in [language], or null when none exists.
  SpeechSource? sourceFor({
    required SoroLanguage language,
    required String text,
    String? audioUrl,
  }) {
    if (audioUrl != null && audioUrl.isNotEmpty) {
      return SpeechSource.url(_absolute(audioUrl));
    }
    final String? asset = _manifest[_key(language, text)];
    return asset == null ? null : SpeechSource.asset(asset);
  }

  static String _absolute(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final String base = kSoroApiBase.endsWith('/')
        ? kSoroApiBase.substring(0, kSoroApiBase.length - 1)
        : kSoroApiBase;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }
}
