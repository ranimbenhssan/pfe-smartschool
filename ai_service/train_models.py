"""
Train AI models for SmartSchool
Run once: python train_models.py
"""
import pandas as pd
import numpy as np
import pickle
import os
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report

print("Loading training data...")
df = pd.read_csv("data/training_data.csv")

# ─── Features ───
FEATURES = [
    "total_days",
    "present_count",
    "absent_count",
    "late_count",
    "absence_rate",
    "late_rate",
    "avg_entry_minutes",
    "std_entry_minutes",
    "max_consecutive_absences",
]

X = df[FEATURES]
y = df["label"]

# ─────────────────────────────────────────
#  MODEL 1: Random Forest Classifier
#  Detects: frequentAbsent, latePattern, suspicious, normal
# ─────────────────────────────────────────
print("\nTraining Random Forest Classifier...")

le = LabelEncoder()
y_encoded = le.fit_transform(y)

X_train, X_test, y_train, y_test = train_test_split(
    X, y_encoded, test_size=0.2, random_state=42
)

rf_model = RandomForestClassifier(
    n_estimators=100,
    max_depth=10,
    random_state=42,
    class_weight="balanced"
)
rf_model.fit(X_train, y_train)

y_pred = rf_model.predict(X_test)
print("\nClassification Report:")
print(classification_report(y_test, y_pred, target_names=le.classes_))

# ─────────────────────────────────────────
#  MODEL 2: Isolation Forest
#  Detects anomalies / suspicious behavior
# ─────────────────────────────────────────
print("\nTraining Isolation Forest...")

iso_model = IsolationForest(
    n_estimators=100,
    contamination=0.1,
    random_state=42
)
iso_model.fit(X[FEATURES])

# ─────────────────────────────────────────
#  Save models
# ─────────────────────────────────────────
os.makedirs("models", exist_ok=True)

with open("models/rf_model.pkl", "wb") as f:
    pickle.dump(rf_model, f)

with open("models/iso_model.pkl", "wb") as f:
    pickle.dump(iso_model, f)

with open("models/label_encoder.pkl", "wb") as f:
    pickle.dump(le, f)

with open("models/features.pkl", "wb") as f:
    pickle.dump(FEATURES, f)

print("\n✅ Models saved to models/")
print("Models: rf_model.pkl, iso_model.pkl, label_encoder.pkl, features.pkl")