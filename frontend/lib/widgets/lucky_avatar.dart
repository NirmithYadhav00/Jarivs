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
  bool _vrmReady = false;

  // Lip sync amplitude simulation
  Timer? _ampTimer;
  double _ampPhase = 0.0;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    _loadVrmAsBase64();
  }

  @override
  void dispose() {
    _ampTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVrmAsBase64() async {
    final bytes = await rootBundle.load('assets/avatar/Lucky.vrm');
    _vrmBase64 = base64Encode(bytes.buffer.asUint8List());
  }

  @override
  void didUpdateWidget(LuckyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _sendState(widget.state);
    }
  }

  void _sendState(LuckyState state) {
    final msg = jsonEncode({'type': 'setState', 'state': state.name});
    _webViewController?.evaluateJavascript(
      source:
          "window.dispatchEvent(new MessageEvent('message', {data:'$msg'}));",
    );
  }

  // Called by TTSService.setStartHandler
  void startTalking() {
    _js("window.startTalking('neutral')");
    _startAmplitude();
  }

  // Called by TTSService.setCompletionHandler
  void stopTalking() {
    _stopAmplitude();
    _js("window.setAmplitude(0)");
    // Small delay so mouth closes smoothly
    Future.delayed(const Duration(milliseconds: 150), () {
      _js("window.stopTalking()");
    });
  }

  // Public JS executor for direct calls from home_screen
  void setThinking(bool active) {
    _js("window.setThinkingPose(${active ? 'true' : 'false'})");
  }

  void pushJs(String code) => _js(code);

  // Called by home_screen amplitude callback
  void pushAmplitude(double amp) {
    _js("window.setAmplitude($amp)");
  }

  void _js(String code) {
    _webViewController?.evaluateJavascript(source: code);
  }

  // Simulate amplitude since flutter_tts has no audio stream
  // Uses layered sine waves to mimic natural speech rhythm
  void _startAmplitude() {
    _ampTimer?.cancel();
    _ampPhase = 0.0;
    _ampTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      _ampPhase += 0.04;
      // Layered sines = natural speech-like movement
      final amp =
          (0.45 +
                  0.30 * sin(_ampPhase * 4.1) +
                  0.15 * sin(_ampPhase * 9.3) +
                  0.10 * sin(_ampPhase * 17.7) +
                  0.05 * (_rand.nextDouble() - 0.5))
              .clamp(0.05, 1.0);
      _js("window.setAmplitude($amp)");
    });
  }

  void _stopAmplitude() {
    _ampTimer?.cancel();
    _ampTimer = null;
  }

  void _onPageReady() {
    if (_vrmBase64 == null) return;
    const chunkSize = 500000;
    final total = _vrmBase64!.length;
    int offset = 0;

    _webViewController?.evaluateJavascript(
      source: "window.vrmChunks = []; window.vrmTotal = $total;",
    );

    while (offset < total) {
      final end = (offset + chunkSize > total) ? total : offset + chunkSize;
      final chunk = _vrmBase64!.substring(offset, end);
      final isLast = end >= total;
      _webViewController?.evaluateJavascript(
        source:
            """
          window.vrmChunks.push('$chunk');
          ${isLast ? 'window.receiveVRM(window.vrmChunks.join(""));' : ''}
        """,
      );
      offset = end;
    }
    _vrmReady = true;
  }

  Future<void> _loadHtmlWithBase() async {
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
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          controller.addJavaScriptHandler(
            handlerName: 'onReady',
            callback: (args) => _onPageReady(),
          );
          _loadHtmlWithBase();
        },
        onLoadStop: (controller, url) => _sendState(widget.state),
        onConsoleMessage: (controller, msg) =>
            debugPrint('[WebView] \${msg.message}'),
        onReceivedError: (controller, request, error) =>
            debugPrint('[WebView ERROR] \${error.description}'),
      ),
    );
  }
}
