import '../core/services/uno_q_motor_service.dart';

/// Converts only an unambiguous leading yes/no response into a lamp gesture.
/// All other model text is deliberately ignored.
class UnoQGestureService {
  UnoQGestureService({UnoQMotorService? motors})
    : _motors = motors ?? UnoQMotorService();

  final UnoQMotorService _motors;

  Future<void> mirrorAnswer(String answer) async {
    final action = _actionFor(answer);
    if (action == null || !await _motors.isConfigured()) return;
    await _motors.send(action);
  }

  UnoQMotorAction? _actionFor(String answer) {
    final firstWord = answer
        .trimLeft()
        .toLowerCase()
        .replaceFirst(RegExp(r'^[^a-z]+'), '')
        .split(RegExp(r'[^a-z]+'))
        .firstOrNull;
    return switch (firstWord) {
      'yes' => UnoQMotorAction.yes,
      'no' => UnoQMotorAction.no,
      _ => null,
    };
  }
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
