import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Where a voice clip comes from: a recording bundled with the app, or a URL
/// served by the Soro API (`/tutor/audio/<hash>.mp3`).
class SpeechSource {
  const SpeechSource.asset(this.value) : isAsset = true;
  const SpeechSource.url(this.value) : isAsset = false;

  /// Asset path relative to `assets/` (for example `audio/tutor/en_0.mp3`), or a full URL.
  final String value;
  final bool isAsset;

  @override
  String toString() => isAsset ? 'asset:$value' : 'url:$value';
}

/// Plays one voice clip at a time and reports its length, so the board can
/// write the line at the same pace as the voice.
abstract class SpeechPlayer {
  /// Starts [source]; returns the clip length when the platform reports it.
  Future<Duration?> play(SpeechSource source);

  Future<void> stop();

  /// Fires when the current clip reaches its end.
  Stream<void> get onComplete;

  void dispose();
}

/// [SpeechPlayer] backed by the `audioplayers` package (Android and web).
class AudioplayersSpeechPlayer implements SpeechPlayer {
  AudioplayersSpeechPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<Duration?> play(SpeechSource source) async {
    await _player.stop();
    await _player.setSource(
      source.isAsset ? AssetSource(source.value) : UrlSource(source.value),
    );
    final Duration? length = await _player.getDuration();
    await _player.resume();
    return length;
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  @override
  void dispose() {
    _player.dispose();
  }
}
