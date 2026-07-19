class DeviceCapabilities {
  const DeviceCapabilities({
    required this.isArm64,
    required this.chipset,
    required this.supportsNpu,
    required this.supportsAiHub,
    required this.recommendedComputeUnit,
    required this.totalMemoryBytes,
    required this.availableMemoryBytes,
  });

  factory DeviceCapabilities.fromMap(Map<Object?, Object?> values) {
    return DeviceCapabilities(
      isArm64: values['isArm64'] as bool? ?? false,
      chipset: values['chipset'] as String?,
      supportsNpu: values['supportsNpu'] as bool? ?? false,
      supportsAiHub: values['supportsAiHub'] as bool? ?? false,
      recommendedComputeUnit:
          values['recommendedComputeUnit'] as String? ?? 'cpu',
      totalMemoryBytes: (values['totalMemoryBytes'] as num?)?.toInt() ?? 0,
      availableMemoryBytes:
          (values['availableMemoryBytes'] as num?)?.toInt() ?? 0,
    );
  }

  final bool isArm64;
  final String? chipset;
  final bool supportsNpu;
  final bool supportsAiHub;
  final String recommendedComputeUnit;
  final int totalMemoryBytes;
  final int availableMemoryBytes;

  String get memoryLabel =>
      '${(totalMemoryBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB RAM';

  String get availableMemoryLabel =>
      '${(availableMemoryBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB free now';
}
