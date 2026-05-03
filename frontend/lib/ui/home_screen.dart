import 'package:flutter/material.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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
    "whatsapp": "com.whatsapp",
    "chatgpt": "com.openai.chatgpt",
    "clock": "com.google.android.deskclock",
    "gpay": "com.google.android.apps.nbu.paisa.user",
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
    await Permission.contacts.request();
    await Permission.phone.request();
    await _stt.init();
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      await _stt.stopListening();
    } else {
      await _tts.stop();
      await _stt.startListening(_onSpeechResult);
    }

    setState(() {
      isListening = !isListening;
    });
  }

  Future<Map<String, dynamic>> _sendToBackend(String text) async {
    final url = Uri.parse("https://jarivs-1.onrender.com/api/v1/process");

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
      }
    } catch (e) {
      print("API ERROR: $e");
    }

    return {"type": "text", "response": "Connection failed"};
  }

  Future<void> _onSpeechResult(String result) async {
    if (isProcessing) return;

    isProcessing = true;
    await _stt.stopListening();

    setState(() {
      isListening = false;
      _text = "You said: $result";
    });

    final response = await _sendToBackend(result);

    final message = response["response"];
    final action = response["action"];
    final app = response["app"];
    final contact = response["contact"];
    final msg = response["message"];

    setState(() {
      _text = message ?? "No response";
    });

    await _tts.speak(message ?? "No response");

    await _handleCommand(action, app, contact, msg);

    isProcessing = false;
  }

  Future<void> _handleCommand(
      String? action, String? app, String? contact, String? message) async {
    if (action == null) return;

    if (app != null && priorityApps.containsKey(app)) {
      await DeviceApps.openApp(priorityApps[app]!);
      return;
    }

    switch (action) {
      case "open_youtube":
        await _openYouTube(app);
        break;
      case "open_app":
        if (app != null) await _openApp(app);
        break;
      case "call":
        await _call(contact);
        break;
      case "sms":
        await _sendSMS(contact, message);
        break;
      case "whatsapp_message":
        await _sendWhatsApp(contact, message);
        break;
      case "search_google":
        await _searchGoogle(app ?? "");
        break;
    }
  }

  // ✅ CLEAN FINAL CONTACT MATCHING (ONLY ONE FUNCTION)
  Future<String?> _findContactNumber(String name) async {
    await FlutterContacts.requestPermission();

    final contacts =
        await FlutterContacts.getContacts(withProperties: true);

    String clean(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    (String base, String? num) split(String s) {
      final c = clean(s);
      final m = RegExp(r'^([a-z]+)(\d+)?$').firstMatch(c);
      if (m != null) {
        return (m.group(1) ?? '', m.group(2));
      }
      return (c, null);
    }

    final (inputBase, inputNum) = split(name);

    for (var c in contacts) {
      if (c.phones.isEmpty) continue;

      final (base, num) = split(c.displayName);

      if (inputNum != null) {
        if (base == inputBase && num == inputNum) {
          return c.phones.first.number;
        }
      }
    }

    if (inputNum == null) {
      for (var c in contacts) {
        if (c.phones.isEmpty) continue;

        final (base, num) = split(c.displayName);

        if (base == inputBase && num == null) {
          return c.phones.first.number;
        }
      }
    }

    return null;
  }

  Future<void> _call(String? name) async {
    if (name == null || name.isEmpty) return;

    final raw = await _findContactNumber(name);

    if (raw != null) {
      final number = _formatNumber(raw);

      final intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$number',
      );

      await intent.launch();
    } else {
      await _tts.speak("Contact not found");
    }
  }

  Future<void> _sendSMS(String? name, String? message) async {
    if (name == null || name.isEmpty) return;

    final number = await _findContactNumber(name);

    if (number != null) {
      final uri = Uri.parse(
        "sms:$number?body=${Uri.encodeComponent(message ?? "")}",
      );
      await launchUrl(uri);
    } else {
      await _tts.speak("Contact not found");
    }
  }

  Future<void> _sendWhatsApp(String? name, String? message) async {
    if (name == null || name.isEmpty) return;

    final raw = await _findContactNumber(name);

    if (raw != null) {
      final number = _formatNumber(raw).replaceAll("+", "");

      final url = Uri.parse(
        "https://wa.me/$number?text=${Uri.encodeComponent(message ?? "")}",
      );

      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await _tts.speak("Contact not found");
    }
  }

  Future<void> _openApp(String name) async {
    final apps = await DeviceApps.getInstalledApplications(
        onlyAppsWithLaunchIntent: true);

    name = name.toLowerCase();

    for (var app in apps) {
      if (app.appName.toLowerCase().contains(name)) {
        await DeviceApps.openApp(app.packageName);
        return;
      }
    }

    await _openSystemApp(name);
  }

  Future<void> _openSystemApp(String app) async {
    if (app.contains("settings")) {
      await AndroidIntent(action: 'android.settings.SETTINGS').launch();
    }
  }

  Future<void> _openYouTube([String? query]) async {
    if (query != null && query.isNotEmpty) {
      final url = Uri.parse(
        "https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}",
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    await DeviceApps.openApp("com.google.android.youtube");
  }

  Future<void> _searchGoogle(String query) async {
    final url = Uri.parse(
      "https://www.google.com/search?q=${Uri.encodeComponent(query)}",
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _formatNumber(String raw) {
    String number = raw.replaceAll(RegExp(r'\s+'), '');
    number = number.replaceAll(RegExp(r'[^\d+]'), '');

    if (number.startsWith("+91")) return number;
    if (number.startsWith("91") && number.length == 12) return "+$number";
    if (number.length == 10) return "+91$number";

    return number;
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