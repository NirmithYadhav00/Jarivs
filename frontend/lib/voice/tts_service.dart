import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  Future<void> init() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    await _tts.stop(); // 🔥 prevent overlap
    await _tts.speak(text);
  }

  // ✅ FIX ADDED HERE
  Future<void> stop() async {
    await _tts.stop();
  }
}