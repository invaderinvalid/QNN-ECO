import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/model_spec.dart';
import '../core/services/geniex_bridge.dart';
import 'brain_service.dart';
import 'listening_service.dart';
import 'voice_service.dart';

enum VoiceConversationPhase {
  starting,
  listening,
  thinking,
  speaking,
  paused,
  error,
}

/// Coordinates listening → local LLM → voice output while preserving one thread.
class VoiceConversationController extends ChangeNotifier {
  VoiceConversationController({
    required GenieXBridge bridge,
    required ModelSpec model,
  }) : _listening = ListeningService(),
       _voice = VoiceService(),
       _brain = BrainService(bridge: bridge, model: model) {
    _listeningSubscription = _listening.events.listen(_onListeningEvent);
    _brain.thread.addListener(_onThreadChanged);
  }

  final ListeningService _listening;
  final VoiceService _voice;
  final BrainService _brain;
  late final StreamSubscription<ListeningEvent> _listeningSubscription;
  Timer? _restartTimer;
  Timer? _silenceTimer;
  VoiceConversationPhase _phase = VoiceConversationPhase.starting;
  String _liveTranscript = '';
  String? _error;
  bool _shouldListen = false;
  bool _silenced = false;
  bool _focusLockActive = false;
  bool _disposed = false;

  ChatThread get thread => _brain.thread;
  VoiceConversationPhase get phase => _phase;
  String get liveTranscript => _liveTranscript;
  String? get error => _error;
  bool get isListening => _phase == VoiceConversationPhase.listening;
  bool get isSilenced => _silenced;
  bool get isBusy =>
      _phase == VoiceConversationPhase.thinking ||
      _phase == VoiceConversationPhase.speaking;

  Future<void> initialize() async {
    await _brain.initialize();
    await _voice.initialize();
    final speechAvailable = await _listening.initialize();
    if (!speechAvailable) {
      _setPhase(
        VoiceConversationPhase.error,
        error: 'Microphone or speech recognition is unavailable.',
      );
      return;
    }
    _shouldListen = true;
    await _beginListening();
  }

  Future<void> pause() async {
    _silenceTimer?.cancel();
    _silenced = false;
    _shouldListen = false;
    _restartTimer?.cancel();
    await _listening.stop();
    _setPhase(VoiceConversationPhase.paused);
  }

  Future<void> resume() async {
    _silenceTimer?.cancel();
    _silenced = false;
    _shouldListen = true;
    await _voice.stop();
    _setPhase(VoiceConversationPhase.paused);
    await _beginListening();
  }

  /// Focus lock keeps recognition alive but ignores speech until the wake word.
  Future<void> setFocusLock(bool active) async {
    _focusLockActive = active;
    if (active) {
      _shouldListen = true;
      await _voice.stop();
      if (!isBusy && !_silenced) await _beginListening();
    }
  }

  Future<void> interruptAndListen() async {
    _silenceTimer?.cancel();
    _silenced = false;
    await _voice.stop();
    _shouldListen = true;
    _setPhase(VoiceConversationPhase.paused);
    await _beginListening();
  }

  Future<void> submitText(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || isBusy) return;
    await _handleUtterance(prompt);
  }

  Future<void> _beginListening() async {
    if (_disposed ||
        _silenced ||
        !_shouldListen ||
        isBusy ||
        !_listening.isAvailable) {
      return;
    }
    _liveTranscript = '';
    _setPhase(VoiceConversationPhase.listening);
    await _listening.start();
  }

  void _onListeningEvent(ListeningEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case ListeningEventType.partial:
        _liveTranscript = event.text;
        notifyListeners();
        break;
      case ListeningEventType.finalResult:
        _restartTimer?.cancel();
        if (_focusLockActive && !_hasWakePrefix(event.text)) {
          _liveTranscript = '';
          _scheduleListeningRestart();
          return;
        }
        final utterance = _focusLockActive
            ? _removeWakePrefix(event.text)
            : event.text.trim();
        unawaited(_handleUtterance(utterance));
        break;
      case ListeningEventType.idle:
        if (_shouldListen && !isBusy) {
          _scheduleListeningRestart();
        }
        break;
      case ListeningEventType.error:
        // Recognition errors are common during continuous listening. Keep them
        // silent and return to the recognizer instead of speaking an error.
        if (_shouldListen) {
          _setPhase(VoiceConversationPhase.paused);
          _scheduleListeningRestart();
        } else {
          _setPhase(VoiceConversationPhase.error, error: event.error);
        }
        break;
      case ListeningEventType.ready:
      case ListeningEventType.listening:
        break;
    }
  }

  Future<void> _handleUtterance(String utterance) async {
    if (_disposed || isBusy) return;
    if (_isShutUpCommand(utterance)) {
      await silenceForAtLeast30Seconds();
      return;
    }
    _liveTranscript = utterance;
    _setPhase(VoiceConversationPhase.thinking);
    await _listening.stop();
    try {
      final reply = await _brain.ask(utterance);
      if (_disposed) return;
      if (reply.trim().isNotEmpty) {
        _setPhase(VoiceConversationPhase.speaking);
        await _voice.speak(reply);
      }
    } on Object catch (error) {
      if (!_disposed) {
        _setPhase(VoiceConversationPhase.error, error: '$error');
      }
    } finally {
      // A turn pauses the recognizer only while the local brain and TTS own
      // the microphone. Preserve an explicit user pause, but otherwise return
      // to continuous listening after both successful and failed turns.
      if (!_disposed && _shouldListen) {
        _setPhase(VoiceConversationPhase.paused);
        await _beginListening();
      }
    }
  }

  void _scheduleListeningRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_beginListening());
    });
  }

  /// Local safety command. It never reaches the LLM or produces a spoken reply.
  Future<void> silenceForAtLeast30Seconds() async {
    _silenceTimer?.cancel();
    _silenced = true;
    _shouldListen = false;
    _restartTimer?.cancel();
    await _voice.stop();
    await _listening.stop();
    _liveTranscript = '';
    _setPhase(VoiceConversationPhase.paused);
    _silenceTimer = Timer(const Duration(seconds: 30), () {
      if (_disposed) return;
      _silenced = false;
      _shouldListen = true;
      unawaited(_beginListening());
    });
  }

  /// In lockdown, every actionable utterance must start with the exact word
  /// "Hello". A later occurrence (for example, "can you say hello") is ignored.
  bool _hasWakePrefix(String text) =>
      RegExp(r'^\s*hello\b', caseSensitive: false).hasMatch(text);

  String _removeWakePrefix(String text) {
    final command = text
        .replaceFirst(
          RegExp(r'^\s*hello\b[\s,.:;!?-]*', caseSensitive: false),
          '',
        )
        .trim();
    return command.isEmpty ? 'Hello' : command;
  }

  bool _isShutUpCommand(String text) => RegExp(
    r'\b(shut\s*up|be\s*quiet|stop\s*listening)\b',
    caseSensitive: false,
  ).hasMatch(text);

  void _onThreadChanged() {
    if (!_disposed) notifyListeners();
  }

  void _setPhase(VoiceConversationPhase value, {String? error}) {
    _phase = value;
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _restartTimer?.cancel();
    _silenceTimer?.cancel();
    _brain.thread.removeListener(_onThreadChanged);
    unawaited(_listeningSubscription.cancel());
    unawaited(_listening.dispose());
    unawaited(_voice.dispose());
    unawaited(_brain.dispose());
    super.dispose();
  }
}
