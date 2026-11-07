// lib/utils/vitals_validator.dart
//
// Physiologically plausible bounds for each vital the band reports.
// Anything outside these limits is a device artefact or protocol error and
// must be discarded — never stored to Firestore or shown in the UI.

class VitalsValidator {
  VitalsValidator._();

  // ── Heart rate ─────────────────────────────────────────────────────────────
  // 30–250 bpm.  Below 30 cannot sustain life; above 250 is only briefly
  // possible in a lethal arrhythmia and cannot be reliably measured by a wrist
  // band.
  static const int hrMin = 30;
  static const int hrMax = 250;

  static bool isValidHr(int? v)   => v != null && v >= hrMin && v <= hrMax;
  static int? sanitizeHr(int? v)  => isValidHr(v) ? v : null;

  // ── SpO2 ───────────────────────────────────────────────────────────────────
  // 70–100 %.  Below 70 % is incompatible with conscious life; above 100 % is
  // physically impossible.
  static const int spo2Min = 70;
  static const int spo2Max = 100;

  static bool isValidSpo2(int? v)   => v != null && v >= spo2Min && v <= spo2Max;
  static int? sanitizeSpo2(int? v)  => isValidSpo2(v) ? v : null;

  // ── Temperature ────────────────────────────────────────────────────────────
  // 34.0–42.5 °C (after the band's ×10 encoding is already reversed).
  // Below 34 °C is severe hypothermia; above 42.5 °C is lethal hyperthermia.
  static const double tempMin = 34.0;
  static const double tempMax = 42.5;

  static bool    isValidTemp(double? v)   => v != null && v >= tempMin && v <= tempMax;
  static double? sanitizeTemp(double? v)  => isValidTemp(v) ? v : null;

  // ── HRV ────────────────────────────────────────────────────────────────────
  // 5–300 ms.  Values below 5 ms are artefacts; above 300 ms are vanishingly
  // rare for rMSSD / SDNN from a wrist device and almost always a parsing error.
  static const int hrvMin = 5;
  static const int hrvMax = 300;

  static bool isValidHrv(int? v)   => v != null && v >= hrvMin && v <= hrvMax;
  static int? sanitizeHrv(int? v)  => isValidHrv(v) ? v : null;

  // ── Blood pressure ─────────────────────────────────────────────────────────
  // Systolic: 60–300 mmHg.  Diastolic: 40–200 mmHg.
  static const int sysBpMin = 60, sysBpMax = 300;
  static const int diaBpMin = 40, diaBpMax = 200;

  static bool isValidSysBp(int? v)  => v != null && v >= sysBpMin && v <= sysBpMax;
  static bool isValidDiaBp(int? v)  => v != null && v >= diaBpMin && v <= diaBpMax;

  static int? sanitizeSysBp(int? v) => isValidSysBp(v) ? v : null;
  static int? sanitizeDiaBp(int? v) => isValidDiaBp(v) ? v : null;
}
