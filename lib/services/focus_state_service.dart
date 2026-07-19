import 'package:flutter/services.dart';

class FocusState {
  const FocusState({
    required this.charging,
    required this.rotated180,
    required this.active,
  });

  final bool charging;
  final bool rotated180;
  final bool active;

  factory FocusState.fromMap(Map<dynamic, dynamic> values) => FocusState(
    charging: values['charging'] == true,
    rotated180: values['rotated180'] == true,
    active: values['active'] == true,
  );
}

/// Streams Android charging and face-down posture while the app is foregrounded.
class FocusStateService {
  static const _states = EventChannel('com.example.qnn_eco/focus_state');

  Stream<FocusState> get states => _states
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => FocusState.fromMap(event as Map<dynamic, dynamic>));
}
