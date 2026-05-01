import 'package:flutter/material.dart';

class ExamModeSettings extends StatefulWidget {
  const ExamModeSettings({super.key});

  @override
  State<ExamModeSettings> createState() => _ExamModeSettingsState();
}

class _ExamModeSettingsState extends State<ExamModeSettings> {
  bool isExamModeActive = false;
  String? passcode;
  bool blockNotifications = false;
  bool blockCalls = false;
  bool blockMessages = false;
  bool blockBackgroundApps = false;
  bool blockInternet = false;
  bool strictMode = false;
  bool readyMode = false;
  List<String> whitelistApps = [];
  int lockDurationMinutes = 60;
  List<String> activityLog = [];
  bool suspiciousActivityDetected = false;

  // Mock suspicious activity detection
  void _detectSuspiciousActivity(String activity) {
    setState(() {
      suspiciousActivityDetected = true;
      activityLog.add('${DateTime.now()}: $activity');
      _showWarningDialog(activity);
    });
  }

  void _showWarningDialog(String activity) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Danger / Warning'),
        content: Text('Suspicious activity detected: $activity\nAll features are now locked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleExamMode() async {
    if (!isExamModeActive) {
      if (passcode == null) {
        await _setPasscode();
      }
      if (passcode != null) {
        await _enterPasscode();
      }
    } else {
      await _enterPasscode();
    }
  }

  Future<void> _setPasscode() async {
    String? code = await showDialog<String>(
      context: context,
      builder: (context) => PasscodeDialog(title: 'Set Passcode'),
    );
    if (code != null) {
      setState(() => passcode = code);
    }
  }

  Future<void> _enterPasscode() async {
    String? code = await showDialog<String>(
      context: context,
      builder: (context) => PasscodeDialog(title: 'Enter Passcode'),
    );
    if (code == passcode) {
      setState(() {
        isExamModeActive = !isExamModeActive;
        if (isExamModeActive) {
          _startTimerLock();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exam Mode ${isExamModeActive ? 'Activated' : 'Deactivated'}')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect Passcode')),
        );
      }
    }
  }

  void _startTimerLock() {
    Future.delayed(Duration(minutes: lockDurationMinutes), () {
      if (mounted) {
        setState(() => isExamModeActive = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exam Mode auto-deactivated due to timer')),
          );
        }
      }
    });
  }

  void _addWhitelistApp() async {
    String? app = await showDialog<String>(
      context: context,
      builder: (context) => const WhitelistAppDialog(),
    );
    if (app != null && app.isNotEmpty) {
      setState(() => whitelistApps.add(app));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Mode Settings'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Security', [
              _buildToggle(
                'Exam Mode Active',
                isExamModeActive,
                (val) => _toggleExamMode(),
                status: isExamModeActive ? 'Active' : 'Inactive',
              ),
              if (passcode != null)
                ListTile(
                  title: const Text('Passcode Set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _setPasscode,
                  ),
                ),
              ListTile(
                title: const Text('Lock Duration (minutes)'),
                trailing: DropdownButton<int>(
                  value: lockDurationMinutes,
                  items: [15, 30, 60, 120, 240].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value min'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => lockDurationMinutes = val!),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Restrictions', [
              _buildToggle(
                'Block Notifications',
                blockNotifications,
                (val) => setState(() => blockNotifications = val),
                status: blockNotifications ? 'Blocked' : 'Allowed',
              ),
              _buildToggle(
                'Block Incoming/Outgoing Calls',
                blockCalls,
                (val) => setState(() => blockCalls = val),
                status: blockCalls ? 'Blocked' : 'Allowed',
              ),
              _buildToggle(
                'Block Messages (SMS, Chat Apps)',
                blockMessages,
                (val) => setState(() => blockMessages = val),
                status: blockMessages ? 'Blocked' : 'Allowed',
              ),
              _buildToggle(
                'Block Background Apps & Processes',
                blockBackgroundApps,
                (val) => setState(() => blockBackgroundApps = val),
                status: blockBackgroundApps ? 'Blocked' : 'Allowed',
              ),
              _buildToggle(
                'Block Internet Access',
                blockInternet,
                (val) => setState(() => blockInternet = val),
                status: blockInternet ? 'Blocked' : 'Allowed',
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Exam Modes', [
              _buildToggle(
                'Strict Exam Mode (All External Blocked)',
                strictMode,
                (val) => setState(() => strictMode = val),
                status: strictMode ? 'Active' : 'Inactive',
              ),
              _buildToggle(
                'Ready Mode / Safe Mode (Whitelist Only)',
                readyMode,
                (val) => setState(() => readyMode = val),
                status: readyMode ? 'Active' : 'Inactive',
              ),
              if (readyMode) ...[
                const SizedBox(height: 10),
                const Text('Whitelisted Apps:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...whitelistApps.map((app) => ListTile(
                  title: Text(app),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => whitelistApps.remove(app)),
                  ),
                )),
                ElevatedButton(
                  onPressed: _addWhitelistApp,
                  child: const Text('Add App'),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection('Monitoring', [
              _buildToggle(
                'Suspicious Activity Detection',
                true, // Always on for demo
                null,
                status: suspiciousActivityDetected ? 'Warning' : 'Normal',
              ),
              ElevatedButton(
                onPressed: () => _detectSuspiciousActivity('App Switching Detected'),
                child: const Text('Simulate App Switching'),
              ),
              ElevatedButton(
                onPressed: () => _detectSuspiciousActivity('Screen Recording Detected'),
                child: const Text('Simulate Screen Recording'),
              ),
              const SizedBox(height: 10),
              const Text('Activity Log:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...activityLog.map((log) => Text(log)),
            ]),
          ],
        ),
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String title, bool value, ValueChanged<bool>? onChanged, {String? status}) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      subtitle: status != null ? Text('Status: $status') : null,
    );
  }
}

class PasscodeDialog extends StatefulWidget {
  final String title;
  const PasscodeDialog({super.key, required this.title});

  @override
  State<PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<PasscodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Enter 4-digit passcode'),
        maxLength: 4,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class WhitelistAppDialog extends StatefulWidget {
  const WhitelistAppDialog({super.key});

  @override
  State<WhitelistAppDialog> createState() => _WhitelistAppDialogState();
}

class _WhitelistAppDialogState extends State<WhitelistAppDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Whitelisted App'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'App name or package'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}