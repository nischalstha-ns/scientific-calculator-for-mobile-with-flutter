import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device-level exam lockdown (Android).
///
/// When engaged:
/// - the app is screen-pinned ([startLockTask]), so Home / Recents / Back
///   cannot leave the app until the exam ends,
/// - screenshots and screen recording are blocked (FLAG_SECURE).
///
/// Screen pinning without device-owner rights asks the user for a one-time
/// confirmation; exiting a pin needs the system Back+Recents gesture.
/// [startLock] returns false when pinning could not be engaged (e.g. iOS,
/// where it is unsupported) — exam mode then still works at the app level
/// (passcode gate + back-button block + tamper logging).
class ExamLock {
  static const _ch = MethodChannel('ns_calculator/exam_lock');

  /// Global exam-mode flag observed by the UI (PopScope back-button block).
  static final ValueNotifier<bool> isActive = ValueNotifier(false);

  /// Tamper events recorded while exam mode is on (shown in settings log).
  static final List<String> tamperLog = [];

  static void logTamper(String event) {
    tamperLog.add('${DateTime.now()}: $event');
  }

  static Future<bool> startLock() async {
    try {
      final ok = await _ch.invokeMethod<bool>('startLock');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopLock() async {
    try {
      await _ch.invokeMethod('stopLock');
    } catch (_) {}
  }

  static Future<void> setSecure(bool secure) async {
    try {
      await _ch.invokeMethod('setSecure', {'secure': secure});
    } catch (_) {}
  }
}
