import 'dart:convert';
import 'package:flutter/material.dart';
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

  @override
  void didUpdateWidget(LuckyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _sendState(widget.state);
    }
  }

  /// Send the current LuckyState to the JS avatar
  void _sendState(LuckyState state) {
    final msg = jsonEncode({
      'type': 'setState',
      'state': state.name, // 'idle' | 'listening' | 'thinking' | 'talking'
    });
    _webViewController?.evaluateJavascript(source: '''
      window.dispatchEvent(new MessageEvent('message', { data: '$msg' }));
    ''');
  }

  /// Call this from HomeScreen when TTS starts
  void startTalking() {
    _webViewController?.evaluateJavascript(source: '''
      window.dispatchEvent(new MessageEvent('message', {
        data: JSON.stringify({ type: 'startTalking' })
      }));
    ''');
  }

  /// Call this from HomeScreen when TTS stops
  void stopTalking() {
    _webViewController?.evaluateJavascript(source: '''
      window.dispatchEvent(new MessageEvent('message', {
        data: JSON.stringify({ type: 'stopTalking' })
      }));
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 420,
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri.uri(Uri.parse('about:blank')),
        ),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (controller) {
  _webViewController = controller;

  controller.loadFile(
    assetFilePath: 'assets/avatar/lucky_viewer.html',
  );
},
        },
        onLoadStop: (controller, url) {
          // Send initial state once page is loaded
          _sendState(widget.state);
        },
        onConsoleMessage: (controller, msg) {
          debugPrint('[WebView] ${msg.message}');
        },
      ),
    );
  }
}