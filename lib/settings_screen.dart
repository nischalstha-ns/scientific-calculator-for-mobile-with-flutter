import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'exam_lock.dart';
import 'hard_lock_screen.dart';
import 'exam_store.dart';

/// Exam mode settings.
///
/// The teacher sets a passcode, then starts the exam: the app pins itself
/// to the screen (screen pinning), blocks screenshots, silences
/// notifications (Do Not Disturb), can auto-decline calls, and logs every
/// tamper attempt. Five tamper strikes trigger a full hard lockdown that
/// only the passcode removes. While the exam is active every toggle here
/// is frozen so students cannot change anything.
class ExamModeSettings extends StatefulWidget {
  const ExamModeSettings({super.key});

  @override
  State<ExamModeSettings> createState() => _ExamModeSettingsState();
}

class _ExamModeSettingsState extends State<ExamModeSettings> {
  bool isExamModeActive = false;
  bool devicePinned = false;
  bool deviceOwner = false;
  bool dndEnabled = false;
  bool declineCalls = false;
  bool keepScreenOn = true;
  bool dndWorking = false;
  bool callsWorking = false;
  int lockDurationMinutes = 60;
  bool _loading = true;
  int _examSession = 0;
  Timer? _examTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final active = ExamLock.isActive.value;
    final pinned = active ? await ExamLock.isPinned() : false;
    final owner = await ExamLock.isDeviceOwner();
    if (mounted) {
      setState(() {
        isExamModeActive = active;
        devicePinned = pinned;
        deviceOwner = owner;
        _loading = false;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : null,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<String?> _askPasscode(String title) async {
    // Stateful dialog owns its controller: dispose() runs when the route
    // is unmounted, i.e. after the pop transition — disposing earlier
    // crashes the exit animation's rebuild (used-after-dispose).
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PasscodePromptDialog(title: title),
    );
  }

  Future<void> _toggleExamMode() async {
    if (_loading) return;
    if (!isExamModeActive) {
      final has = await ExamStore.hasPasscode();
      final code = await _askPasscode(
          has ? 'Enter passcode to start exam' : 'Set exam passcode');
      if (code == null || code.isEmpty) return;
      if (code.length < 4) {
        _snack('Passcode must be at least 4 digits', error: true);
        return;
      }
      if (has && !await ExamStore.verifyPasscode(code)) {
        _snack('Incorrect passcode', error: true);
        return;
      }
      // Engage the exam.
      final res = await ExamLock.startExam(passcode: code);
      // Apply the functional restrictions the teacher enabled.
      if (dndEnabled) await _applyDnd(true, silent: true);
      if (declineCalls) await _applyCallDecline(true, silent: true);
      if (mounted) {
        setState(() {
          isExamModeActive = true;
          devicePinned = res['pinned'] as bool? ?? false;
        });
      }
      _startTimerLock();
      // Pin gate: the exam must not run unpinned by accident. The system
      // pinning dialog needs a moment to be answered, so poll the TRUE
      // pin state for a few seconds before deciding.
      final pinned = await ExamLock.awaitPinConfirmed(
          isCancelled: () => !mounted || !ExamLock.isActive.value);
      if (mounted) setState(() => devicePinned = pinned);
      if (!mounted) return;
      if (pinned) {
        _snack('Exam ON — device pinned. Passcode ends it.');
      } else if (ExamLock.isActive.value) {
        await _pinGateDialog();
      }
    } else {
      final code = await _askPasscode('Enter passcode to end exam');
      if (code == null || code.isEmpty) return;
      if (await ExamLock.unlockWithPasscode(code)) {
        _cancelTimerLock();
        if (mounted) {
          setState(() {
            isExamModeActive = false;
            devicePinned = false;
            dndWorking = false;
            callsWorking = false;
          });
        }
        _snack('Exam mode ended');
      } else {
        await ExamLock.recordStrike('Wrong passcode when ending exam');
        _snack('Incorrect passcode — attempt logged', error: true);
        if (mounted) setState(() {});
      }
    }
  }

  /// Pin gate: shown when the phone could not be pinned. The teacher
  /// must make an explicit choice — the exam never runs unpinned by
  /// accident. Cancel rolls the exam start back completely.
  Future<void> _pinGateDialog() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('\u26a0 Pinning not active'),
        content: const Text(
            'The phone is NOT pinned — Home and Recents gestures still work.\n\n'
            '\u2022 TRY AGAIN: shows the system pinning prompt once more.\n'
            '\u2022 START UNPINNED: runs the exam without gesture blocking (logged).\n'
            '\u2022 CANCEL: ends the exam setup.\n\n'
            'If the system prompt never appears, this phone\u2019s manufacturer '
            'may have disabled screen pinning — use True kiosk mode (device owner) below.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'unpinned'),
              child: const Text('Start unpinned')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'retry'),
              child: const Text('TRY AGAIN')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'retry') {
      await ExamLock.startLock();
      final ok = await ExamLock.awaitPinConfirmed(
          isCancelled: () => !mounted || !ExamLock.isActive.value);
      if (mounted) setState(() => devicePinned = ok);
      if (ok) {
        _snack('Exam ON — device pinned. Passcode ends it.');
      } else if (mounted && ExamLock.isActive.value) {
        await _pinGateDialog();
      }
    } else if (choice == 'unpinned') {
      ExamLock.logTamper('Teacher chose to run the exam UNPINNED');
      if (mounted) setState(() => devicePinned = false);
      _snack('Exam running WITHOUT pinning — gestures work!', error: true);
    } else {
      // Cancel: roll the exam start back completely.
      _cancelTimerLock();
      await ExamLock.stopExam();
      if (mounted) {
        setState(() {
          isExamModeActive = false;
          devicePinned = false;
          dndWorking = false;
          callsWorking = false;
        });
      }
      _snack('Exam cancelled — pinning is required for lockdown');
    }
  }

  /// Do Not Disturb — really silences notifications. Needs one-time
  /// system access; we send the teacher to Settings when missing.
  Future<void> _applyDnd(bool on, {bool silent = false}) async {
    final r = await ExamLock.setDnd(on);
    final ok = r['ok'] == true;
    final needsSettings = r['needsSettings'] == true;
    if (mounted) setState(() => dndWorking = ok && on);
    if (!ok && needsSettings && !silent && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission needed'),
          content: const Text(
              'To silence notifications, allow "Do Not Disturb access" for NS Calculator on the next screen, then turn the toggle on again.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open settings')),
          ],
        ),
      );
      if (go == true) {
        ExamLock.ignoreStrikesUntil =
            DateTime.now().add(const Duration(seconds: 60));
        await ExamLock.openDndSettings();
      }
    } else if (!ok && !silent) {
      _snack('Could not change Do Not Disturb', error: true);
    }
  }

  /// Auto-decline calls — really ends incoming calls during the exam.
  /// Needs the phone permission (asked when enabling).
  Future<void> _applyCallDecline(bool on, {bool silent = false}) async {
    final r = await ExamLock.setCallDecline(on);
    final ok = r['ok'] == true;
    if (mounted) setState(() => callsWorking = ok && on);
    if (!ok && !silent) {
      _snack('Phone permission denied — calls will NOT be declined',
          error: true);
    }
  }

  void _startTimerLock() {
    _cancelTimerLock();
    final session = ++_examSession;
    _examTimer = Timer(Duration(minutes: lockDurationMinutes), () async {
      if (session != _examSession) return; // superseded by a newer exam
      if (mounted && ExamLock.isActive.value) {
        await ExamLock.stopExam();
        if (mounted) {
          setState(() {
            isExamModeActive = false;
            devicePinned = false;
          });
          _snack('Exam auto-ended (timer)');
        }
      }
    });
  }

  void _cancelTimerLock() {
    _examSession++; // invalidate any pending auto-end
    _examTimer?.cancel();
    _examTimer = null;
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = isExamModeActive; // freeze toggles while exam runs
    return ValueListenableBuilder<bool>(
      valueListenable: ExamLock.isHardLocked,
      builder: (_, hardLocked, __) {
        if (hardLocked) return const HardLockScreen();
        return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exam Mode Settings'),
          backgroundColor:
              isExamModeActive ? Colors.red.shade800 : Colors.orange,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Device Lock', [
                      _statusTile(
                        'Screen pinning',
                        devicePinned
                            ? 'ACTIVE — Home, Recents, app switching blocked'
                            : (isExamModeActive
                                ? 'Waiting for system confirmation…'
                                : 'Inactive'),
                        devicePinned,
                      ),
                      _statusTile(
                        'Screenshots & recording',
                        isExamModeActive ? 'Blocked' : 'Allowed',
                        isExamModeActive,
                      ),
                      _statusTile(
                        'Tamper strikes',
                        '${ExamLock.strikes.value}/${ExamLock.maxStrikes}'
                        '${ExamLock.isHardLocked.value ? ' — HARD LOCKED' : ''}',
                        ExamLock.strikes.value == 0,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          'When the exam starts, the app pins itself: the student cannot switch apps or go back until the teacher ends it with the passcode. Five tamper attempts trigger a full lockdown — only the passcode removes it (a phone restart also clears the lock, but the exam re-locks on launch).',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      if (isExamModeActive && !devicePinned)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade800,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12)),
                              onPressed: () async {
                                await ExamLock.startLock();
                                await Future.delayed(
                                    const Duration(seconds: 2));
                                final p = await ExamLock.verifyPin();
                                if (mounted) {
                                  setState(() => devicePinned = p);
                                }
                              },
                              icon: const Icon(Icons.lock),
                              label: const Text('PIN NOW — gestures are working!'),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('True kiosk mode', [
                      _statusTile(
                        'Full lockdown',
                        deviceOwner
                            ? 'ACTIVE — no gesture or button can leave the exam'
                            : 'Not provisioned — standard pinning (system gesture can exit, app re-pins + logs a strike)',
                        deviceOwner,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          'Android always lets the person holding the phone exit ordinary screen pinning (anti-theft safety rule) — no app can remove that. For a literally un-exitable exam, provision the phone once as device owner:',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          '1. On a computer, install Android Platform Tools (ADB).\n'
                          '2. On the phone: enable Developer options → USB debugging, connect via USB.\n'
                          '3. Remove Google accounts from the phone first (or use a fresh/secondary profile) — Android only allows this on an unprovisioned device.\n'
                          '4. Run this command:',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const SelectableText(
                          'adb shell dpm set-device-owner com.example.scientific_calculator/.AdminReceiver',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.greenAccent,
                              fontFamily: 'monospace'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(
                                    text:
                                        'adb shell dpm set-device-owner com.example.scientific_calculator/.AdminReceiver'));
                                _snack('ADB command copied');
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy command'),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          'After this one-time setup, starting Exam Mode locks the phone completely: Home gesture, Recents, notification shade — nothing responds except the calculator. Only the teacher passcode exits.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('Security', [
                      _buildToggle(
                        'Exam Mode',
                        isExamModeActive,
                        locked ? null : (_) => _toggleExamMode(),
                        status: isExamModeActive ? 'ACTIVE' : 'Inactive',
                      ),
                      if (locked)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text(
                            'Settings are frozen while the exam runs.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ListTile(
                        title: const Text('Lock Duration (minutes)'),
                        subtitle: const Text(
                            'Exam auto-ends after this time'),
                        trailing: DropdownButton<int>(
                          value: lockDurationMinutes,
                          items: [15, 30, 60, 120, 240].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value min'),
                            );
                          }).toList(),
                          onChanged: locked
                              ? null
                              : (val) => setState(
                                  () => lockDurationMinutes = val!),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('Restrictions (all functional)', [
                      _buildToggle(
                        'Silence notifications (Do Not Disturb)',
                        dndEnabled,
                        locked
                            ? null
                            : (v) async {
                                setState(() => dndEnabled = v);
                                if (v) await _applyDnd(true);
                              },
                        status: dndWorking ? 'Active' : 'Off',
                      ),
                      _buildToggle(
                        'Auto-decline incoming calls',
                        declineCalls,
                        locked
                            ? null
                            : (v) async {
                                setState(() => declineCalls = v);
                                if (v) await _applyCallDecline(true);
                              },
                        status: callsWorking ? 'Active' : 'Off',
                      ),
                      _buildToggle(
                        'Keep screen on',
                        keepScreenOn,
                        locked
                            ? null
                            : (v) async {
                                setState(() => keepScreenOn = v);
                                if (isExamModeActive) {
                                  await ExamLock.setKeepScreenOn(v);
                                }
                              },
                        status: keepScreenOn ? 'On' : 'Off',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          'Every toggle above performs a real device action. Screen pinning already prevents reaching other apps, so internet blocking is unnecessary.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSection('Monitoring', [
                      ListTile(
                        title: const Text('Tamper log'),
                        subtitle: Text(
                            '${ExamLock.tamperLog.length} event(s) recorded'),
                      ),
                      ...ExamLock.tamperLog.map((log) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            child: Text(log,
                                style: const TextStyle(fontSize: 12)),
                          )),
                      const SizedBox(height: 8),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: locked
                              ? null
                              : () {
                                  ExamLock.logTamper(
                                      'Manual test event (teacher)');
                                  setState(() {});
                                },
                          child: const Text('Log test event'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    if (isExamModeActive)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14)),
                          onPressed: _toggleExamMode,
                          child: const Text('END EXAM (passcode required)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
        );
      },
    );
  }

  Widget _statusTile(String title, String subtitle, bool good) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        good ? Icons.check_circle : Icons.warning,
        color: good ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(
      String title, bool value, ValueChanged<bool>? onChanged,
      {String? status}) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      subtitle: status != null ? Text('Status: $status') : null,
    );
  }
}

/// Passcode prompt. Owns its [TextEditingController] so it is disposed
/// exactly when the dialog route unmounts (after the pop transition),
/// never mid-animation.
class _PasscodePromptDialog extends StatefulWidget {
  final String title;
  const _PasscodePromptDialog({required this.title});

  @override
  State<_PasscodePromptDialog> createState() => _PasscodePromptDialogState();
}

class _PasscodePromptDialogState extends State<_PasscodePromptDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        autofocus: true,
        decoration:
            const InputDecoration(hintText: 'Enter 4-digit passcode'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
            child: const Text('OK')),
      ],
    );
  }
}
