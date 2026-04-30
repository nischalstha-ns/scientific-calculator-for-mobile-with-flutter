import 'package:flutter/material.dart';
import 'calc_engine.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String display = '';
  String? result;
  bool isShift = false;
  bool isAlpha = false;
  bool isDarkMode = true;
  List<String> history = [];
  int historyIndex = -1;

  void handleInput(String val, [String? shiftVal, String? alphaVal]) {
    setState(() {
      String finalVal = val;
      if (isShift && shiftVal != null) {
        finalVal = shiftVal;
        isShift = false;
      } else if (isAlpha && alphaVal != null) {
        finalVal = alphaVal;
        isAlpha = false;
      }

      if (result != null) {
        if (['+', '-', '×', '÷'].contains(finalVal)) {
          display = result! + finalVal;
        } else {
          display = finalVal;
        }
        result = null;
      } else {
        display += finalVal;
      }
    });
  }

  void handleClear() {
    setState(() {
      display = '';
      result = null;
      isShift = false;
      isAlpha = false;
    });
  }

  void handleDel() {
    setState(() {
      if (result != null) {
        result = null;
      } else if (display.isNotEmpty) {
        display = display.substring(0, display.length - 1);
      }
    });
  }

  void calculate() {
    setState(() {
      if (display.isEmpty) return;
      history.insert(0, display);
      if (history.length > 50) history.removeLast();
      historyIndex = -1;
      result = CalcEngine.evaluate(display, result);
    });
  }

  void handleReplay() {
    setState(() {
      if (history.isEmpty) return;
      historyIndex = (historyIndex + 1) % history.length;
      display = history[historyIndex];
      result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? const Color(0xFF2d2d2d) : const Color(0xFFe8e8e8);
    final screenBg = isDarkMode ? const Color(0xFFa8c9a0) : const Color(0xFFd4e9c8);
    final screenInk = isDarkMode ? const Color(0xFF0d2d0d) : const Color(0xFF0a2a0a);
    final btnNum = isDarkMode ? const Color(0xFF4a4a4a) : const Color(0xFFf5f5f5);
    final btnDark = isDarkMode ? const Color(0xFF2a2a2a) : const Color(0xFF3a3a3a);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next-Gen(NS)',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'SCIENTIFIC CALCULATOR',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: isDarkMode ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 100,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.grey, width: 2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isDarkMode = !isDarkMode),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.grey[700]!, Colors.black],
                                    ),
                                    border: const Border(right: BorderSide(color: Colors.white24)),
                                  ),
                                  child: Icon(
                                    isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(child: Container(color: Colors.grey[900])),
                            Expanded(child: Container(color: Colors.grey[900])),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    display = 'SETTINGS MODE';
                                    result = null;
                                  });
                                  Future.delayed(const Duration(milliseconds: 1500), () {
                                    setState(() => display = '');
                                  });
                                },
                                child: Container(
                                  color: Colors.grey[900],
                                  child: Icon(Icons.settings, size: 12, color: Colors.grey[600]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Power Link System',
                        style: TextStyle(fontSize: 7, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Display Screen
              Container(
                height: 145,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: screenBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[600]!, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _indicator('S', isShift, screenInk, screenBg),
                        const SizedBox(width: 8),
                        _indicator('A', isAlpha, screenInk, screenBg),
                        const SizedBox(width: 8),
                        _indicator('CMPLX', false, screenInk, screenBg),
                        const SizedBox(width: 8),
                        _indicator('R', true, screenInk, screenBg),
                        const Spacer(),
                        Text('Math ▲', style: TextStyle(fontSize: 10, color: screenInk, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            display.isEmpty ? '' : display,
                            style: TextStyle(
                              fontSize: 22,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: screenInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        result ?? (display.isEmpty ? '0' : ''),
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.w900,
                          color: screenInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Control Section
              SizedBox(
                height: 95,
                child: Stack(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            _toggleBtn('Shift', isShift, Colors.amber, () {
                              setState(() {
                                isShift = !isShift;
                                isAlpha = false;
                              });
                            }),
                            const SizedBox(width: 8),
                            _toggleBtn('Alpha', isAlpha, Colors.pink, () {
                              setState(() {
                                isAlpha = !isAlpha;
                                isShift = false;
                              });
                            }),
                          ],
                        ),
                        Row(
                          children: [
                            _toggleBtn('Mode\nSetup', false, Colors.grey, () {}),
                            const SizedBox(width: 8),
                            _toggleBtn('On', false, Colors.grey, handleClear),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 5,
                      child: Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: Icon(Icons.keyboard_arrow_up, color: Colors.grey[600], size: 24),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600], size: 24),
                              ),
                              Positioned(
                                left: 8,
                                top: 0,
                                bottom: 0,
                                child: Icon(Icons.keyboard_arrow_left, color: Colors.grey[600], size: 24),
                              ),
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Icon(Icons.keyboard_arrow_right, color: Colors.grey[600], size: 24),
                              ),
                              Center(
                                child: GestureDetector(
                                  onTap: handleReplay,
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[800]!, width: 2),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Replay',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[400],
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Function Buttons (6 cols)
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                mainAxisSpacing: 2,
                crossAxisSpacing: 4,
                childAspectRatio: 1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _fnBtn('CALC', 'SOLVE =', btnDark, () {}),
                  _fnBtn('∫', 'd/dx :', btnDark, () => handleInput('∫(')),
                  const SizedBox(),
                  const SizedBox(),
                  _fnBtn('x⁻¹', 'x!', btnDark, () => handleInput('^-1', '!')),
                  _fnBtn('log', 'Σ', btnDark, () => handleInput('log(')),
                  _fnBtn('□/□', '√', btnDark, () => handleInput('/')),
                  _fnBtn('√', '³√', btnDark, () => handleInput('√(', 'Math.cbrt(')),
                  _fnBtn('x²', 'x³', btnDark, () => handleInput('^2', '^3')),
                  _fnBtn('xⁿ', 'ʸ√', btnDark, () => handleInput('^')),
                  _fnBtn('log', '10ⁿ', btnDark, () => handleInput('log10(')),
                  _fnBtn('ln', 'eⁿ', btnDark, () => handleInput('ln(')),
                  _fnBtn('(-)', '∠ A', btnDark, () => handleInput('-', '', 'A')),
                  _fnBtn('°\'"', '← B', btnDark, () => handleInput('°', '', 'B')),
                  _fnBtn('hyp', 'Abs C', btnDark, () {}),
                  _fnBtn('sin', 'sin⁻¹ D', btnDark, () => handleInput('sin(', 'asin(', 'D')),
                  _fnBtn('cos', 'cos⁻¹ E', btnDark, () => handleInput('cos(', 'acos(', 'E')),
                  _fnBtn('tan', 'tan⁻¹ F', btnDark, () => handleInput('tan(', 'atan(', 'F')),
                  _fnBtn('RCL', 'STO', btnDark, () {}),
                  _fnBtn('ENG', '← i', btnDark, () {}),
                  _fnBtn('(', '% X', btnDark, () => handleInput('(', '', 'X')),
                  _fnBtn(')', ', Y', btnDark, () => handleInput(')', '', 'Y')),
                  _fnBtn('S⇔D', 'a b/c M', btnDark, () {}),
                  _fnBtn('M+', 'M- M', btnDark, () => handleInput('+', '-', 'M')),
                ],
              ),
              const SizedBox(height: 4),

              // Main Keypad (5 cols)
              Expanded(
                child: GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 5,
                  childAspectRatio: 1.1,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _numBtn('7', 'CONST', btnNum, () => handleInput('7')),
                    _numBtn('8', 'CONV', btnNum, () => handleInput('8')),
                    _numBtn('9', 'CLR', btnNum, () => handleInput('9')),
                    _opBtn('DEL', 'INS', Colors.orange, handleDel),
                    _opBtn('AC', 'OFF', Colors.orange, handleClear),
                    _numBtn('4', 'MATRIX', btnNum, () => handleInput('4')),
                    _numBtn('5', 'VECTOR', btnNum, () => handleInput('5')),
                    _numBtn('6', 'VERIFY', btnNum, () => handleInput('6')),
                    _opBtn('×', 'nPr', btnDark, () => handleInput('×')),
                    _opBtn('÷', 'nCr', btnDark, () => handleInput('÷')),
                    _numBtn('1', 'STAT', btnNum, () => handleInput('1')),
                    _numBtn('2', 'CMPLX', btnNum, () => handleInput('2')),
                    _numBtn('3', 'BASE', btnNum, () => handleInput('3')),
                    _opBtn('+', 'Pol', btnDark, () => handleInput('+')),
                    _opBtn('-', 'Rec', btnDark, () => handleInput('-')),
                    _numBtn('0', 'Rnd', btnNum, () => handleInput('0')),
                    _numBtn('·', 'Ran#', btnNum, () => handleInput('.')),
                    _numBtn('×10ˣ', 'π e', btnNum, () => handleInput('*10^(', 'π', 'e')),
                    _numBtn('Ans', 'DRG▶', btnNum, () => handleInput('Ans')),
                    _opBtn('=', 'PreAns', btnDark, calculate),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicator(String text, bool active, Color ink, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      color: active ? ink : Colors.transparent,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: active ? bg : ink.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, Color activeColor, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: activeColor,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 28,
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.grey[600],
              borderRadius: BorderRadius.circular(20),
              border: const Border(bottom: BorderSide(color: Colors.black, width: 3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fnBtn(String label, String subLabel, Color color, VoidCallback onTap) {
    final hasAlpha = subLabel.contains('A') || subLabel.contains('B') || subLabel.contains('C') ||
        subLabel.contains('D') || subLabel.contains('E') || subLabel.contains('F') ||
        subLabel.contains('X') || subLabel.contains('Y') || subLabel.contains('M') ||
        subLabel.contains('sin⁻¹') || subLabel.contains('cos⁻¹') || subLabel.contains('tan⁻¹');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            color: hasAlpha ? Colors.pink[400] : Colors.amber[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: const Border(bottom: BorderSide(color: Colors.black, width: 3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFe0e0e0),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numBtn(String label, String subLabel, Color color, VoidCallback onTap) {
    final isGreen = subLabel.contains('MATRIX') || subLabel.contains('VECTOR') ||
        subLabel.contains('VERIFY') || subLabel.contains('STAT') ||
        subLabel.contains('CMPLX') || subLabel.contains('BASE') ||
        subLabel.contains('CONST') || subLabel.contains('CONV') || subLabel.contains('CLR');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: isGreen ? Colors.teal[300] : Colors.amber[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black54, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _opBtn(String label, String subLabel, Color color, VoidCallback onTap) {
    final isOrange = color == Colors.orange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: Colors.amber[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black54, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: isOrange ? Colors.orange.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
