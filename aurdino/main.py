import cv2
import numpy as np
import time
import threading
from flask import Flask, Response, jsonify, request
from arduino.app_utils import Bridge

IP_CAM_URL = "http://10.48.125.1:8080/video"
MODEL_PATH = "/app/python/version-slim-320.onnx"

HFOV = 60
VFOV = 45
MOUNT_PAN_OFFSET = 0     # tune this after testing, since camera is mounted at an angle
MOUNT_TILT_OFFSET = 0    # tune this after testing
PAN_CENTER = 90
TILT_IDLE = 60
TILT_ACTIVE = 90
DEADBAND_DEG = 3
SMOOTH_ALPHA = 0.3
IDLE_TIMEOUT = 3.0

# Detector settings
INPUT_W, INPUT_H = 320, 240
CONF_THRESHOLD = 0.7
NMS_THRESHOLD = 0.4
MAX_TRACK_JUMP = 150   # pixels — how far a face can "teleport" and still count as the same person

net = cv2.dnn.readNetFromONNX(MODEL_PATH)

app = Flask(__name__)
latest_frame = None
frame_lock = threading.Lock()
bridge_lock = threading.Lock()
gesture_until = 0.0

def bridge_call(name, *args):
    """All MPU→MCU calls share one lane: tracking never interrupts gestures."""
    with bridge_lock:
        return Bridge.call(name, *args)

@app.get("/health")
def health():
    return jsonify(ok=True, service="uno-q-face-tracker")

@app.post("/action")
def action():
    global gesture_until

    payload = request.get_json(silent=True) or {}
    command = payload.get("action")
    if command not in ("yes", "no", "idle"):
        return jsonify(error="unsupported action"), 400

    with bridge_lock:
        # Both gestures contain smooth motor movements. Do not issue a tracking
        # look command until the motion has had time to complete.
        if command in ("yes", "no"):
            gesture_until = time.monotonic() + 4.0
        result = Bridge.call(command)

    return jsonify(ok=True, action=command, result=str(result))

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def pixel_to_angle(cx, cy, w, h):
    pan = PAN_CENTER + ((cx - w / 2) / (w / 2)) * (HFOV / 2)
    tilt = TILT_ACTIVE - ((cy - h / 2) / (h / 2)) * (VFOV / 2)
    return pan, tilt

# ---- SSD prior box generation (fixed config for this model) ----
def generate_priors():
    image_size = [INPUT_W, INPUT_H]
    feature_map_wh = [[40, 30], [20, 15], [10, 8], [5, 4]]
    min_boxes = [[10, 16, 24], [32, 48], [64, 96], [128, 192, 256]]
    strides = [8, 16, 32, 64]
    priors = []
    for k, (fw, fh) in enumerate(feature_map_wh):
        for i in range(fh):
            for j in range(fw):
                cx = (j + 0.5) / (image_size[0] / strides[k])
                cy = (i + 0.5) / (image_size[1] / strides[k])
                for min_box in min_boxes[k]:
                    w = min_box / image_size[0]
                    h = min_box / image_size[1]
                    priors.append([cx, cy, w, h])
    return np.array(priors, dtype=np.float32)

PRIORS = generate_priors()
CENTER_VARIANCE = 0.1
SIZE_VARIANCE = 0.2

def decode_boxes(locations, priors):
    boxes = np.concatenate([
        priors[:, :2] + locations[:, :2] * CENTER_VARIANCE * priors[:, 2:],
        priors[:, 2:] * np.exp(locations[:, 2:] * SIZE_VARIANCE)
    ], axis=1)
    # center-form -> corner-form
    boxes[:, :2] -= boxes[:, 2:] / 2
    boxes[:, 2:] += boxes[:, :2]
    return boxes

def detect_faces(frame):
    h, w = frame.shape[:2]
    blob = cv2.dnn.blobFromImage(frame, size=(INPUT_W, INPUT_H), mean=(127, 127, 127), scalefactor=1/128.0, swapRB=True)
    net.setInput(blob)
    outputs = net.forward(net.getUnconnectedOutLayersNames())
    out0, out1 = outputs[0][0], outputs[1][0]

    if out0.shape[-1] == 4:
        boxes, scores = out0, out1
    else:
        boxes, scores = out1, out0

    boxes = decode_boxes(boxes, PRIORS)

    face_scores = scores[:, 1]
    mask = face_scores > CONF_THRESHOLD
    boxes = boxes[mask]
    face_scores = face_scores[mask]

    if len(boxes) == 0:
        return []

    boxes_px = boxes.copy()
    boxes_px[:, 0] *= w
    boxes_px[:, 2] *= w
    boxes_px[:, 1] *= h
    boxes_px[:, 3] *= h

    nms_boxes = [[int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1])] for b in boxes_px]
    indices = cv2.dnn.NMSBoxes(nms_boxes, face_scores.tolist(), CONF_THRESHOLD, NMS_THRESHOLD)

    results = []
    if len(indices) > 0:
        for i in np.array(indices).flatten():
            x, y, bw, bh = nms_boxes[i]
            results.append((x, y, bw, bh, face_scores[i]))
    return results

def tracking_loop():
    global latest_frame
    cap = cv2.VideoCapture(IP_CAM_URL)
    if not cap.isOpened():
        print("Could not open IP camera stream")
        return

    smoothed_pan, smoothed_tilt = PAN_CENTER, TILT_IDLE
    last_sent_pan, last_sent_tilt = None, None
    last_face_time = time.time()
    locked_cx, locked_cy = None, None   # position of the person we're currently tracking

    while True:
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.5)
            continue

        h, w = frame.shape[:2]
        faces = detect_faces(frame)

        chosen = None
        if len(faces) > 0:
            if locked_cx is None:
                # No one being tracked yet — pick the largest/most confident face
                chosen = max(faces, key=lambda f: f[2] * f[3])
            else:
                # Someone already being tracked — pick whoever is closest to last known position
                best_dist = None
                for f in faces:
                    x, y, bw, bh, score = f
                    fcx, fcy = x + bw / 2, y + bh / 2
                    dist = ((fcx - locked_cx) ** 2 + (fcy - locked_cy) ** 2) ** 0.5
                    if best_dist is None or dist < best_dist:
                        best_dist = dist
                        chosen = f
                # If the closest face jumped too far, treat it as a different person —
                # but still follow them (single-person tracking, whoever is closest is "the" person now)
                if best_dist is not None and best_dist > MAX_TRACK_JUMP:
                    chosen = max(faces, key=lambda f: f[2] * f[3])

        if chosen is not None:
            x, y, bw, bh, score = chosen
            cx, cy = x + bw / 2, y + bh / 2
            locked_cx, locked_cy = cx, cy

            raw_pan, raw_tilt = pixel_to_angle(cx, cy, w, h)
            raw_pan = clamp(raw_pan + MOUNT_PAN_OFFSET, 0, 180)
            raw_tilt = clamp(raw_tilt + MOUNT_TILT_OFFSET, 60, 90)
            smoothed_pan += SMOOTH_ALPHA * (raw_pan - smoothed_pan)
            smoothed_tilt += SMOOTH_ALPHA * (raw_tilt - smoothed_tilt)
            last_face_time = time.time()
            send_pan, send_tilt = round(smoothed_pan), round(smoothed_tilt)

            moved_enough = (
                last_sent_pan is None
                or abs(send_pan - last_sent_pan) >= DEADBAND_DEG
                or abs(send_tilt - last_sent_tilt) >= DEADBAND_DEG
            )
            if moved_enough and time.monotonic() >= gesture_until:
                try:
                    bridge_call("look", int(send_pan), int(send_tilt))
                except Exception as e:
                    print(f"Bridge call failed: {e}")
                last_sent_pan, last_sent_tilt = send_pan, send_tilt

            cv2.rectangle(frame, (x, y), (x + bw, y + bh), (0, 255, 0), 2)
        else:
            locked_cx, locked_cy = None, None
            if time.time() - last_face_time > IDLE_TIMEOUT:
                try:
                    if time.monotonic() >= gesture_until:
                        bridge_call("idle")
                except Exception as e:
                    print(f"Bridge call failed: {e}")
                last_sent_pan, last_sent_tilt = None, None
                last_face_time = time.time()

        with frame_lock:
            latest_frame = frame.copy()

def generate_mjpeg():
    while True:
        with frame_lock:
            if latest_frame is None:
                continue
            ok, jpeg = cv2.imencode('.jpg', latest_frame)
        if ok:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
        time.sleep(0.03)

@app.route('/')
def video_feed():
    return Response(generate_mjpeg(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == "__main__":
    t = threading.Thread(target=tracking_loop, daemon=True)
    t.start()
    app.run(host='0.0.0.0', port=5000, threaded=True)