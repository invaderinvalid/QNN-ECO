import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'uno_q_credentials_service.dart';

enum UnoQMotorAction { yes, no, idle }

class UnoQMotorService {
  UnoQMotorService({UnoQCredentialsService? credentials, http.Client? client})
    : _credentials = credentials ?? UnoQCredentialsService(),
      _client = client ?? http.Client();

  final UnoQCredentialsService _credentials;
  final http.Client _client;

  Future<bool> isConfigured() async =>
      (await _credentials.readConfiguration()).isReady;

  Future<void> checkHealth() async {
    final configuration = await _credentials.readConfiguration();
    if (!configuration.isReady) throw MissingUnoQConfigurationException();
    final response = await _client
        .get(configuration.baseUrl.resolve('/health'))
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) {
      throw StateError('UNO Q health check returned ${response.statusCode}.');
    }
  }

  Future<void> send(UnoQMotorAction action) async {
    final configuration = await _credentials.readConfiguration();
    if (!configuration.isReady) throw MissingUnoQConfigurationException();
    final response = await _client
        .post(
          configuration.baseUrl.resolve('/action'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, String>{'action': action.name}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError(
        'UNO Q rejected ${action.name}: ${response.statusCode}.',
      );
    }
  }

  void dispose() => _client.close();
}
