enum ModelService { listening, brain, voice }

enum ModelDownloadRoute { genieX, aiHubPage }

class ModelSpec {
  const ModelSpec({
    required this.name,
    required this.title,
    required this.description,
    required this.service,
    required this.hub,
    required this.runtime,
    required this.downloadRoute,
    this.precision,
    this.downloadUrl,
    this.directAssetUrl,
    this.requiresChipset = false,
  });

  final String name;
  final String title;
  final String description;
  final ModelService service;
  final String hub;
  final String runtime;
  final ModelDownloadRoute downloadRoute;
  final String? precision;
  final String? downloadUrl;
  final String? directAssetUrl;
  final bool requiresChipset;

  bool get isBrain => service == ModelService.brain;
}

abstract final class ModelCatalog {
  static const whisperTiny = ModelSpec(
    name: 'whisper_tiny',
    title: 'Whisper-Tiny',
    description: 'Speech recognition for the Listening service.',
    service: ModelService.listening,
    hub: 'aihub',
    runtime: 'Qualcomm AI Runtime',
    downloadRoute: ModelDownloadRoute.aiHubPage,
    downloadUrl:
        'https://aihub.qualcomm.com/models/whisper_tiny?domain=Audio&useCase=Speech+Recognition',
    directAssetUrl:
        'https://qaihub-public-assets.s3.us-west-2.amazonaws.com/qai-hub-models/models/whisper_tiny/releases/v0.58.0/whisper_tiny-qnn_context_binary-float-qualcomm_snapdragon_8_elite_gen5_for_galaxy.zip',
    requiresChipset: true,
  );

  static const gemma4E2b = ModelSpec(
    name: 'google/gemma-4-E2B-it-qat-q4_0-gguf',
    title: 'Gemma-4-E2B-it',
    description: 'Local multimodal brain for conversation and responses.',
    service: ModelService.brain,
    hub: 'huggingface',
    runtime: 'GenieX · llama.cpp',
    downloadRoute: ModelDownloadRoute.genieX,
  );

  static const piperTtsEn = ModelSpec(
    name: 'pipertts_en',
    title: 'PiperTTS-EN',
    description: 'English speech generation for the Voice service.',
    service: ModelService.voice,
    hub: 'aihub',
    runtime: 'Qualcomm AI Runtime',
    downloadRoute: ModelDownloadRoute.aiHubPage,
    downloadUrl:
        'https://aihub.qualcomm.com/models/pipertts_en?domain=Audio&useCase=Audio+Generation',
    directAssetUrl:
        'https://qaihub-public-assets.s3.us-west-2.amazonaws.com/qai-hub-models/models/pipertts_en/releases/v0.58.0/pipertts_en-voice_ai-float-qualcomm_snapdragon_8_elite_gen5_for_galaxy.zip',
    requiresChipset: true,
  );

  static const models = <ModelSpec>[whisperTiny, gemma4E2b, piperTtsEn];
  static const brainModels = <ModelSpec>[gemma4E2b];
}
