import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'exam_store.dart';

/// Device-level exam lockdown (Android).
///
/// Protections engaged during an exam:
/// - screen pinning ([startLockTask]): Home / Recents / app switching blocked
/// - FLAG_SECURE: screenshots and screen recording blocked
/// - Do Not Disturb: notifications silenced (needs one-time system access)
/// - auto-decline incoming calls (needs phone permission)
/// - keep screen on + immersive fullscreen
/// - back-button block + 5-strike tamper system -> hard lockdown
/// - exam state persisted: killing the app relaunches straight back
///   into the locked exam (strikes reset on restart; only the passcode
///   ends the exam early)
///
/// Honest limits: without device-owner provisioning, pinning asks the user
/// for a one-time confirmation and the system Back+Recents gesture can exit
/// a pin. The app re-locks on return and every bypass attempt is logged.
class ExamLock {
  static const _ch = MethodChannel('ns_calculator/exam_lock');

  /// Set to 5: five tamper strikes trigger the hard lockdown.
  static const int maxStrikes = 5;

  /// Global exam-mode flag observed by the UI (PopScope back-button block).
  static final ValueNotifier<bool> isActive = ValueNotifier(false);

  /// Full lockdown after [maxStrikes] strikes: only the passcode exits.
  static final ValueNotifier<bool> isHardLocked = ValueNotifier(false);

  /// Current tamper strike count (0..[maxStrikes]).
  static final ValueNotifier<int> strikes = ValueNotifier(0);

  /// Live pin status observed by the UI. True ONLY when the OS confirms
  /// the task is actually pinned — startLock() returning true merely means
  /// "no exception"; on non-owner phones the user must still confirm the
  /// system pinning dialog.
  static final ValueNotifier<bool> isPinnedState = ValueNotifier(false);

  static Timer? _pinTimer;

  /// When the current exam started (guards against false strikes from the
  /// system pinning confirmation dialog at exam start).
  static DateTime? examStartedAt;

  /// Suppress strikes until this time (used when the teacher is sent to
  /// system Settings for DND access — leaving the app then is not tampering).
  static DateTime? ignoreStrikesUntil;

  /// Tamper events recorded while exam mode is on (shown in settings log).
  static final List<String> tamperLog = [];

  static void logTamper(String event) {
    final entry = '${DateTime.now()}: $event';
    tamperLog.add(entry);
    debugPrint('[EXAM] $entry');
    // Persist fire-and-forget: the audit trail must survive app kills.
    ExamStore.addTamperLog(entry).catchError((_) {});
  }

  /// Loads the persisted audit trail (call once at app startup).
  static Future<void> loadTamperLog() async {
    try {
      tamperLog
        ..clear()
        ..addAll(await ExamStore.getTamperLog());
    } catch (_) {}
  }

  /// Records a tamper attempt. At [maxStrikes], engages the hard lockdown.
  /// Strikes in the first 10 s after exam start are ignored (the system
  /// pinning confirmation can briefly background the app).
  static Future<void> recordStrike(String reason) async {
    if (!isActive.value || isHardLocked.value) return;
    if (ignoreStrikesUntil != null &&
        DateTime.now().isBefore(ignoreStrikesUntil!)) {
      return;
    }
    if (examStartedAt != null &&
        DateTime.now().difference(examStartedAt!).inSeconds < 10) {
      return;
    }
    final n = strikes.value + 1;
    strikes.value = n;
    await ExamStore.setStrikes(n);
    logTamper('Strike $n/$maxStrikes: $reason');
    if (n >= maxStrikes) {
      await engageHardLock('Too many tamper attempts ($n)');
    }
  }

  static Future<void> engageHardLock(String reason) async {
    isHardLocked.value = true;
    logTamper('HARD LOCKDOWN engaged: $reason');
    await setSecure(true);
    await startLock();
  }

  /// Starts a full exam: persists state + passcode, engages protections.
  /// Returns {'pinned': bool}.
  static Future<Map<String, dynamic>> startExam(
      {required String passcode}) async {
    await ExamStore.setPasscode(passcode);
    await ExamStore.setExamActive(true);
    await ExamStore.setStrikes(0);
    await ExamStore.clearTamperLog();
    tamperLog.clear();
    strikes.value = 0;
    isHardLocked.value = false;
    examStartedAt = DateTime.now();
    final pinned = await startLock();
    await setSecure(true);
    await setKeepScreenOn(true);
    await setImmersive(true);
    isActive.value = true;
    isPinnedState.value = pinned;
    startPinWatchdog();
    logTamper('Exam started (device pinned: $pinned)');
    return {'pinned': pinned};
  }

  /// Ends the exam and releases every protection.
  static Future<void> stopExam() async {
    await stopLock();
    await setSecure(false);
    await setKeepScreenOn(false);
    await setImmersive(false);
    await setDnd(false);
    await setCallDecline(false);
    await ExamStore.clearExam();
    stopPinWatchdog();
    isPinnedState.value = false;
    strikes.value = 0;
    isHardLocked.value = false;
    isActive.value = false;
    examStartedAt = null;
    logTamper('Exam ended by teacher passcode');
  }

  /// The app was killed and relaunched mid-exam: re-lock immediately.
  /// Strikes reset (the student gains nothing — the exam re-locks anyway).
  static Future<void> resumeExam() async {
    strikes.value = 0;
    await ExamStore.setStrikes(0);
    isHardLocked.value = false;
    examStartedAt = DateTime.now();
    await startLock();
    await setSecure(true);
    await setKeepScreenOn(true);
    await setImmersive(true);
    isActive.value = true;
    startPinWatchdog();
    logTamper('Exam resumed after app restart (strikes reset)');
  }

  /// Verifies the passcode against the stored hash; on success ends exam.
  static Future<bool> unlockWithPasscode(String code) async {
    final ok = await ExamStore.verifyPasscode(code);
    if (ok) {
      await stopExam();
      return true;
    }
    logTamper('Wrong passcode attempt on lock screen');
    return false;
  }

  /// Reads the TRUE pin state from the OS and publishes it.
  /// Logs a tamper event only on the pinned -> unpinned transition
  /// (not on every poll) to avoid log spam.
  static Future<bool> verifyPin() async {
    final pinned = await isPinned();
    final was = isPinnedState.value;
    isPinnedState.value = pinned;
    if (was && !pinned && isActive.value) {
      logTamper('Pin lost — gestures can leave the app until re-pinned');
    }
    return pinned;
  }

  /// Watches the pin while an exam runs: verifies shortly after start
  /// (once the system dialog could have been answered) and then
  /// periodically. The UI shows a live PIN / NOT-PINNED indicator so a
  /// dismissed dialog can never silently leave gestures working.
  static void startPinWatchdog() {
    stopPinWatchdog();
    Future.delayed(const Duration(seconds: 3), () async {
      if (!isActive.value) return;
      await verifyPin();
    });
    _pinTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!isActive.value) {
        stopPinWatchdog();
        return;
      }
      await verifyPin();
    });
  }

  static void stopPinWatchdog() {
    _pinTimer?.cancel();
    _pinTimer = null;
  }

  @visibleForTesting
  static bool get pinWatchdogRunning => _pinTimer?.isActive ?? false;

  /// Re-checks the pin while an exam runs. If the student escaped the
  /// pin (e.g. via the system Back+Recents gesture or the Home button),
  /// re-engages it immediately. Returns true when the pin was intact.
  static Future<bool> ensurePinned() async {
    if (!isActive.value) return true;
    final pinned = await isPinned();
    if (!pinned) {
      await startLock();
      await setSecure(true);
      await setImmersive(true);
      logTamper('Pin escaped — re-pinned automatically');
    }
    return pinned;
  }

  // ── Platform channel ──────────────────────────────────────────

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

  /// Returns {'ok': bool, 'needsSettings': bool}.
  static Future<Map<dynamic, dynamic>> setDnd(bool on) async {
    try {
      final r = await _ch.invokeMethod('setDnd', {'on': on});
      if (r is Map) return r;
    } catch (_) {}
    return {'ok': false, 'needsSettings': false};
  }

  static Future<void> openDndSettings() async {
    try {
      await _ch.invokeMethod('openDndSettings');
    } catch (_) {}
  }

  static Future<void> setKeepScreenOn(bool on) async {
    try {
      await _ch.invokeMethod('setKeepScreenOn', {'on': on});
    } catch (_) {}
  }

  static Future<void> setImmersive(bool on) async {
    try {
      await _ch.invokeMethod('setImmersive', {'on': on});
    } catch (_) {}
  }

  /// Returns {'ok': bool} — false when the phone permission was denied.
  static Future<Map<dynamic, dynamic>> setCallDecline(bool on) async {
    try {
      final r = await _ch.invokeMethod('setCallDecline', {'on': on});
      if (r is Map) return r;
    } catch (_) {}
    return {'ok': false};
  }

  static Future<bool> isPinned() async {
    try {
      return await _ch.invokeMethod<bool>('isPinned') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// True when the phone was provisioned with the app as device owner
  /// (one-time ADB setup by the teacher). Only then is the exam
  /// literally un-exitable: no gesture or button can leave the app.
  static Future<bool> isDeviceOwner() async {
    try {
      return await _ch.invokeMethod<bool>('isDeviceOwner') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isLockTaskPermitted() async {
    try {
      return await _ch.invokeMethod<bool>('isLockTaskPermitted') ?? false;
    } catch (_) {
      return false;
    }
  }
}
