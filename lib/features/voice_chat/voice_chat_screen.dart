import 'package:flutter/material.dart';

import '../../core/models/model_spec.dart';
import '../../core/services/geniex_bridge.dart';
import '../model_setup/model_setup_screen.dart';
import '../../services/voice_conversation_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = VoiceConversationController(
      bridge: widget.bridge,
      model: widget.model,
    )..addListener(_refresh);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _textInput.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submitTypedText() async {
    final text = _textInput.text.trim();
    if (text.isEmpty) return;
    _textInput.clear();
    await _controller.submitText(text);
  }

  @override
  Widget build(BuildContext context) {
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
