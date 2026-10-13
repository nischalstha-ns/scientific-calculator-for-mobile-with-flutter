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
      await _p.setInt(
          _kStartedAt, DateTime.now().millisecondsSinceEpoch);
    }
  }

  static Future<int> examStartedAtMs() async {
    await init();
    return _p.getInt(_kStartedAt) ?? 0;
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

  /// Clears everything: exam over.
  static Future<void> clearExam() async {
    await init();
    await _p.remove(_kActive);
    await _p.remove(_kPassHash);
    await _p.remove(_kStrikes);
    await _p.remove(_kStartedAt);
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
