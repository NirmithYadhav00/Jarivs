import 'package:flutter/material.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:android_intent_plus/android_intent.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final STTService _stt = STTService();
  final TTSService _tts = TTSService();

  String _text = "Tap mic to start";
  bool isListening = false;
  bool isSpeaking = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initApp();

    _tts.init().then((_) {
      _tts.speak("Hello, I am ready");
    });
  }

  Future<void> _initApp() async {
    await Permission.microphone.request();
    await _stt.init();
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      _stt.stopListening();
    } else {
      _stt.startListening(_onSpeechResult);
    }

    setState(() {
      isListening = !isListening;
    });
  }

  // 🌐 API
  Future<Map<String, dynamic>> _sendToBackend(String text) async {
    final url = Uri.parse(
        "https://running-dizziness-boasting.ngrok-free.dev/api/v1/process");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": "mobile_user",
          "query": text,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"type": "text", "response": "Server error"};
      }
    } catch (e) {
      print("❌ ERROR: $e");
      return {"type": "text", "response": "Connection failed"};
    }
  }

  // 📞 CALL
  Future<void> _makeCall(String name) async {
    await AndroidIntent(action: 'android.intent.action.DIAL').launch();
  }

  // 💬 SMS
  Future<void> _sendSMS(String name) async {
    await AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: 'smsto:',
    ).launch();
  }

  // ▶️ YOUTUBE
  Future<void> _openYouTube() async {
    final uri = Uri.parse("vnd.youtube://");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(
        Uri.parse("https://www.youtube.com"),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  // 📱 NORMAL APPS
  Future<bool> _tryOpenInstalledApp(String query) async {
    final apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true,
    );

    // 🚫 BLOCK THESE APPS
    final blocked = [
      "google one",
      "google photos",
      "google pay",
      "google play",
    ];

    // ✅ EXACT MATCH FIRST
    for (var app in apps) {
      final name = app.appName.toLowerCase();
      if (name == query && !blocked.contains(name)) {
        print("🎯 Exact match: ${app.appName}");
        await DeviceApps.openApp(app.packageName);
        return true;
      }
    }

    // ✅ PARTIAL MATCH (FILTERED)
    for (var app in apps) {
      final name = app.appName.toLowerCase();
      if (name.contains(query) && !blocked.contains(name)) {
        print("📱 Match: ${app.appName}");
        await DeviceApps.openApp(app.packageName);
        return true;
      }
    }

    return false;
  }

  // ⚙️ SYSTEM APPS
  Future<void> _trySystemIntent(String query) async {
    if (query.contains("camera")) {
      await AndroidIntent(
        action: 'android.media.action.IMAGE_CAPTURE',
      ).launch();
      return;
    }

    if (query.contains("phone") || query.contains("dial")) {
      await AndroidIntent(
        action: 'android.intent.action.DIAL',
      ).launch();
    }
  }

    setState(() {
      isSpeaking = false;
    });

    isProcessing = false;
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          _text,
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleListening,
        backgroundColor: isListening ? Colors.red : Colors.blue,
        child: Icon(isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }
}