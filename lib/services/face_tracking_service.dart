import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/services/uno_q_credentials_service.dart';

class FacePosition {
  const FacePosition({
    required this.detected,
    required this.x,
    required this.y,
  });

  const FacePosition.idle() : this(detected: false, x: 0, y: 0);

  final bool detected;
  final double x;
  final double y;

  static FacePosition fromJson(Map<String, dynamic> json) => FacePosition(
    detected: json['detected'] == true,
    x: (json['x'] as num?)?.toDouble().clamp(-1, 1) ?? 0,
    y: (json['y'] as num?)?.toDouble().clamp(-1, 1) ?? 0,
  );
}

/// Polls the optional IP-camera bridge for normalized face coordinates.
/// The visual face remains animated locally when the bridge is unavailable.
class FaceTrackingService {
  FaceTrackingService({
    UnoQCredentialsService? credentials,
    http.Client? client,
  }) : _credentials = credentials ?? UnoQCredentialsService(),
       _client = client ?? http.Client();

  final UnoQCredentialsService _credentials;
  final http.Client _client;
  final _positions = StreamController<FacePosition>.broadcast();
  Timer? _pollTimer;
  Uri? _baseUrl;

  Stream<FacePosition> get positions => _positions.stream;

  Future<void> start() async {
    if (_pollTimer != null) return;
    _baseUrl = (await _credentials.readConfiguration()).baseUrl;
    await _poll();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) => _poll(),
    );
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _positions.add(const FacePosition.idle());
  }

  Future<void> _poll() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) return;
    try {
      final response = await _client
          .get(baseUrl.resolve('/tracking'))
          .timeout(const Duration(seconds: 1));
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        _positions.add(FacePosition.fromJson(body));
      }
    } on Object {
      // The lock screen must stay calm when the optional camera bridge is down.
    }
  }

  Future<void> dispose() async {
    stop();
    _client.close();
    await _positions.close();
  }
}
