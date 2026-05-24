import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/lucky_state.dart';
import '../widgets/lucky_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final STTService _stt = STTService();
  final TTSService _tts = TTSService();
  final GlobalKey<LuckyAvatarState> _avatarKey = GlobalKey<LuckyAvatarState>();

  String _text = "Initializing Lucky AI...";
  bool isListening = false;
  bool isProcessing = false;
  String lastCommand = "";
  String? lastContact = "";
  LuckyState currentState = LuckyState.idle;
  bool _initialized = false;

  // ── Animations ──────────────────────────────────────────────
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _ringAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _scanAnim;

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _ringAnim = Tween<double>(begin: 0, end: 1).animate(_ringController);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(_scanController);

    if (!_initialized) {
      _initialized = true;
      Future.microtask(() async {
        await _initApp();
      });
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  // ── State colors ─────────────────────────────────────────────
  Color get _stateColor {
    switch (currentState) {
      case LuckyState.listening:
        return const Color(0xFF00D4FF);
      case LuckyState.thinking:
        return const Color(0xFFFFB800);
      case LuckyState.talking:
        return const Color(0xFFB400FF);
      default:
        return const Color(0xFFCC0044);
    }
  }

  String get _stateLabel {
    switch (currentState) {
      case LuckyState.listening:
        return "LISTENING";
      case LuckyState.thinking:
        return "PROCESSING";
      case LuckyState.talking:
        return "SPEAKING";
      default:
        return "STANDBY";
    }
  }

  // ── All your original logic below (untouched) ────────────────

  Future<void> _initApp() async {
    try {
      print("===== INIT APP =====");
      await _requestPermissions();
      print("===== INIT STT =====");
      await _stt.init();
      print("===== INIT TTS =====");
      await _tts.init();
      _tts.setStartHandler(() => _avatarKey.currentState?.startTalking());
      _tts.setCompletionHandler(() => _avatarKey.currentState?.stopTalking());
      _tts.setErrorHandler((_) => _avatarKey.currentState?.stopTalking());
      _tts.onAmplitude = (amp) {
        _avatarKey.currentState?.pushAmplitude(amp);
      };
      await _tts.speak("Hello, I am Lucky, ready to assist you.");
      print("===== START LISTENING =====");
      if (!mounted) return;
      setState(() {
        isListening = true;
        currentState = LuckyState.listening;
        _text = "Tap mic to speak";
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
      if (_tts.isSpeaking) {
        print("===== INTERRUPT TTS =====");
        await _tts.stop();
        _avatarKey.currentState?.stopTalking();
        isProcessing = false;
        await Future.delayed(const Duration(milliseconds: 300));
        await _stt.startListening(_onSpeechResult);
        if (!mounted) return;
        setState(() {
          isListening = true;
          currentState = LuckyState.listening;
          _text = "Listening...";
        });
        return;
      }
      if (!isListening) {
        await _stt.startListening(_onSpeechResult);
        if (!mounted) return;
        setState(() {
          isListening = true;
          currentState = LuckyState.listening;
          _text = "Listening...";
        });
      } else {
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
      if (result.isEmpty || result.length < 3) return;
      isProcessing = true;
      if (mounted) setState(() {});
      await _stt.stopListening();
      if (mounted)
        setState(() {
          isListening = false;
          _text = "You said: $result";
        });
      final handled = await _handleOfflineCommand(result);
      if (handled) {
        lastCommand = "";
        isProcessing = false;
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() {
          isListening = false;
          currentState = LuckyState.idle;
        });
        return;
      }
      if (result == lastCommand) {
        isProcessing = false;
        return;
      }
      lastCommand = result;
      if (mounted)
        setState(() {
          currentState = LuckyState.thinking;
          _text = "Thinking...";
        });
      _avatarKey.currentState?.setThinking(true);
      final response = await _sendToBackend(result);
      print("===== DECODED RESPONSE =====");
      print(response);
      String? message, action, app, contact, msg, platform;
      if (response is List) {
        for (var item in response) {
          if (item is! Map<String, dynamic>) continue;
          if (item["type"] == "text" &&
              item["responses"] is List &&
              item["responses"].isNotEmpty) {
            message = item["responses"][0]["content"]?.toString();
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
      print("===== ACTION: $action =====");
      print("===== MESSAGE: $message =====");
      if (mounted)
        setState(() {
          _text = message ?? "No response";
        });
      if (message != null && message.isNotEmpty) {
        if (mounted)
          setState(() {
            currentState = LuckyState.talking;
          });
        _avatarKey.currentState?.setThinking(false);
        await _tts.speak(message);
        while (_tts.isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (mounted)
          setState(() {
            currentState = LuckyState.idle;
          });
      } else {
        _avatarKey.currentState?.setThinking(false);
      }
      await _handleCommand(action, app, contact, msg, platform);
      isProcessing = false;
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        isListening = false;
        currentState = LuckyState.idle;
      });
    } catch (e) {
      print("SPEECH RESULT ERROR: $e");
      _avatarKey.currentState?.setThinking(false);
      isProcessing = false;
    }
  }

  Future<void> _speakWithFallback(String text) async {
    try {
      await _tts.speak(text);
      int waited = 0;
      while (!_tts.isSpeaking && waited < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }
      if (_tts.isSpeaking) {
        while (_tts.isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      debugPrint("[TTS FALLBACK] ElevenLabs offline — using device TTS");
      try {
        final ft = FlutterTts();
        await ft.setLanguage("en-IN");
        await ft.setSpeechRate(0.48);
        await ft.setPitch(1.1);
        await ft.speak(text);
        await Future.delayed(
          Duration(milliseconds: (text.length * 60).clamp(600, 5000)),
        );
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  Future<bool> _handleOfflineCommand(String input) async {
    final text = input.toLowerCase().trim();
    final callMatch = RegExp(
      r'^(?:call|ring|dial|give\s+a\s+call\s+to|make\s+a\s+call\s+to)\s+(.+)$',
    ).firstMatch(text);
    if (callMatch != null) {
      final name = callMatch.group(1)!.trim();
      setState(() {
        _text = "Calling $name...";
      });
      await _speakWithFallback("Calling $name");
      lastContact = name;
      await _call(name);
      return true;
    }
    final openMatch = RegExp(
      r'^(?:open|launch|start|go\s+to|show\s+me)\s+(.+)$',
    ).firstMatch(text);
    if (openMatch != null) {
      final appName = openMatch.group(1)!.trim();
      setState(() {
        _text = "Opening $appName...";
      });
      await _speakWithFallback("Opening $appName");
      if (priorityApps.containsKey(appName)) {
        await DeviceApps.openApp(priorityApps[appName]!);
      } else {
        await _openSystemApp(appName);
      }
      return true;
    }
    final alarmMatch = RegExp(
      r'(?:set\s+(?:an?\s+)?alarm|wake\s+me\s+(?:up\s+)?(?:at)?|alarm)[\s\w]*?(\d{1,2})(?:[:\s](\d{2}))?\s*(am|pm)?',
    ).firstMatch(text);
    if (alarmMatch != null ||
        text.contains('alarm') ||
        text.contains('wake me')) {
      int? hour;
      int minute = 0;
      String? period;
      if (alarmMatch != null) {
        hour = int.tryParse(alarmMatch.group(1) ?? '');
        minute = int.tryParse(alarmMatch.group(2) ?? '0') ?? 0;
        period = alarmMatch.group(3);
        if (hour != null) {
          if (period == 'pm' && hour != 12) hour += 12;
          if (period == 'am' && hour == 12) hour = 0;
        }
      }
      if (hour != null) {
        final displayTime = _formatAlarmTime(hour, minute, period);
        setState(() {
          _text = "Setting alarm for $displayTime";
        });
        await _tts.speak("Setting alarm for $displayTime");
        while (_tts.isSpeaking)
          await Future.delayed(const Duration(milliseconds: 100));
        await _setAlarm(hour, minute, "Lucky AI Alarm");
      } else {
        setState(() {
          _text = "Opening alarm...";
        });
        await _tts.speak("Opening alarm. Please set the time.");
        while (_tts.isSpeaking)
          await Future.delayed(const Duration(milliseconds: 100));
        await AndroidIntent(action: 'android.intent.action.SET_ALARM').launch();
      }
      return true;
    }
    final timerMatch = RegExp(
      r'(?:set\s+(?:a\s+)?timer|timer|countdown)[\s\w]*?(\d+)\s*(second|minute|hour)s?',
    ).firstMatch(text);
    if (timerMatch != null) {
      final amount = int.tryParse(timerMatch.group(1) ?? '0') ?? 0;
      final unit = timerMatch.group(2) ?? 'minute';
      final seconds = unit.startsWith('h')
          ? amount * 3600
          : unit.startsWith('m')
          ? amount * 60
          : amount;
      setState(() {
        _text = "Setting timer for $amount ${unit}s";
      });
      await _speakWithFallback("Setting timer for $amount ${unit}s");
      await AndroidIntent(
        action: 'android.intent.action.SET_TIMER',
        arguments: {
          'android.intent.extra.alarm.LENGTH': seconds,
          'android.intent.extra.alarm.SKIP_UI': false,
          'android.intent.extra.alarm.MESSAGE': 'Lucky AI Timer',
        },
      ).launch();
      return true;
    }
    return false;
  }

  Future<void> _setAlarm(int hour, int minute, String label) async {
    await AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: {
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.MESSAGE': label,
        'android.intent.extra.alarm.SKIP_UI': true,
        'android.intent.extra.alarm.VIBRATE': true,
      },
    ).launch();
  }

  String _formatAlarmTime(int hour, int minute, String? period) {
    final p = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:${minute.toString().padLeft(2, '0')} $p';
  }

  Future<dynamic> _sendToBackend(String text) async {
    try {
      final response = await http.post(
        Uri.parse("https://jarivs-1.onrender.com/api/v1/process"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": "mobile_user", "query": text}),
      );
      print("===== STATUS: ${response.statusCode} =====");
      print("===== BODY: ${response.body} =====");
      if (response.statusCode != 200) return null;
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
      print("===== HANDLE COMMAND: $action =====");
      if (contact == "him" || contact == "her") contact = lastContact;
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
          if (app != null) await _openSystemApp(app);
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
    if (platform == "sms")
      await _sendSMS(name, message);
    else if (platform == "whatsapp")
      await _sendWhatsApp(name, message);
    else
      await _sendSMS(name, message);
  }

  Future<Map<String, dynamic>?> _findContactNumber(String name) async {
    await FlutterContacts.requestPermission();
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    String clean(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final input = clean(name);
    if (input.length <= 2) return null;
    List<Map<String, String>> matches = [];
    for (var contact in contacts) {
      if (contact.phones.isEmpty) continue;
      final rawName = contact.displayName.toLowerCase();
      final bracketMatch = RegExp(r'\((.*?)\)').firstMatch(rawName);
      final alias = bracketMatch != null ? bracketMatch.group(1)! : "";
      final combined = clean("$rawName $alias");
      final number = contact.phones.first.number;
      if (combined == input)
        return {
          "type": "single",
          "number": number,
          "name": contact.displayName,
        };
      if (combined.split(" ").contains(input) || combined.contains(input)) {
        matches.add({"name": contact.displayName, "number": number});
        continue;
      }
      if (StringSimilarity.compareTwoStrings(input, combined) > 0.5)
        matches.add({"name": contact.displayName, "number": number});
    }
    if (matches.isEmpty) return null;
    if (matches.length == 1)
      return {
        "type": "single",
        "number": matches[0]["number"],
        "name": matches[0]["name"],
      };
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
      final m = result["matches"] as List;
      await _tts.speak("Did you mean ${m[0]["name"]} or ${m[1]["name"]}?");
      return;
    }
    await AndroidIntent(
      action: 'android.intent.action.CALL',
      data: 'tel:${_formatNumber(result["number"] as String)}',
    ).launch();
  }

  Future<void> _sendSMS(String? name, String? message) async {
    if (name == null || name.isEmpty) return;
    String contactName = name;
    String smsBody = message ?? '';
    const shortWords = [
      'hi',
      'hello',
      'hey',
      'ok',
      'okay',
      'yes',
      'no',
      'bye',
      'thanks',
      'sorry',
      'please',
    ];
    if (shortWords.contains(contactName.toLowerCase()) && smsBody.isNotEmpty) {
      final bodyWords = smsBody
          .replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '')
          .trim();
      smsBody = contactName;
      contactName = bodyWords;
    }
    final result = await _findContactNumber(contactName);
    if (result == null) {
      await _tts.speak("Contact not found");
      return;
    }
    if (result["type"] == "multiple") {
      final m = result["matches"] as List;
      await _tts.speak("Did you mean ${m[0]["name"]} or ${m[1]["name"]}?");
      return;
    }
    final number = _formatNumber(result["number"] as String);
    try {
      await launchUrl(
        Uri.parse("sms:$number?body=${Uri.encodeComponent(smsBody)}"),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      await AndroidIntent(
        action: 'android.intent.action.SENDTO',
        data: 'smsto:$number',
        arguments: {'sms_body': smsBody},
      ).launch();
    }
  }

  Future<void> _sendWhatsApp(String? name, String? message) async {
    if (name == null || name.isEmpty) return;
    String contactName = name;
    String waBody = message ?? '';
    const shortWords = [
      'hi',
      'hello',
      'hey',
      'ok',
      'okay',
      'yes',
      'no',
      'bye',
      'thanks',
      'sorry',
      'please',
    ];
    if (shortWords.contains(contactName.toLowerCase()) && waBody.isNotEmpty) {
      final bodyWords = waBody
          .replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '')
          .trim();
      waBody = contactName;
      contactName = bodyWords;
    }
    final result = await _findContactNumber(contactName);
    if (result == null) {
      await _tts.speak("Contact not found");
      return;
    }
    if (result["type"] == "multiple") {
      final m = result["matches"] as List;
      await _tts.speak("Did you mean ${m[0]["name"]} or ${m[1]["name"]}?");
      return;
    }
    String number = _formatNumber(
      result["number"] as String,
    ).replaceAll(RegExp(r'[^\d]'), '');
    if (!number.startsWith("91")) number = "91$number";
    await launchUrl(
      Uri.parse("https://wa.me/$number?text=${Uri.encodeComponent(waBody)}"),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openApp(String name) async {
    final apps = await DeviceApps.getInstalledApplications(
      onlyAppsWithLaunchIntent: true,
    );
    for (var a in apps) {
      if (a.appName.toLowerCase().contains(name.toLowerCase())) {
        await DeviceApps.openApp(a.packageName);
        return;
      }
    }
    await _tts.speak("$name app not found");
  }

  Future<void> _openSystemApp(String app) async {
    final key = app.toLowerCase().trim();
    try {
      switch (key) {
        case "settings":
          await AndroidIntent(action: 'android.settings.SETTINGS').launch();
          return;
        case "wifi":
        case "wifi settings":
          await AndroidIntent(
            action: 'android.settings.WIFI_SETTINGS',
          ).launch();
          return;
        case "bluetooth":
        case "bluetooth settings":
          await AndroidIntent(
            action: 'android.settings.BLUETOOTH_SETTINGS',
          ).launch();
          return;
        case "location":
        case "gps":
          await AndroidIntent(
            action: 'android.settings.LOCATION_SOURCE_SETTINGS',
          ).launch();
          return;
        case "sound":
        case "volume":
          await AndroidIntent(
            action: 'android.settings.SOUND_SETTINGS',
          ).launch();
          return;
        case "display":
        case "brightness":
          await AndroidIntent(
            action: 'android.settings.DISPLAY_SETTINGS',
          ).launch();
          return;
        case "battery":
        case "battery saver":
          await AndroidIntent(
            action: 'android.intent.action.POWER_USAGE_SUMMARY',
          ).launch();
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
        case "dialer":
          await AndroidIntent(action: 'android.intent.action.DIAL').launch();
          return;
        case "clock":
        case "alarm":
          await AndroidIntent(
            action: 'android.intent.action.SHOW_ALARMS',
          ).launch();
          return;
        case "calculator":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.calculator',
          ).launch();
          return;
        case "messages":
        case "sms":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.apps.messaging',
          ).launch();
          return;
        case "gmail":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.gm',
          ).launch();
          return;
        case "calendar":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.calendar',
          ).launch();
          return;
        case "photos":
        case "gallery":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.apps.photos',
          ).launch();
          return;
        case "chrome":
        case "browser":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.android.chrome',
          ).launch();
          return;
        case "whatsapp":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.whatsapp',
          ).launch();
          return;
        case "instagram":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.instagram.android',
          ).launch();
          return;
        case "telegram":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'org.telegram.messenger',
          ).launch();
          return;
        case "youtube":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.google.android.youtube',
          ).launch();
          return;
        case "spotify":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.spotify.music',
          ).launch();
          return;
        case "netflix":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.netflix.mediaclient',
          ).launch();
          return;
        case "maps":
        case "google maps":
          await AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'geo:0,0',
          ).launch();
          return;
        case "uber":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.ubercab',
          ).launch();
          return;
        case "zomato":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.application.zomato',
          ).launch();
          return;
        case "swiggy":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'in.swiggy.android',
          ).launch();
          return;
        case "amazon":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'in.amazon.mShop.android.shopping',
          ).launch();
          return;
        case "flipkart":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.flipkart.android',
          ).launch();
          return;
        case "phonepe":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.phonepe.app',
          ).launch();
          return;
        case "paytm":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'net.one97.paytm',
          ).launch();
          return;
        case "chatgpt":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'com.openai.chatgpt',
          ).launch();
          return;
        case "zoom":
          await AndroidIntent(
            action: 'android.intent.action.MAIN',
            package: 'us.zoom.videomeetings',
          ).launch();
          return;
        default:
          await _openApp(app);
      }
    } catch (e) {
      print("SYSTEM APP ERROR: $e");
      await _openApp(app);
    }
  }

  Future<void> _openYouTube([String? query]) async {
    try {
      if (query != null && query.isNotEmpty) {
        await launchUrl(
          Uri.parse(
            "https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}",
          ),
          mode: LaunchMode.externalApplication,
        );
      } else {
        await DeviceApps.openApp("com.google.android.youtube");
      }
    } catch (e) {
      print("YOUTUBE ERROR: $e");
    }
  }

  Future<void> _searchGoogle(String query) async {
    await launchUrl(
      Uri.parse(
        "https://www.google.com/search?q=${Uri.encodeComponent(query)}",
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  String _formatNumber(String raw) {
    String n = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\d+]'), '');
    if (n.startsWith("+91")) return n;
    if (n.startsWith("91") && n.length == 12) return "+$n";
    if (n.length == 10) return "+91$n";
    return n;
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04010A),
      body: Stack(
        children: [
          // ── Background ─────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _HudBgPainter(_ringAnim)),
          ),

          // ── Scan line ──────────────────────────────────────
          AnimatedBuilder(
            animation: _scanAnim,
            builder: (_, __) => Positioned(
              top: MediaQuery.of(context).size.height * _scanAnim.value,
              left: 0,
              right: 0,
              height: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _stateColor.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Corner brackets ────────────────────────────────
          ..._buildCorners(),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "L.U.C.K.Y",
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: _stateColor,
                              shadows: [
                                Shadow(
                                  color: _stateColor.withOpacity(0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "PERSONAL AI",
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 3,
                              color: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _stateColor.withOpacity(0.4),
                            ),
                            color: _stateColor.withOpacity(0.08),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _stateColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _stateColor,
                                      blurRadius: 6 * _pulseAnim.value,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _stateLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w600,
                                  color: _stateColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Avatar with HUD rings ────────────────────
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated HUD rings
                      AnimatedBuilder(
                        animation: _ringAnim,
                        builder: (_, __) => CustomPaint(
                          size: const Size(300, 300),
                          painter: _HudRingPainter(
                            _ringAnim.value,
                            _stateColor,
                          ),
                        ),
                      ),
                      // Glow behind avatar
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 220 * _pulseAnim.value,
                          height: 220 * _pulseAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _stateColor.withOpacity(0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Avatar
                      LuckyAvatar(key: _avatarKey, state: currentState),
                    ],
                  ),
                ),

                // ── Response card ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    constraints: const BoxConstraints(
                      minHeight: 70,
                      maxHeight: 130,
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(color: _stateColor.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "◈ LUCKY SAYS",
                          style: TextStyle(
                            fontSize: 8,
                            letterSpacing: 2,
                            color: _stateColor.withOpacity(0.6),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Text(
                              _text.isEmpty
                                  ? "All systems operational."
                                  : _text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Mic button ───────────────────────────────
                GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) {
                      final active =
                          isListening && currentState == LuckyState.listening;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (active)
                            Container(
                              width: 100 + 16 * _pulseAnim.value,
                              height: 100 + 16 * _pulseAnim.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _stateColor.withOpacity(
                                    0.15 * _pulseAnim.value,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _stateColor.withOpacity(0.3),
                                width: 1,
                              ),
                              color: Colors.transparent,
                            ),
                          ),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: active
                                    ? [
                                        _stateColor,
                                        _stateColor.withOpacity(0.6),
                                      ]
                                    : [
                                        const Color(0xFF8B00CC),
                                        const Color(0xFFCC0033),
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _stateColor.withOpacity(0.45),
                                  blurRadius: active
                                      ? 24 * _pulseAnim.value
                                      : 16,
                                ),
                              ],
                            ),
                            child: Icon(
                              active
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // ── Bottom status bar ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _dot(const Color(0xFFB400FF)),
                          const SizedBox(width: 4),
                          _dot(const Color(0xFFCC0033)),
                          const SizedBox(width: 4),
                          _dot(Colors.white12),
                          const SizedBox(width: 8),
                          const Text(
                            "SYS ACTIVE",
                            style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 2,
                              color: Colors.white24,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white12,
                        ),
                      ),
                      const Text(
                        "NEURAL NET READY",
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.5,
                          color: Colors.white24,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: color != Colors.white12
          ? [BoxShadow(color: color, blurRadius: 4)]
          : null,
    ),
  );

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thick = 1.5;
    const pad = 16.0;
    const top = 44.0;
    Color c1 = const Color(0xFFB400FF);
    Color c2 = const Color(0xFFCC0033);
    return [
      Positioned(
        top: top,
        left: pad,
        child: _Corner(size, thick, true, true, c1),
      ),
      Positioned(
        top: top,
        right: pad,
        child: _Corner(size, thick, true, false, c1),
      ),
      Positioned(
        bottom: pad,
        left: pad,
        child: _Corner(size, thick, false, true, c2),
      ),
      Positioned(
        bottom: pad,
        right: pad,
        child: _Corner(size, thick, false, false, c2),
      ),
    ];
  }
}

class _Corner extends StatelessWidget {
  final double size, thick;
  final bool top, left;
  final Color color;
  const _Corner(this.size, this.thick, this.top, this.left, this.color);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CornerPainter(thick, top, left, color)),
  );
}

class _CornerPainter extends CustomPainter {
  final double thick;
  final bool top, left;
  final Color color;
  const _CornerPainter(this.thick, this.top, this.left, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke;
    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;
    canvas.drawLine(Offset(x, y), Offset(x + dx, y), p);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), p);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _HudBgPainter extends CustomPainter {
  final Animation<double> anim;
  _HudBgPainter(this.anim) : super(repaint: anim);
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF04010A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final grid = Paint()
      ..color = const Color(0xFFB400FF).withOpacity(0.035)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 32)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 32)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _HudRingPainter extends CustomPainter {
  final double t;
  final Color color;
  _HudRingPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    void arc(double r, double startAngle, double sweep, Color c, double w) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = c
          ..strokeWidth = w
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Static rings
    canvas.drawCircle(
      Offset(cx, cy),
      138,
      Paint()
        ..color = color.withOpacity(0.07)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      112,
      Paint()
        ..color = const Color(0xFFCC0033).withOpacity(0.06)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      88,
      Paint()
        ..color = color.withOpacity(0.05)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );

    // Rotating arcs
    final a = t * 2 * pi;
    arc(138, a, pi * 0.6, color.withOpacity(0.5), 1.5);
    arc(138, a + pi, pi * 0.4, const Color(0xFFCC0033).withOpacity(0.4), 1.5);
    arc(112, -a * 0.7, pi * 0.5, color.withOpacity(0.3), 1.0);
    arc(
      112,
      -a * 0.7 + pi,
      pi * 0.3,
      const Color(0xFFCC0033).withOpacity(0.3),
      1.0,
    );

    // Tick marks at N/S/E/W
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      final x1 = cx + cos(angle) * 130;
      final y1 = cy + sin(angle) * 130;
      final x2 = cx + cos(angle) * 144;
      final y2 = cy + sin(angle) * 144;
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = (i % 2 == 0 ? color : const Color(0xFFCC0033)).withOpacity(
            0.7,
          )
          ..strokeWidth = 1.5,
      );
    }

    // Small dot markers
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4 + a * 0.1;
      final dx = cx + cos(angle) * 138;
      final dy2 = cy + sin(angle) * 138;
      canvas.drawCircle(
        Offset(dx, dy2),
        2,
        Paint()..color = color.withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_HudRingPainter old) => old.t != t || old.color != color;
}
