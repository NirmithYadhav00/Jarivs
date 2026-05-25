import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/lucky_state.dart';
import '../widgets/lucky_avatar.dart';

// ─── Waveform Widget ─────────────────────────────────────────────────────────
class _WaveformWidget extends StatefulWidget {
  final LuckyState state;
  final Color color1;
  final Color color2;
  const _WaveformWidget({
    required this.state,
    required this.color1,
    required this.color2,
  });
  @override
  State<_WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<_WaveformWidget> {
  final List<double> _h = List.filled(40, 0.12);
  final _rng = Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        final active =
            widget.state == LuckyState.listening ||
            widget.state == LuckyState.talking;
        for (int i = 0; i < _h.length; i++) {
          if (active) {
            _h[i] = 0.08 + _rng.nextDouble() * 0.88;
          } else {
            _h[i] = _h[i] * 0.7 + 0.08 * 0.3;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_h.length, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                height: (_h[i] * 32).clamp(3.0, 32.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [widget.color1, widget.color2],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color1.withOpacity(0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Home Screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── All existing services / keys / state — UNCHANGED ──────────────────────
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

  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  // NEW: extra visual-only controllers
  late AnimationController _particleController;
  late AnimationController _orbitController;

  late Animation<double> _ringAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _scanAnim;
  late Animation<double> _particleAnim;
  late Animation<double> _orbitAnim;

  int _voiceLatency = 42;
  int _neuralLoad = 67;
  String _mood = "CURIOUS";
  int _memorySync = 98;
  String _responseTime = "0.42s";

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

    // Original controllers
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

    // Visual-only new controllers
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _ringAnim = Tween<double>(begin: 0, end: 1).animate(_ringController);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(_scanController);
    _particleAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_particleController);
    _orbitAnim = Tween<double>(begin: 0, end: 1).animate(_orbitController);

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
    _particleController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  // ── Color palette ──────────────────────────────────────────────────────────
  static const _cyan = Color(0xFF00D4FF);
  static const _magenta = Color(0xFFB400FF);
  static const _red = Color(0xFFCC0044);
  static const _amber = Color(0xFFFFB800);
  static const _bg = Color(0xFF04010A);
  static const _purple = Color(0xFF6C00CC);

  Color get _stateColor {
    switch (currentState) {
      case LuckyState.listening:
        return _cyan;
      case LuckyState.thinking:
        return _amber;
      case LuckyState.talking:
        return _magenta;
      default:
        return _red;
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

  String get _speechInputLabel {
    if (currentState == LuckyState.listening) return "ACTIVE";
    if (currentState == LuckyState.thinking) return "PROCESSING";
    return "IDLE";
  }

  // ── All original business logic — UNCHANGED ───────────────────────────────
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
        _text = "Listening to you...";
        _mood = "CURIOUS";
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
          _mood = "FOCUSED";
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
          _mood = "CURIOUS";
        });
        return;
      }
      if (result == lastCommand) {
        isProcessing = false;
        return;
      }
      lastCommand = result;
      final sw = Stopwatch()..start();
      if (mounted)
        setState(() {
          currentState = LuckyState.thinking;
          _text = "Thinking...";
          _neuralLoad = 85;
        });
      _avatarKey.currentState?.setThinking(true);
      final response = await _sendToBackend(result);
      sw.stop();
      _responseTime = "${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s";
      _voiceLatency = (sw.elapsedMilliseconds ~/ 10).clamp(10, 999);
      print("===== DECODED RESPONSE =====");
      print(response);
      String? message, action, app, contact, msg, platform;
      if (response is List) {
        for (var item in response) {
          if (item is! Map<String, dynamic>) continue;
          if (item["type"] == "text" &&
              item["responses"] is List &&
              item["responses"].isNotEmpty)
            message = item["responses"][0]["content"]?.toString();
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
          _neuralLoad = 67;
          _memorySync = (_memorySync + 1).clamp(0, 100);
        });
      if (message != null && message.isNotEmpty) {
        if (mounted)
          setState(() {
            currentState = LuckyState.talking;
            _mood = "EXPRESSIVE";
          });
        _avatarKey.currentState?.setThinking(false);
        await _tts.speak(message);
        while (_tts.isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (mounted)
          setState(() {
            currentState = LuckyState.idle;
            _mood = "CURIOUS";
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

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = "${_monthName(now.month)} ${now.day}, ${now.year}"
        .toUpperCase();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = "$h12:$minute $ampm";

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Background: grid + radial vignette ──────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _HudBgPainter(_ringAnim)),
          ),
          // Radial ambient glow centered on avatar
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RadialGlowPainter(_stateColor, _pulseAnim),
              ),
            ),
          ),
          // ── Scan line ───────────────────────────────────────────────────
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
          // ── Floating neural particles ────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleAnim,
                builder: (_, __) => CustomPaint(
                  painter: _NeuralParticlesPainter(
                    _particleAnim.value,
                    _stateColor,
                  ),
                ),
              ),
            ),
          ),
          // ── Corner brackets ─────────────────────────────────────────
          ..._buildCorners(),
          // ── Main content ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ─────────────────────────────────────────────
                _buildTopBar(),
                // ── Stats + Avatar ───────────────────────────────────────
                Expanded(
                  flex: 5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _statItem(
                              "VOICE LATENCY",
                              "${_voiceLatency}ms",
                              _cyan,
                            ),
                            const SizedBox(height: 14),
                            _statItem("NEURAL LOAD", "$_neuralLoad%", _cyan),
                            const SizedBox(height: 14),
                            _statItem("MOOD", _mood, _cyan),
                            const SizedBox(height: 14),
                            _statItem("MEMORY SYNC", "$_memorySync%", _cyan),
                          ],
                        ),
                      ),
                      // Avatar + HUD rings + orbit indicators
                      Expanded(child: _buildAvatarSection()),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _statItem(
                              "DATE",
                              dateStr,
                              _magenta,
                              alignRight: true,
                            ),
                            const SizedBox(height: 14),
                            _statItem(
                              "TIME",
                              timeStr,
                              _magenta,
                              alignRight: true,
                            ),
                            const SizedBox(height: 14),
                            _statItem(
                              "MODEL",
                              "LCKY-7B",
                              _magenta,
                              alignRight: true,
                            ),
                            const SizedBox(height: 14),
                            _statItem(
                              "VERSION",
                              "2.4.1",
                              _magenta,
                              alignRight: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── L.U.C.K.Y Says card ──────────────────────────────────
                _buildResponseCard(),
                const SizedBox(height: 12),
                // ── Mic row ──────────────────────────────────────────────
                _buildMicRow(),
                // ── Bottom bar ───────────────────────────────────────────
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // L.U.C.K.Y logo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [_cyan, _purple, _magenta],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: const Text(
                  "L.U.C.K.Y",
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Color(0xFF00D4FF), blurRadius: 16),
                      Shadow(color: Color(0xFFB400FF), blurRadius: 8),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  const Text(
                    "PERSONAL AI  ",
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 3,
                      color: Colors.white38,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _cyan.withOpacity(0.7)),
                      borderRadius: BorderRadius.circular(3),
                      color: _cyan.withOpacity(0.08),
                      boxShadow: [
                        BoxShadow(color: _cyan.withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                    child: const Text(
                      "ONLINE",
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.5,
                        color: _cyan,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Dynamic status chip
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _stateColor.withOpacity(0.6),
                  width: 1.2,
                ),
                color: _stateColor.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: _stateColor.withOpacity(0.2 * _pulseAnim.value),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pulsing dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _stateColor,
                      boxShadow: [
                        BoxShadow(
                          color: _stateColor,
                          blurRadius: 10 * _pulseAnim.value,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _stateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: _stateColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar Section with circular HUD ──────────────────────────────────────
  Widget _buildAvatarSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer rotating rings
        AnimatedBuilder(
          animation: _ringAnim,
          builder: (_, __) => CustomPaint(
            size: const Size(270, 270),
            painter: _HudRingPainter(_ringAnim.value, _stateColor),
          ),
        ),
        // Orbit indicators
        AnimatedBuilder(
          animation: _orbitAnim,
          builder: (_, __) => CustomPaint(
            size: const Size(270, 270),
            painter: _OrbitIndicatorPainter(_orbitAnim.value, _stateColor),
          ),
        ),
        // Voice-reactive pulse
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 195 * _pulseAnim.value,
            height: 195 * _pulseAnim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _stateColor.withOpacity(0.18),
                  _stateColor.withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // Secondary inner ring (softer)
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _stateColor.withOpacity(0.12 + 0.08 * _pulseAnim.value),
                width: 1,
              ),
            ),
          ),
        ),
        // The avatar
        LuckyAvatar(key: _avatarKey, state: currentState),
      ],
    );
  }

  // ── Response Card (L.U.C.K.Y SAYS) ────────────────────────────────────────
  Widget _buildResponseCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Glassmorphism layers
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: _cyan.withOpacity(0.28), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: _cyan.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: _magenta.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _stateColor,
                        boxShadow: [
                          BoxShadow(color: _stateColor, blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "L.U.C.K.Y SAYS",
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        color: _cyan.withOpacity(0.9),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.more_horiz, color: Colors.white24, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                key: ValueKey(_text),
                _text.isEmpty ? "All systems operational." : _text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            _WaveformWidget(
              state: currentState,
              color1: _cyan,
              color2: _magenta,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip("SPEECH INPUT", _speechInputLabel, _cyan),
                _chip("NOISE FILTER", "ON", _cyan),
                _chip("EMOTION SYNC", "STABLE", _cyan),
                _chip("RESPONSE TIME", _responseTime, _cyan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Mic Row ───────────────────────────────────────────────────────────────
  Widget _buildMicRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _sidePanel(
            topLabel: "SYSTEM\nSTATUS",
            lines: [
              _panelLine("ALL SYSTEMS", Colors.white70, bold: true),
              _panelLine("NOMINAL", Colors.greenAccent),
            ],
            showDot: true,
            dotColor: Colors.greenAccent,
          ),
          // Mic button — enhanced glow/pulse/ripple
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
                    // Outer ripple 2
                    if (active)
                      Container(
                        width: 110 + 20 * _pulseAnim.value,
                        height: 110 + 20 * _pulseAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _stateColor.withOpacity(
                              0.08 * _pulseAnim.value,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    // Outer ripple 1
                    if (active)
                      Container(
                        width: 96 + 16 * _pulseAnim.value,
                        height: 96 + 16 * _pulseAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _stateColor.withOpacity(
                              0.18 * _pulseAnim.value,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                    // Ring border
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _stateColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _stateColor.withOpacity(0.1),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    // Core button
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: active ? [_cyan, _magenta] : [_magenta, _red],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _stateColor.withOpacity(active ? 0.7 : 0.45),
                            blurRadius: active ? 32 * _pulseAnim.value : 20,
                            spreadRadius: active ? 2 : 0,
                          ),
                          BoxShadow(
                            color: _stateColor.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        active ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _sidePanel(
            topLabel: "NEURAL\nNETWORK",
            lines: [_panelLine("READY", _cyan, bold: true)],
            showGraph: true,
            graphColor: _cyan,
          ),
        ],
      ),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _dot(_magenta),
              const SizedBox(width: 4),
              _dot(_red),
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
            width: 50,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [_cyan.withOpacity(0.3), _magenta.withOpacity(0.3)],
              ),
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
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _statItem(
    String label,
    String value,
    Color color, {
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 7,
            letterSpacing: 1.5,
            color: Colors.white38,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: color,
            fontFamily: 'monospace',
            shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 8)],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.8),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 6,
                letterSpacing: 1,
                color: Colors.white38,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            fontFamily: 'monospace',
            shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 6)],
          ),
        ),
      ],
    );
  }

  Widget _sidePanel({
    required String topLabel,
    required List<Widget> lines,
    bool showDot = false,
    Color dotColor = Colors.white,
    bool showGraph = false,
    Color graphColor = Colors.white,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showDot) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: [BoxShadow(color: dotColor, blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  topLabel,
                  style: const TextStyle(
                    fontSize: 7,
                    letterSpacing: 1.5,
                    color: Colors.white38,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...lines,
          if (showGraph) ...[
            const SizedBox(height: 6),
            CustomPaint(
              size: const Size(80, 18),
              painter: _MiniGraphPainter(graphColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panelLine(String text, Color color, {bool bold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontFamily: 'monospace',
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 5)],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color, blurRadius: 6)],
    ),
  );

  String _monthName(int m) {
    const n = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return n[m - 1];
  }

  List<Widget> _buildCorners() {
    const size = 22.0, thick = 1.5, pad = 14.0, top = 42.0;
    return [
      Positioned(
        top: top,
        left: pad,
        child: _Corner(size, thick, true, true, _magenta),
      ),
      Positioned(
        top: top,
        right: pad,
        child: _Corner(size, thick, true, false, _magenta),
      ),
      Positioned(
        bottom: pad,
        left: pad,
        child: _Corner(size, thick, false, true, _red),
      ),
      Positioned(
        bottom: pad,
        right: pad,
        child: _Corner(size, thick, false, false, _red),
      ),
    ];
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

/// Grid background (unchanged logic, enhanced grid color)
class _HudBgPainter extends CustomPainter {
  final Animation<double> anim;
  _HudBgPainter(this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF04010A),
    );
    // Primary grid
    final grid = Paint()
      ..color = const Color(0xFFB400FF).withOpacity(0.035)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 32)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 32)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    // Secondary larger grid (cyan tint)
    final grid2 = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.02)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 96)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid2);
    for (double y = 0; y < size.height; y += 96)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid2);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Radial ambient glow behind avatar (visual only)
class _RadialGlowPainter extends CustomPainter {
  final Color color;
  final Animation<double> pulse;
  _RadialGlowPainter(this.color, this.pulse) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;
    final r = size.width * 0.42 * (0.9 + 0.1 * pulse.value);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.07),
          color.withOpacity(0.025),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_RadialGlowPainter old) => old.color != color;
}

/// Floating neural particles (visual only)
class _NeuralParticlesPainter extends CustomPainter {
  final double t;
  final Color color;
  _NeuralParticlesPainter(this.t, this.color);

  static final _rng = Random(42);
  static final List<_Particle> _particles = List.generate(22, (i) {
    return _Particle(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      r: 1.0 + _rng.nextDouble() * 1.8,
      speed: 0.04 + _rng.nextDouble() * 0.08,
      phase: _rng.nextDouble(),
      drift: (_rng.nextDouble() - 0.5) * 0.3,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final y = ((p.y - p.speed * t + p.phase) % 1.0);
      final x = p.x + sin((t + p.phase) * pi * 2) * p.drift * 0.04;
      final opacity = (sin((t + p.phase) * pi * 2) * 0.5 + 0.5) * 0.55;
      canvas.drawCircle(
        Offset(x.clamp(0, 1) * size.width, y * size.height),
        p.r,
        Paint()..color = color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_NeuralParticlesPainter old) =>
      old.t != t || old.color != color;
}

class _Particle {
  final double x, y, r, speed, phase, drift;
  const _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
    required this.phase,
    required this.drift,
  });
}

/// Orbiting indicators around the avatar (visual only)
class _OrbitIndicatorPainter extends CustomPainter {
  final double t;
  final Color color;
  _OrbitIndicatorPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    const orbitR = 118.0;
    final a = t * 2 * pi;
    // 3 orbiting diamonds at equal spacing
    for (int i = 0; i < 3; i++) {
      final angle = a + i * (2 * pi / 3);
      final ox = cx + cos(angle) * orbitR;
      final oy = cy + sin(angle) * orbitR;
      final paint = Paint()
        ..color =
            (i == 0
                    ? color
                    : (i == 1
                          ? const Color(0xFFB400FF)
                          : const Color(0xFF6C00CC)))
                .withOpacity(0.75);
      // Small diamond
      final path = Path()
        ..moveTo(ox, oy - 5)
        ..lineTo(ox + 4, oy)
        ..lineTo(ox, oy + 5)
        ..lineTo(ox - 4, oy)
        ..close();
      canvas.drawPath(path, paint);
    }
    // Tick marks on the outer ring
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final inner = 112.0, outer = i % 3 == 0 ? 122.0 : 117.0;
      canvas.drawLine(
        Offset(cx + cos(angle) * inner, cy + sin(angle) * inner),
        Offset(cx + cos(angle) * outer, cy + sin(angle) * outer),
        Paint()
          ..color = color.withOpacity(i % 3 == 0 ? 0.6 : 0.3)
          ..strokeWidth = i % 3 == 0 ? 1.5 : 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitIndicatorPainter old) =>
      old.t != t || old.color != color;
}

/// HUD rings (enhanced from original)
class _HudRingPainter extends CustomPainter {
  final double t;
  final Color color;
  _HudRingPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;

    void arc(double r, double s, double sw, Color c, double w) =>
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          s,
          sw,
          false,
          Paint()
            ..color = c
            ..strokeWidth = w
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );

    void ring(double r, Color c, {double w = 0.5}) => canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = c
        ..strokeWidth = w
        ..style = PaintingStyle.stroke,
    );

    // Static guide rings
    ring(130, color.withOpacity(0.08));
    ring(106, const Color(0xFFCC0033).withOpacity(0.07));
    ring(84, color.withOpacity(0.06));
    ring(60, const Color(0xFF6C00CC).withOpacity(0.06));

    final a = t * 2 * pi;

    // Rotating arcs
    arc(130, a, pi * 0.65, color.withOpacity(0.55), 1.8);
    arc(130, a + pi, pi * 0.42, const Color(0xFFCC0033).withOpacity(0.45), 1.8);
    arc(106, -a * 0.7, pi * 0.55, color.withOpacity(0.35), 1.2);
    arc(
      106,
      -a * 0.7 + pi,
      pi * 0.32,
      const Color(0xFFCC0033).withOpacity(0.3),
      1.0,
    );
    arc(84, a * 1.3, pi * 0.3, const Color(0xFF6C00CC).withOpacity(0.4), 1.0);

    // Cardinal tick marks
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      canvas.drawLine(
        Offset(cx + cos(angle) * 122, cy + sin(angle) * 122),
        Offset(cx + cos(angle) * 136, cy + sin(angle) * 136),
        Paint()
          ..color = (i % 2 == 0 ? color : const Color(0xFFCC0033)).withOpacity(
            0.75,
          )
          ..strokeWidth = 1.8,
      );
    }
    // Orbiting dots on outer ring
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4 + a * 0.12;
      canvas.drawCircle(
        Offset(cx + cos(angle) * 130, cy + sin(angle) * 130),
        2.2,
        Paint()..color = color.withOpacity(0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_HudRingPainter old) => old.t != t || old.color != color;
}

/// Mini graph (unchanged)
class _MiniGraphPainter extends CustomPainter {
  final Color color;
  _MiniGraphPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final pts = [0.5, 0.3, 0.7, 0.4, 0.8, 0.2, 0.6, 0.9, 0.3, 0.7];
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * (1 - pts[i]);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.75)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(size.width, size.height * (1 - pts.last)),
      2.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Corner brackets (unchanged)
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
