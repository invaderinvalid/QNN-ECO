import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/face_tracking_service.dart';
import '../services/voice_conversation_controller.dart';

class AgentFace extends StatelessWidget {
  const AgentFace({super.key, required this.position, required this.phase});

  final FacePosition position;
  final VoiceConversationPhase phase;

  @override
  Widget build(BuildContext context) {
    final pupilColor = switch (phase) {
      VoiceConversationPhase.thinking => const Color(0xffffd166),
      VoiceConversationPhase.speaking => const Color(0xff86efac),
      VoiceConversationPhase.error => const Color(0xfffda4af),
      _ => const Color(0xff9ee7ff),
    };
    final mouth = switch (phase) {
      VoiceConversationPhase.thinking => '◡',
      VoiceConversationPhase.speaking => '◜◡◝',
      VoiceConversationPhase.error => '︵',
      _ => '⌣',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 238,
          height: 126,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                child: _Eye(position: position, color: pupilColor),
              ),
              Positioned(
                right: 12,
                child: _Eye(position: position, color: pupilColor),
              ),
            ],
          ),
        ),
        Text(
          mouth,
          style: TextStyle(color: pupilColor, fontSize: 42, height: 0.8),
        ).animate().fadeIn(duration: 260.ms).scale(begin: const Offset(.8, .8)),
      ],
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye({required this.position, required this.color});

  final FacePosition position;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final target = position.detected
        ? Alignment(position.x * .58, position.y * .42)
        : Alignment.center;
    return Container(
          width: 92,
          height: 74,
          decoration: const BoxDecoration(
            color: Color(0xfff8fafc),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: target,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xff0f172a),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: -3, end: 3, duration: 1800.ms, curve: Curves.easeInOut);
  }
}
