import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calculator_screen.dart';
import 'exam_lock.dart';
import 'exam_store.dart';
import 'key_sound.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If the app was killed mid-exam, relaunch straight back into lockdown —
  // killing the app is not an escape hatch.
  await ExamStore.init();
  await KeySound.init();
  await ExamLock.loadTamperLog();
  if (await ExamStore.isExamActive()) {
    ExamLock.strikes.value = await ExamStore.getStrikes();
    await ExamLock.resumeExam();
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NS CALCULATOR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const CalculatorScreen(),
    );
  }
}
