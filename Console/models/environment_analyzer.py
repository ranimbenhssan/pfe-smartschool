"""
EnvironmentAnalyzer — Rule-based + statistical analysis of classroom sensor data.
Computes comfort scores and detects trends.
"""

import numpy as np
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

THRESHOLDS = {
    "temperature": {"min": 16, "max": 30, "ideal_min": 20, "ideal_max": 25},
    "humidity":    {"min": 30, "max": 70, "ideal_min": 40, "ideal_max": 60},
    "light_level": {"min": 300, "max": 1000, "ideal_min": 400, "ideal_max": 800},
    "noise_level": {"max": 70, "ideal_max": 55},
}


class EnvironmentAnalyzer:

    def analyze(self, room_id: str, temperature: float, humidity: float,
                light_level: float, noise_level: float) -> dict:

        issues = []
        warnings = []
        scores = []

        # ── Temperature ──
        t = THRESHOLDS["temperature"]
        if temperature < t["min"] or temperature > t["max"]:
            issues.append(f"Temperature out of range ({temperature}°C)")
            scores.append(0)
        elif temperature < t["ideal_min"] or temperature > t["ideal_max"]:
            warnings.append(f"Temperature not ideal ({temperature}°C)")
            scores.append(50)
        else:
            scores.append(100)

        # ── Humidity ──
        h = THRESHOLDS["humidity"]
        if humidity < h["min"] or humidity > h["max"]:
            issues.append(f"Humidity out of range ({humidity}%)")
            scores.append(0)
        elif humidity < h["ideal_min"] or humidity > h["ideal_max"]:
            warnings.append(f"Humidity not ideal ({humidity}%)")
            scores.append(50)
        else:
            scores.append(100)

        # ── Light ──
        l = THRESHOLDS["light_level"]
        if light_level < l["min"]:
            issues.append(f"Too dark ({light_level} lux)")
            scores.append(0)
        elif light_level < l["ideal_min"] or light_level > l["ideal_max"]:
            warnings.append(f"Light not ideal ({light_level} lux)")
            scores.append(50)
        else:
            scores.append(100)

        # ── Noise ──
        n = THRESHOLDS["noise_level"]
        if noise_level > n["max"]:
            issues.append(f"Too noisy ({noise_level} dB)")
            scores.append(0)
        elif noise_level > n["ideal_max"]:
            warnings.append(f"Noise slightly high ({noise_level} dB)")
            scores.append(50)
        else:
            scores.append(100)

        comfort_score = int(np.mean(scores))
        severity = "high" if issues else ("medium" if warnings else "low")

        return {
            "room_id": room_id,
            "comfort_score": comfort_score,
            "severity": severity,
            "issues": issues,
            "warnings": warnings,
            "readings": {
                "temperature": temperature,
                "humidity": humidity,
                "light_level": light_level,
                "noise_level": noise_level,
            },
            "recommendations": self._get_recommendations(issues + warnings),
            "timestamp": datetime.now().isoformat(),
        }

    def _get_recommendations(self, problems: list) -> list:
        recs = []
        for p in problems:
            if "cold" in p.lower() or "temperature" in p.lower():
                recs.append("Adjust heating/cooling system.")
            if "dark" in p.lower() or "light" in p.lower():
                recs.append("Turn on additional lights or open blinds.")
            if "noisy" in p.lower() or "noise" in p.lower():
                recs.append("Reduce noise sources or check for equipment issues.")
            if "humidity" in p.lower():
                recs.append("Use a humidifier or dehumidifier as needed.")
        return list(set(recs))