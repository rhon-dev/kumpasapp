# MediaPipe Tasks API — pose + hands + face (1662 features)
"""
Live webcam inference demo for gesture recognition.

Loads gesture_model.pkl, captures webcam frames via MediaPipe Tasks API,
and overlays predicted sign + confidence in real time.

Usage:
    python3 webcam_demo.py

Press Q to quit.
"""

import cv2
import numpy as np
import os
import pickle
import time
import urllib.request
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(SCRIPT_DIR, "models", "gesture_model.pkl")
MODELS_DIR = os.path.join(SCRIPT_DIR, "models")

N_FEATURES = 1662
SEQUENCE_LENGTH = 30
CONFIDENCE_THRESHOLD = 0.6

_MODEL_URLS = {
    'pose': (
        'pose_landmarker_full.task',
        'https://storage.googleapis.com/mediapipe-models/pose_landmarker/'
        'pose_landmarker_full/float16/latest/pose_landmarker_full.task',
    ),
    'hand': (
        'hand_landmarker.task',
        'https://storage.googleapis.com/mediapipe-models/hand_landmarker/'
        'hand_landmarker/float16/latest/hand_landmarker.task',
    ),
    'face': (
        'face_landmarker.task',
        'https://storage.googleapis.com/mediapipe-models/face_landmarker/'
        'face_landmarker/float16/latest/face_landmarker.task',
    ),
}

# Connections for drawing (from mediapipe constants)
_POSE_CONNECTIONS = frozenset([
    (0,1),(1,2),(2,3),(3,7),(0,4),(4,5),(5,6),(6,8),
    (9,10),(11,12),(11,13),(13,15),(15,17),(15,19),(15,21),(17,19),
    (12,14),(14,16),(16,18),(16,20),(16,22),(18,20),
    (11,23),(12,24),(23,24),(23,25),(24,26),(25,27),(26,28),(27,29),(28,30),(29,31),(30,32),(27,31),(28,32),
])
_HAND_CONNECTIONS = frozenset([
    (0,1),(1,2),(2,3),(3,4),(0,5),(5,6),(6,7),(7,8),
    (5,9),(9,10),(10,11),(11,12),(9,13),(13,14),(14,15),(15,16),
    (13,17),(0,17),(17,18),(18,19),(19,20),
])


def ensure_models():
    os.makedirs(MODELS_DIR, exist_ok=True)
    paths = {}
    for key, (fname, url) in _MODEL_URLS.items():
        path = os.path.join(MODELS_DIR, fname)
        if not os.path.exists(path):
            print(f"Downloading {key} model ({fname})...")
            urllib.request.urlretrieve(url, path)
        paths[key] = path
    return paths


def build_landmarkers(model_paths):
    BaseOptions = mp_python.BaseOptions
    RunningMode = mp_vision.RunningMode

    pose = mp_vision.PoseLandmarker.create_from_options(
        mp_vision.PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_paths['pose']),
            running_mode=RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
    )
    hand = mp_vision.HandLandmarker.create_from_options(
        mp_vision.HandLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_paths['hand']),
            running_mode=RunningMode.VIDEO,
            num_hands=2,
            min_hand_detection_confidence=0.5,
            min_hand_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
    )
    face = mp_vision.FaceLandmarker.create_from_options(
        mp_vision.FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_paths['face']),
            running_mode=RunningMode.VIDEO,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_face_presence_confidence=0.5,
        )
    )
    return pose, hand, face


def landmarks_for_frame(rgb, pose_lm, hand_lm, face_lm, timestamp_ms):
    mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    ts = int(timestamp_ms)

    pose_res = pose_lm.detect_for_video(mp_img, ts)
    hand_res = hand_lm.detect_for_video(mp_img, ts)
    face_res = face_lm.detect_for_video(mp_img, ts)

    # Pose: 33 × 4
    if pose_res.pose_landmarks:
        pose = np.array(
            [[lm.x, lm.y, lm.z, lm.visibility] for lm in pose_res.pose_landmarks[0]],
            dtype=np.float32,
        ).flatten()
    else:
        pose = np.zeros(33 * 4, dtype=np.float32)

    left = np.zeros(21 * 3, dtype=np.float32)
    right = np.zeros(21 * 3, dtype=np.float32)
    for i, handedness_list in enumerate(hand_res.handedness):
        label = handedness_list[0].category_name
        arr = np.array(
            [[lm.x, lm.y, lm.z] for lm in hand_res.hand_landmarks[i]],
            dtype=np.float32,
        ).flatten()
        if label == 'Left':
            left = arr
        else:
            right = arr

    if face_res.face_landmarks:
        pts = face_res.face_landmarks[0][:468]
        face = np.array([[lm.x, lm.y, lm.z] for lm in pts], dtype=np.float32).flatten()
        if face.shape[0] < 468 * 3:
            face = np.pad(face, (0, 468 * 3 - face.shape[0]))
    else:
        face = np.zeros(468 * 3, dtype=np.float32)

    return (
        np.concatenate([pose, left, right, face]),
        pose_res, hand_res, face_res,
    )


def draw_landmarks(frame, pose_res, hand_res):
    h, w = frame.shape[:2]

    def px(lm):
        return int(lm.x * w), int(lm.y * h)

    if pose_res.pose_landmarks:
        pts = pose_res.pose_landmarks[0]
        for a, b in _POSE_CONNECTIONS:
            if a < len(pts) and b < len(pts):
                cv2.line(frame, px(pts[a]), px(pts[b]), (80, 180, 80), 1)
        for lm in pts:
            cv2.circle(frame, px(lm), 3, (0, 255, 0), -1)

    colors = [(255, 100, 100), (100, 100, 255)]
    for idx, hand_pts in enumerate(hand_res.hand_landmarks):
        color = colors[idx % 2]
        for a, b in _HAND_CONNECTIONS:
            if a < len(hand_pts) and b < len(hand_pts):
                cv2.line(frame, px(hand_pts[a]), px(hand_pts[b]), color, 1)
        for lm in hand_pts:
            cv2.circle(frame, px(lm), 4, color, -1)


def overlay_prediction(frame, sign, confidence, buffered):
    h, w = frame.shape[:2]

    bar_w = int(w * 0.6)
    fill = int(bar_w * min(buffered / SEQUENCE_LENGTH, 1.0))
    cv2.rectangle(frame, (20, h - 30), (20 + bar_w, h - 14), (50, 50, 50), -1)
    cv2.rectangle(frame, (20, h - 30), (20 + fill, h - 14), (0, 200, 100), -1)
    cv2.putText(frame, f"Buffer: {buffered}/{SEQUENCE_LENGTH}",
                (20, h - 36), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 200, 200), 1)

    if sign is None:
        return

    conf_pct = int(confidence * 100)
    color = (60, 200, 60) if confidence >= 0.7 else (30, 180, 220) if confidence >= 0.4 else (60, 60, 220)
    cv2.rectangle(frame, (0, 0), (w, 70), (0, 0, 0), -1)
    cv2.putText(frame, sign, (16, 48), cv2.FONT_HERSHEY_DUPLEX, 1.4, color, 2)
    cv2.putText(frame, f"{conf_pct}%", (w - 90, 48), cv2.FONT_HERSHEY_SIMPLEX, 1.1, color, 2)


def load_model(path):
    with open(path, 'rb') as f:
        data = pickle.load(f)
    return data['model'], data['scaler'], {v: k for k, v in data['sign_to_label'].items()}


def main():
    print("Loading gesture model...")
    model, scaler, label_to_sign = load_model(MODEL_PATH)
    print(f"Signs ({len(label_to_sign)}): {list(label_to_sign.values())}")

    print("Loading MediaPipe models...")
    model_paths = ensure_models()
    pose_lm, hand_lm, face_lm = build_landmarkers(model_paths)

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        raise RuntimeError("Could not open webcam.")

    frame_buffer = []
    current_sign = None
    current_conf = 0.0
    start_time = time.time()

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            timestamp_ms = (time.time() - start_time) * 1000

            feat, pose_res, hand_res, _ = landmarks_for_frame(
                rgb, pose_lm, hand_lm, face_lm, timestamp_ms
            )

            draw_landmarks(frame, pose_res, hand_res)

            frame_buffer.append(feat)
            if len(frame_buffer) > SEQUENCE_LENGTH:
                frame_buffer.pop(0)

            if len(frame_buffer) == SEQUENCE_LENGTH:
                seq = np.array(frame_buffer, dtype=np.float32).flatten().reshape(1, -1)
                seq_scaled = scaler.transform(seq)
                pred_label = model.predict(seq_scaled)[0]
                proba = model.predict_proba(seq_scaled)[0]
                current_conf = float(proba[pred_label])
                suffix = "" if current_conf >= CONFIDENCE_THRESHOLD else "?"
                current_sign = f"{label_to_sign[pred_label]}{suffix}"

            overlay_prediction(frame, current_sign, current_conf, len(frame_buffer))

            cv2.imshow("Kumpas — Gesture Demo (Q to quit)", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    finally:
        pose_lm.close()
        hand_lm.close()
        face_lm.close()
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
