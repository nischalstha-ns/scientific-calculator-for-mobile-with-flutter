import 'package:shared_preferences/shared_preferences.dart';

/// Persistent exam state. Survives app kills so a student cannot escape
/// an exam by force-stopping the app: on relaunch the exam re-locks.
///
/// The passcode is never stored in plaintext — only a salted hash.
class ExamStore {
  static const _kActive = 'exam_active';
  static const _kPassHash = 'exam_pass_hash';
  static const _kStrikes = 'exam_strikes';
  static const _kStartedAt = 'exam_started_at';
  static const _kTamperLog = 'exam_tamper_log';
  static const _kDurationMin = 'exam_duration_min';
  static const _kUnlockFails = 'exam_unlock_fails';
  static const _kCooldownUntil = 'exam_cooldown_until';
  static const _kCooldownLevel = 'exam_cooldown_level';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError('ExamStore.init() must be awaited first');
    }
    return p;
  }

  static Future<bool> isExamActive() async {
    await init();
    return _p.getBool(_kActive) ?? false;
  }

  static Future<void> setExamActive(bool v) async {
    await init();
    await _p.setBool(_kActive, v);
    if (v) {
      await setStartedAtMs(DateTime.now().millisecondsSinceEpoch);
    }
  }

  static Future<void> setStartedAtMs(int ms) async {
    await init();
    await _p.setInt(_kStartedAt, ms);
  }

  static Future<int> examStartedAtMs() async {
    await init();
    return _p.getInt(_kStartedAt) ?? 0;
  }

  /// Teacher's chosen exam length. A preference, not exam state: it is
  /// kept across exams (not wiped by [clearExam]) so the teacher does
  /// not have to re-pick it every time.
  static Future<void> setDurationMinutes(int minutes) async {
    await init();
    await _p.setInt(_kDurationMin, minutes);
  }

  static Future<int?> getDurationMinutes() async {
    await init();
    return _p.getInt(_kDurationMin);
  }

  // ── Passcode unlock attempts + cooldown (brute-force protection) ──
  // Persisted so killing the app cannot reset the attempt counter or
  // escape an active cooldown.

  static Future<int> getUnlockFails() async {
    await init();
    return _p.getInt(_kUnlockFails) ?? 0;
  }

  static Future<void> setUnlockFails(int n) async {
    await init();
    await _p.setInt(_kUnlockFails, n);
  }

  /// Epoch ms until which passcode entry is locked out (0 = no cooldown).
  static Future<int> getCooldownUntilMs() async {
    await init();
    return _p.getInt(_kCooldownUntil) ?? 0;
  }

  static Future<void> setCooldownUntilMs(int ms) async {
    await init();
    await _p.setInt(_kCooldownUntil, ms);
  }

  /// How many cooldowns have been served this exam (escalation level).
  static Future<int> getCooldownLevel() async {
    await init();
    return _p.getInt(_kCooldownLevel) ?? 0;
  }

  static Future<void> setCooldownLevel(int n) async {
    await init();
    await _p.setInt(_kCooldownLevel, n);
  }

  static Future<void> clearUnlockState() async {
    await init();
    await _p.remove(_kUnlockFails);
    await _p.remove(_kCooldownUntil);
    await _p.remove(_kCooldownLevel);
  }

  static Future<void> setPasscode(String code) async {
    await init();
    await _p.setString(_kPassHash, _hash(code));
  }

  static Future<bool> hasPasscode() async {
    await init();
    return _p.containsKey(_kPassHash);
  }

  static Future<bool> verifyPasscode(String code) async {
    await init();
    final stored = _p.getString(_kPassHash);
    if (stored == null || code.isEmpty) return false;
    return _constantTimeEquals(stored, _hash(code));
  }

  static Future<int> getStrikes() async {
    await init();
    return _p.getInt(_kStrikes) ?? 0;
  }

  static Future<void> setStrikes(int n) async {
    await init();
    await _p.setInt(_kStrikes, n);
  }

  /// Audit trail: survives app kills so tamper evidence is never lost.
  /// Capped at 200 entries.
  static Future<List<String>> getTamperLog() async {
    await init();
    return _p.getStringList(_kTamperLog) ?? [];
  }

  static Future<void> addTamperLog(String entry) async {
    await init();
    final log = _p.getStringList(_kTamperLog) ?? [];
    log.add(entry);
    while (log.length > 200) {
      log.removeAt(0);
    }
    await _p.setStringList(_kTamperLog, log);
  }

  static Future<void> clearTamperLog() async {
    await init();
    await _p.remove(_kTamperLog);
  }

  /// Clears everything: exam over. (The duration preference is kept —
  /// see [setDurationMinutes].)
  static Future<void> clearExam() async {
    await init();
    await _p.remove(_kActive);
    await _p.remove(_kPassHash);
    await _p.remove(_kStrikes);
    await _p.remove(_kStartedAt);
    await _p.remove(_kUnlockFails);
    await _p.remove(_kCooldownUntil);
    await _p.remove(_kCooldownLevel);
  }

  // Salted djb2-style hash, hex encoded. Obscures the passcode at rest;
  // it is not intended to resist a determined forensic attack.
  static String _hash(String input) {
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    const salt = 'ns-calc-exam-v1';
    final s = '$salt:$input';
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      h1 = ((h1 * 33) + c) & 0xFFFFFFFF;
      h2 = ((h2 ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h1.toRadixString(16).padLeft(8, '0') +
        h2.toRadixString(16).padLeft(8, '0');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
