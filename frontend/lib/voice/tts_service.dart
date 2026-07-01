// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class TTSService {
  // ── ElevenLabs Config ───────────────────────────────────────
  static const _apiKey =
      'bf4c4ac232903a6cbd5afc7c8666a8f5cb08dea956ca721f2fbc93dea717ea90';
  static const _voiceId = 'pzZexJdfzglTIPEvNIei'; // Aria
  static const _model = 'eleven_turbo_v2';

  final AudioPlayer _player = AudioPlayer();
  bool isSpeaking = false;

  // ── Callbacks ───────────────────────────────────────────────
  VoidCallback? _startCallback;
  VoidCallback? _completionCallback;
  Function(String)? _errorCallback;
  Function(double)? onAmplitude;

  void setStartHandler(VoidCallback fn) => _startCallback = fn;
  void setCompletionHandler(VoidCallback fn) => _completionCallback = fn;
  void setErrorHandler(Function(String) fn) => _errorCallback = fn;

  // Amplitude timer
  Timer? _ampTimer;
  double _ampPhase = 0.0;
  final Random _rand = Random();

  Future<void> init() async {
    _player.playerStateStream.listen((state) {
      final playing =
          state.playing && state.processingState != ProcessingState.completed;

      if (playing && !isSpeaking) {
        isSpeaking = true;
        _startCallback?.call();
        _startAmplitude();
      }

      if (!playing && isSpeaking) {
        isSpeaking = false;
        _stopAmplitude();
        _completionCallback?.call();
      }
    });
  }

  // ── Speak ───────────────────────────────────────────────────
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await stop();
      debugPrint('[TTS] Fetching Aria voice...');

      final bytes = await _fetchAudio(text);
      if (bytes == null) {
        _errorCallback?.call('Failed to fetch audio');
        return;
      }

      debugPrint('[TTS] Playing ${bytes.length} bytes');
      await _player.setAudioSource(_BytesSource(bytes));
      await _player.play();
    } catch (e) {
      debugPrint('[TTS] Error: $e');
      isSpeaking = false;
      _stopAmplitude();
      _errorCallback?.call(e.toString());
    }
  }

  // ── ElevenLabs API ──────────────────────────────────────────
  // Future<Uint8List?> _fetchAudio(String text) async {
  //   try {
  //     final res = await http.post(
  //       Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
  //       headers: {
  //         'xi-api-key': _apiKey,
  //         'Content-Type': 'application/json',
  //         'Accept': 'audio/mpeg',
  //       },
  //       body: jsonEncode({
  //         'text': text,
  //         'model_id': _model,
  //         'voice_settings': {
  //           'stability': 0.5,
  //           'similarity_boost': 0.75,
  //           'style': 0.0,
  //           'use_speaker_boost': true,
  //         },
  //       }),
  //     );

  //     if (res.statusCode == 200) return res.bodyBytes;
  //     debugPrint('[TTS] API error: ${res.statusCode} ${res.body}');
  //     return null;
  //   } catch (e) {
  //     debugPrint('[TTS] Fetch error: $e');
  //     return null;
  //   }
  // }

Future<Uint8List?> _fetchAudio(String text) async {
  try {
    final res = await http.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
      headers: {
        'xi-api-key': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': _model,
      }),
    );

    print("STATUS = ${res.statusCode}");
    print("HEADERS = ${res.headers}");
    print("BODY = ${res.body}");

    if (res.statusCode == 200) {
      return res.bodyBytes;
    }

    return null;
  } catch (e) {
    print(e);
    return null;
  }
}
  // ── Amplitude simulation ─────────────────────────────────────
  void _startAmplitude() {
    _ampTimer?.cancel();
    _ampPhase = 0.0;
    _ampTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      _ampPhase += 0.04;
      final amp =
          (0.45 +
                  0.30 * sin(_ampPhase * 4.1) +
                  0.15 * sin(_ampPhase * 9.3) +
                  0.10 * sin(_ampPhase * 17.7) +
                  0.05 * (_rand.nextDouble() - 0.5))
              .clamp(0.05, 1.0);
      onAmplitude?.call(amp);
    });
  }

  void _stopAmplitude() {
    _ampTimer?.cancel();
    _ampTimer = null;
    onAmplitude?.call(0.0);
  }

  // ── Stop ────────────────────────────────────────────────────
  Future<void> stop() async {
    _stopAmplitude();
    isSpeaking = false;
    await _player.stop();
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}

// ── In-memory audio source ───────────────────────────────────
class _BytesSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesSource(this._bytes) : super(tag: 'AriaVoice');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
