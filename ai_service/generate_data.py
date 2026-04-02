"""
Generate synthetic training data for SmartSchool AI models
Run once: python generate_data.py
"""
import pandas as pd
import numpy as np
import json
import os

np.random.seed(42)
N_STUDENTS = 200
N_DAYS = 90

print("Generating synthetic attendance data...")

records = []
for student_id in range(N_STUDENTS):
    # Assign behavior pattern
    pattern = np.random.choice(
        ["good", "frequent_absent", "late_pattern", "suspicious"],
        p=[0.6, 0.15, 0.15, 0.10]
    )

    absent_count = 0
    late_count = 0
    entry_times = []

    for day in range(N_DAYS):
        # Skip weekends
        if day % 7 in [5, 6]:
            continue

        if pattern == "good":
            status = np.random.choice(
                ["present", "absent", "late"],
                p=[0.92, 0.05, 0.03]
            )
        elif pattern == "frequent_absent":
            status = np.random.choice(
                ["present", "absent", "late"],
                p=[0.60, 0.35, 0.05]
            )
        elif pattern == "late_pattern":
            status = np.random.choice(
                ["present", "absent", "late"],
                p=[0.60, 0.05, 0.35]
            )
        else:  # suspicious
            status = np.random.choice(
                ["present", "absent", "late"],
                p=[0.50, 0.25, 0.25]
            )

        if status == "absent":
            absent_count += 1
            entry_time = -1
        elif status == "late":
            late_count += 1
            entry_time = np.random.uniform(20, 90)  # minutes after 8AM
        else:
            entry_time = np.random.uniform(-10, 15)  # minutes around 8AM

        entry_times.append(entry_time)

    # Features
    total_days = len(entry_times)
    present_count = total_days - absent_count - late_count
    absence_rate = absent_count / total_days if total_days > 0 else 0
    late_rate = late_count / total_days if total_days > 0 else 0

    valid_times = [t for t in entry_times if t >= 0]
    avg_entry = np.mean(valid_times) if valid_times else 0
    std_entry = np.std(valid_times) if len(valid_times) > 1 else 0
    consecutive_absences = 0
    max_consecutive = 0
    for t in entry_times:
        if t == -1:
            consecutive_absences += 1
            max_consecutive = max(max_consecutive, consecutive_absences)
        else:
            consecutive_absences = 0

    # Label
    if pattern == "frequent_absent" and absent_count >= 3:
        label = "frequentAbsent"
    elif pattern == "late_pattern" and late_count >= 4:
        label = "latePattern"
    elif pattern == "suspicious" and (absent_count >= 2 or late_count >= 3):
        label = "suspicious"
    else:
        label = "normal"

    records.append({
        "student_id": f"student_{student_id}",
        "total_days": total_days,
        "present_count": present_count,
        "absent_count": absent_count,
        "late_count": late_count,
        "absence_rate": round(absence_rate, 3),
        "late_rate": round(late_rate, 3),
        "avg_entry_minutes": round(avg_entry, 2),
        "std_entry_minutes": round(std_entry, 2),
        "max_consecutive_absences": max_consecutive,
        "label": label,
    })

df = pd.DataFrame(records)
os.makedirs("data", exist_ok=True)
df.to_csv("data/training_data.csv", index=False)

print(f"Generated {len(df)} student records")
print(f"Label distribution:\n{df['label'].value_counts()}")
print("Saved to data/training_data.csv")