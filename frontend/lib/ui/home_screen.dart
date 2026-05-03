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
      _stt.stopListening();
    } else {
      _stt.startListening(_onSpeechResult);
    }

    setState(() {
      isListening = !isListening;
    });
  }

  String normalize(String text) => text.toLowerCase().trim();

  // 🌐 API
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
      }
    } catch (e) {
      print("API ERROR: $e");
    }

    return {"type": "text", "response": "Connection failed"};
  }

  // 🎤 MAIN FLOW
  Future<void> _onSpeechResult(String result) async {
    if (isProcessing) return;

    isProcessing = true;
    _stt.stopListening();

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

  // 🔥 COMMAND HANDLER
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

 Future<String?> _findContactNumber(String name) async {
  await FlutterContacts.requestPermission();

  final contacts = await FlutterContacts.getContacts(
    withProperties: true,
  );

  name = name.toLowerCase().trim();

  String clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  String input = clean(name);

  // 🟢 1. EXACT RAW MATCH (HIGHEST PRIORITY)
  for (var c in contacts) {
    final display = c.displayName.toLowerCase();

    if (display == name && c.phones.isNotEmpty) {
      return c.phones.first.number;
    }
  }

  // 🟢 2. EXACT CLEAN MATCH (no numbers)
  for (var c in contacts) {
    final display = clean(c.displayName);

    if (display == input && c.phones.isNotEmpty) {
      return c.phones.first.number;
    }
  }

  // 🟡 3. WORD MATCH (prefer without numbers)
  List<Map<String, dynamic>> matches = [];

  for (var c in contacts) {
    final displayRaw = c.displayName.toLowerCase();

    final words = RegExp(r'[a-z]+')
        .allMatches(displayRaw)
        .map((e) => e.group(0)!)
        .toList();

    if (words.contains(input) && c.phones.isNotEmpty) {
      matches.add({
        "name": displayRaw,
        "number": c.phones.first.number,
      });
    }
  }

  Future<String?> _findContactNumber(String name) async {
  await FlutterContacts.requestPermission();

  final contacts = await FlutterContacts.getContacts(
    withProperties: true,
  );

  // --- helpers ---
  String clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  // split into base + number (if any)
  (String base, String? num) split(String s) {
    final c = clean(s);
    final m = RegExp(r'^([a-z]+)(\d+)?$').firstMatch(c);
    if (m != null) {
      return (m.group(1) ?? '', m.group(2));
    }
    return (c, null);
  }

  final (inputBase, inputNum) = split(name);

  // 1) STRICT MATCH: base + number (if user said a number)
  for (var c in contacts) {
    if (c.phones.isEmpty) continue;

    final (base, num) = split(c.displayName);

    if (inputNum != null) {
      // user said "pappa2"
      if (base == inputBase && num == inputNum) {
        return c.phones.first.number;
      }
    }
  }

  // 2) STRICT MATCH: base only (user said "pappa" → ignore numbered ones)
  if (inputNum == null) {
    for (var c in contacts) {
      if (c.phones.isEmpty) continue;

      final (base, num) = split(c.displayName);

      if (base == inputBase && num == null) {
        return c.phones.first.number;
      }
    }
  }

  // 3) Fallback: exact cleaned string (still deterministic)
  final inputClean = clean(name);
  for (var c in contacts) {
    if (c.phones.isEmpty) continue;

    if (clean(c.displayName) == inputClean) {
      return c.phones.first.number;
    }
  }

  return null;
}

  // 🔵 4. FUZZY MATCH (STRICT)
  String? bestNumber;
  int bestScore = 999;

  for (var c in contacts) {
    final display = clean(c.displayName);

    int score = _levenshteinDistance(input, display);

    if (score < bestScore && c.phones.isNotEmpty) {
      bestScore = score;
      bestNumber = c.phones.first.number;
    }
  }

  if (bestScore <= 1) {
    return bestNumber;
  }

  return null;
}
  int _levenshteinDistance(String s1, String s2) {
    List<List<int>> dp = List.generate(
      s1.length + 1,
      (_) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) dp[i][0] = i;
    for (int j = 0; j <= s2.length; j++) dp[0][j] = j;

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;

        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[s1.length][s2.length];
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
      onlyAppsWithLaunchIntent: true,
    );

    name = normalize(name);

    for (var app in apps) {
      if (normalize(app.appName).contains(name)) {
        await DeviceApps.openApp(app.packageName);
        return;
      }
    }

    await _openSystemApp(name);
  }

  Future<void> _openSystemApp(String app) async {
    if (app.contains("settings")) {
      await AndroidIntent(action: 'android.settings.SETTINGS').launch();
      return;
    }

    if (app.contains("contacts")) {
      await AndroidIntent(
        action: 'android.intent.action.VIEW',
        type: 'vnd.android.cursor.dir/contact',
      ).launch();
      return;
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