import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  bool isSpeaking = false;

  Future<void> init() async {
    await _tts.setLanguage("en-US");

    await _tts.setSpeechRate(0.58);

    await _tts.setVolume(1.0);

    await _tts.setPitch(1.0);

    // VERY IMPORTANT
    await _tts.awaitSpeakCompletion(true);

    _tts.setStartHandler(() {
      print("===== TTS STARTED =====");

      isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      print("===== TTS COMPLETED =====");

      isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      print("===== TTS CANCELLED =====");

      isSpeaking = false;
    });

    _tts.setErrorHandler((message) {
      print("TTS ERROR: $message");

      isSpeaking = false;
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    try {
      await _tts.stop();

      isSpeaking = true;

      await _tts.speak(text);
    } catch (e) {
      print("TTS SPEAK ERROR: $e");

      isSpeaking = false;
    }
  }

  Future<void> stop() async {
    isSpeaking = false;

    await _tts.stop();
  }
}
