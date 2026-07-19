import 'package:flutter/services.dart';

import '../models/chat_entry.dart';
import '../models/device_capabilities.dart';
import '../models/model_spec.dart';

class GenieXBridge {
  static const _methods = MethodChannel('com.example.qnn_eco/geniex');
  static const progress = EventChannel('com.example.qnn_eco/geniex_progress');
  static const chat = EventChannel('com.example.qnn_eco/geniex_chat');

  Future<bool> isModelDownloaded(ModelSpec model) async {
    return await _methods.invokeMethod<bool>(
          'isModelDownloaded',
          <String, String>{'modelName': model.name},
        ) ??
        false;
  }

  Future<DeviceCapabilities> getDeviceCapabilities() async {
    final values = await _methods.invokeMapMethod<Object?, Object?>(
      'getDeviceCapabilities',
    );
    if (values == null) {
      throw StateError('The device capability check returned no data.');
    }
    return DeviceCapabilities.fromMap(values);
  }

  Future<void> download(ModelSpec model, String? chipset) {
    return _methods.invokeMethod<void>('downloadModel', <String, Object?>{
      'modelName': model.name,
      'precision': model.precision,
      'hub': model.hub,
      'chipset': model.requiresChipset ? chipset : null,
    });
  }

  Future<void> generateReply(String modelName, List<ChatEntry> messages) {
    return _methods.invokeMethod<void>('generateReply', <String, Object?>{
      'modelName': modelName,
      'messages': messages
          .map(
            (message) => <String, String>{
              'role': message.role,
              'content': message.content,
            },
          )
          .toList(),
    });
  }

  Future<void> stopGeneration() =>
      _methods.invokeMethod<void>('stopGeneration');
}
