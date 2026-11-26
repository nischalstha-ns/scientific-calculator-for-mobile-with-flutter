import 'dart:async';

import 'package:flutter/material.dart';
import 'exam_lock.dart';

/// Full-device lockdown shown after [ExamLock.maxStrikes] tamper strikes.
///
/// Nothing on this screen is tappable except the passcode unlock.
/// Only the teacher passcode removes it — a phone restart also clears
/// the lock, but the exam re-locks on launch.
///
/// The screen shows how many passcode attempts are left; after
/// [ExamLock.maxUnlockAttempts] wrong codes a cooldown engages and a
/// live countdown shows when trying again is possible.
class HardLockScreen extends StatefulWidget {
  const HardLockScreen({super.key});

  @override
  State<HardLockScreen> createState() => _HardLockScreenState();
}

class _HardLockScreenState extends State<HardLockScreen> {
  final _passCtrl = TextEditingController();
  bool _busy = false;
  int _attemptsLeft = ExamLock.maxUnlockAttempts;
  Duration _cooldown = Duration.zero;
  Timer? _tick;

  bool get _coolingDown => _cooldown > Duration.zero;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Reloads attempts-left / cooldown from persistent storage and runs
  /// the 1-second countdown ticker only while a cooldown is active.
  Future<void> _refreshStatus() async {
    final left = await ExamLock.unlockAttemptsLeft();
    final cd = await ExamLock.unlockCooldownRemaining();
    if (!mounted) return;
    setState(() {
      _attemptsLeft = left;
      _cooldown = cd;
    });
    _tick?.cancel();
    _tick = null;
    if (cd > Duration.zero) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
        final rem = await ExamLock.unlockCooldownRemaining();
        if (!mounted) return;
        setState(() => _cooldown = rem);
        if (rem <= Duration.zero) {
          _tick?.cancel();
          _tick = null;
          _refreshStatus();
        }
      });
    }
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _unlock() async {
    if (_busy) return;
    if (_coolingDown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Cooldown — try again in ${_fmt(_cooldown)}')),
      );
      return;
    }
    setState(() => _busy = true);
    final ok =
        await ExamLock.unlockWithPasscode(_passCtrl.text.trim());
    if (!ok && mounted) {
      _passCtrl.clear();
      await _refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_coolingDown
              ? 'Too many wrong attempts — cooldown ${_fmt(_cooldown)}'
              : 'Wrong passcode — $_attemptsLeft attempt(s) left'),
        ),
      );
      setState(() => _busy = false);
    }
    // On success ExamLock.stopExam() flips the notifiers and this
    // screen disappears on its own.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 72, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'DEVICE LOCKED',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Too many tamper attempts '
                    '(${ExamLock.maxStrikes}/${ExamLock.maxStrikes}).\n'
                    'The device is now fully restricted.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Teacher passcode required to unlock',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    enabled: !_coolingDown && !_busy,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    onSubmitted: (_) => _unlock(),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      hintText: '••••',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_coolingDown)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '⏳ TOO MANY WRONG ATTEMPTS',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try again in ${_fmt(_cooldown)}',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      _attemptsLeft == 1
                          ? '⚠ Last attempt before cooldown'
                          : 'Attempts left: $_attemptsLeft',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _attemptsLeft == 1
                              ? Colors.yellow.shade200
                              : Colors.white70),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      onPressed:
                          (_busy || _coolingDown) ? null : _unlock,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3))
                          : Text(_coolingDown ? 'LOCKED OUT' : 'UNLOCK',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Restarting the phone also clears this lock,\n'
                    'but the exam will re-lock on launch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
