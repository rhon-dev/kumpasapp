# MediaPipe Holistic (unified pose + hands + face)
"""
Train gesture recognition model on extracted hand landmarks.

Feature layout (1662 values per frame, produced by 1_extract_landmarks.py):
  POSE_LEN  = 33  × 4 = 132   (x, y, z, visibility)
  HAND_LEN  = 21  × 3 =  63   (x, y, z) — each hand
  FACE_LEN  = 468 × 3 = 1404  (x, y, z)
  N_FEATURES = 132 + 63 + 63 + 1404 = 1662

Critical fixes vs v1:
  1. Data leakage removed: augmentation and scaler.fit happen ONLY on training
     data. In v1, scaler.fit_transform ran on all data before the split, so
     the scaler "saw" the test set during training — inflating val accuracy.
  2. Stratified split preserves class balance in both train and test sets.
  3. 5-fold cross-validation gives a reliable accuracy estimate when the
     dataset is small (20 videos per class).
  4. Full classification report shows per-class precision/recall, not just
     a single accuracy number.
  5. Relative paths so the script runs on any machine.
"""

import json
import numpy as np
import os
import pickle
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.metrics import classification_report

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LANDMARKS_FILE = os.path.join(SCRIPT_DIR, "extracted_landmarks", "landmarks_data.json")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "models")
SIGNS = [
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
SEQUENCE_LENGTH = 30

os.makedirs(OUTPUT_DIR, exist_ok=True)


def prepare_sequences(landmarks_data):
    """
    Convert raw video landmarks to fixed-length feature vectors.
    Takes the middle SEQUENCE_LENGTH frames so both the start and end of the
    sign are represented (vs v1 which took only the last 30 frames).
    """
    X, y = [], []
    sign_to_label = {sign: idx for idx, sign in enumerate(SIGNS)}
    num_features = None

    for video in landmarks_data:
        sign_name = video['sign_name']
        if sign_name not in sign_to_label:
            continue

        frames = np.array(video['landmarks'])  # (num_frames, features_per_frame)

        if num_features is None:
            num_features = frames.shape[1]

        if len(frames) >= SEQUENCE_LENGTH:
            # Take the middle SEQUENCE_LENGTH frames
            start = (len(frames) - SEQUENCE_LENGTH) // 2
            sequence = frames[start:start + SEQUENCE_LENGTH].flatten()
        else:
            # Pad shorter videos with zeros at the end
            padded = np.zeros((SEQUENCE_LENGTH, num_features))
            padded[:len(frames)] = frames
            sequence = padded.flatten()

        X.append(sequence)
        y.append(sign_to_label[sign_name])

    if num_features is None:
        raise ValueError("No valid sequences found. Check that landmarks_data.json is not empty.")
    return np.array(X), np.array(y), sign_to_label, num_features


def augment_data(X, y, copies=4, noise_std=0.02):
    """
    Augment by adding Gaussian noise copies.
    Called ONLY on training data to avoid leaking test info.
    """
    X_aug, y_aug = [X], [y]
    for _ in range(copies - 1):
        noisy = X + np.random.normal(0, noise_std, X.shape)
        X_aug.append(np.clip(noisy, 0, 1))
        y_aug.append(y)
    return np.concatenate(X_aug), np.concatenate(y_aug)


def train_model():
    print("=" * 60)
    print("Gesture Recognition Model Training")
    print("=" * 60)

    # --- 1. Load data ---
    print("\n1. Loading data...")
    with open(LANDMARKS_FILE, 'r') as f:
        landmarks_data = json.load(f)
    print(f"   {len(landmarks_data)} videos")

    # --- 2. Build feature matrix ---
    print("\n2. Preparing sequences...")
    X, y, sign_to_label, num_features = prepare_sequences(landmarks_data)
    total_features = SEQUENCE_LENGTH * num_features
    print(f"   X shape         : {X.shape}  ({SEQUENCE_LENGTH} frames x {num_features} features)")
    print(f"   Total features  : {total_features}")
    unique, counts = np.unique(y, return_counts=True)
    print(f"   Class distribution: { {SIGNS[i]: c for i, c in zip(unique, counts)} }")

    # --- 3. Stratified train/test split BEFORE any augmentation or scaling ---
    print("\n3. Stratified 80/20 split...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"   Train: {X_train.shape[0]}  |  Test: {X_test.shape[0]}")

    # --- 4. Augment ONLY training data ---
    print("\n4. Augmenting training data (x4 with noise)...")
    X_train, y_train = augment_data(X_train, y_train, copies=4, noise_std=0.02)
    print(f"   Training samples after augmentation: {X_train.shape[0]}")

    # --- 5. Fit scaler on TRAINING data only, then apply to both ---
    print("\n5. Scaling features (fit on train, transform both)...")
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)   # use training mean/std only

    # --- 6. Cross-validation on training set ---
    print("\n6. 5-fold cross-validation on training set...")
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_model = RandomForestClassifier(
        n_estimators=200, max_depth=20, min_samples_split=3,
        random_state=42, n_jobs=-1
    )
    cv_scores = cross_val_score(cv_model, X_train, y_train, cv=cv, scoring='accuracy')
    print(f"   CV accuracy: {cv_scores.mean():.2%}  (+/- {cv_scores.std():.2%})")

    # --- 7. Train final model on full training set ---
    print("\n7. Training final Random Forest...")
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=20,
        min_samples_split=3,
        min_samples_leaf=1,
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train, y_train)

    # --- 8. Evaluate on held-out test set ---
    print("\n8. Test set results...")
    y_pred = model.predict(X_test)
    test_acc = model.score(X_test, y_test)
    print(f"\n   Test Accuracy: {test_acc:.2%}\n")
    print(classification_report(y_test, y_pred, target_names=SIGNS, zero_division=0))

    # --- 9. Save model ---
    print("9. Saving model...")
    model_data = {
        'model': model,
        'scaler': scaler,
        'sign_to_label': sign_to_label,
        'sequence_length': SEQUENCE_LENGTH,
        'num_features': num_features,
        'total_features': total_features,   # used by Flask API for validation
    }
    model_path = os.path.join(OUTPUT_DIR, "gesture_model.pkl")
    with open(model_path, 'wb') as f:
        pickle.dump(model_data, f)
    print(f"   Saved: {model_path}")

    sign_mapping = {'label_to_sign': {str(v): k for k, v in sign_to_label.items()}}
    mapping_path = os.path.join(OUTPUT_DIR, "sign_mapping.json")
    with open(mapping_path, 'w') as f:
        json.dump(sign_mapping, f)
    print(f"   Saved: {mapping_path}")

    print("\n" + "=" * 60)
    print("Done!")
    print(f"  CV Accuracy  : {cv_scores.mean():.2%} (+/- {cv_scores.std():.2%})")
    print(f"  Test Accuracy: {test_acc:.2%}")
    print(f"  API input    : {total_features} values  ({SEQUENCE_LENGTH} frames x {num_features} features)")
    print("=" * 60)
    print("\nNext step: python3 flask_api.py")


if __name__ == "__main__":
    train_model()
