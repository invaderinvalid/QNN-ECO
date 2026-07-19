import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal abstraction so credential behavior remains independently testable
/// and no UI/service depends directly on a storage plugin.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class EncryptedSecureKeyValueStore implements SecureKeyValueStore {
  EncryptedSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class MissingAiHubApiKeyException extends StateError {
  MissingAiHubApiKeyException()
    : super('A Qualcomm AI Hub API key is required for this download.');
}

/// Owns the user's Qualcomm AI Hub token. Only authenticated AI Hub clients
/// should read the token; UI code only checks whether one has been saved.
class AiHubCredentialsService {
  AiHubCredentialsService({SecureKeyValueStore? store})
    : _store = store ?? EncryptedSecureKeyValueStore();

  static const _apiTokenKey = 'qualcomm_ai_hub_api_token';

  final SecureKeyValueStore _store;

  Future<bool> hasSavedApiToken() async {
    final token = await _store.read(_apiTokenKey);
    return token != null && token.trim().isNotEmpty;
  }

  /// Exposes the key only to a future authenticated AI Hub client, never UI.
  Future<String> requireApiToken() async {
    final token = (await _store.read(_apiTokenKey))?.trim();
    if (token == null || token.isEmpty) throw MissingAiHubApiKeyException();
    return token;
  }

  Future<void> saveApiToken(String value) async {
    final token = value.trim();
    if (token.isEmpty) {
      throw ArgumentError.value(value, 'value', 'An API key is required.');
    }
    await _store.write(_apiTokenKey, token);
  }

  Future<void> clearApiToken() => _store.delete(_apiTokenKey);
}
