import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks tutor lines. [speak] resolves when speech ends or is stopped.
abstract class TutorSpeaker {
  /// True while a line is being spoken.
  ValueListenable<bool> get speaking;

  /// When muted, [speak] makes no sound and completes immediately.
  bool get muted;
  set muted(bool value);

  /// Speaks [text] now, from [audioUrl] when given, else device speech.
  Future<void> speak(String text, {String? audioUrl});

  Future<void> stop();

  void dispose();
}

/// Plays the endpoint's mp3 (`audio_url`) and falls back to device
/// text-to-speech, so the button always speaks, even offline.
class DeviceTutorSpeaker implements TutorSpeaker {
  DeviceTutorSpeaker({this.baseUrl = ''});

  /// Prefix for relative `audio_url` values served by the tutor API.
  final String baseUrl;

  AudioPlayer? _player;
  FlutterTts? _tts;
  final ValueNotifier<bool> _speaking = ValueNotifier<bool>(false);
  int _generation = 0;

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  bool muted = false;

  @override
  Future<void> speak(String text, {String? audioUrl}) async {
    final int gen = ++_generation;
    await _halt();
    if (muted || text.trim().isEmpty) return;
    _speaking.value = true;
    try {
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          await _playUrl(audioUrl, gen);
          return;
        } catch (_) {
          // fall through to device speech
        }
      }
      if (gen != _generation) return;
      await _speakDevice(text);
    } finally {
      if (gen == _generation) _speaking.value = false;
    }
  }

  Future<void> _playUrl(String url, int gen) async {
    final AudioPlayer player = _player ??= AudioPlayer();
    final String full = url.startsWith('http') ? url : '$baseUrl$url';
    await player.play(UrlSource(full));
    await player.onPlayerComplete.first.timeout(const Duration(minutes: 2));
  }

  Future<void> _speakDevice(String text) async {
    final FlutterTts tts = _tts ??= FlutterTts();
    await tts.setLanguage('en-US');
    await tts.awaitSpeakCompletion(true);
    await tts.speak(text);
  }

  Future<void> _halt() async {
    try {
      await _player?.stop();
      await _tts?.stop();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _generation++;
    _speaking.value = false;
    await _halt();
  }

  @override
  void dispose() {
    _generation++;
    _player?.dispose();
    _tts?.stop();
    _speaking.dispose();
  }
}
