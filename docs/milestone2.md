# Milestone 2

## Device specs

- Model: OnePlus CPH2745
- Chipset: Snapdragon SM8850 (Snapdragon 8 Elite Gen 5)
- CPU ABI: arm64-v8a
- Android: 16 (API 36)
- Usable RAM reported: 10.9 GiB; available RAM observed during setup: about 5.9 GiB

## Implemented

- Modular Flutter setup with Listening, Brain, and Voice model cards.
- On-device Whisper-Tiny and PiperTTS-EN archive downloads with resume support, progress, and persisted completion status.
- Gemma-4-E2B-it local brain download through GenieX/Hugging Face.
- Model setup capability summary, direct chat entry, threaded text chat, and continuous voice-conversation flow.
- Release-build JNI keep rules for GenieX and an Android release APK.

## Problems and resolutions

- GenieX native pull aborted because R8 renamed `HubSource`; kept all GenieX SDK types and members so JNI can resolve their exact names.
- Audio cards remained on Downloading after their archives completed; removed the dependency on Gemma's cache refresh and show archive progress plus Downloaded state.
- Start chat could route back to setup while GenieX cache access was busy; open the confirmed Gemma chat directly.
- Android recognition could end after a partial transcript without a final result; promote that transcript on recognition completion and submit it to the brain.
- Listening stopped after a voice turn; preserve the user's listening intent and resume after response playback or a recoverable error.
- USB package replacement closes the running app and may invalidate app-private downloaded assets; avoid replacing the installed build while models are being retained unless an update is required.
