import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/face_tracking_service.dart';
import '../services/voice_conversation_controller.dart';

/// The lock-screen avatar. Camera coordinates move the gaze; its expression
/// is derived only from the local voice state.
class AgentFace extends StatefulWidget {
  const AgentFace({super.key, required this.position, required this.phase});

  final FacePosition position;
  final VoiceConversationPhase phase;

  @override
  State<AgentFace> createState() => _AgentFaceState();
}

class _AgentFaceState extends State<AgentFace> {
  Timer? _blinkTimer;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(const Duration(milliseconds: 2700), () {
      if (!mounted) return;
      setState(() => _blinking = true);
      Timer(const Duration(milliseconds: 115), () {
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expression = _Expression.fromPhase(widget.phase);
    final gaze = widget.position.detected
        ? Alignment(
            widget.position.x.clamp(-1, 1) * .42,
            widget.position.y.clamp(-1, 1) * .25,
          )
        : Alignment.center;
    return SizedBox(
          width: 302,
          height: 216,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                    width: 278,
                    height: 186,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(90),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xff172554), Color(0xff020617)],
                      ),
                      border: Border.all(
                        color: expression.iris.withValues(alpha: .42),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: expression.iris.withValues(alpha: .24),
                          blurRadius: 34,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(.985, .985),
                    end: const Offset(1.015, 1.015),
                    duration: 2200.ms,
                    curve: Curves.easeInOut,
                  ),
              Positioned(
                top: 29,
                left: 46,
                child: _Brow(
                  angle: expression.leftBrow,
                  color: expression.iris,
                ),
              ),
              Positioned(
                top: 29,
                right: 46,
                child: _Brow(
                  angle: expression.rightBrow,
                  color: expression.iris,
                ),
              ),
              Positioned(
                top: 54,
                left: 36,
                child: _AnimeEye(
                  gaze: gaze,
                  iris: expression.iris,
                  blinking: _blinking,
                  eyeTilt: expression.leftEyeTilt,
                ),
              ),
              Positioned(
                top: 54,
                right: 36,
                child: _AnimeEye(
                  gaze: gaze,
                  iris: expression.iris,
                  blinking: _blinking,
                  eyeTilt: expression.rightEyeTilt,
                ),
              ),
              Positioned(
                bottom: 20,
                child: _Mouth(kind: expression.mouth, color: expression.iris),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(.82, .82),
          end: const Offset(1, 1),
          duration: 420.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _AnimeEye extends StatelessWidget {
  const _AnimeEye({
    required this.gaze,
    required this.iris,
    required this.blinking,
    required this.eyeTilt,
  });

  final Alignment gaze;
  final Color iris;
  final bool blinking;
  final double eyeTilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: eyeTilt,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 95),
        curve: Curves.easeInOut,
        width: 98,
        height: blinking ? 8 : 76,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xfffffbff),
          borderRadius: BorderRadius.circular(52),
          border: Border.all(color: const Color(0xff0f172a), width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: blinking
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(9),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 230),
                  curve: Curves.easeOutCubic,
                  alignment: gaze,
                  child: Container(
                    width: 48,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          iris,
                          iris.withValues(alpha: .84),
                          const Color(0xff020617),
                        ],
                        stops: const [0, .2, .72, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: iris.withValues(alpha: .62),
                          blurRadius: 13,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: const Alignment(0, .2),
                          child: Container(
                            width: 21,
                            height: 29,
                            decoration: const BoxDecoration(
                              color: Color(0xff020617),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 7,
                          left: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 13, height: 13),
                          ),
                        ),
                        const Positioned(
                          right: 8,
                          bottom: 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white70,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 6, height: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Brow extends StatelessWidget {
  const _Brow({required this.angle, required this.color});

  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 72,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

class _Mouth extends StatelessWidget {
  const _Mouth({required this.kind, required this.color});

  final _MouthKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(78, 34),
    painter: _MouthPainter(kind: kind, color: color),
  );
}

class _MouthPainter extends CustomPainter {
  const _MouthPainter({required this.kind, required this.color});

  final _MouthKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    switch (kind) {
      case _MouthKind.smile:
        path.moveTo(13, 10);
        path.quadraticBezierTo(size.width / 2, 31, size.width - 13, 10);
      case _MouthKind.open:
        canvas.drawOval(
          const Rect.fromLTWH(25, 4, 28, 24),
          Paint()..color = color,
        );
      case _MouthKind.flat:
        path.moveTo(18, 18);
        path.lineTo(size.width - 18, 18);
      case _MouthKind.frown:
        path.moveTo(13, 26);
        path.quadraticBezierTo(size.width / 2, 5, size.width - 13, 26);
    }
    if (kind != _MouthKind.open) canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MouthPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

enum _MouthKind { smile, open, flat, frown }

class _Expression {
  const _Expression({
    required this.iris,
    required this.leftBrow,
    required this.rightBrow,
    required this.leftEyeTilt,
    required this.rightEyeTilt,
    required this.mouth,
  });

  final Color iris;
  final double leftBrow;
  final double rightBrow;
  final double leftEyeTilt;
  final double rightEyeTilt;
  final _MouthKind mouth;

  factory _Expression.fromPhase(VoiceConversationPhase phase) =>
      switch (phase) {
        VoiceConversationPhase.thinking => const _Expression(
          iris: Color(0xffffc857),
          leftBrow: -.16,
          rightBrow: .16,
          leftEyeTilt: -.05,
          rightEyeTilt: .05,
          mouth: _MouthKind.flat,
        ),
        VoiceConversationPhase.speaking => const _Expression(
          iris: Color(0xff8ee3a0),
          leftBrow: .04,
          rightBrow: -.04,
          leftEyeTilt: -.03,
          rightEyeTilt: .03,
          mouth: _MouthKind.open,
        ),
        VoiceConversationPhase.error => const _Expression(
          iris: Color(0xffff8fab),
          leftBrow: .2,
          rightBrow: -.2,
          leftEyeTilt: .1,
          rightEyeTilt: -.1,
          mouth: _MouthKind.frown,
        ),
        _ => const _Expression(
          iris: Color(0xff7dd3fc),
          leftBrow: -.04,
          rightBrow: .04,
          leftEyeTilt: 0,
          rightEyeTilt: 0,
          mouth: _MouthKind.smile,
        ),
      };
}
