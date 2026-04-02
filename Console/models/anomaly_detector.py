"""
AnomalyDetector — Isolation Forest for detecting suspicious behavior.
Detects: unusual entry times, unusual absence bursts, erratic patterns.
"""

import numpy as np
import pickle
import os
from datetime import datetime, timedelta
from sklearn.ensemble import IsolationForest
import logging

logger = logging.getLogger(__name__)
MODEL_PATH = "models/saved/anomaly_model.pkl"


class AnomalyDetector:
    def __init__(self, db):
        self.db = db
        self.model = None
        self.load_or_train()

    def load_or_train(self):
        os.makedirs("models/saved", exist_ok=True)
        if os.path.exists(MODEL_PATH):
            with open(MODEL_PATH, "rb") as f:
                self.model = pickle.load(f)
            logger.info("Anomaly model loaded.")
        else:
            self.train_with_synthetic_data()

    def train(self):
        logger.info("Training anomaly model...")
        X = self._fetch_features()
        if len(X) < 10:
            self.train_with_synthetic_data()
            return
        self._fit(X)

    def train_with_synthetic_data(self):
        np.random.seed(42)
        n = 300
        # Normal: consistent arrival times, low absence rate
        normal = np.column_stack([
            np.random.normal(8.5, 0.5, n),   # avg_entry_hour (8:30 AM)
            np.random.uniform(0, 0.15, n),   # absence_rate
            np.random.uniform(0, 1, n),      # skip_rate (in uni but absent)
            np.random.normal(2, 0.5, n),     # avg_absences_per_week
        ])
        # Anomalous: erratic
        anomalous = np.column_stack([
            np.random.uniform(6, 14, 30),
            np.random.uniform(0.4, 1.0, 30),
            np.random.uniform(0.5, 1.0, 30),
            np.random.uniform(5, 10, 30),
        ])
        X = np.vstack([normal, anomalous])
        self._fit(X)
        logger.info("Anomaly model trained on synthetic data.")

    def _fit(self, X):
        self.model = IsolationForest(contamination=0.1, random_state=42)
        self.model.fit(X)
        with open(MODEL_PATH, "wb") as f:
            pickle.dump(self.model, f)

    def detect(self, student_id: str) -> dict:
        features = self._build_features(student_id)
        if features is None:
            return {"student_id": student_id, "anomaly": False, "score": 0.0, "reason": "insufficient_data"}

        X = np.array([features])
        pred = self.model.predict(X)[0]       # -1 = anomaly, 1 = normal
        score = self.model.decision_function(X)[0]
        is_anomaly = pred == -1

        result = {
            "student_id": student_id,
            "anomaly": bool(is_anomaly),
            "score": round(float(score), 4),
            "features": {
                "avg_entry_hour": round(features[0], 2),
                "absence_rate": round(features[1], 3),
                "skip_rate": round(features[2], 3),
                "avg_absences_per_week": round(features[3], 2),
            },
        }

        if is_anomaly:
            self._create_anomaly_flag(student_id, result)

        return result

    def _build_features(self, student_id: str):
        try:
            # Get RFID logs (entry times)
            rfid_snap = (self.db.collection("rfid_logs")
                        .where("studentId", "==", student_id)
                        .where("location", "==", "gate")
                        .order_by("timestamp", direction="DESCENDING")
                        .limit(30)
                        .stream())

            entry_hours = []
            for doc in rfid_snap:
                ts = doc.to_dict().get("timestamp")
                if ts:
                    dt = ts if isinstance(ts, datetime) else ts.to_datetime()
                    entry_hours.append(dt.hour + dt.minute / 60)

            avg_entry_hour = np.mean(entry_hours) if entry_hours else 8.5

            # Get attendance stats
            cutoff = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
            att_snap = (self.db.collection("attendance")
                       .where("studentId", "==", student_id)
                       .where("date", ">=", cutoff)
                       .stream())

            total, absences, skips = 0, 0, 0
            for doc in att_snap:
                d = doc.to_dict()
                total += 1
                if d.get("status") == "absent":
                    absences += 1

            # Get skip count (ai_flags of type in_university_skipped_class)
            flag_snap = (self.db.collection("ai_flags")
                        .where("studentId", "==", student_id)
                        .where("type", "==", "in_university_skipped_class")
                        .stream())
            skips = sum(1 for _ in flag_snap)

            if total == 0:
                return None

            absence_rate = absences / total
            skip_rate = skips / max(absences, 1)
            avg_absences_per_week = absences / 4.0  # over ~4 weeks

            return [avg_entry_hour, absence_rate, skip_rate, avg_absences_per_week]

        except Exception as e:
            logger.error(f"Error building features for {student_id}: {e}")
            return None

    def _fetch_features(self):
        """Fetch features for all students for training."""
        X = []
        try:
            students = self.db.collection("students").stream()
            for doc in students:
                features = self._build_features(doc.id)
                if features:
                    X.append(features)
        except Exception as e:
            logger.error(f"Error fetching features: {e}")
        return np.array(X) if X else np.array([]).reshape(0, 4)

    def _create_anomaly_flag(self, student_id: str, result: dict):
        try:
            student_doc = self.db.collection("students").doc(student_id).get()
            student_name = student_doc.to_dict().get("name", "Unknown") if student_doc.exists else "Unknown"

            flag_ref = self.db.collection("ai_flags").document()
            flag_ref.set({
                "id": flag_ref.id,
                "studentId": student_id,
                "studentName": student_name,
                "type": "suspicious_behavior",
                "severity": "high",
                "description": (
                    f"Isolation Forest detected anomalous behavior for {student_name}. "
                    f"Anomaly score: {result['score']}. "
                    f"Absence rate: {result['features']['absence_rate']:.1%}, "
                    f"Skip rate: {result['features']['skip_rate']:.1%}."
                ),
                "anomalyScore": result["score"],
                "features": result["features"],
                "resolved": False,
                "createdAt": datetime.now(),
            })
        except Exception as e:
            logger.error(f"Error creating anomaly flag: {e}")