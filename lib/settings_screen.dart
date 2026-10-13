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
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration:
              const InputDecoration(hintText: 'Enter 4-digit passcode'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    return code;
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
      _snack(devicePinned
          ? 'Exam ON — device pinned. Passcode ends it.'
          : 'Exam ON — confirm the system pinning prompt to fully lock.');
      _startTimerLock();
    } else {
      final code = await _askPasscode('Enter passcode to end exam');
      if (code == null || code.isEmpty) return;
      if (await ExamLock.unlockWithPasscode(code)) {
        _examSession++; // invalidate the pending auto-end timer
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

  Future<void> _startTimerLock() async {
    final session = ++_examSession;
    await Future.delayed(Duration(minutes: lockDurationMinutes));
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
