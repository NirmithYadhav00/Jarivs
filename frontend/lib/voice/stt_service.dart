// import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class STTService {
  final SpeechToText _speech = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  /// INIT
  Future<void> init() async {
    _isInitialized = await _speech.initialize(
      onStatus: (status) {
        print("STT Status: $status");
        // ❌ NO AUTO RESTART
      },
      onError: (error) {
        _handleError(error);
      },
    );
  }

  /// START LISTENING
  Future<void> startListening(void Function(String) onResult) async {
    if (!_isInitialized || _isListening) return;

    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        listenMode: ListenMode.confirmation,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 10),
      );
    } catch (e) {
      print("Listen crash: $e");
      _isListening = false;
    }
  }

  /// STOP LISTENING
  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }

  /// ERROR HANDLING
  void _handleError(SpeechRecognitionError error) {
    final errorMsg = error.errorMsg;

    if (errorMsg == 'error_no_match') return;
    if (errorMsg == 'error_busy') return;

    _isListening = false;
    print("STT Error: $errorMsg");
  }
}