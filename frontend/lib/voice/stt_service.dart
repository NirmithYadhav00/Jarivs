import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class STTService {

  final SpeechToText _speech = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;

  // prevents duplicate final callbacks
  String _lastProcessedText = "";

  /// INIT
  Future<void> init() async {

    print("===== INIT STT =====");

    _isInitialized = await _speech.initialize(

      onStatus: (status) {

        print("STT Status: $status");

        if (status == "done" ||
            status == "notListening") {

          _isListening = false;
        }
      },

      onError: (error) {

        _handleError(error);
      },
    );
  }

  /// START LISTENING
  Future<void> startListening(
      void Function(String) onResult) async {

    // don't stack listeners
    if (!_isInitialized) return;

    if (_isListening) return;

    try {

      print("===== START LISTENING =====");

      _lastProcessedText = "";

      _isListening = true;

      await _speech.listen(

        listenMode: ListenMode.dictation,

        partialResults: false,

        listenFor: const Duration(
          seconds: 15,
        ),

        pauseFor: const Duration(
          seconds: 3,
        ),

        cancelOnError: false,

        onResult: (result) {

          final text = result.recognizedWords
              .trim()
              .toLowerCase();

          print("USER SAID: $text");

          if (text.isEmpty) return;

          // process only final result
          if (!result.finalResult) return;

          // prevent duplicate callbacks
          if (text == _lastProcessedText) {
            return;
          }

          _lastProcessedText = text;

          print(
              "FINAL SPEECH: $text");

          _isListening = false;

          onResult(text);
        },
      );

    } catch (e) {

      print(
          "LISTEN CRASH: $e");

      _isListening = false;
    }
  }

  /// STOP LISTENING
  Future<void> stopListening() async {

    print(
        "===== STOP LISTENING =====");

    try {

      if (_speech.isListening) {

        await _speech.stop();
      }

    } catch (_) {}

    _isListening = false;
  }

  /// ERROR HANDLING
  void _handleError(
      SpeechRecognitionError error) {

    print(
        "STT Error: ${error.errorMsg}");

    final msg = error.errorMsg;

    // harmless errors
    if (msg == "error_no_match") return;

    if (msg == "error_busy") return;

    _isListening = false;
  }
}