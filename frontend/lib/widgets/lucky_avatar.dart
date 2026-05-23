import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/lucky_state.dart';

class LuckyAvatar extends StatefulWidget {
  final LuckyState state;

  const LuckyAvatar({
    super.key,
    required this.state,
  });

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

  void _sendState(LuckyState state) {
    final msg = jsonEncode({
      "type": "setState",
      "state": state.name,
    });

    _webViewController?.evaluateJavascript(
      source: """
      window.dispatchEvent(
        new MessageEvent(
          'message',
          {data:'$msg'}
        )
      );
      """,
    );
  }

  void startTalking() {
    _webViewController?.evaluateJavascript(
      source: """
      window.dispatchEvent(
        new MessageEvent(
          'message',
          {
            data: JSON.stringify({
              type:'startTalking'
            })
          }
        )
      );
      """,
    );
  }

  void stopTalking() {
    _webViewController?.evaluateJavascript(
      source: """
      window.dispatchEvent(
        new MessageEvent(
          'message',
          {
            data: JSON.stringify({
              type:'stopTalking'
            })
          }
        )
      );
      """,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 420,

      child: InAppWebView(
        initialFile: "assets/avatar/lucky_viewer.html",

        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),

        onWebViewCreated: (controller) {
          _webViewController = controller;
        },

        onLoadStop: (controller, url) {
          _sendState(widget.state);
        },

        onConsoleMessage: (controller, consoleMessage) {
          debugPrint(
            "[WebView] ${consoleMessage.message}",
          );
        },
      ),
    );
  }
}