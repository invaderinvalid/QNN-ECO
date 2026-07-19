import 'package:flutter_test/flutter_test.dart';
import 'package:qnn_eco/core/services/ai_hub_credentials_service.dart';

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

void main() {
  late _MemorySecureStore store;
  late AiHubCredentialsService service;

  setUp(() {
    store = _MemorySecureStore();
    service = AiHubCredentialsService(store: store);
  });

  test('saves a trimmed API key and exposes it only on demand', () async {
    await service.saveApiToken('  personal-key  ');

    expect(await service.hasSavedApiToken(), isTrue);
    expect(await service.requireApiToken(), 'personal-key');
  });

  test('rejects an empty API key', () async {
    expect(service.saveApiToken('   '), throwsA(isA<ArgumentError>()));
  });

  test('clearing the key makes authenticated access fail', () async {
    await service.saveApiToken('personal-key');
    await service.clearApiToken();

    expect(await service.hasSavedApiToken(), isFalse);
    expect(
      service.requireApiToken(),
      throwsA(isA<MissingAiHubApiKeyException>()),
    );
  });
}
