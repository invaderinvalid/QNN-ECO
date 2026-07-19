import 'ai_hub_credentials_service.dart';

class UnoQConfiguration {
  const UnoQConfiguration({required this.baseUrl});

  final Uri baseUrl;

  bool get isReady => baseUrl.hasAuthority;
}

class MissingUnoQConfigurationException extends StateError {
  MissingUnoQConfigurationException()
    : super('Set the UNO Q bridge address before using the lamp.');
}

/// Stores only the local UNO Q bridge address for trusted Wi-Fi use.
class UnoQCredentialsService {
  UnoQCredentialsService({SecureKeyValueStore? store})
    : _store = store ?? EncryptedSecureKeyValueStore();

  static final defaultBaseUrl = Uri.parse('http://10.48.125.131:5000');
  static const _baseUrlKey = 'uno_q_base_url';
  // Obsolete command key from older releases; removed on first read.
  static const _apiKeyKey = 'uno_q_command_key';

  final SecureKeyValueStore _store;

  Future<UnoQConfiguration> readConfiguration() async {
    final savedUrl = (await _store.read(_baseUrlKey))?.trim();
    final baseUrl = Uri.tryParse(savedUrl ?? '') ?? defaultBaseUrl;
    await _store.delete(_apiKeyKey);
    return UnoQConfiguration(baseUrl: baseUrl);
  }

  Future<void> save({required String baseUrl}) async {
    final parsed = Uri.tryParse(baseUrl.trim());
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Enter a complete board URL.',
      );
    }
    await _store.write(
      _baseUrlKey,
      parsed.toString().replaceFirst(RegExp(r'/$'), ''),
    );
  }

  Future<void> clear() async {
    await _store.delete(_baseUrlKey);
    await _store.delete(_apiKeyKey);
  }
}
