/*
  ============================================================
  SmartSchool IoT — ESP32
  Firebase ESP Client library (Firebase.RTDB.xxx API)
  ============================================================
  Library: "Firebase ESP Client" by Mobizt
  Search in Library Manager: Firebase ESP Client
  Install version >= 4.x

  Board: ESP32 Dev Module
  Partition: Default 4MB with spiffs
  Upload Speed: 115200

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

// ─── Libraries ────────────────────────────────────────────────────────────────
#include <WiFi.h>
#include <Firebase_ESP_Client.h>          // Firebase ESP Client by Mobizt
#include "addons/TokenHelper.h"           // Included with the library
#include "addons/RTDBHelper.h"            // Included with the library
#include <DHT.h>
#include <MFRC522.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>

// ─── WiFi ─────────────────────────────────────────────────────────────────────
#define WIFI_SSID      "iPhone de Ranim"
#define WIFI_PASSWORD  "ranim1234"

// ─── Firebase ─────────────────────────────────────────────────────────────────
// RTDB URL: Firebase Console → Realtime Database → copy URL
// e.g. "https://your-project-default-rtdb.firebaseio.com/"
#define FIREBASE_HOST  "https://pfe-smartschool-default-rtdb.europe-west1.firebasedatabase.app/"

// API Key: Firebase Console → Project Settings → General → Web API Key
#define API_KEY        "AIzaSyDTWS13ATaP_0No4yjp6RC-MOiddghSmsc"

// Database secret: Firebase Console → Project Settings
//   → Service Accounts → Database secrets → Show
// Used for legacy auth (no email/password needed)
#define DATABASE_SECRET "CyMLHjOdJ88awIAwGyEhgBSX83mF6aEfAYJ0WcUk"

// ─── Device ID ────────────────────────────────────────────────────────────────
#define FLOOR_ID  "floor_2"

// ─── DHT22 ────────────────────────────────────────────────────────────────────
#define DHT_PIN_ED26  9
#define DHT_PIN_ED24  10
#define DHT_TYPE      DHT22

// ─── RC522 RFID ───────────────────────────────────────────────────────────────
#define RFID_SS_PIN   5
#define RFID_RST_PIN  4

// ─── LEDs ─────────────────────────────────────────────────────────────────────
#define LED_GREEN  26
#define LED_RED    27

// ─── Servo ────────────────────────────────────────────────────────────────────
#define SERVO_PIN    2
#define SERVO_OPEN   90
#define SERVO_CLOSE   0
#define SERVO_HOLD   4000   // ms gate stays open

// ─── Objects ──────────────────────────────────────────────────────────────────
DHT               dht_ED26(DHT_PIN_ED26, DHT_TYPE);
DHT               dht_ED24(DHT_PIN_ED24, DHT_TYPE);
MFRC522           rfid(RFID_SS_PIN, RFID_RST_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo             gateServo;

// Firebase objects
FirebaseData      fbData;
FirebaseAuth      fbAuth;
FirebaseConfig    fbConfig;

// ─── Timing ───────────────────────────────────────────────────────────────────
unsigned long lastTempMs = 0;
const unsigned long TEMP_INTERVAL = 30000;  // 30 seconds

bool firebaseReady = false;

// ─────────────────────────────────────────────────────────────────────────────
//  SETUP
// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // ── GPIO ──────────────────────────────────────────────────────────────────
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED,   OUTPUT);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_RED,   LOW);

  gateServo.attach(SERVO_PIN);
  gateServo.write(SERVO_CLOSE);

  // ── LCD ───────────────────────────────────────────────────────────────────
  lcd.init();
  lcd.backlight();
  lcdPrint("SmartSchool", "Starting...");

  // ── DHT22 ─────────────────────────────────────────────────────────────────
  dht_ED26.begin();
  dht_ED24.begin();
  delay(2000);

  // ── RFID ──────────────────────────────────────────────────────────────────
  SPI.begin();
  rfid.PCD_Init();
  delay(100);
  Serial.println("RFID ready");

  // ── WiFi ──────────────────────────────────────────────────────────────────
  lcdPrint("Connecting WiFi", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 30) {
    delay(500);
    Serial.print(".");
    tries++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    lcdPrint("WiFi FAILED", "Check creds");
    Serial.println("\nWiFi failed — halting");
    while (true) delay(1000);
  }

  Serial.println("\nWiFi connected: " + WiFi.localIP().toString());

  // ── Firebase ESP Client setup ──────────────────────────────────────────────
  fbConfig.api_key     = API_KEY;
  fbConfig.database_url = "https://" FIREBASE_HOST;

  // Use database secret for authentication (no user account needed)
  fbAuth.token.uid = "";
  fbConfig.signer.tokens.legacy_token = DATABASE_SECRET;

  // Token status callback
  fbConfig.token_status_callback = tokenStatusCallback;

  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);

  // Wait until Firebase is ready
  lcdPrint("Firebase", "Connecting...");
  unsigned long waitStart = millis();
  while (!Firebase.ready() && millis() - waitStart < 10000) {
    delay(300);
    Serial.print(".");
  }

  firebaseReady = Firebase.ready();
  if (firebaseReady) {
    Serial.println("\nFirebase ready");
    // Mark device online
    Firebase.RTDB.setBool(&fbData,
        "/iot/devices/" FLOOR_ID "/online", true);
    Firebase.RTDB.setString(&fbData,
        "/iot/devices/" FLOOR_ID "/ip",
        WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\nFirebase NOT ready — check config");
  }

  lcdPrint("Ready", "Scan your card");
  Serial.println("SmartSchool IoT running");
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOOP
// ─────────────────────────────────────────────────────────────────────────────
void loop() {
  // Reconnect WiFi if dropped
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

  // 2. Check RFID
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    handleRfidScan();
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TEMPERATURE UPLOAD  →  Firebase.RTDB.setFloat
// ─────────────────────────────────────────────────────────────────────────────
void uploadTemperature() {
  // ── ED26 (pin 2) ────────────────────────────────────────────────────────
  float t26 = dht_ED26.readTemperature();
  float h26 = dht_ED26.readHumidity();

  if (!isnan(t26) && !isnan(h26)) {
    String base = "/iot/temperature/" FLOOR_ID "/dht22_ED26";
    Firebase.RTDB.setFloat(&fbData, (base + "/temperature").c_str(), t26);
    Firebase.RTDB.setFloat(&fbData, (base + "/humidity").c_str(),    h26);
    Firebase.RTDB.setInt(&fbData,   (base + "/pin").c_str(),         2);
    Firebase.RTDB.setInt(&fbData,   (base + "/updatedAt").c_str(),   (int)millis());
    Serial.printf("[ED26] %.1f°C  %.1f%%\n", t26, h26);
  } else {
    Serial.println("[ED26] Sensor read failed");
  }

  // ── ED24 (pin 4) ────────────────────────────────────────────────────────
  float t24 = dht_ED24.readTemperature();
  float h24 = dht_ED24.readHumidity();

  if (!isnan(t24) && !isnan(h24)) {
    String base = "/iot/temperature/" FLOOR_ID "/dht22_ED24";
    Firebase.RTDB.setFloat(&fbData, (base + "/temperature").c_str(), t24);
    Firebase.RTDB.setFloat(&fbData, (base + "/humidity").c_str(),    h24);
    Firebase.RTDB.setInt(&fbData,   (base + "/pin").c_str(),         4);
    Firebase.RTDB.setInt(&fbData,   (base + "/updatedAt").c_str(),   (int)millis());
    Serial.printf("[ED24] %.1f°C  %.1f%%\n", t24, h24);
  } else {
    Serial.println("[ED24] Sensor read failed");
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RFID SCAN  →  Firebase.RTDB.pushJSON + Firebase.RTDB.getString
// ─────────────────────────────────────────────────────────────────────────────
void handleRfidScan() {
  // Build uppercase hex tag string
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

  // Build JSON payload
  FirebaseJson json;
  json.set("tag",        tag.c_str());
  json.set("scannedAt",  (int)millis());
  json.set("floor",      FLOOR_ID);
  json.set("processed",  false);
  json.set("response",   "");

  String scanPath = "/iot/rfid_scans";

  // Push → Firebase.RTDB.pushJSON
  if (!Firebase.RTDB.pushJSON(&fbData, scanPath.c_str(), &json)) {
    Serial.println("Push error: " + fbData.errorReason());
    lcdPrint("Server Error", "Try again");
    blinkLed(LED_RED, 3);
    delay(1500);
    lcdPrint("Ready", "Scan your card");
    return;
  }

  String scanId       = fbData.pushName();
  String responsePath = scanPath + "/" + scanId + "/response";
  Serial.println("Scan pushed: " + scanId);

  // Poll for Flutter response (max 5s, 50 × 100ms)
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
//  GRANT ACCESS  — green LED + LCD + servo
// ─────────────────────────────────────────────────────────────────────────────
void grantAccess() {
  Serial.println(">> ACCESS GRANTED");
  digitalWrite(LED_GREEN, HIGH);
  digitalWrite(LED_RED,   LOW);
  lcdPrint("  AUTHORIZED  ", "  Access OK   ");
  gateServo.write(SERVO_OPEN);
  delay(SERVO_HOLD);
  gateServo.write(SERVO_CLOSE);
  digitalWrite(LED_GREEN, LOW);
}

// ─────────────────────────────────────────────────────────────────────────────
//  DENY ACCESS  — red LED + LCD, no servo
// ─────────────────────────────────────────────────────────────────────────────
void denyAccess(const char* reason) {
  Serial.print(">> ACCESS DENIED — ");
  Serial.println(reason);
  digitalWrite(LED_RED,   HIGH);
  digitalWrite(LED_GREEN, LOW);
  lcdPrint("   DENIED     ", reason);
  delay(2000);
  digitalWrite(LED_RED, LOW);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
void lcdPrint(const char* line1, const char* line2) {
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(line1);
  lcd.setCursor(0, 1); lcd.print(line2);
}

void lcdPrint(const char* line1, String line2) {
  lcdPrint(line1, line2.c_str());
}

void blinkLed(int pin, int times) {
  for (int i = 0; i < times; i++) {
    digitalWrite(pin, HIGH); delay(200);
    digitalWrite(pin, LOW);  delay(200);
  }
}
