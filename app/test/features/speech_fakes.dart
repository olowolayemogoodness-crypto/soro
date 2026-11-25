import 'dart:async';
import 'dart:convert';

import 'package:app/features/board/speech_player.dart';
import 'package:app/features/board/spoken_clips.dart';

/// Records what was played; never touches the audio platform.
class FakeSpeechPlayer implements SpeechPlayer {
  FakeSpeechPlayer({this.length = const Duration(seconds: 2)});

  final Duration? length;
  final List<SpeechSource> played = <SpeechSource>[];
  int stops = 0;
  final StreamController<void> _done = StreamController<void>.broadcast();

  @override
  Future<Duration?> play(SpeechSource source) async {
    played.add(source);
    return length;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Stream<void> get onComplete => _done.stream;

  /// Simulates the clip reaching its end.
  void finish() => _done.add(null);

  @override
  void dispose() {
    _done.close();
  }
}

/// A clip lookup backed by an in-memory manifest.
SpokenClips clipsFor(Map<String, String> manifest) =>
    SpokenClips(manifestLoader: () async => jsonEncode(manifest));
