# QNN-ECO

An Android-only, on-device companion for Snapdragon devices. QNN-ECO uses Qualcomm GenieX models for local chat and notification triage, keeps a rolling private conversation memory, and can drive IR, MacroDroid automations, and an Arduino UNO Q lamp.

## What it does

- Downloads and runs the selected local LLM through GenieX.
- Runs continuous voice interaction. During Focus Lock, every request must start with **Hello**; other speech is ignored.
- Focus Lock activates when the phone is charging and rotated upside down. It presents an animated agent face that follows the IP-camera tracking feed when the UNO Q bridge is reachable.
- Reads notifications only after Android notification access is granted, classifies them on-device as promotional, crisis, distressed, mild negative, neutral, or positive, and preserves recent items locally for the notification-status tool.
- Keeps the existing IR signal mapping and triggers the matching configured MacroDroid webhook for each non-promotional sentiment. Notification text is never included in the webhook request.
- Controls the UNO Q lamp with the restricted actions `yes`, `no`, and `idle` over local Wi-Fi.

## Phone setup

1. Install the release APK on a supported Snapdragon Android phone.
2. Open **Model setup**, add any required AI Hub credentials, and download the listed models.
3. Grant microphone permission for voice interaction.
4. Open **Notification triage** and grant Android notification access. The listener starts only after this user-granted system permission is enabled.
5. In **Voice conversation**, use the lamp icon to save the UNO Q bridge address, for example `http://10.48.125.131:5000`.
6. To activate Focus Lock, connect power and turn the phone upside down. Say **Hello** at the beginning of every spoken request. Say “shut up”, “be quiet”, or “stop listening” to silence it for at least 30 seconds.

For demos, use the lock icon in Voice conversation to force the same lockdown screen. Its **LIVE** button exits the forced screen and pauses the voice agent; normal microphone controls can start it again.

## MacroDroid

Import or create five MacroDroid webhooks matching the five notification sentiments: `crisis`, `distressed`, `mild_negative`, `neutral`, and `positive`. The supplied build contains the configured endpoints. A webhook failure is logged and does not prevent the local IR signal or spoken alert.

## Arduino UNO Q / IP camera setup

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The Android release is debug-signed in the current Gradle configuration. Replace it with a production signing key before distributing outside your own devices.
