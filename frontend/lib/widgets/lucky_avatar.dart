import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/lucky_state.dart';

class LuckyAvatar extends StatefulWidget {
  final LuckyState state;
  const LuckyAvatar({super.key, required this.state});

  @override
  State<LuckyAvatar> createState() => LuckyAvatarState();
}

class LuckyAvatarState extends State<LuckyAvatar> {
  InAppWebViewController? _webViewController;
  String? _vrmBase64;
  bool _vrmReady = false; // true only after VRM fully parsed in JS
  bool _pageLoaded = false; // true after HTML page load fires
  final List<String> _jsQueue = [];

  // Lip sync
  Timer? _ampTimer;
  double _ampPhase = 0.0;
  final Random _rand = Random();
  bool _isTalkingLocally = false;

  @override
  void initState() {
    super.initState();
    _loadVrm();
  }

  @override
  void dispose() {
    _ampTimer?.cancel();
    super.dispose();
  }

  // ── Load VRM bytes ───────────────────────────────────────────────────────
  Future<void> _loadVrm() async {
    final bytes = await rootBundle.load('assets/avatar/Lucky.vrm');
    _vrmBase64 = base64Encode(bytes.buffer.asUint8List());
    // If page already loaded before VRM finished encoding, send now
    if (_pageLoaded && !_vrmReady) _sendVrmChunks();
  }

  // ── Send VRM in async chunks so UI thread is never blocked ──────────────
  Future<void> _sendVrmChunks() async {
    if (_vrmBase64 == null || _webViewController == null) return;

    const chunkSize = 300000;
    final total = _vrmBase64!.length;

    await _webViewController!.evaluateJavascript(
      source: "window.vrmChunks=[]; window.vrmTotal=$total;",
    );

    int offset = 0;
    while (offset < total) {
      final end = (offset + chunkSize > total) ? total : offset + chunkSize;
      final chunk = _vrmBase64!.substring(offset, end);
      final isLast = end >= total;

      await _webViewController!.evaluateJavascript(
        source: isLast
            ? "window.vrmChunks.push('$chunk'); window.receiveVRM(window.vrmChunks.join(''));"
            : "window.vrmChunks.push('$chunk');",
      );

      offset = end;
      if (!isLast) await Future.delayed(const Duration(milliseconds: 8));
    }
  }

  // ── Called by JS handler 'onVRMReady' ────────────────────────────────────
  void _onVRMReady() {
    _vrmReady = true;
    _flushQueue();
  }

  void _flushQueue() {
    for (final code in _jsQueue) {
      _webViewController?.evaluateJavascript(source: code);
    }
    _jsQueue.clear();
  }

  // ── State changes ────────────────────────────────────────────────────────
  @override
  void didUpdateWidget(LuckyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sendState(widget.state);
  }

  void _sendState(LuckyState state) {
    final msg = jsonEncode({'type': 'setState', 'state': state.name});
    final escaped = msg.replaceAll("'", "\\'");
    _js("window.dispatchEvent(new MessageEvent('message',{data:'$escaped'}));");
  }

  // ── Public API ───────────────────────────────────────────────────────────

  void startTalking() {
    _isTalkingLocally = true;
    _js("window.startTalking('neutral')");
    _startAmplitude();
  }

  void stopTalking() {
    _isTalkingLocally = false;
    _stopAmplitude();
    _js("window.setAmplitude(0)");
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_isTalkingLocally) _js("window.stopTalking()");
    });
  }

  void setThinking(bool active) {
    _js("window.setThinkingPose(${active ? 'true' : 'false'})");
  }

  void pushJs(String code) => _js(code);

  /// Called by TTSService amplitude callback
  void pushAmplitude(double amp) {
    if (!_isTalkingLocally) return;
    _js("window.setAmplitude($amp)");
  }

  // ── JS bridge — queues until VRM ready ──────────────────────────────────
  void _js(String code) {
    if (_vrmReady && _webViewController != null) {
      _webViewController!.evaluateJavascript(source: code);
    } else {
      if (code.startsWith("window.setAmplitude")) {
        _jsQueue.removeWhere((c) => c.startsWith("window.setAmplitude"));
      }
      _jsQueue.add(code);
    }
  }

  // ── Amplitude simulation ─────────────────────────────────────────────────
  void _startAmplitude() {
    _ampTimer?.cancel();
    _ampPhase = 0.0;
    _ampTimer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!_isTalkingLocally) {
        t.cancel();
        _ampTimer = null;
        return;
      }
      _ampPhase += 0.06;

      final syllable = 0.38 * sin(_ampPhase * 1.9);
      final word = 0.22 * sin(_ampPhase * 6.9);
      final flutter = 0.10 * sin(_ampPhase * 22.0);
      final noise = 0.05 * (_rand.nextDouble() - 0.5);
      final breath = 0.5 + 0.5 * sin(_ampPhase * 0.4);

      final amp = ((syllable + word + flutter + noise) * breath + 0.30).clamp(
        0.04,
        0.95,
      );

      _js("window.setAmplitude($amp)");
    });
  }

  void _stopAmplitude() {
    _ampTimer?.cancel();
    _ampTimer = null;
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: InAppWebView(
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowFileAccess: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          // FIX: useHybridComposition: false — hybrid composition causes the
          // WebView surface to be destroyed when the soft keyboard opens,
          // which crashes/blanks the VRM view on Adreno GPUs (Moto g96 5G).
          // Setting to false uses the standard TextureView path which is
          // stable with keyboard open/close events.
          useHybridComposition: false, // ← FIXED (was true)
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;

          controller.addJavaScriptHandler(
            handlerName: 'onVRMReady',
            callback: (_) => _onVRMReady(),
          );

          _loadHtml();
        },
        onLoadStop: (controller, url) async {
          _pageLoaded = true;
          if (_vrmBase64 != null) {
            await _sendVrmChunks();
          }
          _sendState(widget.state);
        },
        onConsoleMessage: (controller, msg) {
          // Only log warnings/errors to reduce logcat noise
          if (msg.messageLevel == ConsoleMessageLevel.WARNING ||
              msg.messageLevel == ConsoleMessageLevel.ERROR) {
            debugPrint('[WebView] ${msg.message}');
          }
        },
        onReceivedError: (controller, request, error) =>
            debugPrint('[WebView ERROR] ${error.description}'),
      ),
    );
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString('assets/avatar/lucky_viewer.html');
    await _webViewController?.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: WebUri('file:///android_asset/flutter_assets/assets/avatar/'),
      historyUrl: WebUri(
        'file:///android_asset/flutter_assets/assets/avatar/lucky_viewer.html',
      ),
    );
  }
}
