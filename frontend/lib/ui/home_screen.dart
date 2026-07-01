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
import '../widgets/profile_header.dart';

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
  final List<double> _h = List.filled(40, 0.08);
  final _rng = Random();
  Timer? _timer;

  bool get _active =>
      widget.state == LuckyState.listening ||
      widget.state == LuckyState.talking;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_WaveformWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      if (_active)
        _startTimer();
      else
        _stopTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _h.length; i++) {
          _h[i] = 0.08 + _rng.nextDouble() * 0.88;
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (mounted)
      setState(() {
        for (int i = 0; i < _h.length; i++) _h[i] = 0.08;
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
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          _h.length,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                height: (_h[i] * 28).clamp(2.0, 28.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [widget.color1, widget.color2],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoloIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool active;
  const _HoloIcon({
    required this.icon,
    required this.color,
    this.size = 54,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(active ? 0.18 : 0.08),
        border: Border.all(
          color: color.withOpacity(active ? 0.85 : 0.50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(active ? 0.42 : 0.16),
            blurRadius: active ? 20 : 10,
            spreadRadius: active ? 2 : 0,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color.withOpacity(active ? 1.0 : 0.85),
        size: size * 0.40,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final STTService _stt = STTService();
  final TTSService _tts = TTSService();
  final GlobalKey<LuckyAvatarState> _avatarKey = GlobalKey<LuckyAvatarState>();

  // Text input
  final TextEditingController _typeController = TextEditingController();
  final FocusNode _typeFocus = FocusNode();
  bool _showTyping = false;

  String _text = "Initializing Lucky AI...";
  bool isListening = false;
  bool isProcessing = false;
  String lastCommand = "";
  String? lastContact = "";
  LuckyState currentState = LuckyState.idle;
  bool _initialized = false;

  // Animations
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _floatController;
  late Animation<double> _ringAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _scanAnim;
  // ignore: unused_field
  late Animation<double> _floatAnim;

  String _responseTime = "0.00s";

  // ── Sidebar state (new) ─────────────────────────────────────────────────
  bool _sidebarOpen = false;
  bool _profileMenuOpen = false;

  // Placeholder chat history — wire this up to your real chat storage later
  final List<String> _chatHistory = [
    "Trip planning to Goa",
    "Fix wifi settings",
    "Set alarm for tomorrow",
    "Call mom",
  ];

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
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _ringAnim = Tween<double>(begin: 0, end: 1).animate(_ringController);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(_scanController);
    _floatAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

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
    _floatController.dispose();
    _typeController.dispose();
    _typeFocus.dispose();
    super.dispose();
  }

  // ── Color palette — inspired by reference image (blue/cyan holographic) ──
  static const _cyan = Color(0xFF00D4FF);
  static const _cyanLight = Color(0xFF60E8FF);
  static const _blue = Color(0xFF0A84FF);
  static const _white = Color(0xFFDEF0FF);
  static const _bg = Color(0xFF03060F);
  static const _bgCard = Color(0xFF060E1C);
  static const _bgPanel = Color(0xFF071018);

  Color get _stateColor {
    switch (currentState) {
      case LuckyState.listening:
        return _cyan;
      case LuckyState.thinking:
        return const Color(0xFF4DA8FF);
      case LuckyState.talking:
        return _cyanLight;
      default:
        return _blue;
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

  // ══════════════════════════════════════════════════════════════════════════
  // ALL ORIGINAL LOGIC — UNTOUCHED
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _initApp() async {
    try {
      print("===== INIT APP =====");
      await _requestPermissions();
      await _stt.init();
      await _tts.init();
      _tts.setStartHandler(() => _avatarKey.currentState?.startTalking());
      _tts.setCompletionHandler(() => _avatarKey.currentState?.stopTalking());
      _tts.setErrorHandler((_) => _avatarKey.currentState?.stopTalking());
      _tts.onAmplitude = (amp) {
        _avatarKey.currentState?.pushAmplitude(amp);
      };
      await _tts.speak("Hello, I am Lucky, ready to assist you.");
      while (_tts.isSpeaking)
        await Future.delayed(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _stt.startListening(_onSpeechResult);
      if (!mounted) return;
      setState(() {
        isListening = true;
        currentState = LuckyState.listening;
        _text = "Listening to you...";
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
          currentState = LuckyState.idle;
          _text = "Tap mic to speak";
        });
      }
    } catch (e) {
      print("TOGGLE ERROR: $e");
    }
  }

  Future<void> _sendTyped() async {
    final input = _typeController.text.trim();
    if (input.isEmpty) return;
    _typeController.clear();
    _typeFocus.unfocus();
    setState(() {
      _showTyping = false;
    });
    await _onSpeechResult(input);
  }

  Future<void> _onSpeechResult(String result) async {
    try {
      print("===== RAW SPEECH =====");
      print(result);
      if (isProcessing) return;
      result = result.trim().toLowerCase();
      if (result.isEmpty || result.length < 2) return;
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
        while (_tts.isSpeaking)
          await Future.delayed(const Duration(milliseconds: 100));
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        await _stt.startListening(_onSpeechResult);
        if (!mounted) return;
        setState(() {
          isListening = true;
          currentState = LuckyState.listening;
          _text = "Listening to you...";
        });
        return;
      }
      if (result == lastCommand) {
        isProcessing = false;
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        await _stt.startListening(_onSpeechResult);
        if (!mounted) return;
        setState(() {
          isListening = true;
          currentState = LuckyState.listening;
        });
        return;
      }
      lastCommand = result;
      final sw = Stopwatch()..start();
      if (mounted)
        setState(() {
          currentState = LuckyState.thinking;
          _text = "Thinking...";
        });
      _avatarKey.currentState?.setThinking(true);
      final response = await _sendToBackend(result);
      sw.stop();
      _responseTime = "${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s";

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

      if (message != null && message.isNotEmpty) {
        _avatarKey.currentState?.setThinking(false);
        final String safeMessage = message;
        if (mounted)
          setState(() {
            currentState = LuckyState.talking;
            _text = safeMessage;
          });
        await _tts.speak(safeMessage);
        int waited = 0;
        while (_tts.isSpeaking && waited < 30000) {
          await Future.delayed(const Duration(milliseconds: 100));
          waited += 100;
        }
        if (mounted)
          setState(() {
            currentState = LuckyState.idle;
          });
      } else {
        _avatarKey.currentState?.setThinking(false);
        if (mounted)
          setState(() {
            _text = "No response";
          });
      }

      await _handleCommand(action, app, contact, msg, platform);
      isProcessing = false;
      while (_tts.isSpeaking)
        await Future.delayed(const Duration(milliseconds: 100));
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _stt.startListening(_onSpeechResult);
      if (!mounted) return;
      setState(() {
        isListening = true;
        currentState = LuckyState.listening;
        _text = "Listening to you...";
      });
    } catch (e) {
      print("SPEECH RESULT ERROR: $e");
      _avatarKey.currentState?.setThinking(false);
      isProcessing = false;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _stt.startListening(_onSpeechResult);
      if (!mounted) return;
      setState(() {
        isListening = true;
        currentState = LuckyState.listening;
        _text = "Listening to you...";
      });
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
      if (priorityApps.containsKey(appName))
        await DeviceApps.openApp(priorityApps[appName]!);
      else
        await _openSystemApp(appName);
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
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final p = hour >= 12 ? 'PM' : 'AM';
    return '$h:${minute.toString().padLeft(2, '0')} $p';
  }

  Future<dynamic> _sendToBackend(String text) async {
    try {
      final response = await http.post(
        Uri.parse("https://jarivs-1.onrender.com/api/v1/process"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": "mobile_user", "query": text}),
      );
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
      await _openApp(app);
    }
  }

  Future<void> _openYouTube([String? query]) async {
    try {
      if (query != null && query.isNotEmpty)
        await launchUrl(
          Uri.parse(
            "https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}",
          ),
          mode: LaunchMode.externalApplication,
        );
      else
        await DeviceApps.openApp("com.google.android.youtube");
    } catch (e) {}
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

  // ══════════════════════════════════════════════════════════════════════════
  // SIDEBAR — new logic, isolated from everything above
  // ══════════════════════════════════════════════════════════════════════════
  void _toggleSidebar() {
    setState(() {
      _sidebarOpen = !_sidebarOpen;
      if (!_sidebarOpen) _profileMenuOpen = false;
    });
  }

  void _closeSidebar() {
    if (!_sidebarOpen && !_profileMenuOpen) return;
    setState(() {
      _sidebarOpen = false;
      _profileMenuOpen = false;
    });
  }

  void _toggleProfileMenu() {
    setState(() {
      _profileMenuOpen = !_profileMenuOpen;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = "$h12:$minute $ampm";
    final dateStr = "${_monthName(now.month)} ${now.day}, ${now.year}";

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background — deep space with city-light glow
          Positioned.fill(child: CustomPaint(painter: _SpaceBgPainter())),

          // Subtle scan line
          AnimatedBuilder(
            animation: _scanAnim,
            builder: (_, __) => Positioned(
              top: MediaQuery.of(context).size.height * _scanAnim.value,
              left: 0,
              right: 0,
              height: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _stateColor.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(timeStr, dateStr),
                Expanded(flex: 6, child: _buildAvatarSection()),
                _buildResponseCard(),
                const SizedBox(height: 8),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showTyping) _buildTypeInput(),
                      _buildActionRow(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sidebar dim overlay (new) ─────────────────────────────────
          IgnorePointer(
            ignoring: !_sidebarOpen,
            child: GestureDetector(
              onTap: _closeSidebar,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _sidebarOpen ? 1 : 0,
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
          ),

          // ── Sidebar panel (new) ───────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            left: _sidebarOpen ? 0 : -300,
            width: 300,
            child: _buildSidebar(),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(String timeStr, String dateStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Menu button + Logo + subtitle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _toggleSidebar,
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cyan.withOpacity(0.08),
                    border: Border.all(color: _cyan.withOpacity(0.35)),
                  ),
                  child: Icon(
                    Icons.menu_rounded,
                    color: _cyan.withOpacity(0.85),
                    size: 18,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Glowing indicator dot
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _cyan,
                          boxShadow: [
                            BoxShadow(
                              color: _cyan.withOpacity(0.9),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [_cyanLight, _cyan, _blue],
                        ).createShader(b),
                        child: const Text(
                          "L.U.C.K.Y",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        "PERSONAL AI  ",
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 2.5,
                          color: _cyan.withOpacity(0.45),
                          fontFamily: 'monospace',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _cyan.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(3),
                          color: _cyan.withOpacity(0.08),
                        ),
                        child: Text(
                          "ONLINE",
                          style: TextStyle(
                            fontSize: 7,
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
            ],
          ),

          // Right: State badge + time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _bgPanel,
                    border: Border.all(
                      color: _stateColor.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _stateColor.withOpacity(0.12 * _pulseAnim.value),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: _stateColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                timeStr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _white,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8,
                  letterSpacing: 0.8,
                  color: _cyan.withOpacity(0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Avatar section with holographic floating icons ────────────────────────
  Widget _buildAvatarSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating holographic rings
        AnimatedBuilder(
          animation: _ringAnim,
          builder: (_, __) => CustomPaint(
            size: const Size(280, 280),
            painter: _HoloRingPainter(_ringAnim.value, _stateColor),
          ),
        ),

        // Radial pulse glow
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 195 * _pulseAnim.value,
            height: 195 * _pulseAnim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_cyan.withOpacity(0.07), Colors.transparent],
              ),
            ),
          ),
        ),

        // Avatar — UNCHANGED
        ClipRect(
          child: Align(
            alignment: const Alignment(0, -0.3),
            heightFactor: 0.72,
            widthFactor: 1.0,
            child: LuckyAvatar(key: _avatarKey, state: currentState),
          ),
        ),
      ],
    );
  }

  // ── Response card ─────────────────────────────────────────────────────────
  Widget _buildResponseCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _bgCard,
          border: Border.all(color: _cyan.withOpacity(0.20), width: 1),
          boxShadow: [
            BoxShadow(
              color: _cyan.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _stateColor,
                        boxShadow: [
                          BoxShadow(color: _stateColor, blurRadius: 5),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "L.U.C.K.Y SAYS",
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        color: _cyan.withOpacity(0.75),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _stateColor.withOpacity(0.10),
                        border: Border.all(
                          color: _stateColor.withOpacity(0.38),
                        ),
                      ),
                      child: Text(
                        _stateLabel,
                        style: TextStyle(
                          fontSize: 7,
                          letterSpacing: 1.2,
                          color: _stateColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.more_horiz,
                  color: _cyan.withOpacity(0.25),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Response text with fade transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                key: ValueKey(_text),
                _text.isEmpty ? "All systems operational." : _text,
                style: const TextStyle(
                  color: _white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            _WaveformWidget(
              state: currentState,
              color1: _cyan,
              color2: _cyanLight,
            ),
            const SizedBox(height: 10),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip("SPEECH INPUT", _speechInputLabel),
                _statChip("NOISE FILTER", "ON"),
                _statChip("EMOTION SYNC", "STABLE"),
                _statChip("RESPONSE", _responseTime),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Type input ────────────────────────────────────────────────────────────
  Widget _buildTypeInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _bgCard,
          border: Border.all(color: _cyan.withOpacity(0.32), width: 1),
          boxShadow: [
            BoxShadow(color: _cyan.withOpacity(0.07), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _typeController,
                focusNode: _typeFocus,
                style: const TextStyle(color: _white, fontSize: 14),
                cursorColor: _cyan,
                decoration: InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(
                    color: _cyan.withOpacity(0.28),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendTyped(),
                textInputAction: TextInputAction.send,
              ),
            ),
            GestureDetector(
              onTap: _sendTyped,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_cyan, _blue]),
                  boxShadow: [
                    BoxShadow(color: _cyan.withOpacity(0.38), blurRadius: 10),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action row: keyboard toggle + mic button ──────────────────────────────
  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Keyboard toggle — holographic icon style
          GestureDetector(
            onTap: () {
              setState(() {
                _showTyping = !_showTyping;
              });
              if (_showTyping) {
                Future.delayed(
                  const Duration(milliseconds: 100),
                  () => _typeFocus.requestFocus(),
                );
              } else {
                _typeFocus.unfocus();
              }
            },
            child: _HoloIcon(
              icon: _showTyping
                  ? Icons.keyboard_hide_rounded
                  : Icons.keyboard_rounded,
              color: _showTyping ? _cyan : _blue,
              size: 52,
              active: _showTyping,
            ),
          ),

          const SizedBox(width: 28),

          // Mic button — centre-stage, glowing rings
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
                    // Outer pulse ring
                    if (active)
                      Container(
                        width: 98 + 16 * _pulseAnim.value,
                        height: 98 + 16 * _pulseAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _cyan.withOpacity(0.14 * _pulseAnim.value),
                            width: 1.5,
                          ),
                        ),
                      ),
                    // Mid ring
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? _cyan.withOpacity(0.06)
                            : Colors.transparent,
                        border: Border.all(
                          color: _stateColor.withOpacity(0.30),
                          width: 1,
                        ),
                      ),
                    ),
                    // Core button
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bgPanel,
                        border: Border.all(
                          color: _stateColor.withOpacity(0.65),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _stateColor.withOpacity(
                              active ? 0.50 : 0.28,
                            ),
                            blurRadius: active ? 26 * _pulseAnim.value : 14,
                            spreadRadius: active ? 2 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        active ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _stateColor,
                        size: 28,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 28),
          // Spacer for symmetry
          const SizedBox(width: 52, height: 52),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _statChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 6,
            letterSpacing: 1,
            color: _cyan.withOpacity(0.4),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _cyan,
            fontFamily: 'monospace',
            shadows: [Shadow(color: _cyan.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  // ── Sidebar UI (new) ────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _bgPanel,
          border: Border(right: BorderSide(color: _cyan.withOpacity(0.15))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [_cyanLight, _cyan, _blue],
                      ).createShader(b),
                      child: const Text(
                        "L.U.C.K.Y",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _closeSidebar,
                      child: Icon(
                        Icons.close_rounded,
                        color: _cyan.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // New chat button
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: GestureDetector(
                  onTap: () {
                    _closeSidebar();
                    // TODO: hook up new-chat logic
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _cyan.withOpacity(0.10),
                      border: Border.all(color: _cyan.withOpacity(0.45)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: _cyan, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "New Chat",
                          style: TextStyle(
                            color: _cyan,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "HISTORY",
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: _cyan.withOpacity(0.4),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Chat history list
              Expanded(
                child: _chatHistory.isEmpty
                    ? Center(
                        child: Text(
                          "No conversations yet",
                          style: TextStyle(
                            color: _cyan.withOpacity(0.3),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _chatHistory.length,
                        itemBuilder: (context, index) {
                          final title = _chatHistory[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                _closeSidebar();
                                // TODO: hook up load-chat logic
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: _cyan.withOpacity(0.55),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _white.withOpacity(0.85),
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              Divider(color: _cyan.withOpacity(0.12), height: 1),

              // Profile menu popup (shown above the profile row)
              if (_profileMenuOpen) _buildProfileMenuItems(),

              // Profile button
              ProfileHeader(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItems() {
    Widget item(IconData icon, String label, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: _cyan.withOpacity(0.65), size: 17),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: _white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(Icons.settings_outlined, "Settings", () {
            _closeSidebar();
            // TODO: navigate to Settings screen
          }),
          item(Icons.language_rounded, "Language", () {
            _closeSidebar();
            // TODO: navigate to Language screen
          }),
          item(Icons.help_outline_rounded, "Get help", () {
            _closeSidebar();
            // TODO: navigate to Get help screen
          }),
          item(Icons.info_outline_rounded, "Learn more", () {
            _closeSidebar();
            // TODO: navigate to Learn more screen
          }),
          Divider(color: _cyan.withOpacity(0.12), height: 1),
          item(Icons.logout_rounded, "Logout", () {
            _closeSidebar();
            // TODO: hook up logout logic
          }),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const n = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return n[m - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

/// Deep space background with city-glow effect (matches reference image dark BG)
class _SpaceBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base dark fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF03060F),
    );

    // Blue glow at top center — mimics the reference image's background radiance
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.0,
          colors: [
            const Color(0xFF0A84FF).withOpacity(0.10),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Subtle grid lines
    final grid = Paint()
      ..color = const Color(0xFF0A84FF).withOpacity(0.03)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 36)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 36)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);

    // Tiny star dots in upper half
    final star = Paint()..color = const Color(0xFF60E8FF).withOpacity(0.10);
    final rng = Random(99);
    for (int i = 0; i < 28; i++) {
      canvas.drawCircle(
        Offset(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height * 0.55,
        ),
        0.7,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Holographic rotating ring — matches the circular UI arcs in the reference image
class _HoloRingPainter extends CustomPainter {
  final double t;
  final Color color;
  _HoloRingPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    void arc(double r, double start, double sweep, Color c, double w) =>
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start,
          sweep,
          false,
          Paint()
            ..color = c
            ..strokeWidth = w
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );

    void ring(double r, Color c) => canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = c
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );

    final a = t * 2 * pi;
    const baseBlue = Color(0xFF0A84FF);

    // Static rings
    ring(132, color.withOpacity(0.06));
    ring(108, baseBlue.withOpacity(0.07));
    ring(86, color.withOpacity(0.05));

    // Rotating arcs — matches reference image's circular holographic UI
    arc(132, a, pi * 0.62, color.withOpacity(0.48), 1.5);
    arc(132, a + pi, pi * 0.38, baseBlue.withOpacity(0.32), 1.5);
    arc(108, -a * 0.75, pi * 0.50, color.withOpacity(0.26), 1.0);
    arc(108, -a * 0.75 + pi, pi * 0.28, baseBlue.withOpacity(0.20), 0.8);

    // Cardinal tick marks
    for (int i = 0; i < 4; i++) {
      final angle = i * pi / 2 + a * 0.04;
      canvas.drawLine(
        Offset(cx + cos(angle) * 124, cy + sin(angle) * 124),
        Offset(cx + cos(angle) * 136, cy + sin(angle) * 136),
        Paint()
          ..color = color.withOpacity(0.55)
          ..strokeWidth = 1.5,
      );
    }

    // Orbiting dots
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 + a * 0.18;
      canvas.drawCircle(
        Offset(cx + cos(angle) * 132, cy + sin(angle) * 132),
        1.8,
        Paint()..color = color.withOpacity(0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_HoloRingPainter old) => old.t != t || old.color != color;
}
