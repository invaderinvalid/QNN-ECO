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

## MacroDroid

Import or create five MacroDroid webhooks matching the five notification sentiments: `crisis`, `distressed`, `mild_negative`, `neutral`, and `positive`. The supplied build contains the configured endpoints. A webhook failure is logged and does not prevent the local IR signal or spoken alert.

## Arduino UNO Q / IP camera setup

The accompanying Arduino bundle contains the MCU sketch and the App Lab Python bridge.

1. In Arduino App Lab, use `smart_lamp.ino` as the sketch. It needs **Adafruit BusIO** and **Adafruit PWM Servo Driver Library**.
2. Replace the app's `python/main.py` with `face_tracking_bridge.py`, and ensure its ONNX detector is at the configured `MODEL_PATH`.
3. In the root App Lab `app.yaml`, set:

   ```yaml
   ports:
     - 5000
   ```

4. Set `IP_CAM_URL` in `face_tracking_bridge.py` to the IP camera's MJPEG stream.
5. Run the App Lab app and verify `http://BOARD_IP:5000/health`.

The bridge exposes `/action` for the restricted lamp actions and `/tracking` for normalized face coordinates. It has no QNN key or API key: use it only on a trusted local Wi-Fi network.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The Android release is debug-signed in the current Gradle configuration. Replace it with a production signing key before distributing outside your own devices.
