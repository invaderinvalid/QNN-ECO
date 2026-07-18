import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const QnnEcoApp());
}

class QnnEcoApp extends StatelessWidget {
  const QnnEcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QNN-ECO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff4f46e5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ModelCatalogScreen(),
    );
  }
}

class ModelSpec {
  const ModelSpec({
    required this.name,
    required this.title,
    required this.description,
    required this.hub,
    required this.runtime,
    required this.tags,
    this.supportsChat = true,
    this.precision,
    this.requiresChipset = false,
    this.minimumMemoryBytes = 0,
  });

  final String name;
  final String title;
  final String description;
  final String hub;
  final String runtime;
  final List<String> tags;
  final bool supportsChat;
  final String? precision;
  final bool requiresChipset;
  final int minimumMemoryBytes;
}

class DeviceCapabilities {
  const DeviceCapabilities({
    required this.isArm64,
    required this.chipset,
    required this.supportsNpu,
    required this.supportsAiHub,
    required this.recommendedComputeUnit,
    required this.totalMemoryBytes,
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
    );
  }

  final bool isArm64;
  final String? chipset;
  final bool supportsNpu;
  final bool supportsAiHub;
  final String recommendedComputeUnit;
  final int totalMemoryBytes;
}

const _models = <ModelSpec>[
  ModelSpec(
    name: 'unsloth/Qwen3-0.6B-GGUF',
    title: 'Qwen3 0.6B',
    description: 'Compact chat model and the recommended first download.',
    hub: 'huggingface',
    runtime: 'llama.cpp',
    precision: 'Q4_0',
    tags: ['Text', 'GGUF', 'NPU / GPU / CPU'],
  ),
  ModelSpec(
    name: 'unsloth/Qwen3-VL-2B-Instruct-GGUF',
    title: 'Qwen3-VL 2B',
    description: 'Vision-language model for prompts that include images.',
    hub: 'huggingface',
    runtime: 'llama.cpp',
    precision: 'Q4_0',
    tags: ['Vision + text', 'GGUF', 'NPU / GPU / CPU'],
    supportsChat: false,
  ),
  ModelSpec(
    name: 'ai-hub-models/Qwen3-4B-Instruct-2507',
    title: 'Qwen3 4B Instruct',
    description: 'Qualcomm AI Hub model, pre-compiled for a Snapdragon NPU.',
    hub: 'aihub',
    runtime: 'Qualcomm AI Engine Direct',
    tags: ['Text', 'AI Hub', 'NPU'],
    requiresChipset: true,
    minimumMemoryBytes: 12 * 1024 * 1024 * 1024,
  ),
];

class GenieXBridge {
  static const _methods = MethodChannel('com.example.qnn_eco/geniex');
  static const progress = EventChannel('com.example.qnn_eco/geniex_progress');
  static const chat = EventChannel('com.example.qnn_eco/geniex_chat');

  Future<Set<String>> listDownloadedModels() async {
    final models = await _methods.invokeListMethod<String>(
      'listDownloadedModels',
    );
    return (models ?? const <String>[]).toSet();
  }

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

class ModelCatalogScreen extends StatefulWidget {
  const ModelCatalogScreen({super.key});

  @override
  State<ModelCatalogScreen> createState() => _ModelCatalogScreenState();
}

class _ModelCatalogScreenState extends State<ModelCatalogScreen> {
  final _bridge = GenieXBridge();
  final Map<String, _DownloadProgress> _progress = {};
  final Set<String> _downloading = {};
  Set<String> _downloaded = {};
  StreamSubscription<dynamic>? _progressSubscription;
  Timer? _statusTimer;
  DeviceCapabilities? _capabilities;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _progressSubscription = GenieXBridge.progress
        .receiveBroadcastStream()
        .listen(_onProgress, onError: (_) {});
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshActiveDownloads(),
    );
    _refreshDownloadedModels();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDownloadedModels() async {
    try {
      final capabilities = await _bridge.getDeviceCapabilities();
      final states = await Future.wait(_models.map(_bridge.isModelDownloaded));
      final downloaded = <String>{
        for (var index = 0; index < _models.length; index++)
          if (states[index]) _models[index].name,
      };
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _downloaded = downloaded;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not read the model cache: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshActiveDownloads() async {
    if (_downloading.isEmpty || !mounted) return;
    final activeModels = _models.where(
      (model) => _downloading.contains(model.name),
    );
    final states = await Future.wait(
      activeModels.map(_bridge.isModelDownloaded),
    );
    final completed = <String>{
      for (var index = 0; index < activeModels.length; index++)
        if (states[index]) activeModels.elementAt(index).name,
    };
    if (completed.isEmpty || !mounted) return;
    setState(() {
      _downloaded = {..._downloaded, ...completed};
      _downloading.removeAll(completed);
      for (final modelName in completed) {
        _progress.remove(modelName);
      }
    });
  }

  void _onProgress(dynamic value) {
    if (value is! Map || !mounted) return;
    final modelName = value['modelName'] as String?;
    if (modelName == null) return;
    setState(() {
      _progress[modelName] = _DownloadProgress(
        (value['fraction'] as num?)?.toDouble() ?? 0,
        (value['downloadedBytes'] as num?)?.toInt() ?? 0,
        (value['totalBytes'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Future<void> _download(ModelSpec model) async {
    setState(() {
      _downloading.add(model.name);
      _error = null;
    });
    try {
      await _bridge.download(model, _capabilities?.chipset);
      await _refreshDownloadedModels();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'The model download failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading.remove(model.name);
          _progress.remove(model.name);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QNN-ECO'),
            Text('GenieX model catalogue', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refreshDownloadedModels,
            tooltip: 'Refresh installed models',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDownloadedModels,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Available models',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a curated GenieX model. Downloads are stored on-device and can resume after an interruption.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_capabilities != null)
              _DeviceCapabilityCard(capabilities: _capabilities!),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            for (final model in _models) ...[
              _ModelCard(
                model: model,
                installed: _downloaded.contains(model.name),
                downloading: _downloading.contains(model.name),
                progress: _progress[model.name],
                unavailableReason: _unavailableReason(model),
                onDownload: _canRun(model) ? () => _download(model) : null,
                onTestChat: model.supportsChat && _canRun(model)
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(model: model),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            Text(
              'AI Hub models require a matching Snapdragon 8 Elite chipset. GGUF models support the llama.cpp runtime.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  bool _canRun(ModelSpec model) {
    final capabilities = _capabilities;
    if (capabilities == null || !capabilities.isArm64) return false;
    if (model.requiresChipset && !capabilities.supportsAiHub) return false;
    return capabilities.totalMemoryBytes >= model.minimumMemoryBytes;
  }

  String? _unavailableReason(ModelSpec model) {
    final capabilities = _capabilities;
    if (capabilities == null) return 'Checking device';
    if (!capabilities.isArm64) return 'Requires 64-bit ARM';
    if (model.requiresChipset && !capabilities.supportsAiHub) {
      return 'Requires Snapdragon 8 Elite';
    }
    if (capabilities.totalMemoryBytes < model.minimumMemoryBytes) {
      return 'Requires 12 GiB RAM';
    }
    return null;
  }
}

class _DeviceCapabilityCard extends StatelessWidget {
  const _DeviceCapabilityCard({required this.capabilities});

  final DeviceCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final verified = capabilities.supportsNpu;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: verified
            ? colors.secondaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified_outlined : Icons.memory_outlined,
            color: verified
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              verified
                  ? '${capabilities.chipset} detected · NPU enabled · ${_formatGiB(capabilities.totalMemoryBytes)} GiB RAM'
                  : capabilities.isArm64
                  ? 'NPU not verified · GGUF chats will use CPU'
                  : 'Unsupported CPU architecture · arm64-v8a is required',
              style: TextStyle(
                color: verified
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatGiB(int bytes) =>
      (bytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.installed,
    required this.downloading,
    required this.progress,
    required this.unavailableReason,
    required this.onDownload,
    required this.onTestChat,
  });

  final ModelSpec model;
  final bool installed;
  final bool downloading;
  final _DownloadProgress? progress;
  final String? unavailableReason;
  final VoidCallback? onDownload;
  final VoidCallback? onTestChat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  model.tags.first == 'Vision + text'
                      ? Icons.image_outlined
                      : Icons.smart_toy_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    model.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (installed) const Chip(label: Text('Installed')),
              ],
            ),
            const SizedBox(height: 8),
            Text(model.description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in model.tags) Chip(label: Text(tag)),
                Chip(label: Text(model.runtime)),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 6),
              Text(
                progress == null ? 'Preparing download…' : progress!.label,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: installed
                  ? FilledButton.icon(
                      onPressed: onTestChat,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(
                        onTestChat != null
                            ? 'Test chat'
                            : unavailableReason ?? 'Vision model',
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: downloading ? null : onDownload,
                      icon: downloading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(
                        downloading
                            ? 'Downloading'
                            : onDownload == null
                            ? unavailableReason ?? 'Unsupported device'
                            : 'Download',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatEntry {
  const ChatEntry({required this.role, required this.content});

  final String role;
  final String content;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.model});

  final ModelSpec model;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _bridge = GenieXBridge();
  final _input = TextEditingController();
  final _messages = <ChatEntry>[];
  StreamSubscription<dynamic>? _chatSubscription;
  bool _generating = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _chatSubscription = GenieXBridge.chat.receiveBroadcastStream().listen(
      _onChatEvent,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _input.dispose();
    if (_generating) _bridge.stopGeneration();
    super.dispose();
  }

  void _onChatEvent(dynamic value) {
    if (value is! Map || value['modelName'] != widget.model.name || !mounted) {
      return;
    }
    final type = value['type'] as String?;
    final text = value['text'] as String? ?? '';
    setState(() {
      switch (type) {
        case 'status':
          _status = text;
          break;
        case 'token':
          _status = null;
          if (_messages.isEmpty || _messages.last.role != 'assistant') {
            _messages.add(ChatEntry(role: 'assistant', content: text));
          } else {
            final last = _messages.removeLast();
            _messages.add(
              ChatEntry(role: 'assistant', content: last.content + text),
            );
          }
          break;
        case 'completed':
          _generating = false;
          _status = null;
          break;
        case 'error':
          _generating = false;
          _status = null;
          _messages.add(ChatEntry(role: 'error', content: text));
          break;
      }
    });
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty || _generating) return;

    setState(() {
      _messages.add(ChatEntry(role: 'user', content: content));
      _generating = true;
      _status = 'Starting…';
    });
    _input.clear();

    try {
      await _bridge.generateReply(widget.model.name, _messages);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _status = null;
        _messages.add(ChatEntry(role: 'error', content: '$error'));
      });
    }
  }

  Future<void> _stop() async {
    try {
      await _bridge.stopGeneration();
      if (mounted) {
        setState(() {
          _generating = false;
          _status = null;
        });
      }
    } catch (_) {
      // The stream will surface any native failure to the chat transcript.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test chat'),
            Text(widget.model.title, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_generating)
            IconButton(
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Stop generating',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Send a message to load ${widget.model.title} and start a local chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) =>
                          _ChatBubble(entry: _messages[index]),
                    ),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _status!,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_generating,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ask the model anything',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _generating ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = entry.role == 'user';
    final isError = entry.role == 'error';
    final background = isError
        ? colors.errorContainer
        : isUser
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final foreground = isError
        ? colors.onErrorContainer
        : isUser
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(entry.content, style: TextStyle(color: foreground)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadProgress {
  const _DownloadProgress(this.fraction, this.downloadedBytes, this.totalBytes);

  final double fraction;
  final int downloadedBytes;
  final int totalBytes;

  String get label {
    if (totalBytes <= 0) return 'Downloading…';
    return '${(fraction * 100).toStringAsFixed(0)}% · ${_formatBytes(downloadedBytes)} of ${_formatBytes(totalBytes)}';
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
