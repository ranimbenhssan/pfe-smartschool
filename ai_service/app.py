"""
SmartSchool AI Microservice
Flask REST API for attendance pattern detection
"""
from flask import Flask, request, jsonify
import pickle
import numpy as np
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# ─────────────────────────────────────────
#  Load Models
# ─────────────────────────────────────────
MODELS_LOADED = False
rf_model = None
iso_model = None
label_encoder = None
features = None

def load_models():
    global rf_model, iso_model, label_encoder, features, MODELS_LOADED
    try:
        with open("models/rf_model.pkl", "rb") as f:
            rf_model = pickle.load(f)
        with open("models/iso_model.pkl", "rb") as f:
            iso_model = pickle.load(f)
        with open("models/label_encoder.pkl", "rb") as f:
            label_encoder = pickle.load(f)
        with open("models/features.pkl", "rb") as f:
            features = pickle.load(f)
        MODELS_LOADED = True
        print("✅ AI Models loaded successfully")
    except Exception as e:
        print(f"⚠️ Models not loaded: {e}")
        print("Run: python generate_data.py && python train_models.py")
        MODELS_LOADED = False

load_models()

# ─────────────────────────────────────────
#  HEALTH CHECK
# ─────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "running",
        "models_loaded": MODELS_LOADED,
        "service": "SmartSchool AI Service",
        "version": "1.0.0"
    })

# ─────────────────────────────────────────
#  ANALYZE ATTENDANCE
#  POST /analyze/attendance
#  Input: student attendance stats
#  Output: flag_type, risk_score, details
# ─────────────────────────────────────────
@app.route("/analyze/attendance", methods=["POST"])
def analyze_attendance():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        # Extract features
        total_days = int(data.get("total", 0))
        present = int(data.get("present", 0))
        absent = int(data.get("absent", 0))
        late = int(data.get("late", 0))

        if total_days == 0:
            return jsonify({
                "flag_type": None,
                "risk_score": 0,
                "details": "Not enough data",
                "recommendation": "Monitor student attendance"
            })

        absence_rate = absent / total_days
        late_rate = late / total_days
        avg_entry = float(data.get("avg_entry_minutes", 0))
        std_entry = float(data.get("std_entry_minutes", 0))
        max_consecutive = int(data.get("max_consecutive_absences", 0))

        # ─── Rule-based fallback ───
        flag_type = None
        risk_score = 0.0
        details = ""

        if absent >= 5:
            flag_type = "frequentAbsent"
            risk_score = min(1.0, absent / 15)
            details = f"Student absent {absent} times ({round(absence_rate*100)}% absence rate)"
        elif absent >= 3:
            flag_type = "frequentAbsent"
            risk_score = min(0.8, absent / 10)
            details = f"Student absent {absent} times in last 30 days"
        elif late >= 5:
            flag_type = "latePattern"
            risk_score = min(1.0, late / 15)
            details = f"Student late {late} times ({round(late_rate*100)}% late rate)"
        elif late >= 4:
            flag_type = "latePattern"
            risk_score = min(0.7, late / 10)
            details = f"Student has repeated late arrivals ({late} times)"

        # ─── ML Model prediction ───
        if MODELS_LOADED:
            try:
                X = np.array([[
                    total_days, present, absent, late,
                    absence_rate, late_rate,
                    avg_entry, std_entry, max_consecutive
                ]])

                # Random Forest prediction
                pred = rf_model.predict(X)[0]
                pred_proba = rf_model.predict_proba(X)[0]
                pred_label = label_encoder.inverse_transform([pred])[0]
                confidence = float(max(pred_proba))

                # Isolation Forest anomaly score
                iso_score = iso_model.decision_function(X)[0]
                is_anomaly = iso_model.predict(X)[0] == -1

                if pred_label != "normal" and confidence > 0.5:
                    flag_type = pred_label
                    risk_score = round(confidence, 3)
                    if pred_label == "frequentAbsent":
                        details = f"AI detected frequent absence pattern. Absent {absent} times ({round(absence_rate*100)}% rate)"
                    elif pred_label == "latePattern":
                        details = f"AI detected late arrival pattern. Late {late} times ({round(late_rate*100)}% rate)"
                    elif pred_label == "suspicious":
                        details = f"AI detected suspicious attendance behavior requiring attention"

                if is_anomaly and flag_type is None:
                    flag_type = "suspicious"
                    risk_score = round(max(0.4, abs(iso_score)), 3)
                    details = f"AI detected unusual attendance pattern"

            except Exception as e:
                print(f"⚠️ ML prediction error: {e}")

        recommendation = _get_recommendation(flag_type, absent, late, total_days)

        return jsonify({
            "flag_type": flag_type,
            "risk_score": round(risk_score, 3),
            "details": details,
            "recommendation": recommendation,
            "stats": {
                "total_days": total_days,
                "present": present,
                "absent": absent,
                "late": late,
                "absence_rate": round(absence_rate * 100, 1),
                "late_rate": round(late_rate * 100, 1),
            }
        })

    except Exception as e:
        print(f"❌ analyze_attendance error: {e}")
        return jsonify({"error": str(e)}), 500

# ─────────────────────────────────────────
#  ANALYZE ENTRY PATTERN
#  POST /analyze/pattern
#  Input: list of entry timestamps
#  Output: is_suspicious, reason
# ─────────────────────────────────────────
@app.route("/analyze/pattern", methods=["POST"])
def analyze_pattern():
    try:
        data = request.get_json()
        entry_times = data.get("entry_times", [])

        if len(entry_times) < 5:
            return jsonify({
                "is_suspicious": False,
                "reason": "Not enough data",
                "pattern": "unknown"
            })

        times = np.array(entry_times)
        mean_time = float(np.mean(times))
        std_time = float(np.std(times))
        late_entries = int(np.sum(times > 15))
        very_late = int(np.sum(times > 45))

        is_suspicious = False
        reason = ""
        pattern = "normal"

        if very_late >= 3:
            is_suspicious = True
            pattern = "very_late"
            reason = f"Student arrives very late ({very_late} times over 45 minutes late)"
        elif late_entries >= 5:
            is_suspicious = True
            pattern = "consistently_late"
            reason = f"Student consistently late ({late_entries} late entries, avg {round(mean_time, 1)} min)"
        elif std_time > 30:
            is_suspicious = True
            pattern = "irregular"
            reason = f"Highly irregular entry times (std: {round(std_time, 1)} min)"

        return jsonify({
            "is_suspicious": is_suspicious,
            "reason": reason,
            "pattern": pattern,
            "stats": {
                "mean_entry_minutes": round(mean_time, 2),
                "std_entry_minutes": round(std_time, 2),
                "late_entries": late_entries,
                "very_late_entries": very_late,
            }
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ─────────────────────────────────────────
#  ANALYZE CLASSROOM COMFORT
#  POST /analyze/classroom
#  Input: sensor readings array
#  Output: comfort_score, recommendations
# ─────────────────────────────────────────
@app.route("/analyze/classroom", methods=["POST"])
def analyze_classroom():
    try:
        data = request.get_json()
        readings = data.get("readings", [])

        if not readings:
            return jsonify({"error": "No readings provided"}), 400

        temps = [r.get("temperature", 22) for r in readings]
        hums = [r.get("humidity", 50) for r in readings]
        lights = [r.get("lightLevel", 400) for r in readings]
        noises = [r.get("noiseLevel", 40) for r in readings]

        avg_temp = float(np.mean(temps))
        avg_hum = float(np.mean(hums))
        avg_light = float(np.mean(lights))
        avg_noise = float(np.mean(noises))

        # Calculate comfort score
        score = 100.0
        recommendations = []

        if avg_temp < 18 or avg_temp > 28:
            score -= 30
            if avg_temp > 28:
                recommendations.append("Room is too hot. Turn on AC or open windows.")
            else:
                recommendations.append("Room is too cold. Consider heating.")
        elif avg_temp < 20 or avg_temp > 25:
            score -= 10
            recommendations.append("Temperature slightly outside ideal range (20-25°C).")

        if avg_hum < 30 or avg_hum > 70:
            score -= 25
            if avg_hum > 70:
                recommendations.append("High humidity. Improve ventilation.")
            else:
                recommendations.append("Low humidity. Consider a humidifier.")
        elif avg_hum < 40 or avg_hum > 60:
            score -= 10

        if avg_light < 100:
            score -= 25
            recommendations.append("Very poor lighting. Turn on all lights.")
        elif avg_light < 300:
            score -= 10
            recommendations.append("Insufficient lighting for studying.")

        if avg_noise > 80:
            score -= 20
            recommendations.append("Excessive noise level. Students may struggle to concentrate.")
        elif avg_noise > 60:
            score -= 10
            recommendations.append("Elevated noise level.")

        score = max(0, min(100, score))

        if not recommendations:
            recommendations.append("Classroom environment is comfortable for learning.")

        comfort_level = "good" if score >= 70 else "average" if score >= 40 else "poor"

        return jsonify({
            "comfort_score": round(score, 1),
            "comfort_level": comfort_level,
            "recommendations": recommendations,
            "averages": {
                "temperature": round(avg_temp, 1),
                "humidity": round(avg_hum, 1),
                "light_level": round(avg_light, 1),
                "noise_level": round(avg_noise, 1),
            }
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ─────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────
def _get_recommendation(flag_type, absent, late, total):
    if flag_type == "frequentAbsent":
        rate = round(absent / total * 100) if total > 0 else 0
        return f"Contact parents immediately. Absence rate is {rate}%. Consider intervention."
    elif flag_type == "latePattern":
        return f"Discuss tardiness with student and parents. {late} late arrivals recorded."
    elif flag_type == "suspicious":
        return "Monitor student closely. Unusual attendance behavior detected."
    return "Student attendance is within normal range."

# ─────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"🚀 SmartSchool AI Service starting on port {port}")
    app.run(host="0.0.0.0", port=port, debug=False)
