const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────
//  CONFIG
// ─────────────────────────────────────────
const SCHOOL_START_HOUR = 8;   // 8:00 AM
const SCHOOL_START_MIN  = 0;
const LATE_THRESHOLD_MIN = 15; // 15 min after start = late
const AI_SERVICE_URL = "https://your-ai-service.railway.app"; // update later

// ─────────────────────────────────────────
//  HELPER: format date as YYYY-MM-DD
// ─────────────────────────────────────────
function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

// ─────────────────────────────────────────
//  HELPER: send push notification
// ─────────────────────────────────────────
async function sendNotification(userId, title, message, type = "general") {
  try {
    const notifRef = db.collection("notifications").doc();
    await notifRef.set({
      userId,
      title,
      message,
      type,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    functions.logger.log(`✅ Notification sent to ${userId}: ${title}`);
  } catch (e) {
    functions.logger.error(`❌ Notification error: ${e}`);
  }
}

// ─────────────────────────────────────────
//  HELPER: call AI service
// ─────────────────────────────────────────
async function callAIService(endpoint, data) {
  try {
    const response = await axios.post(`${AI_SERVICE_URL}${endpoint}`, data, {
      timeout: 10000,
    });
    return response.data;
  } catch (e) {
    functions.logger.warn(`⚠️ AI service unavailable: ${e.message}`);
    return null;
  }
}

// ─────────────────────────────────────────
//  1. RFID SCAN — Called by ESP32
//     POST /rfidScan
//     Body: { rfidTag, doorId, direction }
// ─────────────────────────────────────────
exports.rfidScan = functions.https.onRequest(async (req, res) => {
  // Allow CORS for ESP32
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  try {
    const { rfidTag, doorId, direction } = req.body;

    if (!rfidTag || !doorId || !direction) {
      res.status(400).json({ error: "Missing required fields" });
      return;
    }

    functions.logger.log(`📡 RFID scan: ${rfidTag} at ${doorId} direction: ${direction}`);

    const now = new Date();
    const dateStr = formatDate(now);

    // ─── Find student by RFID tag ───
    const studentSnap = await db
      .collection("students")
      .where("rfidTag", "==", rfidTag)
      .limit(1)
      .get();

    if (studentSnap.empty) {
      // Unknown tag — log it
      await db.collection("rfid_logs").add({
        rfidTag,
        doorId,
        direction: direction.toUpperCase(),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRecognized: false,
        studentId: "",
        studentName: "Unknown",
      });
      functions.logger.warn(`⚠️ Unknown RFID tag: ${rfidTag}`);
      res.status(200).json({ status: "unknown_tag", rfidTag });
      return;
    }

    const studentDoc = studentSnap.docs[0];
    const student = studentDoc.data();
    const studentId = studentDoc.id;

    // ─── Log the RFID scan ───
    await db.collection("rfid_logs").add({
      rfidTag,
      studentId,
      studentName: student.name,
      doorId,
      direction: direction.toUpperCase(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRecognized: true,
    });

    // ─── Process attendance on entry (IN) ───
    if (direction.toUpperCase() === "IN") {
      // Determine attendance status
      const schoolStart = new Date(now);
      schoolStart.setHours(SCHOOL_START_HOUR, SCHOOL_START_MIN, 0, 0);

      const diffMinutes = (now - schoolStart) / 60000;
      let status = "present";
      if (diffMinutes > LATE_THRESHOLD_MIN) {
        status = "late";
      }

      // Check if attendance already exists for today
      const existingAttendance = await db
        .collection("attendance")
        .where("studentId", "==", studentId)
        .where("date", "==", dateStr)
        .limit(1)
        .get();

      if (existingAttendance.empty) {
        // Create new attendance record
        const attendanceRef = db.collection("attendance").doc();
        await attendanceRef.set({
          studentId,
          studentName: student.name,
          classId: student.classId,
          date: dateStr,
          status,
          entryTime: admin.firestore.FieldValue.serverTimestamp(),
          exitTime: null,
          note: "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        functions.logger.log(`✅ Attendance recorded: ${student.name} - ${status}`);

        // ─── Send notification to teacher ───
        const classDoc = await db.collection("classes").doc(student.classId).get();
        if (classDoc.exists) {
          const classData = classDoc.data();
          const teacherIds = classData.teacherIds || [];
          for (const teacherId of teacherIds) {
            await sendNotification(
              teacherId,
              `Student ${status === "late" ? "Late" : "Arrived"}`,
              `${student.name} ${status === "late" ? "arrived late" : "arrived"} at ${now.getHours()}:${String(now.getMinutes()).padStart(2, "0")}`,
              "attendance"
            );
          }
        }

        // ─── Trigger AI analysis ───
        await triggerAIAnalysis(studentId, student.name, student.classId);

      } else {
        // Update entry time if already exists
        await existingAttendance.docs[0].ref.update({
          entryTime: admin.firestore.FieldValue.serverTimestamp(),
          status,
        });
      }
    }

    // ─── Process exit (OUT) ───
    if (direction.toUpperCase() === "OUT") {
      const existingAttendance = await db
        .collection("attendance")
        .where("studentId", "==", studentId)
        .where("date", "==", dateStr)
        .limit(1)
        .get();

      if (!existingAttendance.empty) {
        await existingAttendance.docs[0].ref.update({
          exitTime: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    res.status(200).json({
      status: "success",
      studentName: student.name,
      attendanceStatus: direction.toUpperCase() === "IN" ? "recorded" : "exit_recorded",
    });

  } catch (error) {
    functions.logger.error("❌ rfidScan error:", error);
    res.status(500).json({ error: error.message });
  }
});

// ─────────────────────────────────────────
//  2. SENSOR DATA — Called by ESP32
//     POST /sensorData
//     Body: { roomId, temperature, humidity, lightLevel, noiseLevel }
// ─────────────────────────────────────────
exports.sensorData = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  try {
    const { roomId, temperature, humidity, lightLevel, noiseLevel } = req.body;

    if (!roomId) {
      res.status(400).json({ error: "roomId is required" });
      return;
    }

    functions.logger.log(`🌡️ Sensor data from room ${roomId}: temp=${temperature}, humidity=${humidity}`);

    // ─── Get room info ───
    const roomDoc = await db.collection("rooms").doc(roomId).get();
    if (!roomDoc.exists) {
      res.status(404).json({ error: "Room not found" });
      return;
    }
    const room = roomDoc.data();

    // ─── Calculate comfort score ───
    let comfortScore = 100;
    const temp = parseFloat(temperature) || 0;
    const hum = parseFloat(humidity) || 0;
    const light = parseFloat(lightLevel) || 0;
    const noise = parseFloat(noiseLevel) || 0;

    // Temperature: ideal 20-25°C
    if (temp < 18 || temp > 28) comfortScore -= 30;
    else if (temp < 20 || temp > 25) comfortScore -= 10;

    // Humidity: ideal 40-60%
    if (hum < 30 || hum > 70) comfortScore -= 25;
    else if (hum < 40 || hum > 60) comfortScore -= 10;

    // Light: ideal above 300 lux
    if (light < 100) comfortScore -= 25;
    else if (light < 300) comfortScore -= 10;

    // Noise: ideal below 50dB
    if (noise > 80) comfortScore -= 20;
    else if (noise > 60) comfortScore -= 10;

    comfortScore = Math.max(0, Math.min(100, comfortScore));

    // ─── Store sensor reading ───
    await db.collection("sensor_data").add({
      roomId,
      roomName: room.name || roomId,
      temperature: temp,
      humidity: hum,
      lightLevel: light,
      noiseLevel: noise,
      comfortScore,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ─── Update room comfort score ───
    await db.collection("rooms").doc(roomId).update({
      comfortScore,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.log(`✅ Sensor data stored. Comfort score: ${comfortScore}`);

    res.status(200).json({
      status: "success",
      comfortScore,
      roomId,
    });

  } catch (error) {
    functions.logger.error("❌ sensorData error:", error);
    res.status(500).json({ error: error.message });
  }
});

// ─────────────────────────────────────────
//  3. MARK ABSENT — Scheduled daily at 9AM
//     Marks students as absent if no entry
// ─────────────────────────────────────────
exports.markAbsentStudents = functions.pubsub
  .schedule("0 9 * * 1-5") // 9AM Monday-Friday
  .timeZone("Africa/Tunis")
  .onRun(async (context) => {
    try {
      const today = formatDate(new Date());
      functions.logger.log(`📅 Marking absent students for ${today}`);

      // Get all students
      const studentsSnap = await db.collection("students").get();

      for (const studentDoc of studentsSnap.docs) {
        const student = studentDoc.data();
        const studentId = studentDoc.id;

        // Check if attendance exists for today
        const attendanceSnap = await db
          .collection("attendance")
          .where("studentId", "==", studentId)
          .where("date", "==", today)
          .limit(1)
          .get();

        if (attendanceSnap.empty) {
          // No entry — mark as absent
          await db.collection("attendance").add({
            studentId,
            studentName: student.name,
            classId: student.classId,
            date: today,
            status: "absent",
            entryTime: null,
            exitTime: null,
            note: "Auto-marked absent",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          functions.logger.log(`❌ Marked absent: ${student.name}`);

          // Notify teacher
          const classDoc = await db
            .collection("classes")
            .doc(student.classId)
            .get();
          if (classDoc.exists) {
            const teacherIds = classDoc.data().teacherIds || [];
            for (const teacherId of teacherIds) {
              await sendNotification(
                teacherId,
                "Student Absent",
                `${student.name} is absent today (${today})`,
                "attendance"
              );
            }
          }

          // Trigger AI analysis
          await triggerAIAnalysis(studentId, student.name, student.classId);
        }
      }

      functions.logger.log("✅ markAbsentStudents completed");
      return null;
    } catch (error) {
      functions.logger.error("❌ markAbsentStudents error:", error);
      return null;
    }
  });

// ─────────────────────────────────────────
//  4. AI ANALYSIS TRIGGER
//     Called internally after attendance change
// ─────────────────────────────────────────
async function triggerAIAnalysis(studentId, studentName, classId) {
  try {
    // Get last 30 days of attendance
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const attendanceSnap = await db
      .collection("attendance")
      .where("studentId", "==", studentId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    const attendanceHistory = attendanceSnap.docs.map((doc) => doc.data());

    const present = attendanceHistory.filter((a) => a.status === "present").length;
    const absent = attendanceHistory.filter((a) => a.status === "absent").length;
    const late = attendanceHistory.filter((a) => a.status === "late").length;
    const total = attendanceHistory.length;

    functions.logger.log(`🤖 AI Analysis for ${studentName}: present=${present}, absent=${absent}, late=${late}`);

    let flagType = null;
    let details = "";
    let riskScore = 0;

    // ─── Rule-based detection (fallback if AI service unavailable) ───
    const absenceRate = total > 0 ? absent / total : 0;
    const lateRate = total > 0 ? late / total : 0;

    if (absent >= 3) {
      flagType = "frequentAbsent";
      details = `Student has been absent ${absent} times in the last 30 days (${Math.round(absenceRate * 100)}% absence rate)`;
      riskScore = Math.min(1, absenceRate * 2);
    } else if (late >= 4) {
      flagType = "latePattern";
      details = `Student has arrived late ${late} times in the last 30 days`;
      riskScore = Math.min(1, lateRate * 2);
    }

    // ─── Call AI service if available ───
    const aiResult = await callAIService("/analyze/attendance", {
      studentId,
      present,
      absent,
      late,
      total,
      absenceRate,
      lateRate,
    });

    if (aiResult && aiResult.flag_type) {
      flagType = aiResult.flag_type;
      details = aiResult.details || details;
      riskScore = aiResult.risk_score || riskScore;
    }

    // ─── Create AI flag if needed ───
    if (flagType && riskScore > 0.3) {
      // Check if flag already exists
      const existingFlag = await db
        .collection("ai_flags")
        .where("studentId", "==", studentId)
        .where("type", "==", flagType)
        .where("resolved", "==", false)
        .limit(1)
        .get();

      if (existingFlag.empty) {
        const flagRef = db.collection("ai_flags").doc();
        await flagRef.set({
          studentId,
          studentName,
          classId,
          type: flagType,
          details,
          riskScore,
          resolved: false,
          detectedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolvedAt: null,
        });

        functions.logger.log(`🚨 AI Flag created: ${flagType} for ${studentName}`);

        // Notify admin
        const adminsSnap = await db
          .collection("users")
          .where("role", "==", "admin")
          .get();

        for (const adminDoc of adminsSnap.docs) {
          await sendNotification(
            adminDoc.id,
            `AI Alert: ${flagType === "frequentAbsent" ? "Frequent Absence" : "Late Pattern"}`,
            `${studentName}: ${details}`,
            "aiAlert"
          );
        }

        // Notify teachers of the class
        const classDoc = await db.collection("classes").doc(classId).get();
        if (classDoc.exists) {
          const teacherIds = classDoc.data().teacherIds || [];
          for (const teacherId of teacherIds) {
            await sendNotification(
              teacherId,
              `AI Alert: ${studentName}`,
              details,
              "aiAlert"
            );
          }
        }
      }
    }
  } catch (error) {
    functions.logger.error("❌ triggerAIAnalysis error:", error);
  }
}

// ─────────────────────────────────────────
//  5. MANUAL AI TRIGGER — HTTP endpoint
//     POST /triggerAI
//     Body: { studentId }
// ─────────────────────────────────────────
exports.triggerAI = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  try {
    const { studentId } = req.body;
    if (!studentId) {
      res.status(400).json({ error: "studentId required" });
      return;
    }
    const studentDoc = await db.collection("students").doc(studentId).get();
    if (!studentDoc.exists) {
      res.status(404).json({ error: "Student not found" });
      return;
    }
    const student = studentDoc.data();
    await triggerAIAnalysis(studentId, student.name, student.classId);
    res.status(200).json({ status: "success", message: "AI analysis triggered" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ─────────────────────────────────────────
//  6. GET FUNCTIONS URLS — for ESP32 config
//     GET /getConfig
// ─────────────────────────────────────────
exports.getConfig = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.status(200).json({
    status: "SmartSchool Cloud Functions running",
    endpoints: {
      rfidScan: "/rfidScan",
      sensorData: "/sensorData",
      triggerAI: "/triggerAI",
    },
  });
});