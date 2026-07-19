#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <Arduino_RouterBridge.h>

Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(0x40);

constexpr int SERVO_FREQ = 50;
constexpr uint8_t CH_BACK = 0;
constexpr uint8_t CH_UPDOWN = 1;
constexpr uint8_t CH_LEFTRIGHT = 2;

constexpr int BACK_MIN = 0;
constexpr int BACK_MAX = 65;
constexpr int BACK_NORMAL = 0;
constexpr int UPDOWN_MIN = 60;
constexpr int UPDOWN_MAX = 90;
constexpr int UPDOWN_NORMAL = 60;
constexpr int UPDOWN_ACTIVE = 90;
constexpr int LR_MIN = 0;
constexpr int LR_MAX = 180;
constexpr int LR_NORMAL = 90;
constexpr int LR_LEFT = 0;
constexpr int LR_RIGHT = 180;
constexpr int PAN_ENABLE_THRESHOLD = 80;
constexpr int SERVOMIN = 102;
constexpr int SERVOMAX = 512;

int curBack = BACK_NORMAL;
int curUpDown = UPDOWN_NORMAL;
int curLeftRight = LR_NORMAL;

int angleToPulse(int angle) {
  return map(constrain(angle, 0, 180), 0, 180, SERVOMIN, SERVOMAX);
}

void writeAngle(uint8_t channel, int angle) {
  pwm.setPWM(channel, 0, angleToPulse(angle));
}

// Servo movement is deliberately gradual; no call may exceed the declared limits.
void smoothMove(uint8_t channel, int &currentAngle, int targetAngle, int stepDelayMs = 15) {
  if (currentAngle == targetAngle) return;
  const int step = targetAngle > currentAngle ? 1 : -1;
  for (int angle = currentAngle; angle != targetAngle; angle += step) {
    writeAngle(channel, angle);
    delay(stepDelayMs);
  }
  writeAngle(channel, targetAngle);
  currentAngle = targetAngle;
}

bool motorsAreHome() {
  return curUpDown == UPDOWN_NORMAL && curLeftRight == LR_NORMAL;
}

void setBackHome() {
  smoothMove(CH_BACK, curBack, BACK_NORMAL);
}

bool setBack(int angle) {
  angle = constrain(angle, BACK_MIN, BACK_MAX);
  // Tilt the back only after the lamp head is safely centred and lowered.
  if (angle != BACK_NORMAL && !motorsAreHome()) {
    smoothMove(CH_LEFTRIGHT, curLeftRight, LR_NORMAL);
    smoothMove(CH_UPDOWN, curUpDown, UPDOWN_NORMAL);
  }
  smoothMove(CH_BACK, curBack, angle);
  return true;
}

bool setUpDown(int angle) {
  angle = constrain(angle, UPDOWN_MIN, UPDOWN_MAX);
  if (curBack != BACK_NORMAL) setBackHome();
  smoothMove(CH_UPDOWN, curUpDown, angle);
  return true;
}

bool setLeftRight(int angle) {
  angle = constrain(angle, LR_MIN, LR_MAX);
  if (curUpDown < PAN_ENABLE_THRESHOLD) return false;
  if (curBack != BACK_NORMAL) setBackHome();
  smoothMove(CH_LEFTRIGHT, curLeftRight, angle);
  return true;
}

void idleState() {
  setBackHome();
  setUpDown(UPDOWN_NORMAL);
  setLeftRight(LR_NORMAL);
}

void gestureYes() {
  if (curUpDown < PAN_ENABLE_THRESHOLD) setUpDown(UPDOWN_ACTIVE);
  for (int i = 0; i < 2; i++) {
    setUpDown(UPDOWN_MAX);
    delay(150);
    setUpDown(UPDOWN_MIN + 5);
    delay(150);
  }
  setUpDown(UPDOWN_ACTIVE);
}

void gestureNo() {
  setUpDown(UPDOWN_ACTIVE);
  for (int i = 0; i < 2; i++) {
    setLeftRight(LR_LEFT + 30);
    delay(150);
    setLeftRight(LR_RIGHT - 30);
    delay(150);
  }
  setLeftRight(LR_NORMAL);
}

void lookAtPerson(int panAngle, int tiltAngle) {
  setUpDown(constrain(tiltAngle, UPDOWN_MIN, UPDOWN_MAX));
  setLeftRight(constrain(panAngle, LR_MIN, LR_MAX));
}

// Only these four operations are callable through Arduino Bridge.
String look(int pan, int tilt) {
  lookAtPerson(pan, tilt);
  return "OK";
}

String goIdle() {
  idleState();
  return "OK";
}

String yes() {
  gestureYes();
  return "OK";
}

String no() {
  gestureNo();
  return "OK";
}

void setup() {
  pwm.begin();
  pwm.setPWMFreq(SERVO_FREQ);
  delay(200);
  idleState();

  Bridge.begin();
  Bridge.provide("look", look);
  Bridge.provide("idle", goIdle);
  Bridge.provide("yes", yes);
  Bridge.provide("no", no);
  Monitor.println("Smart lamp ready.");
}

void loop() {
  // Arduino Bridge dispatches incoming calls in the background.
}