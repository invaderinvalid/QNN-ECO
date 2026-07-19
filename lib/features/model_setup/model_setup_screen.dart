import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/device_capabilities.dart';
import '../../core/models/model_spec.dart';
import '../../core/services/ai_hub_asset_download_service.dart';
import '../../core/services/ai_hub_credentials_service.dart';
import '../../core/services/geniex_bridge.dart';
import 'widgets/ai_hub_credentials_dialog.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({
    super.key,
    required this.bridge,
    required this.onBrainReady,
  });

  final GenieXBridge bridge;
  final VoidCallback onBrainReady;

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  bool _checking = true;
  DeviceCapabilities? _capabilities;
  final Set<String> _downloadedModels = <String>{};
  final Set<String> _downloadingModels = <String>{};
  final Map<String, _DownloadProgress> _progress =
      <String, _DownloadProgress>{};
  final _aiHubCredentials = AiHubCredentialsService();
  final _aiHubAssetDownloads = AiHubAssetDownloadService();
  StreamSubscription<dynamic>? _progressSubscription;
  bool _aiHubConnected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _progressSubscription = GenieXBridge.progress
        .receiveBroadcastStream()
        .listen(_onProgress, onError: (_) {});
    _refreshModelState();
    _refreshAiHubConnection();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshModelState() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final capabilities = await widget.bridge.getDeviceCapabilities();
      final directAssetModels = ModelCatalog.models
          .where((model) => model.downloadRoute != ModelDownloadRoute.genieX)
          .toList(growable: false);
      final directAssetStates = await Future.wait(
        directAssetModels.map(_aiHubAssetDownloads.isDownloaded),
      );
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _downloadedModels
          ..removeAll(directAssetModels.map((model) => model.name))
          ..addAll(<String>{
            for (var index = 0; index < directAssetModels.length; index++)
              if (directAssetStates[index]) directAssetModels[index].name,
          });
      });

      // GenieX can hold its cache lock while a large model is being pulled.
      // Do not hold up the audio cards' installed state behind that operation.
      final genieXModels = ModelCatalog.models
          .where((model) => model.downloadRoute == ModelDownloadRoute.genieX)
          .toList(growable: false);
      final genieXStates = await Future.wait(
        genieXModels.map(widget.bridge.isModelDownloaded),
      );
      if (!mounted) return;
      setState(() {
        _downloadedModels
          ..removeAll(genieXModels.map((model) => model.name))
          ..addAll(<String>{
            for (var index = 0; index < genieXModels.length; index++)
              if (genieXStates[index]) genieXModels[index].name,
          });
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onProgress(dynamic value) {
    if (value is! Map || !mounted) return;
    final modelName = value['modelName'] as String?;
    if (modelName == null || !_downloadingModels.contains(modelName)) return;
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
      _downloadingModels.add(model.name);
      _error = null;
    });
    try {
      await widget.bridge.download(model, _capabilities?.chipset);
      await _refreshModelState();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingModels.remove(model.name);
          _progress.remove(model.name);
        });
      }
    }
  }

  Future<void> _refreshAiHubConnection() async {
    try {
      final connected = await _aiHubCredentials.hasSavedApiToken();
      if (mounted) setState(() => _aiHubConnected = connected);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<bool> _showAiHubCredentials({bool requiredForDownload = false}) async {
    final change = await showDialog<AiHubCredentialsChange>(
      context: context,
      builder: (_) => AiHubCredentialsDialog(
        hasSavedApiKey: _aiHubConnected,
        requiredForDownload: requiredForDownload,
      ),
    );
    if (!mounted || change == null) return false;

    try {
      if (change.clear) {
        await _aiHubCredentials.clearApiToken();
        await _refreshAiHubConnection();
        return false;
      } else if (change.apiToken != null) {
        await _aiHubCredentials.saveApiToken(change.apiToken!);
        await _refreshAiHubConnection();
        return true;
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
    return false;
  }

  Future<void> _requestModelDownload(ModelSpec model) async {
    try {
      if (model.downloadRoute == ModelDownloadRoute.genieX) {
        await _download(model);
      } else {
        await _downloadAiHubAsset(model);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _downloadAiHubAsset(ModelSpec model) async {
    setState(() {
      _downloadingModels.add(model.name);
      _error = null;
    });
    try {
      await _aiHubAssetDownloads.download(
        model,
        onProgress: (downloaded, total) {
          if (!mounted) return;
          setState(() {
            _progress[model.name] = _DownloadProgress(
              total > 0 ? downloaded / total : 0,
              downloaded,
              total,
            );
          });
        },
      );
      // This is intentionally local rather than a full state refresh. A Gemma
      // pull can keep GenieX's cache check busy, which previously left audio
      // cards stuck on "Downloading" after their archive had completed.
      if (mounted) {
        setState(() => _downloadedModels.add(model.name));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not download ${model.title}: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingModels.remove(model.name);
          _progress.remove(model.name);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brainInstalled = _downloadedModels.contains(
      ModelCatalog.gemma4E2b.name,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model setup'),
        actions: [
          IconButton(
            tooltip: _aiHubConnected
                ? 'AI Hub API key saved'
                : 'Connect Qualcomm AI Hub',
            onPressed: _showAiHubCredentials,
            icon: Icon(_aiHubConnected ? Icons.key : Icons.key_outlined),
          ),
          IconButton(
            tooltip: 'Refresh model status',
            onPressed: _checking ? null : _refreshModelState,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_capabilities != null) ...[
            _DeviceCapabilityCard(capabilities: _capabilities!),
            const SizedBox(height: 8),
          ],
          for (final model in ModelCatalog.models) ...[
            _ModelServiceCard(
              model: model,
              installed: _downloadedModels.contains(model.name),
              downloading: _downloadingModels.contains(model.name),
              progress: _progress[model.name],
              onDownload: () => _requestModelDownload(model),
            ),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            const SizedBox(height: 4),
            _ErrorCard(message: _error!),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: brainInstalled ? widget.onBrainReady : null,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              _checking
                  ? 'Checking installed models…'
                  : brainInstalled
                  ? 'Start chat'
                  : 'Download Gemma to start chat',
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelServiceCard extends StatelessWidget {
  const _ModelServiceCard({
    required this.model,
    required this.installed,
    required this.downloading,
    required this.progress,
    required this.onDownload,
  });

  final ModelSpec model;
  final bool installed;
  final bool downloading;
  final _DownloadProgress? progress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usesGenieX = model.downloadRoute == ModelDownloadRoute.genieX;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  child: Icon(_iconFor(model.service), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelFor(model.service),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(model.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(model.description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              model.runtime,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            if (downloading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 4),
              Text(
                progress?.label ?? 'Preparing download…',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: installed
                  ? Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        usesGenieX ? 'Installed' : 'Downloaded',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  : FilledButton.icon(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: downloading ? null : onDownload,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(
                        downloading ? 'Downloading' : 'Download',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ModelService service) {
    return switch (service) {
      ModelService.listening => Icons.hearing_outlined,
      ModelService.brain => Icons.psychology_outlined,
      ModelService.voice => Icons.record_voice_over_outlined,
    };
  }

  String _labelFor(ModelService service) {
    return switch (service) {
      ModelService.listening => 'Listening',
      ModelService.brain => 'Brain',
      ModelService.voice => 'Voice',
    };
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: colors.onErrorContainer, fontSize: 12),
      ),
    );
  }
}

class _DeviceCapabilityCard extends StatelessWidget {
  const _DeviceCapabilityCard({required this.capabilities});

  final DeviceCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${capabilities.chipset ?? 'Unknown chipset'} · ${capabilities.supportsNpu ? 'NPU ready' : 'NPU not verified'}',
              style: TextStyle(
                color: colors.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Usable RAM: ${capabilities.memoryLabel} · Available: ${capabilities.availableMemoryLabel}',
              style: TextStyle(
                color: colors.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
