/*
  ============================================================
  SmartSchool IoT — ESP32 (PROTOTYPE)
  Firebase ESP Client library (Firebase.RTDB.xxx)
  ============================================================
  PROTOTYPE MODE:
  • One ESP32 handles everything (DHT22 + RFID + LCD + Servo + LEDs)
  • DHT22 writes to floor_2 only → Flutter mirrors to all other floors
  • RFID handles university entry for all students and teachers

  For multi-floor production deployment:
  • Flash one ESP32 per floor
  • Change FLOOR_NUMBER + FLOOR_ID + HAS_RFID per unit
  • Remove startPrototypeBroadcast() call from Flutter iot_service.dart

  Library: "Firebase ESP Client" by Mobizt (>= v4)
  Board: ESP32 Dev Module
  Partition: Default 4MB with spiffs

  Wiring:
    DHT22 ED26  → GPIO 2   (data), 3.3V, GND
    DHT22 ED24  → GPIO 4   (data), 3.3V, GND
    RC522 SDA   → GPIO 5
    RC522 SCK   → GPIO 18
    RC522 MOSI  → GPIO 23
    RC522 MISO  → GPIO 19
    RC522 RST   → GPIO 15
    LCD SDA     → GPIO 21
    LCD SCL     → GPIO 22
    LED GREEN   → GPIO 26  (+ 220Ω to GND)
    LED RED     → GPIO 27  (+ 220Ω to GND)
    SERVO       → GPIO 13  (5V external, shared GND)
  ============================================================
*/

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include <DHT.h>
#include <MFRC522.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include <time.h>

// ─────────────────────────────────────────────────────────────────────────────
//  ★  CONFIGURE THESE FOR EACH ESP32 UNIT  ★
// ─────────────────────────────────────────────────────────────────────────────
#define WIFI_SSID       "iPhone de Ranim"
#define WIFI_PASSWORD   "ranim1234"
#define FIREBASE_HOST   "pfe-smartschool-default-rtdb.europe-west1.firebasedatabase.app/"
#define API_KEY         "AIzaSyDTWS13ATaP_0No4yjp6RC-MOiddghSmsc"
#define DATABASE_SECRET "CyMLHjOdJ88awIAwGyEhgBSX83mF6aEfAYJ0WcUk"

// ── PROTOTYPE: single ESP32 on floor 2 ────────────────────────────────────
// Flutter mirrors floor_2 readings to all other floors automatically.
// When adding more ESP32 units later, change these 3 lines per unit:
//   Floor 0: FLOOR_NUMBER 0 | FLOOR_ID "floor_0" | HAS_RFID true
//   Floor 1: FLOOR_NUMBER 1 | FLOOR_ID "floor_1" | HAS_RFID false
//   Floor 3: FLOOR_NUMBER 3 | FLOOR_ID "floor_3" | HAS_RFID false
//   Floor 4: FLOOR_NUMBER 4 | FLOOR_ID "floor_4" | HAS_RFID false
#define FLOOR_NUMBER    2
#define FLOOR_ID        "floor_2"
#define HAS_RFID        true    // prototype: RFID at this single unit

// ─── DHT22 — single sensor ────────────────────────────────────────────────────
#define SENSOR_NAME   "dht22"
#define SENSOR_PIN    27

#define DHT_TYPE  DHT22

// ─── DHT22 ────────────────────────────────────────────────────────────────────
#define DHT_TYPE  DHT22

// ─── RC522 RFID ───────────────────────────────────────────────────────────────
#define RFID_SS_PIN   5
#define RFID_RST_PIN  4

// ─── LEDs ─────────────────────────────────────────────────────────────────────
#define LED_GREEN  26
#define LED_RED    25

// ─── Servo ────────────────────────────────────────────────────────────────────
#define SERVO_PIN    13
#define SERVO_OPEN   90
#define SERVO_CLOSE   0
#define SERVO_HOLD   3000

// ─── Objects ──────────────────────────────────────────────────────────────────
DHT               dht(SENSOR_PIN, DHT_TYPE);
MFRC522           rfid(RFID_SS_PIN, RFID_RST_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo             gateServo;
FirebaseData      fbData;
FirebaseAuth      fbAuth;
FirebaseConfig    fbConfig;

unsigned long lastTempMs = 0;
const unsigned long TEMP_INTERVAL = 30000;
bool firebaseReady = false;

// ─────────────────────────────────────────────────────────────────────────────
//  SETUP
// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n== SmartSchool IoT — " FLOOR_ID " ==");

  // ── GPIO ──────────────────────────────────────────────────────────────────
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED,   OUTPUT);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_RED,   LOW);

  gateServo.attach(SERVO_PIN);
  gateServo.write(SERVO_CLOSE);

  // ── LCD ───────────────────────────────────────────────────────────────────
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcdPrint("SmartSchool","");

  // ── DHT22 ─────────────────────────────────────────────────────────────────
  dht.begin();
  delay(2000);

  // ── RFID (only if present on this floor) ──────────────────────────────────
  if (HAS_RFID) {
    SPI.begin();
    rfid.PCD_Init();
    delay(100);
    Serial.println("RFID ready");
  }

  // ── WiFi ──────────────────────────────────────────────────────────────────
  lcdPrint("WiFi...", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 30) {
    delay(500);
    Serial.print(".");
    tries++;
  }
  if (WiFi.status() != WL_CONNECTED) {
    lcdPrint("WiFi FAILED", "Check creds");
    while (true) delay(1000);
  }
  Serial.println("\nWiFi: " + WiFi.localIP().toString());

  // ── Firebase ──────────────────────────────────────────────────────────────
  fbConfig.api_key      = API_KEY;
  fbConfig.database_url = "https://" FIREBASE_HOST;
  fbConfig.signer.tokens.legacy_token = DATABASE_SECRET;
  fbConfig.token_status_callback = tokenStatusCallback;

  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);

  lcdPrint("Firebase...", "Connecting");
  unsigned long w = millis();
  while (!Firebase.ready() && millis() - w < 10000) delay(300);

  firebaseReady = Firebase.ready();
  if (firebaseReady) {
    // Announce this floor device online
    Firebase.RTDB.setBool(&fbData,
        "/iot/devices/" FLOOR_ID "/online", true);
    Firebase.RTDB.setString(&fbData,
        "/iot/devices/" FLOOR_ID "/ip",
        WiFi.localIP().toString().c_str());
    Firebase.RTDB.setInt(&fbData,
        "/iot/devices/" FLOOR_ID "/floor", FLOOR_NUMBER);
    Serial.println("Firebase ready — " FLOOR_ID);
  } else {
    Serial.println("Firebase NOT ready");
  }

  lcdPrint("Ready", HAS_RFID ? "Scan your card" : "Monitoring...");
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOOP
// ─────────────────────────────────────────────────────────────────────────────
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    delay(3000);
    return;
  }

  firebaseReady = Firebase.ready();

  // 1. Upload temperature every 30s
  if (firebaseReady && millis() - lastTempMs > TEMP_INTERVAL) {
    lastTempMs = millis();
    uploadTemperature();
  }

  // 2. Check RFID (only if this floor has a reader)
  if (HAS_RFID && rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    handleRfidScan();
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEMPERATURE — single DHT22, writes to floor_2
//  Flutter mirrors this reading to all other floors (prototype mode)
// ─────────────────────────────────────────────────────────────────────────────
void uploadTemperature() {
  float temp = dht.readTemperature();
  float hum  = dht.readHumidity();

  if (isnan(temp) || isnan(hum)) {
    Serial.println("[DHT22] Read failed — check wiring on pin " + String(SENSOR_PIN));
    return;
  }

  Serial.printf("[DHT22] %.1f°C  %.1f%%  — uploading...\n", temp, hum);

  String base = "/iot/temperature/" FLOOR_ID "/" SENSOR_NAME;

  bool ok = true;
  if (!Firebase.RTDB.setFloat(&fbData,  (base + "/temperature").c_str(), temp))
    { Serial.println("  ERR temperature: " + fbData.errorReason()); ok = false; }
  if (!Firebase.RTDB.setFloat(&fbData,  (base + "/humidity").c_str(),    hum))
    { Serial.println("  ERR humidity: "    + fbData.errorReason()); ok = false; }
  if (!Firebase.RTDB.setInt(&fbData,    (base + "/pin").c_str(),         SENSOR_PIN))
    { Serial.println("  ERR pin: "         + fbData.errorReason()); ok = false; }
  if (!Firebase.RTDB.setInt(&fbData,    (base + "/floor").c_str(),       FLOOR_NUMBER))
    { Serial.println("  ERR floor: "       + fbData.errorReason()); ok = false; }
  if (!Firebase.RTDB.setInt(&fbData,    (base + "/updatedAt").c_str(),   (int)millis()))
    { Serial.println("  ERR updatedAt: "   + fbData.errorReason()); ok = false; }

  if (ok) Serial.println("  Upload OK → " + base);
}

// ─────────────────────────────────────────────────────────────────────────────
//  RFID — university entry only
// ─────────────────────────────────────────────────────────────────────────────
void handleRfidScan() {
  String tag = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) tag += "0";
    tag += String(rfid.uid.uidByte[i], HEX);
  }
  tag.toUpperCase();

  Serial.println("Tag: " + tag);
  lcdPrint("Scanning...", tag.c_str());

  if (!firebaseReady) {
    lcdPrint("Firebase Error", "Not connected");
    blinkLed(LED_RED, 3);
    delay(1500);
    lcdPrint("Ready", "Scan your card");
    return;
  }

  // Push scan to RTDB — Flutter processes and responds
  FirebaseJson json;
  json.set("tag",       tag.c_str());
  json.set("scannedAt", (int)millis());
  json.set("floor",     FLOOR_ID);
  json.set("processed", false);
  json.set("response",  "");

  if (!Firebase.RTDB.pushJSON(&fbData, "/iot/rfid_scans", &json)) {
    Serial.println("Push error: " + fbData.errorReason());
    lcdPrint("Server Error", "Try again");
    blinkLed(LED_RED, 3);
    delay(1500);
    lcdPrint("Ready", "Scan your card");
    return;
  }

  String scanId       = fbData.pushName();
  String responsePath = "/iot/rfid_scans/" + scanId + "/response";

  // Poll for Flutter response (max 5s)
  String response = "";
  for (int i = 0; i < 50; i++) {
    delay(100);
    if (Firebase.RTDB.getString(&fbData, responsePath.c_str())) {
      String val = fbData.stringData();
      if (val == "authorized" || val == "denied") {
        response = val;
        break;
      }
    }
  }

  Serial.println("Response: " + (response.length() ? response : "timeout"));

  if (response == "authorized") {
    grantAccess();
  } else {
    denyAccess(response.length() ? "Unknown tag" : "Timeout");
  }

  delay(500);
  lcdPrint("Ready", "Scan your card");
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACCESS FEEDBACK
// ─────────────────────────────────────────────────────────────────────────────
void grantAccess() {
  Serial.println(">> AUTHORIZED");
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_RED,   LOW);
  lcdPrint("  AUTHORIZED  ", "  Access OK   ");
  gateServo.write(SERVO_OPEN);
  delay(SERVO_HOLD);
  gateServo.write(SERVO_CLOSE);
  digitalWrite(LED_GREEN, LOW);
}

void denyAccess(const char* reason) {
  Serial.printf(">> DENIED — %s\n", reason);
  digitalWrite(LED_RED,   HIGH);
  digitalWrite(LED_GREEN, LOW);
  lcdPrint("   DENIED     ", reason);
  delay(2000);
  digitalWrite(LED_RED, LOW);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
void lcdPrint(const char* l1, const char* l2) {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(l1);
  lcd.setCursor(0, 1); lcd.print(l2);
}
void lcdPrint(const char* l1, String l2) { lcdPrint(l1, l2.c_str()); }

void blinkLed(int pin, int n) {
  for (int i = 0; i < n; i++) {
    digitalWrite(pin, HIGH); delay(200);
    digitalWrite(pin, LOW);  delay(200);
  }
}
