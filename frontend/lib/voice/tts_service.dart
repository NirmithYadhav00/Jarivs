import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  bool isSpeaking = false;

  // 🔑 External callbacks for avatar lip sync
  VoidCallback? _startCallback;
  VoidCallback? _completionCallback;
  Function(String)? _errorCallback;

  void setStartHandler(VoidCallback fn) => _startCallback = fn;
  void setCompletionHandler(VoidCallback fn) => _completionCallback = fn;
  void setErrorHandler(Function(String) fn) => _errorCallback = fn;

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

      _startCallback?.call(); // 🔑 avatar start
    });

    _tts.setCompletionHandler(() {
      print("===== TTS COMPLETED =====");

      isSpeaking = false;

      _completionCallback?.call(); // 🔑 avatar stop
    });

    _tts.setCancelHandler(() {
      print("===== TTS CANCELLED =====");

      isSpeaking = false;

      _completionCallback?.call(); // 🔑 avatar stop
    });

    _tts.setErrorHandler((message) {
      print("TTS ERROR: $message");

      isSpeaking = false;

      _errorCallback?.call(message); // 🔑 avatar stop
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