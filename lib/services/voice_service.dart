import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Produces spoken replies and exposes speech state to the conversation UI.
class VoiceService {
  final _tts = FlutterTts();
  final isSpeaking = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.38);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((_) => isSpeaking.value = false);
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    isSpeaking.value = true;
    try {
      await _tts.speak(text, focus: true);
    } finally {
      isSpeaking.value = false;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeaking.value = false;
  }

  Future<void> dispose() async {
    await stop();
    isSpeaking.dispose();
  }
}
