# Milestone 1

## Device specs

- Model: CPH2745
- Chipset: Snapdragon SM8850 (Snapdragon 8 Elite Gen 5)
- CPU ABI: arm64-v8a
- Android: 16 (API 36)
- Usable system RAM reported: 10.6 GiB

## Implemented

- Flutter Android app with a GenieX model catalogue and resumable downloads.
- Device capability detection for ABI, chipset/NPU, and RAM.
- Native GenieX SDK initialization, model loading, streamed chat, and test-chat screen.
- Runtime-specific configuration for GGUF/llama.cpp and Qualcomm AI Hub/QAIRT models.
- Native plugin extraction and AI Hub model compatibility checks.

## Problems and resolutions

- Native GenieX plugins were not found after install; enabled legacy JNI packaging so Android extracts the plugin libraries.
- QAIRT rejected llama.cpp parameters; separated model configuration by runtime and use the QAIRT-compatible load plan.
- AI Hub download completion was not reflected consistently; resolve downloaded-model aliases through GenieX and refresh active downloads.
- Qwen3-4B caused critical memory pressure; added a shared 12 GiB RAM requirement guard for download and loading, with a clear catalogue message. Qwen3 0.6B remains supported on this device.
