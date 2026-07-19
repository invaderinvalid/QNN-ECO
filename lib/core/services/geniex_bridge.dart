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

  Future<NotificationTriageStatus> getNotificationTriageStatus() async {
    final values = await _methods.invokeMapMethod<Object?, Object?>(
      'getNotificationTriageStatus',
    );
    if (values == null) {
      throw StateError('Notification triage status returned no data.');
    }
    return NotificationTriageStatus.fromMap(values);
  }

  Future<void> openNotificationListenerSettings() =>
      _methods.invokeMethod<void>('openNotificationListenerSettings');

  Future<String> getRecentNotificationStatus() async {
    return await _methods.invokeMethod<String>('getRecentNotificationStatus') ??
        'No recent notifications are available in the local temporary cache.';
  }
}

class NotificationTriageStatus {
  const NotificationTriageStatus({
    required this.listenerEnabled,
    required this.irAvailable,
  });

  final bool listenerEnabled;
  final bool irAvailable;

  factory NotificationTriageStatus.fromMap(Map<Object?, Object?> values) {
    return NotificationTriageStatus(
      listenerEnabled: values['listenerEnabled'] == true,
      irAvailable: values['irAvailable'] == true,
    );
  }
}
