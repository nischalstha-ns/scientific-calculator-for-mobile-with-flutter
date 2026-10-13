import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scientific_calculator/exam_lock.dart';
import 'package:scientific_calculator/exam_store.dart';
import 'package:scientific_calculator/hard_lock_screen.dart';
import 'package:scientific_calculator/settings_screen.dart';
import 'package:scientific_calculator/main.dart';

/// UI-level exam security tests: the hard-lock screen and the
/// frozen-settings behaviour during an exam.
///
/// Note: the exam MethodChannel is mocked — on a real device these calls
/// reach MainActivity; in widget tests an unmocked channel never resolves.
void _mockExamChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('ns_calculator/exam_lock'), (call) async {
    switch (call.method) {
      case 'isPinned':
        return false;
      case 'isDeviceOwner':
        return false;
      case 'isLockTaskPermitted':
        return false;
      case 'startLock':
        return true;
      case 'setDnd':
        return {'ok': true, 'needsSettings': false};
      case 'setCallDecline':
        return {'ok': true};
      default:
        return null;
    }
  });
}

/// UI-level exam security tests: the hard-lock screen and the
/// frozen-settings behaviour during an exam.
void main() {
  setUp(() async {
    _mockExamChannel();
    SharedPreferences.setMockInitialValues({});
    await ExamStore.init();
    ExamLock.isActive.value = false;
    ExamLock.isHardLocked.value = false;
    ExamLock.strikes.value = 0;
    ExamLock.tamperLog.clear();
    ExamLock.examStartedAt = null;
    ExamLock.ignoreStrikesUntil = null;
  });

  tearDown(() {
    ExamLock.isActive.value = false;
    ExamLock.isHardLocked.value = false;
    ExamLock.strikes.value = 0;
  });

  testWidgets('hard lock screen: wrong passcode stays locked',
      (WidgetTester tester) async {
    await ExamStore.setPasscode('4321');
    await ExamStore.setExamActive(true);
    ExamLock.isActive.value = true;
    ExamLock.isHardLocked.value = true;

    await tester.pumpWidget(const MaterialApp(home: HardLockScreen()));
    await tester.pumpAndSettle();
    expect(find.text('DEVICE LOCKED'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('UNLOCK'));
    await tester.pumpAndSettle();

    expect(ExamLock.isHardLocked.value, isTrue,
        reason: 'wrong passcode must not unlock');
    expect(ExamLock.isActive.value, isTrue);
    expect(find.text('DEVICE LOCKED'), findsOneWidget);
  });

  testWidgets('hard lock screen: correct passcode ends exam',
      (WidgetTester tester) async {
    await ExamStore.setPasscode('4321');
    await ExamStore.setExamActive(true);
    ExamLock.isActive.value = true;
    ExamLock.isHardLocked.value = true;
    ExamLock.strikes.value = 5;

    // Mirror the real app: the lock screen swaps out when unlocked.
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: ExamLock.isHardLocked,
        builder: (_, hardLocked, __) => hardLocked
            ? const HardLockScreen()
            : const Scaffold(body: Text('UNLOCKED')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('DEVICE LOCKED'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '4321');
    await tester.tap(find.text('UNLOCK'));
    await tester.pumpAndSettle();

    expect(find.text('UNLOCKED'), findsOneWidget,
        reason: 'lock screen must disappear after correct passcode');
    expect(ExamLock.isHardLocked.value, isFalse);
    expect(ExamLock.isActive.value, isFalse);
    expect(ExamLock.strikes.value, 0);
    expect(await ExamStore.isExamActive(), isFalse,
        reason: 'exam state must be cleared from storage');
  });

  testWidgets('settings toggles are frozen while exam is active',
      (WidgetTester tester) async {
    ExamLock.isActive.value = true;
    ExamLock.examStartedAt =
        DateTime.now().subtract(const Duration(minutes: 5));

    await tester.pumpWidget(const MaterialApp(home: ExamModeSettings()));
    await tester.pumpAndSettle();

    // Every SwitchListTile must be disabled (onChanged null) during exam.
    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
    expect(switches, isNotEmpty);
    for (final sw in switches) {
      expect(sw.onChanged, isNull,
          reason: 'toggle "${sw.title}" must be frozen during exam');
    }
    expect(find.textContaining('frozen while the exam runs'), findsOneWidget);
  });

  testWidgets('calculator shows live pin indicator during exam',
      (WidgetTester tester) async {
    ExamLock.isActive.value = true;
    ExamLock.isPinnedState.value = false;
    ExamLock.examStartedAt =
        DateTime.now().subtract(const Duration(minutes: 5));

    await tester.pumpWidget(const CalculatorApp());
    await tester.pumpAndSettle();

    // Not really pinned -> red !PIN warning must be visible.
    expect(find.text('!PIN'), findsOneWidget);

    // Pin confirmed -> green PIN.
    ExamLock.isPinnedState.value = true;
    await tester.pumpAndSettle();
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('!PIN'), findsNothing);
  });

  testWidgets('pin gate: dialog appears when pin cannot be confirmed; '
      'Cancel rolls the exam back', (WidgetTester tester) async {
    // Mock: startLock "succeeds" but isPinned stays false — as if the
    // system pinning dialog was dismissed. Shorten the gate so no
    // multi-second fake-clock pumps are needed.
    ExamLock.gatePollGap = const Duration(milliseconds: 10);
    ExamLock.gatePollTries = 2;
    addTearDown(() {
      ExamLock.gatePollGap = const Duration(seconds: 2);
      ExamLock.gatePollTries = 5;
    });

    await tester.pumpWidget(const MaterialApp(home: ExamModeSettings()));
    await tester.pumpAndSettle();

    final examSwitch = find.widgetWithText(SwitchListTile, 'Exam Mode');
    await tester.ensureVisible(examSwitch);
    await tester.pumpAndSettle();
    await tester.tap(examSwitch);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle(); // gate polls (2 x 10ms) then shows dialog

    expect(find.textContaining('Pinning not active'), findsOneWidget,
        reason: 'gate must block an unpinned exam start');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(ExamLock.isActive.value, isFalse,
        reason: 'cancelling the gate must roll the exam back');
    expect(find.textContaining('Pinning not active'), findsNothing);
  });

  testWidgets('settings shows hard lock screen when hard-locked',
      (WidgetTester tester) async {
    ExamLock.isActive.value = true;
    ExamLock.isHardLocked.value = true;

    await tester.pumpWidget(const MaterialApp(home: ExamModeSettings()));
    await tester.pumpAndSettle();

    // The settings content is replaced by the lock screen — no way
    // to reach toggles or the END EXAM button without the passcode.
    expect(find.text('DEVICE LOCKED'), findsOneWidget);
    expect(find.text('Exam Mode Settings'), findsNothing);
  });
}
