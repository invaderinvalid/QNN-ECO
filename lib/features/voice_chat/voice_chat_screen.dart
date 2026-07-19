import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/model_spec.dart';
import '../../core/services/geniex_bridge.dart';
import '../model_setup/model_setup_screen.dart';
import '../notification_triage/notification_triage_screen.dart';
import '../uno_q_lamp/uno_q_lamp_screen.dart';
import '../../services/voice_conversation_controller.dart';
import '../../services/focus_state_service.dart';
import '../../services/face_tracking_service.dart';
import '../../widgets/agent_face.dart';
import '../../widgets/chat_bubble.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key, required this.bridge, required this.model});

  final GenieXBridge bridge;
  final ModelSpec model;

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  late final VoiceConversationController _controller;
  final _textInput = TextEditingController();
  final _focusState = FocusStateService();
  late final FaceTrackingService _faceTracking;
  StreamSubscription<FocusState>? _focusSubscription;
  StreamSubscription<FacePosition>? _faceSubscription;
  bool _systemFocusLockActive = false;
  bool _demoFocusLockActive = false;
  FacePosition _facePosition = const FacePosition.idle();

  bool get _focusLockActive => _systemFocusLockActive || _demoFocusLockActive;

  @override
  void initState() {
    super.initState();
    _controller = VoiceConversationController(
      bridge: widget.bridge,
      model: widget.model,
    )..addListener(_refresh);
    _controller.initialize();
    _faceTracking = FaceTrackingService();
    _faceSubscription = _faceTracking.positions.listen((position) {
      if (mounted) setState(() => _facePosition = position);
    });
    _focusSubscription = _focusState.states.listen(_onFocusState);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _textInput.dispose();
    _focusSubscription?.cancel();
    _faceSubscription?.cancel();
    unawaited(_faceTracking.dispose());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onFocusState(FocusState state) {
    final wasActive = _focusLockActive;
    _systemFocusLockActive = state.active;
    final changed = wasActive != _focusLockActive;
    if (changed) {
      unawaited(_applyFocusLock(_focusLockActive));
    }
    if (mounted) setState(() {});
  }

  Future<void> _startDemoLockdown() async {
    if (_demoFocusLockActive) return;
    final wasActive = _focusLockActive;
    setState(() => _demoFocusLockActive = true);
    if (!wasActive) await _applyFocusLock(true);
  }

  Future<void> _exitDemoLockdown() async {
    if (!_demoFocusLockActive) return;
    _demoFocusLockActive = false;
    if (!_systemFocusLockActive) await _applyFocusLock(false);
    // LIVE mode means no voice processing runs until the user starts it again.
    await _controller.pause();
    if (mounted) setState(() {});
  }

  Future<void> _applyFocusLock(bool active) async {
    if (active) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await _faceTracking.start();
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _faceTracking.stop();
    }
    await _controller.setFocusLock(active);
  }

  Future<void> _submitTypedText() async {
    final text = _textInput.text.trim();
    if (text.isEmpty) return;
    _textInput.clear();
    await _controller.submitText(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_focusLockActive) {
      return PopScope(
        canPop: false,
        child: _FocusLockScreen(
          listening: _controller.isListening,
          transcript: _controller.liveTranscript,
          position: _facePosition,
          phase: _controller.phase,
          showLiveExit: _demoFocusLockActive,
          onLiveExit: _exitDemoLockdown,
        ),
      );
    }
    final phase = _controller.phase;
    final listening = phase == VoiceConversationPhase.listening;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voice conversation'),
            Text(widget.model.title, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Force lockdown demo',
            onPressed: _startDemoLockdown,
            icon: const Icon(Icons.lock_outline),
          ),
          IconButton(
            tooltip: 'UNO Q lamp',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const UnoQLampScreen()),
            ),
            icon: const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            tooltip: 'Notification triage',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NotificationTriageScreen(bridge: widget.bridge),
              ),
            ),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'Model setup',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ModelSetupScreen(
                  bridge: widget.bridge,
                  onBrainReady: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: listening ? 'Pause listening' : 'Listen now',
            onPressed: phase == VoiceConversationPhase.speaking
                ? _controller.interruptAndListen
                : _controller.isBusy
                ? null
                : listening
                ? _controller.pause
                : _controller.resume,
            icon: Icon(listening ? Icons.mic : Icons.mic_none_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _VoiceStatus(
              phase: phase,
              transcript: _controller.liveTranscript,
              error: _controller.error,
            ),
            Expanded(
              child: _controller.thread.entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Speak when the microphone is active. Your conversation stays on this device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _controller.thread.entries.length,
                      itemBuilder: (context, index) =>
                          ChatBubble(entry: _controller.thread.entries[index]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textInput,
                      enabled: !_controller.isBusy,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitTypedText(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Or type a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _controller.isBusy
                        ? phase == VoiceConversationPhase.speaking
                              ? 'Stop speaking and listen'
                              : 'Working'
                        : listening
                        ? 'Pause listening'
                        : 'Start listening',
                    onPressed: phase == VoiceConversationPhase.speaking
                        ? _controller.interruptAndListen
                        : _controller.isBusy
                        ? null
                        : listening
                        ? _controller.pause
                        : _controller.resume,
                    icon: Icon(
                      listening ? Icons.stop_circle_outlined : Icons.mic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusLockScreen extends StatelessWidget {
  const _FocusLockScreen({
    required this.listening,
    required this.transcript,
    required this.position,
    required this.phase,
    required this.showLiveExit,
    required this.onLiveExit,
  });

  final bool listening;
  final String transcript;
  final FacePosition position;
  final VoiceConversationPhase phase;
  final bool showLiveExit;
  final VoidCallback onLiveExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AgentFace(position: position, phase: phase),
            const SizedBox(height: 30),
            Text(
              listening
                  ? 'Focus lock · say “Hello” first'
                  : 'Focus lock · waiting for “Hello”',
              style: const TextStyle(color: Color(0xff9e9e9e), fontSize: 13),
            ),
            if (showLiveExit) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onLiveExit,
                icon: const Icon(Icons.radio_button_checked_outlined),
                label: const Text('LIVE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff9ee7ff),
                ),
              ),
            ],
            if (transcript.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  transcript,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff6f6f6f),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoiceStatus extends StatelessWidget {
  const _VoiceStatus({
    required this.phase,
    required this.transcript,
    required this.error,
  });

  final VoiceConversationPhase phase;
  final String transcript;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (phase) {
      VoiceConversationPhase.starting => 'Preparing microphone…',
      VoiceConversationPhase.listening => 'Listening…',
      VoiceConversationPhase.thinking => 'Local brain is thinking…',
      VoiceConversationPhase.speaking =>
        'Speaking… Tap the microphone to interrupt.',
      VoiceConversationPhase.paused => 'Listening paused',
      VoiceConversationPhase.error => error ?? 'Voice service needs attention',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: phase == VoiceConversationPhase.error
          ? colors.errorContainer
          : colors.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: phase == VoiceConversationPhase.error
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer,
            ),
          ),
          if (transcript.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              transcript,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ],
        ],
      ),
    );
  }
}
