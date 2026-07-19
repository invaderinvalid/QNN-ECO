import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum ListeningEventType { ready, listening, partial, finalResult, idle, error }

class ListeningEvent {
  const ListeningEvent(this.type, {this.text = '', this.error});

  final ListeningEventType type;
  final String text;
  final String? error;
}

/// Owns one speech-recognition instance for the full app session.
class ListeningService {
  final _speech = stt.SpeechToText();
  final _events = StreamController<ListeningEvent>.broadcast();
  String _lastFinalText = '';
  String _latestTranscript = '';
  bool _available = false;

  Stream<ListeningEvent> get events => _events.stream;
  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    _available = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    _events.add(
      ListeningEvent(
        _available ? ListeningEventType.ready : ListeningEventType.error,
        error: _available ? null : 'Speech recognition is unavailable.',
      ),
    );
    return _available;
  }

  Future<void> start() async {
    if (!_available || _speech.isListening) return;
    _lastFinalText = '';
    _latestTranscript = '';
    try {
      _events.add(const ListeningEvent(ListeningEventType.listening));
      await _speech.listen(
        onResult: _onResult,
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } on Object catch (error) {
      _events.add(ListeningEvent(ListeningEventType.error, error: '$error'));
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  Future<void> cancel() async {
    if (_speech.isListening) await _speech.cancel();
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    _latestTranscript = text;
    if (!result.finalResult) {
      _events.add(ListeningEvent(ListeningEventType.partial, text: text));
      return;
    }
    _emitFinalResult(text);
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _events.add(const ListeningEvent(ListeningEventType.listening));
    } else if (status == 'done' || status == 'notListening') {
      // Android can finish a recognition session after reporting only partial
      // results. Promote the final partial transcript before announcing idle,
      // otherwise the conversation controller has nothing to send to the LLM.
      _emitFinalResult(_latestTranscript);
      _events.add(const ListeningEvent(ListeningEventType.idle));
    }
  }

  void _emitFinalResult(String text) {
    if (text.isEmpty || text == _lastFinalText) return;
    _lastFinalText = text;
    _events.add(ListeningEvent(ListeningEventType.finalResult, text: text));
  }

  void _onError(SpeechRecognitionError error) {
    _events.add(
      ListeningEvent(ListeningEventType.error, error: error.errorMsg),
    );
  }

  Future<void> dispose() async {
    await cancel();
    await _events.close();
  }
}
