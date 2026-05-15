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
import 'package:string_similarity/string_similarity.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final STTService _stt = STTService();
  final TTSService _tts = TTSService();

  String _text = "Initializing Lucky AI...";

  bool isListening = false;
  bool isProcessing = false;

  String lastCommand = "";
  String? lastContact = "";

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initApp();
    });
  }

  Future<void> _initApp() async {
    try {
      print("===== INIT APP =====");

      await _requestPermissions();

      print("===== INIT STT =====");
      await _stt.init();

      print("===== INIT TTS =====");
      await _tts.init();

      await _tts.speak("Hello, I am ready");

      print("===== START LISTENING =====");

      await _stt.startListening(_onSpeechResult);

      if (!mounted) return;

      setState(() {
        isListening = true;
        _text = "Listening...";
      });
    } catch (e) {
      print("INIT ERROR: $e");
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.contacts.request();
    await Permission.phone.request();
    await Permission.sms.request();
  }


Future<void> _toggleListening() async {

  try {

    // 🔥 INTERRUPT SPEAKING
    if (_tts.isSpeaking) {

      print("===== INTERRUPT TTS =====");

      await _tts.stop();

      isProcessing = false;

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      await _stt.startListening(_onSpeechResult);

      if (!mounted) return;

      setState(() {

        isListening = true;

        _text = "Listening...";
      });

      return;
    }

    // 🔥 NORMAL START
    if (!isListening) {

      await _stt.startListening(_onSpeechResult);

      if (!mounted) return;

      setState(() {

        isListening = true;

        _text = "Listening...";
      });

    } else {

      // 🔥 STOP LISTENING
      await _stt.stopListening();

      if (!mounted) return;

      setState(() {

        isListening = false;

        _text = "Stopped listening";
      });
    }

  } catch (e) {

    print("TOGGLE ERROR: $e");
  }
}



  Future<void> _onSpeechResult(String result) async {
    try {
      print("===== RAW SPEECH =====");
      print(result);

      if (isProcessing) return;

      result = result.trim().toLowerCase();

      print("===== CLEAN SPEECH =====");
      print(result);

      // ignore invalid speech
      if (result.isEmpty || result.length < 3) {
        return;
      }

      // ignore duplicate command
      if (result == lastCommand) {
        return;
      }

      lastCommand = result;

      isProcessing = true;

      await _stt.stopListening();

      if (mounted) {
        setState(() {
          isListening = false;

          _text = "You said: $result";
        });
      }

      // 🔥 INSTANT FEEDBACK
      await _tts.speak("Thinking");

      print("===== API REQUEST =====");
      print(result);

      final response = await _sendToBackend(result);

      print("===== DECODED RESPONSE =====");
      print(response);

      String? message;
      String? action;
      String? app;
      String? contact;
      String? msg;
      String? platform;

      if (response is List) {
        for (var item in response) {
          if (item is! Map<String, dynamic>) continue;

          if (item["type"] == "text") {
            if (item["responses"] is List && item["responses"].isNotEmpty) {
              message = item["responses"][0]["content"]?.toString();
            }
          }

          if (item["type"] == "command") {
            action = item["action"]?.toString();

            app = item["app"]?.toString();

            contact = item["contact"]?.toString();

            msg = item["message"]?.toString();

            platform = item["platform"]?.toString();
          }
        }
      } else if (response is Map<String, dynamic>) {
        message = response["response"]?.toString();

        action = response["action"]?.toString();

        app = response["app"]?.toString();

        contact = response["contact"]?.toString();

        msg = response["message"]?.toString();

        platform = response["platform"]?.toString();
      }

      print("===== ACTION =====");
      print(action);

      print("===== MESSAGE =====");
      print(message);

      if (mounted) {
        setState(() {
          _text = message ?? "No response";
        });
      }

      // 🔥 SPEAK FINAL ANSWER
      if (message != null && message.isNotEmpty) {
        await _tts.speak(message);
      }

      // 🔥 HANDLE COMMANDS
      await _handleCommand(action, app, contact, msg, platform);

      isProcessing = false;

      // 🔥 WAIT UNTIL TTS FINISHES
      while (_tts.isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 🔥 SMALL NATURAL DELAY
      await Future.delayed(const Duration(milliseconds: 500));

      print("===== RESTART LISTENING =====");

      await _stt.startListening(_onSpeechResult);

      if (mounted) {
        setState(() {
          isListening = true;

          _text = "Listening...";
        });
      }
    } catch (e) {
      print("SPEECH RESULT ERROR: $e");

      isProcessing = false;
    }
  }

  Future<dynamic> _sendToBackend(String text) async {
    try {
      print("===== API REQUEST =====");
      print(text);

      final response = await http.post(
        Uri.parse("https://jarivs-1.onrender.com/api/v1/process"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": "mobile_user", "query": text}),
      );

      print("===== STATUS CODE =====");
      print(response.statusCode);

      print("===== RESPONSE BODY =====");
      print(response.body);

      if (response.statusCode != 200) {
        return null;
      }

      return jsonDecode(response.body);
    } catch (e) {
      print("BACKEND ERROR: $e");
      return null;
    }
  }

  Future<void> _handleCommand(
    String? action,
    String? app,
    String? contact,
    String? message,
    String? platform,
  ) async {
    try {
      if (action == null) return;

      print("===== HANDLE COMMAND =====");
      print(action);

      if (contact == "him" || contact == "her") {
        contact = lastContact;
      }

      if (action == "call" ||
          action == "sms" ||
          action == "whatsapp_message" ||
          action == "send_message") {
        if (contact == null || contact.isEmpty) {
          await _tts.speak("Who should I contact?");
          return;
        }

        lastContact = contact;
      }

      if (app != null && priorityApps.containsKey(app)) {
        await DeviceApps.openApp(priorityApps[app]!);
        return;
      }

      switch (action) {
        case "call":
          await _call(contact);
          break;

        case "sms":
          await _sendSMS(contact, message);
          break;

        case "whatsapp_message":
          await _sendWhatsApp(contact, message);
          break;

        case "send_message":
          await _handleMessagingPlatform(contact, message, platform);
          break;

        case "open_app":
          if (app != null) {
            await _openSystemApp(app);
          }
          break;

        case "open_youtube":
          await _openYouTube(app);
          break;

        case "search_google":
          await _searchGoogle(app ?? "");
          break;

        default:
          print("UNKNOWN ACTION: $action");
      }
    } catch (e) {
      print("COMMAND ERROR: $e");
    }
  }

  Future<void> _handleMessagingPlatform(
    String? name,
    String? message,
    String? platform,
  ) async {
    if (platform == "sms") {
      await _sendSMS(name, message);
    } else if (platform == "whatsapp") {
      await _sendWhatsApp(name, message);
    } else {
      await _sendSMS(name, message);
    }
  }

  Future<Map<String, dynamic>?> _findContactNumber(String name) async {
    await FlutterContacts.requestPermission();

    final contacts = await FlutterContacts.getContacts(withProperties: true);

    String clean(String s) {
      return s
          .toLowerCase()
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final input = clean(name);

    if (input.length <= 2) return null;

    List<Map<String, String>> matches = [];

    for (var contact in contacts) {
      if (contact.phones.isEmpty) continue;

      final rawName = contact.displayName.toLowerCase();

      final bracketMatch = RegExp(r'\((.*?)\)').firstMatch(rawName);

      String alias = bracketMatch != null ? bracketMatch.group(1)! : "";

      final combined = clean("$rawName $alias");

      final number = contact.phones.first.number;

      if (combined == input) {
        return {
          "type": "single",
          "number": number,
          "name": contact.displayName,
        };
      }

      if (combined.split(" ").contains(input)) {
        matches.add({"name": contact.displayName, "number": number});

        continue;
      }

      if (combined.contains(input)) {
        matches.add({"name": contact.displayName, "number": number});

        continue;
      }

      double sim = StringSimilarity.compareTwoStrings(input, combined);

      if (sim > 0.5) {
        matches.add({"name": contact.displayName, "number": number});
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    if (matches.length == 1) {
      return {
        "type": "single",
        "number": matches[0]["number"],
        "name": matches[0]["name"],
      };
    }

    return {"type": "multiple", "matches": matches};
  }

  Future<void> _call(String? name) async {
    if (name == null || name.isEmpty) {
      await _tts.speak("Who should I call?");
      return;
    }

    final result = await _findContactNumber(name);

    if (result == null) {
      await _tts.speak("Contact not found");
      return;
    }

    if (result["type"] == "multiple") {
      final matches = result["matches"];

      await _tts.speak(
        "Did you mean ${matches[0]["name"]} or ${matches[1]["name"]}?",
      );

      return;
    }

    final number = _formatNumber(result["number"]);

    final intent = AndroidIntent(
      action: 'android.intent.action.CALL',
      data: 'tel:$number',
    );

    await intent.launch();
  }

  Future<void> _sendSMS(String? name, String? message) async {
    if (name == null || name.isEmpty) return;

    final result = await _findContactNumber(name);

    if (result == null) {
      await _tts.speak("Contact not found");
      return;
    }

    if (result["type"] == "multiple") {
      final matches = result["matches"];

      await _tts.speak(
        "Did you mean ${matches[0]["name"]} or ${matches[1]["name"]}?",
      );

      return;
    }

    final number = _formatNumber(result["number"]);

    final intent = AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: 'smsto:$number',
      arguments: {'sms_body': message ?? ''},
    );

    await intent.launch();
  }

  Future<void> _sendWhatsApp(String? name, String? message) async {
    if (name == null || name.isEmpty) return;

    final result = await _findContactNumber(name);

    if (result == null) {
      await _tts.speak("Contact not found");
      return;
    }

    if (result["type"] == "multiple") {
      final matches = result["matches"];

      await _tts.speak(
        "Did you mean ${matches[0]["name"]} or ${matches[1]["name"]}?",
      );

      return;
    }

    String number = _formatNumber(result["number"]);

    number = number.replaceAll(RegExp(r'[^\d]'), '');

    if (!number.startsWith("91")) {
      number = "91$number";
    }

    final url = Uri.parse(
      "https://wa.me/$number?text=${Uri.encodeComponent(message ?? "")}",
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openApp(String name) async {
    final apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true,
    );

    for (var app in apps) {
      if (app.appName.toLowerCase().contains(name.toLowerCase())) {
        await DeviceApps.openApp(app.packageName);
        return;
      }
    }

    await _tts.speak("$name app not found");
  }

  Future<void> _openSystemApp(String app) async {
    try {
      print("===== OPEN SYSTEM APP =====");
      print(app);

      switch (app.toLowerCase()) {
        case "settings":
          await AndroidIntent(action: 'android.settings.SETTINGS').launch();

          return;

        case "contacts":
          await AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'content://contacts/people/',
          ).launch();

          return;

        case "camera":
          await AndroidIntent(
            action: 'android.media.action.IMAGE_CAPTURE',
          ).launch();

          return;

        case "phone":
          await AndroidIntent(action: 'android.intent.action.DIAL').launch();

          return;

        case "messages":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.apps.messaging',
          ).launch();

          return;

        case "clock":
          await AndroidIntent(
            action: 'android.intent.action.SHOW_ALARMS',
          ).launch();

          return;

        default:
          await _openApp(app);
      }
    } catch (e) {
      print("SYSTEM APP ERROR: $e");

      await _tts.speak("Unable to open $app");
    }
  }

  Future<void> _openYouTube([String? query]) async {
    try {
      if (query != null && query.isNotEmpty) {
        final url = Uri.parse(
          "https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}",
        );

        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await DeviceApps.openApp("com.google.android.youtube");
      }
    } catch (e) {
      print("YOUTUBE ERROR: $e");
    }
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

    if (number.startsWith("+91")) {
      return number;
    }

    if (number.startsWith("91") && number.length == 12) {
      return "+$number";
    }

    if (number.length == 10) {
      return "+91$number";
    }

    return number;
  }

  @override
  void dispose() {
    _stt.stopListening();
    _tts.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
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
