import 'package:flutter/material.dart';

class VoiceController extends ChangeNotifier {
  bool isListening = false;
  bool isSpeaking = false;

  Future<void> startListening() async {
    // your existing STT start logic
  }

  Future<void> stopListening() async {
    // your existing STT stop logic
  }

  Future<void> toggleListening() async {
    if (isListening) {
      await stopListening();
    } else {
      await startListening();
    }

    isListening = !isListening;
    notifyListeners(); // ✅ NOW VALID
  }
}