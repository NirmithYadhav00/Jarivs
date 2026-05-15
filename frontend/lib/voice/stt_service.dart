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

        // 🔥 RESET LISTEN STATE CORRECTLY
        if (status == "done" || status == "notListening") {
          _isListening = false;
        }
      },
      onError: (error) {
        _handleError(error);
      },
    );
  }

  /// START LISTENING
  Future<void> startListening(void Function(String) onResult) async {
    if (!_isInitialized || _isListening) return;

    try {
      _isListening = true;

      await _speech.listen(
  onResult: (result) {

  final text = result.recognizedWords
      .trim()
      .toLowerCase();

  print("USER SAID: $text");

  final wordCount = text
      .split(RegExp(r'\s+'))
      .length;

  // ignore empty
  if (text.isEmpty) {
    return;
  }

  // ignore incomplete speech
  if (wordCount < 3) {
    return;
  }

  // ignore broken partial finals
  if (text == "what is" ||
      text == "open" ||
      text == "search" ||
      text == "call") {
    return;
  }

  // ONLY final stable result
  if (result.finalResult) {

    print("FINAL SPEECH: $text");

    onResult(text);
  }
},

        listenMode: ListenMode.dictation,
        partialResults: false,

        // ⚡ SPEED OPTIMIZED
        listenFor: const Duration(seconds: 6),
        pauseFor: const Duration(milliseconds: 1200),
        cancelOnError: false,
      );
    } catch (e) {
      print("Listen crash: $e");
      _isListening = false;
    }
  }

  /// STOP LISTENING
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    _isListening = false;
  }

  /// ERROR HANDLING
  void _handleError(SpeechRecognitionError error) {
    final errorMsg = error.errorMsg;

    print("STT Error: $errorMsg");

    // ignore harmless errors
    if (errorMsg == 'error_no_match') return;
    if (errorMsg == 'error_busy') return;

    _isListening = false;
  }
}