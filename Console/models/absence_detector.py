"""
AbsenceDetector — Random Forest model for absence pattern recognition.
Detects: frequent absences, late arrival patterns, day-of-week patterns.
"""

import numpy as np
import pickle
import os
from datetime import datetime, timedelta
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder
import logging

logger = logging.getLogger(__name__)

MODEL_PATH = "models/saved/absence_model.pkl"


class AbsenceDetector:
    def __init__(self, db):
        self.db = db
        self.model = None
        self.load_or_train()

    # ─── Load or Train ──────────────────────────────────────────────────────

    def load_or_train(self):
        os.makedirs("models/saved", exist_ok=True)
        if os.path.exists(MODEL_PATH):
            with open(MODEL_PATH, "rb") as f:
                self.model = pickle.load(f)
            logger.info("Absence model loaded from disk.")
        else:
            logger.info("No saved model. Training with synthetic data...")
            self.train_with_synthetic_data()

    def train(self):
        """Retrain on real Firestore data."""
        logger.info("Training absence model on Firestore data...")
        X, y = self._fetch_training_data()
        if len(X) < 10:
            logger.warning("Not enough real data. Using synthetic.")
            self.train_with_synthetic_data()
            return
        self._fit(X, y)
        logger.info(f"Model trained on {len(X)} records.")

    def train_with_synthetic_data(self):
        """Generate synthetic training data for initial deployment."""
        np.random.seed(42)
        n = 500
        X = np.column_stack([
            np.random.randint(0, 7, n),          # day_of_week (0=Mon)
            np.random.randint(0, 6, n),          # absence_count_7d
            np.random.randint(0, 14, n),         # absence_count_14d
            np.random.randint(0, 30, n),         # absence_count_30d
            np.random.choice([0, 1], n),         # was_at_university
            np.random.randint(0, 12, n),         # hour_of_day
            np.random.randint(1, 5, n),          # classes_per_day
        ])
        # Label: 0=normal, 1=at_risk, 2=critical
        y = np.where(X[:, 2] >= 5, 2, np.where(X[:, 1] >= 2, 1, 0))
        self._fit(X, y)
        logger.info("Trained on synthetic data.")

    def _fit(self, X, y):
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.model.fit(X, y)
        with open(MODEL_PATH, "wb") as f:
            pickle.dump(self.model, f)

    # ─── Analyze Single Event ───────────────────────────────────────────────

    def analyze(self, student_id: str, class_id: str, date: str,
                status: str, was_at_university: bool) -> dict:
        """Analyze a single attendance event and flag if needed."""

        # Get recent absence counts
        counts = self._get_absence_counts(student_id)
        day_of_week = datetime.strptime(date, "%Y-%m-%d").weekday()
        hour = datetime.now().hour

        features = np.array([[
            day_of_week,
            counts["7d"],
            counts["14d"],
            counts["30d"],
            1 if was_at_university else 0,
            hour,
            counts["classes_today"],
        ]])

        risk_level = "normal"
        flag_created = False

        if self.model:
            pred = self.model.predict(features)[0]
            proba = self.model.predict_proba(features)[0]
            risk_level = ["normal", "at_risk", "critical"][pred]

            if risk_level in ["at_risk", "critical"] and status == "absent":
                flag_created = self._create_flag(student_id, class_id, date, risk_level, counts, proba)

        return {
            "student_id": student_id,
            "risk_level": risk_level,
            "absence_counts": counts,
            "was_at_university": was_at_university,
            "flag_created": flag_created,
        }

    def analyze_pattern(self, student_id: str, absence_count: int, period_days: int) -> dict:
        """Analyze overall absence pattern for daily cron."""
        counts = self._get_absence_counts(student_id)

        risk_level = "normal"
        if absence_count >= 5:
            risk_level = "critical"
        elif absence_count >= 3:
            risk_level = "at_risk"

        day_pattern = self._get_day_pattern(student_id)

        return {
            "student_id": student_id,
            "risk_level": risk_level,
            "absence_count": absence_count,
            "period_days": period_days,
            "absence_counts": counts,
            "day_pattern": day_pattern,
        }

    def get_stats(self, student_id: str) -> dict:
        """Return attendance stats for a student."""
        counts = self._get_absence_counts(student_id)
        total = self._get_total_attendance(student_id)
        rate = round((total - counts["30d"]) / max(total, 1) * 100, 1)
        return {
            "student_id": student_id,
            "attendance_rate": rate,
            "absence_counts": counts,
            "total_records": total,
        }

    # ─── Firestore Helpers ──────────────────────────────────────────────────

    def _get_absence_counts(self, student_id: str) -> dict:
        now = datetime.now()
        dates = {
            "7d":  (now - timedelta(days=7)).strftime("%Y-%m-%d"),
            "14d": (now - timedelta(days=14)).strftime("%Y-%m-%d"),
            "30d": (now - timedelta(days=30)).strftime("%Y-%m-%d"),
        }
        counts = {"7d": 0, "14d": 0, "30d": 0, "classes_today": 0}
        today = now.strftime("%Y-%m-%d")

        try:
            snap = (self.db.collection("attendance")
                    .where("studentId", "==", student_id)
                    .where("status", "==", "absent")
                    .where("date", ">=", dates["30d"])
                    .stream())

            for doc in snap:
                d = doc.to_dict()
                date_str = d.get("date", "")
                if date_str >= dates["7d"]:  counts["7d"] += 1
                if date_str >= dates["14d"]: counts["14d"] += 1
                counts["30d"] += 1

            today_snap = (self.db.collection("attendance")
                         .where("studentId", "==", student_id)
                         .where("date", "==", today)
                         .stream())
            counts["classes_today"] = sum(1 for _ in today_snap)
        except Exception as e:
            logger.error(f"Firestore error in _get_absence_counts: {e}")

        return counts

    def _get_total_attendance(self, student_id: str) -> int:
        try:
            snap = (self.db.collection("attendance")
                    .where("studentId", "==", student_id)
                    .stream())
            return sum(1 for _ in snap)
        except Exception:
            return 0

    def _get_day_pattern(self, student_id: str) -> dict:
        """Returns which days of week the student is most absent."""
        day_counts = {i: 0 for i in range(7)}
        try:
            snap = (self.db.collection("attendance")
                    .where("studentId", "==", student_id)
                    .where("status", "==", "absent")
                    .stream())
            for doc in snap:
                date_str = doc.to_dict().get("date", "")
                try:
                    day = datetime.strptime(date_str, "%Y-%m-%d").weekday()
                    day_counts[day] += 1
                except Exception:
                    pass
        except Exception as e:
            logger.error(f"Error in _get_day_pattern: {e}")

        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return {days[k]: v for k, v in day_counts.items()}

    def _create_flag(self, student_id, class_id, date, risk_level, counts, proba) -> bool:
        """Create an AI flag in Firestore."""
        try:
            existing = (self.db.collection("ai_flags")
                       .where("studentId", "==", student_id)
                       .where("type", "==", "ai_absence_risk")
                       .where("resolved", "==", False)
                       .limit(1)
                       .stream())
            if any(True for _ in existing):
                return False  # Already flagged

            student_doc = self.db.collection("students").doc(student_id).get()
            student_name = student_doc.to_dict().get("name", "Unknown") if student_doc.exists else "Unknown"

            flag_ref = self.db.collection("ai_flags").document()
            flag_ref.set({
                "id": flag_ref.id,
                "studentId": student_id,
                "studentName": student_name,
                "classId": class_id,
                "date": date,
                "type": "ai_absence_risk",
                "severity": "high" if risk_level == "critical" else "medium",
                "description": (
                    f"AI detected {risk_level} absence risk for {student_name}. "
                    f"Absences: {counts['7d']} (7d), {counts['14d']} (14d), {counts['30d']} (30d). "
                    f"Confidence: {round(max(proba) * 100)}%."
                ),
                "riskLevel": risk_level,
                "absenceCounts": counts,
                "confidence": round(float(max(proba)), 3),
                "resolved": False,
                "createdAt": datetime.now(),
            })
            return True
        except Exception as e:
            logger.error(f"Error creating AI flag: {e}")
            return False

    def _fetch_training_data(self):
        """Fetch real attendance data from Firestore for training."""
        X, y = [], []
        try:
            cutoff = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")
            snap = (self.db.collection("attendance")
                    .where("date", ">=", cutoff)
                    .stream())

            student_counts: dict = {}
            for doc in snap:
                d = doc.to_dict()
                sid = d.get("studentId", "")
                if sid not in student_counts:
                    student_counts[sid] = {"absent": 0, "present": 0, "late": 0}
                student_counts[sid][d.get("status", "absent")] += 1

            for sid, counts in student_counts.items():
                total = sum(counts.values())
                if total == 0:
                    continue
                absence_rate = counts["absent"] / total
                label = 2 if absence_rate > 0.4 else (1 if absence_rate > 0.2 else 0)
                X.append([0, counts["absent"], counts["absent"], counts["absent"], 0, 9, 5])
                y.append(label)

        except Exception as e:
            logger.error(f"Error fetching training data: {e}")

        return np.array(X) if X else np.array([]).reshape(0, 7), np.array(y)