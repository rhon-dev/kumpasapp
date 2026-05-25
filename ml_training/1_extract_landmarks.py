# MediaPipe Tasks API — pose + hands + face (1662 features)
"""
Extract landmarks from FSL-105 dataset videos using MediaPipe Tasks API.

Feature vector per frame (1662 values):
  - pose:       33 × 4  (x, y, z, visibility) = 132
  - left_hand:  21 × 3  (x, y, z)             =  63
  - right_hand: 21 × 3  (x, y, z)             =  63
  - face:      468 × 3  (x, y, z)             = 1404
  Total: 1662

Model files are downloaded automatically to ml_training/models/ on first run.
"""

import cv2
import numpy as np
import os
import json
import urllib.request
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision

SELECTED_SIGNS = (
    list(range(0, 10)) +   # Greetings
    list(range(10, 20)) +  # Survival
    list(range(20, 30)) +  # Numbers
    list(range(42, 52)) +  # Days
    list(range(52, 62))    # Family
)

SELECTED_SIGN_NAMES = [
    # Greetings (0-9)
    "GOOD MORNING", "GOOD AFTERNOON", "GOOD EVENING", "HELLO", "HOW ARE YOU",
    "IM FINE", "NICE TO MEET YOU", "THANK YOU", "YOURE WELCOME", "SEE YOU TOMORROW",
    # Survival (10-19)
    "UNDERSTAND", "DON'T UNDERSTAND", "KNOW", "DON'T KNOW", "NO",
    "YES", "WRONG", "CORRECT", "SLOW", "FAST",
    # Numbers (20-29)
    "ONE", "TWO", "THREE", "FOUR", "FIVE",
    "SIX", "SEVEN", "EIGHT", "NINE", "TEN",
    # Days (42-51)
    "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY",
    "SATURDAY", "SUNDAY", "TODAY", "TOMORROW", "YESTERDAY",
    # Family (52-61)
    "FATHER", "MOTHER", "SON", "DAUGHTER", "GRANDFATHER",
    "GRANDMOTHER", "UNCLE", "AUNTIE", "COUSIN", "PARENTS",
]

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.join(
    os.path.expanduser("~"), "Downloads",
    "FSL-105 A dataset for recognizing 105 Filipino sign language videos"
)
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "extracted_landmarks")
MODELS_DIR = os.path.join(SCRIPT_DIR, "models")

N_FEATURES = 1662  # 132 + 63 + 63 + 1404

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(MODELS_DIR, exist_ok=True)

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


def ensure_models():
    paths = {}
    for key, (fname, url) in _MODEL_URLS.items():
        path = os.path.join(MODELS_DIR, fname)
        if not os.path.exists(path):
            print(f"Downloading {key} model ({fname})...")
            urllib.request.urlretrieve(url, path)
            print(f"  Saved: {path}")
        paths[key] = path
    return paths


def build_landmarkers(model_paths):
    BaseOptions = mp_python.BaseOptions
    RunningMode = mp_vision.RunningMode

    pose = mp_vision.PoseLandmarker.create_from_options(
        mp_vision.PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_paths['pose']),
            running_mode=RunningMode.IMAGE,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
        )
    )
    hand = mp_vision.HandLandmarker.create_from_options(
        mp_vision.HandLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_paths['hand']),
            running_mode=RunningMode.IMAGE,
            num_hands=2,
            min_hand_detection_confidence=0.5,
            min_hand_presence_confidence=0.5,
        )
    )
    face = mp_vision.FaceLandmarker.create_from_options(
        mp_vision.FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_paths['face']),
            running_mode=RunningMode.IMAGE,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_face_presence_confidence=0.5,
        )
    )
    return pose, hand, face


def landmarks_for_frame(rgb, pose_lm, hand_lm, face_lm):
    """Return flat float32 array of shape (1662,) from one RGB frame."""
    mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

    pose_res = pose_lm.detect(mp_img)
    hand_res = hand_lm.detect(mp_img)
    face_res = face_lm.detect(mp_img)

    # Pose: 33 × 4
    if pose_res.pose_landmarks:
        pose = np.array(
            [[lm.x, lm.y, lm.z, lm.visibility] for lm in pose_res.pose_landmarks[0]],
            dtype=np.float32,
        ).flatten()
    else:
        pose = np.zeros(33 * 4, dtype=np.float32)

    # Hands: separate left / right by handedness label
    left = np.zeros(21 * 3, dtype=np.float32)
    right = np.zeros(21 * 3, dtype=np.float32)
    for i, handedness_list in enumerate(hand_res.handedness):
        label = handedness_list[0].category_name  # 'Left' or 'Right'
        arr = np.array(
            [[lm.x, lm.y, lm.z] for lm in hand_res.hand_landmarks[i]],
            dtype=np.float32,
        ).flatten()
        if label == 'Left':
            left = arr
        else:
            right = arr

    # Face: use first 468 landmarks (Tasks API may return 478 with iris)
    if face_res.face_landmarks:
        pts = face_res.face_landmarks[0][:468]
        face = np.array(
            [[lm.x, lm.y, lm.z] for lm in pts],
            dtype=np.float32,
        ).flatten()
        if face.shape[0] < 468 * 3:
            face = np.pad(face, (0, 468 * 3 - face.shape[0]))
    else:
        face = np.zeros(468 * 3, dtype=np.float32)

    return np.concatenate([pose, left, right, face])


def extract_features_from_video(video_path, pose_lm, hand_lm, face_lm):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return None

    sequence = []
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.resize(frame, (640, 480))
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        sequence.append(landmarks_for_frame(rgb, pose_lm, hand_lm, face_lm).tolist())

    cap.release()

    if len(sequence) < 5:
        return None
    return sequence


def process_sign_videos(sign_id, sign_name, pose_lm, hand_lm, face_lm):
    sign_path = os.path.join(DATASET_PATH, "clips", str(sign_id))
    if not os.path.exists(sign_path):
        print(f"  Path not found: {sign_path}")
        return []

    video_files = sorted(
        f for f in os.listdir(sign_path)
        if f.upper().endswith('.MOV') or f.endswith('.mp4')
    )
    print(f"\n{sign_name} (ID {sign_id}): {len(video_files)} videos")

    results = []
    for i, vf in enumerate(video_files, 1):
        path = os.path.join(sign_path, vf)
        print(f"  [{i:2d}/{len(video_files)}] {vf}...", end=" ", flush=True)
        features = extract_features_from_video(path, pose_lm, hand_lm, face_lm)
        if features:
            results.append({
                'sign_id': sign_id,
                'sign_name': sign_name,
                'video_file': vf,
                'num_frames': len(features),
                'landmarks': features,
            })
            print(f"OK  ({len(features)} frames, {N_FEATURES} features/frame)")
        else:
            print("SKIP  (no landmarks detected)")
    return results


if __name__ == "__main__":
    output_file = os.path.join(OUTPUT_DIR, "landmarks_data.json")

    # Resume: load existing data and skip already-done signs
    if os.path.exists(output_file):
        with open(output_file) as f:
            all_data = json.load(f)
        done_ids = set(d['sign_id'] for d in all_data)
        print(f"Resuming — {len(done_ids)} signs already done, {len(all_data)} videos loaded.")
    else:
        all_data = []
        done_ids = set()

    print("=" * 60)
    print("FSL-105 Landmark Extraction — MediaPipe Tasks API")
    print(f"Features per frame : {N_FEATURES}  (132 pose + 63 lh + 63 rh + 1404 face)")
    print(f"Dataset            : {DATASET_PATH}")
    print(f"Output             : {OUTPUT_DIR}")
    print("=" * 60)

    model_paths = ensure_models()
    pose_lm, hand_lm, face_lm = build_landmarkers(model_paths)

    try:
        for sid, sname in zip(SELECTED_SIGNS, SELECTED_SIGN_NAMES):
            if sid in done_ids:
                print(f"SKIP (already done): {sname}")
                continue
            sign_data = process_sign_videos(sid, sname, pose_lm, hand_lm, face_lm)
            all_data.extend(sign_data)
            # Checkpoint: save after every sign so a crash loses at most 1 sign
            with open(output_file, 'w') as f:
                json.dump(all_data, f)
            print(f"  Checkpoint saved ({len(all_data)} videos total)")
    finally:
        pose_lm.close()
        hand_lm.close()
        face_lm.close()

    print(f"\nDone. Saved {len(all_data)} videos -> {output_file}")
    print("\nPer-class count:")
    for sid, sname in zip(SELECTED_SIGNS, SELECTED_SIGN_NAMES):
        count = sum(1 for d in all_data if d['sign_id'] == sid)
        print(f"  {sname}: {count} videos")
    print("\nNext step: python3 2_train_model.py")
