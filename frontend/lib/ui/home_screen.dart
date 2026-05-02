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
  bool isProcessing = false;

  final Map<String, String> priorityApps = {
    "google": "com.google.android.googlequicksearchbox",
    "youtube": "com.google.android.youtube",
    "playstore": "com.android.vending",
    "play store": "com.android.vending",
    "whatsapp": "com.whatsapp",
    "chatgpt": "com.openai.chatgpt",
    "clock": "com.google.android.deskclock",
    "github": "com.github.android",
    "hotstar": "in.startv.hotstar",
    "gpay": "com.google.android.apps.nbu.paisa.user",
    "google pay": "com.google.android.apps.nbu.paisa.user",
  };

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

  String normalize(String text) {
    return text.toLowerCase().trim();
  }

  Future<Map<String, dynamic>> _sendToBackend(String text) async {
    final url =
        Uri.parse("https://jarivs-1.onrender.com/api/v1/process");

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
      return {"type": "text", "response": "Connection failed"};
    }
  }

  Future<void> _onSpeechResult(String result) async {
    if (isProcessing) return;

    isProcessing = true;

    _stt.stopListening();

    setState(() {
      isListening = false;
      _text = "You said: $result";
    });

    try {
      final response = await _sendToBackend(result);

      final message = response["response"];
      final action = response["action"];
      final app = response["app"];

      setState(() {
        _text = message ?? "No response";
      });

      await _tts.speak(message ?? "No response");

      await _handleCommand(action, app, result);
    } catch (e) {
      print("❌ ERROR: $e");
    }

    isProcessing = false;
  }

  Future<void> _handleCommand(
      String? action, String? app, String query) async {
    if (action == null) return;

    query = normalize(query);
    app = app != null ? normalize(app) : null;

    // 🔥 PRIORITY
    if (app != null && priorityApps.containsKey(app)) {
      await DeviceApps.openApp(priorityApps[app]!);
      return;
    }

    if (action == "open_youtube") {
      await _openYouTube(app); // ✅ FIXED
      return;
    }

    if (action == "open_app" && app != null) {
      final opened = await _smartAppOpen(app);

      if (!opened) {
        await _trySystemIntent(app);
      }

      return;
    }

    if (action == "call") {
      await _makeCall();
      return;
    }

    if (action == "sms") {
      await _sendSMS();
      return;
    }
  }

  Future<bool> _smartAppOpen(String query) async {
    final apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true,
    );

    query = normalize(query);

    for (var app in apps) {
      final name = normalize(app.appName);
      if (name == query) {
        await DeviceApps.openApp(app.packageName);
        return true;
      }
    }

    for (var app in apps) {
      final name = normalize(app.appName);
      if (name.startsWith(query)) {
        await DeviceApps.openApp(app.packageName);
        return true;
      }
    }

    for (var app in apps) {
      final name = normalize(app.appName);
      if (name.contains(query)) {
        await DeviceApps.openApp(app.packageName);
        return true;
      }
    }

    return false;
  }

  // 🔥 FIXED YOUTUBE
  Future<void> _openYouTube([String? query]) async {
    if (query != null && query.isNotEmpty) {
      final url = Uri.parse(
        "https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}",
      );

      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    bool opened = await DeviceApps.openApp("com.google.android.youtube");

    if (!opened) {
      await launchUrl(
        Uri.parse("https://www.youtube.com"),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _makeCall() async {
    await AndroidIntent(action: 'android.intent.action.DIAL').launch();
  }

  Future<void> _sendSMS() async {
    await AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: 'smsto:',
    ).launch();
  }

  Future<void> _trySystemIntent(String query) async {
    if (query.contains("settings")) {
      await AndroidIntent(
        action: 'android.settings.SETTINGS',
      ).launch();
      return;
    }

    if (query.contains("camera")) {
      await AndroidIntent(
        action: 'android.media.action.IMAGE_CAPTURE',
      ).launch();
      return;
    }

    if (query.contains("photos") || query.contains("gallery")) {
      bool opened = await DeviceApps.openApp("com.google.android.apps.photos");

      if (!opened) {
        await launchUrl(
          Uri.parse("content://media/external/images/media"),
          mode: LaunchMode.externalApplication,
        );
      }
      return;
    }

    if (query.contains("recorder") || query.contains("voice")) {
      await AndroidIntent(
        action: 'android.provider.MediaStore.RECORD_SOUND',
      ).launch();
      return;
    }

    if (query.contains("phone") || query.contains("dial")) {
      await AndroidIntent(
        action: 'android.intent.action.DIAL',
      ).launch();
      return;
    }
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