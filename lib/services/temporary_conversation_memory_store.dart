import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Keeps only the current rolling conversation memory in the OS cache.
/// The file is ignored once it reaches its expiry and is deleted on every read.
class TemporaryConversationMemoryStore {
  static const lifetime = Duration(hours: 1);

  Future<String?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(raw['expiresAt'] as String);
      if (!DateTime.now().isBefore(expiresAt)) {
        await _deleteIfPresent(file);
        return null;
      }
      return (raw['summary'] as String?)?.trim().isEmpty ?? true
          ? null
          : (raw['summary'] as String).trim();
    } catch (_) {
      await _deleteIfPresent(file);
      return null;
    }
  }

  Future<void> save(String summary) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(<String, String>{
        'summary': summary,
        'expiresAt': DateTime.now().add(lifetime).toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }

  Future<void> clear() async => _deleteIfPresent(await _file());

  Future<File> _file() async {
    final directory = await getTemporaryDirectory();
    return File('${directory.path}/qnn_eco_conversation_memory.json');
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
