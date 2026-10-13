import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scientific_calculator/exam_lock.dart';
import 'package:scientific_calculator/exam_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ExamStore.init();
    // Reset all static exam state between tests.
    ExamLock.isActive.value = false;
    ExamLock.isHardLocked.value = false;
    ExamLock.strikes.value = 0;
    ExamLock.tamperLog.clear();
    ExamLock.examStartedAt = null;
    ExamLock.ignoreStrikesUntil = null;
  });

  tearDown(() {
    ExamLock.stopPinWatchdog();
  });

  group('ExamStore passcode', () {
    test('no passcode initially, verify fails', () async {
      expect(await ExamStore.hasPasscode(), isFalse);
      expect(await ExamStore.verifyPasscode('1234'), isFalse);
    });

    test('correct passcode verifies, wrong one does not', () async {
      await ExamStore.setPasscode('9876');
      expect(await ExamStore.hasPasscode(), isTrue);
      expect(await ExamStore.verifyPasscode('9876'), isTrue);
      expect(await ExamStore.verifyPasscode('0000'), isFalse);
      expect(await ExamStore.verifyPasscode(''), isFalse);
    });

    test('passcode is stored hashed, never plaintext', () async {
      await ExamStore.setPasscode('1234');
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('exam_pass_hash');
      expect(stored, isNotNull);
      expect(stored, isNot(contains('1234')));
    });

    test('tamper log persists across app restart', () async {
      ExamLock.isActive.value = true;
      ExamLock.examStartedAt =
          DateTime.now().subtract(const Duration(minutes: 1));
      await ExamLock.recordStrike('kill-me test strike');
      // let the fire-and-forget persist complete
      await Future.delayed(const Duration(milliseconds: 300));
      final stored = await ExamStore.getTamperLog();
      expect(stored.any((e) => e.contains('kill-me test strike')), isTrue,
          reason: 'strike must reach persistent storage');

      // simulate app kill: memory wiped, reload from storage
      ExamLock.tamperLog.clear();
      await ExamLock.loadTamperLog();
      expect(
          ExamLock.tamperLog.any((e) => e.contains('kill-me test strike')),
          isTrue,
          reason: 'audit trail must survive restart');
    });

    test('new exam starts with a fresh tamper log', () async {
      await ExamStore.addTamperLog('old exam event');
      await ExamLock.startExam(passcode: '1234');
      // Only the fresh 'Exam started' entry should exist.
      expect(ExamLock.tamperLog, hasLength(1));
      expect(ExamLock.tamperLog.single, contains('Exam started'));
      await Future.delayed(const Duration(milliseconds: 300));
      final stored = await ExamStore.getTamperLog();
      expect(stored.any((e) => e.contains('old exam event')), isFalse,
          reason: 'previous exam log must not leak into the new exam');
      expect(stored.any((e) => e.contains('Exam started')), isTrue);
      await ExamLock.stopExam();
    });

    test('verifyPin publishes the true pin state', () async {
      // Unit tests have no platform channel: isPinned() -> false.
      ExamLock.isPinnedState.value = true; // pretend previously pinned
      final pinned = await ExamLock.verifyPin();
      expect(pinned, isFalse);
      expect(ExamLock.isPinnedState.value, isFalse);
    });

    test('pin watchdog runs during exam and stops after', () async {
      expect(ExamLock.pinWatchdogRunning, isFalse);
      await ExamLock.startExam(passcode: '1234');
      expect(ExamLock.pinWatchdogRunning, isTrue,
          reason: 'watchdog must run while exam is active');
      expect(ExamLock.isPinnedState.value, isFalse,
          reason: 'unmocked channel: pin not really active');
      await ExamLock.stopExam();
      expect(ExamLock.pinWatchdogRunning, isFalse,
          reason: 'watchdog must stop when exam ends');
    });

    test('awaitPinConfirmed returns false when pin never confirms', () async {
      ExamLock.isActive.value = true;
      final ok = await ExamLock.awaitPinConfirmed(
        tries: 2,
        gap: const Duration(milliseconds: 10),
      );
      expect(ok, isFalse,
          reason: 'unmocked channel: pin can never confirm');
      expect(ExamLock.isPinnedState.value, isFalse);
      ExamLock.isActive.value = false;
    });

    test('awaitPinConfirmed aborts immediately when cancelled', () async {
      ExamLock.isActive.value = true;
      final sw = Stopwatch()..start();
      final ok = await ExamLock.awaitPinConfirmed(
        tries: 10,
        gap: const Duration(milliseconds: 50),
        isCancelled: () => true,
      );
      sw.stop();
      expect(ok, isFalse);
      expect(sw.elapsedMilliseconds, lessThan(300),
          reason: 'must abort on cancel, not poll 10 times');
      ExamLock.isActive.value = false;
    });

    test('clearExam wipes everything', () async {
      await ExamStore.setPasscode('1234');
      await ExamStore.setExamActive(true);
      await ExamStore.setStrikes(3);
      await ExamStore.clearExam();
      expect(await ExamStore.hasPasscode(), isFalse);
      expect(await ExamStore.isExamActive(), isFalse);
      expect(await ExamStore.getStrikes(), 0);
    });
  });

  group('ExamLock strikes', () {
    test('strikes do nothing when exam is inactive', () async {
      await ExamLock.recordStrike('back pressed');
      expect(ExamLock.strikes.value, 0);
      expect(ExamLock.isHardLocked.value, isFalse);
    });

    test('strikes 1-4 accumulate without hard lock', () async {
      ExamLock.isActive.value = true;
      ExamLock.examStartedAt =
          DateTime.now().subtract(const Duration(minutes: 1));
      for (var i = 1; i <= 4; i++) {
        await ExamLock.recordStrike('attempt $i');
        expect(ExamLock.strikes.value, i);
        expect(ExamLock.isHardLocked.value, isFalse);
      }
      expect(ExamLock.tamperLog.length, 4);
    });

    test('5th strike engages hard lockdown', () async {
      ExamLock.isActive.value = true;
      ExamLock.examStartedAt =
          DateTime.now().subtract(const Duration(minutes: 1));
      for (var i = 0; i < 5; i++) {
        await ExamLock.recordStrike('attempt');
      }
      expect(ExamLock.strikes.value, 5);
      expect(ExamLock.isHardLocked.value, isTrue);
      // Further strikes are ignored while hard-locked.
      await ExamLock.recordStrike('another');
      expect(ExamLock.strikes.value, 5);
    });

    test('strikes suppressed inside the ignore window', () async {
      ExamLock.isActive.value = true;
      ExamLock.examStartedAt =
          DateTime.now().subtract(const Duration(minutes: 1));
      ExamLock.ignoreStrikesUntil =
          DateTime.now().add(const Duration(seconds: 30));
      await ExamLock.recordStrike('backgrounded');
      expect(ExamLock.strikes.value, 0);
    });
  });

  group('ExamLock unlock', () {
    test('wrong passcode keeps everything locked', () async {
      await ExamStore.setPasscode('4321');
      await ExamStore.setExamActive(true);
      ExamLock.isActive.value = true;
      ExamLock.isHardLocked.value = true;
      final ok = await ExamLock.unlockWithPasscode('0000');
      expect(ok, isFalse);
      expect(ExamLock.isHardLocked.value, isTrue);
      expect(ExamLock.isActive.value, isTrue);
    });

    test('correct passcode ends exam and clears state', () async {
      await ExamStore.setPasscode('4321');
      await ExamStore.setExamActive(true);
      await ExamStore.setStrikes(5);
      ExamLock.isActive.value = true;
      ExamLock.isHardLocked.value = true;
      ExamLock.strikes.value = 5;
      final ok = await ExamLock.unlockWithPasscode('4321');
      expect(ok, isTrue);
      expect(ExamLock.isHardLocked.value, isFalse);
      expect(ExamLock.isActive.value, isFalse);
      expect(ExamLock.strikes.value, 0);
      expect(await ExamStore.isExamActive(), isFalse);
      expect(await ExamStore.hasPasscode(), isFalse);
    });

    test('startExam persists state for kill-recovery', () async {
      final res = await ExamLock.startExam(passcode: '2468');
      expect(ExamLock.isActive.value, isTrue);
      expect(await ExamStore.isExamActive(), isTrue);
      expect(await ExamStore.verifyPasscode('2468'), isTrue);
      expect(res['pinned'], isA<bool>());
      // Simulate app kill: fresh notifiers, state reloaded from store.
      ExamLock.isActive.value = false;
      ExamLock.isHardLocked.value = false;
      final stillActive = await ExamStore.isExamActive();
      expect(stillActive, isTrue);
      await ExamLock.resumeExam();
      expect(ExamLock.isActive.value, isTrue);
      expect(ExamLock.strikes.value, 0);
      await ExamLock.stopExam();
    });
  });
}
