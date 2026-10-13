import 'package:flutter/material.dart';
import 'exam_lock.dart';

/// Full-device lockdown shown after [ExamLock.maxStrikes] tamper strikes.
///
/// Nothing on this screen is tappable except the passcode unlock.
/// Only the teacher passcode removes it — a phone restart also clears
/// the lock, but the exam re-locks on launch.
class HardLockScreen extends StatefulWidget {
  const HardLockScreen({super.key});

  @override
  State<HardLockScreen> createState() => _HardLockScreenState();
}

class _HardLockScreenState extends State<HardLockScreen> {
  final _passCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok =
        await ExamLock.unlockWithPasscode(_passCtrl.text.trim());
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong passcode — still locked')),
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      onPressed: _busy ? null : _unlock,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3))
                          : const Text('UNLOCK',
                              style: TextStyle(
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
