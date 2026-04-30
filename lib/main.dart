import 'package:flutter/material.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String display = '';
  String result = '0';

  void onButtonClick(String value) {
    setState(() {
      if (value == 'AC') {
        display = '';
        result = '0';
      } else if (value == 'DEL') {
        if (display.isNotEmpty) {
          display = display.substring(0, display.length - 1);
        }
      } else if (value == '=') {
        calculate();
      } else {
        display += value;
      }
    });
  }

  void calculate() {
    try {
      String exp = display
          .replaceAll('×', '*')
          .replaceAll('÷', '/');

      final res = _evaluate(exp);
      result = res.toString();
    } catch (e) {
      result = "Error";
    }
  }

  double _evaluate(String exp) {
    // VERY basic evaluation (you can upgrade with math parser)
    return double.parse(
        (exp.isEmpty ? 0 : double.parse(exp)).toString());
  }

  Widget buildButton(String text,
      {Color? color, double flex = 1}) {
    return Expanded(
      flex: flex.toInt(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey[850],
            padding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => onButtonClick(text),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRow(List<Widget> children) {
    return Row(children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // DISPLAY
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      display,
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BUTTONS
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  buildRow([
                    buildButton('7'),
                    buildButton('8'),
                    buildButton('9'),
                    buildButton('DEL', color: Colors.orange),
                    buildButton('AC', color: Colors.red),
                  ]),
                  buildRow([
                    buildButton('4'),
                    buildButton('5'),
                    buildButton('6'),
                    buildButton('×', color: Colors.blue),
                    buildButton('÷', color: Colors.blue),
                  ]),
                  buildRow([
                    buildButton('1'),
                    buildButton('2'),
                    buildButton('3'),
                    buildButton('+', color: Colors.blue),
                    buildButton('-', color: Colors.blue),
                  ]),
                  buildRow([
                    buildButton('0', flex: 2),
                    buildButton('.'),
                    buildButton('=', color: Colors.green),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}