import 'package:flutter/material.dart';
import 'calc_engine.dart';
import 'settings_screen.dart';

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
  int cursorPosition = 0;
  CalculatorMode currentMode = CalculatorMode.comp;
  List<double> statData = [];

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
          cursorPosition = display.length;
        } else {
          display = finalVal;
          cursorPosition = finalVal.length;
        }
        result = null;
      } else {
        display = display.substring(0, cursorPosition) + finalVal + display.substring(cursorPosition);
        cursorPosition += finalVal.length;
      }
    });
  }

  void handleClear() {
    setState(() {
      display = '';
      result = null;
      isShift = false;
      isAlpha = false;
      cursorPosition = 0;
    });
  }

  void handleDel() {
    setState(() {
      if (result != null) {
        result = null;
      } else if (display.isNotEmpty && cursorPosition > 0) {
        display = display.substring(0, cursorPosition - 1) + display.substring(cursorPosition);
        cursorPosition--;
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
      cursorPosition = display.length;
    });
  }

  void handleReplay() {
    setState(() {
      if (history.isEmpty) return;
      historyIndex = (historyIndex + 2) % history.length;
      display = history[historyIndex];
      result = null;
      cursorPosition = display.length;
    });
  }

  void handleArrowUp() {
    setState(() {
      if (history.isEmpty) return;
      if (historyIndex < history.length - 1) {
        historyIndex++;
      } else {
        historyIndex = 0;
      }
      display = history[historyIndex];
      result = null;
      cursorPosition = display.length;
    });
  }

  void handleArrowDown() {
    setState(() {
      if (history.isEmpty) return;
      if (historyIndex > 0) {
        historyIndex--;
      } else {
        historyIndex = history.length - 1;
      }
      display = history[historyIndex];
      result = null;
      cursorPosition = display.length;
    });
  }

  void handleArrowLeft() {
    setState(() {
      if (cursorPosition > 0) {
        cursorPosition--;
      }
    });
  }

  void handleArrowRight() {
    setState(() {
      if (cursorPosition < display.length) {
        cursorPosition++;
      }
    });
  }

  String _displayWithCursor() {
    if (result != null) return display;
    if (display.isEmpty) return '';
    return '${display.substring(0, cursorPosition)}|${display.substring(cursorPosition)}';
  }

  String _getModeName(CalculatorMode mode) {
    switch (mode) {
      case CalculatorMode.comp: return 'COMP';
      case CalculatorMode.stat: return 'STAT';
      case CalculatorMode.table: return 'TABLE';
      case CalculatorMode.complex: return 'CMPLX';
      case CalculatorMode.baseN: return 'BASE-N';
      case CalculatorMode.matrix: return 'MATRIX';
      case CalculatorMode.vector: return 'VECTOR';
      case CalculatorMode.equation: return 'EQN';
    }
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ── Responsive scale: base reference 390×780 (iPhone 14) ──
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final scale = (w / 390).clamp(0.75, 1.35);
            final vScale = (h / 780).clamp(0.80, 1.30);

            // Proportional heights replace hardcoded values
            final displayH = (h * 0.18).clamp(120.0, 220.0);
            final controlH = (h * 0.14).clamp(96.0, 150.0);
            final dPadSize = (controlH * 0.95).clamp(80.0, 130.0);
            final outerPad = (16 * scale).clamp(10.0, 22.0);
            final gapL = (10 * vScale).clamp(6.0, 14.0);
            final gapM = (6 * vScale).clamp(4.0, 10.0);
            final gapS = (3 * vScale).clamp(2.0, 6.0);

            return Padding(
              padding: EdgeInsets.all(outerPad),
              child: Column(
                children: [
                  _buildHeader(scale),
                  SizedBox(height: gapL),
                  _buildDisplay(displayH, screenBg, screenInk, scale),
                  SizedBox(height: gapL),
                  _buildControlSection(controlH, dPadSize, scale),
                  SizedBox(height: gapM),
                  _buildFunctionGrid(btnDark, scale, vScale),
                  SizedBox(height: gapS),
                   Expanded(
                       child: _buildKeypad(btnNum, btnDark, scale, vScale)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────
  Widget _buildHeader(double scale) {
    final powerW = (100 * scale).clamp(90.0, 130.0);
    final powerH = (36 * scale).clamp(32.0, 44.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Next-Gen(NS)',
              style: TextStyle(
                fontSize: 28 * scale,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: isDarkMode ? Colors.white : Colors.black87,
                shadows: const [
                  Shadow(
                      color: Colors.black38,
                      offset: Offset(1, 1),
                      blurRadius: 2),
                ],
              ),
            ),
            SizedBox(height: 2 * scale),
            Text(
              'SCIENTIFIC CALCULATOR',
              style: TextStyle(
                fontSize: 9 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: powerW,
              height: powerH,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.grey.shade700, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => isDarkMode = !isDarkMode),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade700, Colors.black],
                          ),
                          border: const Border(
                              right: BorderSide(color: Colors.white24)),
                        ),
                        child: Icon(
                          isDarkMode
                              ? Icons.nightlight_round
                              : Icons.wb_sunny,
                          size: 14 * scale,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Container(color: Colors.grey.shade900)),
                  Expanded(child: Container(color: Colors.grey.shade900)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ExamModeSettings()),
                        );
                      },
                      child: Container(
                        color: Colors.grey.shade900,
                        child: Icon(Icons.settings,
                            size: 14 * scale,
                            color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3 * scale),
            Text(
              'Power Link System',
              style: TextStyle(
                  fontSize: 8 * scale, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  // ── Display Screen ─────────────────────────────────────────
  Widget _buildDisplay(
      double height, Color screenBg, Color screenInk, double scale) {
    return Container(
      width: double.infinity,
      height: height,
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: screenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700, width: 4),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
              spreadRadius: 1),
          BoxShadow(
              color: Colors.white10,
              blurRadius: 1,
              offset: Offset(0, -1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _indicator('S', isShift, screenInk, screenBg, scale),
              SizedBox(width: 10 * scale),
              _indicator('A', isAlpha, screenInk, screenBg, scale),
              SizedBox(width: 10 * scale),
              _indicator('CMPLX', false, screenInk, screenBg, scale),
              SizedBox(width: 10 * scale),
              _indicator('R', true, screenInk, screenBg, scale),
              const Spacer(),
              Text('Math ▲',
                  style: TextStyle(
                      fontSize: 11 * scale,
                      color: screenInk,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          // Expression line — auto-shrink with FittedBox
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                display.isEmpty ? ' ' : _displayWithCursor(),
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: screenInk,
                ),
                maxLines: 1,
              ),
            ),
          ),
          SizedBox(height: 4 * scale),
          // Result line — auto-shrink
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                result ?? (display.isEmpty ? '0' : ''),
                style: TextStyle(
                  fontSize: 40 * scale,
                  fontWeight: FontWeight.w900,
                  color: screenInk,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Control Section (Shift/Alpha | D-Pad | Mode/On) ────────
  Widget _buildControlSection(
      double height, double dPadSize, double scale) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toggleBtn('Shift', isShift, Colors.amber, scale,
                        () {
                      setState(() {
                        isShift = !isShift;
                        isAlpha = false;
                      });
                    }),
                    SizedBox(width: 10 * scale),
                    _toggleBtn('Alpha', isAlpha, Colors.pink, scale, () {
                      setState(() {
                        isAlpha = !isAlpha;
                        isShift = false;
                      });
                    }),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toggleBtn(
                        'Mode\n${_getModeName(currentMode)}', false, Colors.grey, scale, () {
                      setState(() {
                        currentMode = CalculatorMode.values[(currentMode.index + 1) % CalculatorMode.values.length];
                      });
                    }),
                    SizedBox(width: 10 * scale),
                    _toggleBtn(
                        'On', false, Colors.grey, scale, handleClear),
                  ],
                ),
              ],
            ),
          ),
          // D-pad — responsive size
          Center(child: _buildDpad(dPadSize, scale)),
        ],
      ),
    );
  }

  Widget _buildDpad(double size, double scale) {
    final arrowSize = size * 0.22;
    final centerSize = size * 0.55;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 5)),
        ],
        gradient: RadialGradient(
          colors: [Colors.grey.shade700, Colors.grey.shade900],
          radius: 0.8,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 4,
            child: _arrowTap(
                Icons.keyboard_arrow_up, arrowSize, handleArrowUp),
          ),
          Positioned(
            bottom: 4,
            child: _arrowTap(Icons.keyboard_arrow_down, arrowSize,
                handleArrowDown),
          ),
          Positioned(
            left: 4,
            child: _arrowTap(Icons.keyboard_arrow_left, arrowSize,
                handleArrowLeft),
          ),
          Positioned(
            right: 4,
            child: _arrowTap(Icons.keyboard_arrow_right, arrowSize,
                handleArrowRight),
          ),
          GestureDetector(
            onTap: handleReplay,
            child: Container(
              width: centerSize,
              height: centerSize,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.grey.shade800, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                      spreadRadius: -1),
                ],
              ),
              child: Center(
                child: Text(
                  'Replay',
                  style: TextStyle(
                    fontSize: 9 * scale,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowTap(IconData icon, double size, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: Colors.grey.shade400, size: size),
      ),
    );
  }

  // ── Function Grid (6 cols × 4 rows) ────────────────────────
  Widget _buildFunctionGrid(Color btnDark, double scale, double vScale) {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      mainAxisSpacing: 4 * vScale,
      crossAxisSpacing: 4 * scale,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _fnBtn('CALC', 'SOLVE =', btnDark, scale, () {}),
        _fnBtn('∫', 'd/dx :', btnDark, scale, () => handleInput('∫(')),
        const SizedBox(),
        const SizedBox(),
        _fnBtn('x⁻¹', 'x!', btnDark, scale,
            () => handleInput('^-1', '!')),
        _fnBtn('log', 'Σ', btnDark, scale, () => handleInput('log(')),
        _fnBtn('□/□', '√', btnDark, scale, () => handleInput('/')),
        _fnBtn('√', '³√', btnDark, scale,
            () => handleInput('√(', 'Math.cbrt(')),
        _fnBtn('x²', 'x³', btnDark, scale,
            () => handleInput('^2', '^3')),
        _fnBtn('xⁿ', 'ʸ√', btnDark, scale, () => handleInput('^')),
        _fnBtn('log', '10ⁿ', btnDark, scale,
            () => handleInput('log10(')),
        _fnBtn('ln', 'eⁿ', btnDark, scale, () => handleInput('ln(')),
        _fnBtn('(-)', '∠ A', btnDark, scale,
            () => handleInput('-', '', 'A')),
        _fnBtn('°\'"', '← B', btnDark, scale,
            () => handleInput('°', '', 'B')),
        _fnBtn('hyp', 'Abs C', btnDark, scale, () {}),
        _fnBtn('sin', 'sin⁻¹ D', btnDark, scale,
            () => handleInput('sin(', 'asin(', 'D')),
        _fnBtn('cos', 'cos⁻¹ E', btnDark, scale,
            () => handleInput('cos(', 'acos(', 'E')),
        _fnBtn('tan', 'tan⁻¹ F', btnDark, scale,
            () => handleInput('tan(', 'atan(', 'F')),
        _fnBtn('RCL', 'STO', btnDark, scale, () {}),
        _fnBtn('ENG', '← i', btnDark, scale, () {}),
        _fnBtn('(', '% X', btnDark, scale, () => handleInput('(', '', 'X')),
        _fnBtn(')', ', Y', btnDark, scale, () => handleInput(')', '', 'Y')),
        _fnBtn('S⇔D', 'a b/c M', btnDark, scale, () {}),
        _fnBtn('M+', 'M- M', btnDark, scale,
            () => handleInput('+', '-', 'M')),
      ],
    );
  }

  // ── Keypad (mode-dependent) ──────────────────────────
  Widget _buildKeypad(Color btnNum, Color btnDark, double scale, double vScale) {
    if (currentMode == CalculatorMode.stat) {
      return _buildStatKeypad(btnNum, btnDark, scale, vScale);
    }
    // Default COMP mode
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      mainAxisSpacing: 4 * vScale,
      crossAxisSpacing: 4 * scale,
      childAspectRatio: 1.0,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _numBtn('7', 'CONST', btnNum, scale, () => handleInput('7')),
        _numBtn('8', 'CONV', btnNum, scale, () => handleInput('8')),
        _numBtn('9', 'CLR', btnNum, scale, () => handleInput('9')),
        _opBtn('DEL', 'INS', Colors.orange, scale, handleDel),
        _opBtn('AC', 'OFF', Colors.orange, scale, handleClear),
        _numBtn('4', 'MATRIX', btnNum, scale, () => handleInput('4')),
        _numBtn('5', 'VECTOR', btnNum, scale, () => handleInput('5')),
        _numBtn('6', 'VERIFY', btnNum, scale, () => handleInput('6')),
        _opBtn('×', 'nPr', btnDark, scale, () => handleInput('×')),
        _opBtn('÷', 'nCr', btnDark, scale, () => handleInput('÷')),
        _numBtn('1', 'STAT', btnNum, scale, () => handleInput('1')),
        _numBtn('2', 'CMPLX', btnNum, scale, () => handleInput('2')),
        _numBtn('3', 'BASE', btnNum, scale, () => handleInput('3')),
        _opBtn('+', 'Pol', btnDark, scale, () => handleInput('+')),
        _opBtn('-', 'Rec', btnDark, scale, () => handleInput('-')),
        _numBtn('0', 'Rnd', btnNum, scale, () => handleInput('0')),
        _numBtn('·', 'Ran#', btnNum, scale, () => handleInput('.')),
        _numBtn('×10ˣ', 'π e', btnNum, scale, () => handleInput('*10^(', 'π', 'e')),
        _numBtn('Ans', 'DRG▶', btnNum, scale, () => handleInput('Ans')),
        _opBtn('=', 'PreAns', btnDark, scale, calculate),
      ],
    );
  }

  Widget _buildStatKeypad(Color btnNum, Color btnDark, double scale, double vScale) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      mainAxisSpacing: 4 * vScale,
      crossAxisSpacing: 4 * scale,
      childAspectRatio: 1.0,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _numBtn('7', '', btnNum, scale, () => handleInput('7')),
        _numBtn('8', '', btnNum, scale, () => handleInput('8')),
        _numBtn('9', '', btnNum, scale, () => handleInput('9')),
        _opBtn('DEL', '', Colors.orange, scale, handleDel),
        _opBtn('AC', '', Colors.orange, scale, handleClear),
        _numBtn('4', '', btnNum, scale, () => handleInput('4')),
        _numBtn('5', '', btnNum, scale, () => handleInput('5')),
        _numBtn('6', '', btnNum, scale, () => handleInput('6')),
        _opBtn('×', '', btnDark, scale, () => handleInput('×')),
        _opBtn('÷', '', btnDark, scale, () => handleInput('÷')),
        _numBtn('1', '', btnNum, scale, () => handleInput('1')),
        _numBtn('2', '', btnNum, scale, () => handleInput('2')),
        _numBtn('3', '', btnNum, scale, () => handleInput('3')),
        _opBtn('+', '', btnDark, scale, () => handleInput('+')),
        _opBtn('-', '', btnDark, scale, () => handleInput('-')),
        _numBtn('0', '', btnNum, scale, () => handleInput('0')),
        _numBtn('·', '', btnNum, scale, () => handleInput('.')),
        _statBtn('DT', 'Data', btnDark, scale, () => _addStatData()),
        _statBtn('CD', 'Clear Data', btnDark, scale, () => setState(() => statData.clear())),
        _opBtn('=', '', btnDark, scale, _calculateStat),
      ],
    );
  }

  void _addStatData() {
    if (display.isNotEmpty) {
      double? val = double.tryParse(display);
      if (val != null) {
        setState(() {
          statData.add(val);
          display = '';
          result = null;
        });
      }
    }
  }

  void _calculateStat() {
    if (statData.isEmpty) return;
    double sum = statData.reduce((a, b) => a + b);
    double mean = sum / statData.length;
    setState(() {
      result = 'Mean: $mean';
    });
  }

  Widget _indicator(String text, bool active, Color ink, Color bg, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2 * scale),
      color: active ? ink : Colors.transparent,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11 * scale,
          fontWeight: FontWeight.bold,
          color: active ? bg : ink.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, Color activeColor, double scale, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8 * scale,
            fontWeight: FontWeight.w900,
            color: activeColor,
          ),
        ),
        SizedBox(height: 4 * scale),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50 * scale,
            height: 28 * scale,
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.grey[600],
              borderRadius: BorderRadius.circular(20),
              border: const Border(bottom: BorderSide(color: Colors.black, width: 3)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fnBtn(String label, String subLabel, Color color, double scale, VoidCallback onTap) {
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
            fontSize: 8 * scale,
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
              margin: EdgeInsets.only(top: 2 * scale),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: const Border(bottom: BorderSide(color: Colors.black, width: 3)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFe0e0e0),
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

  Widget _numBtn(String label, String subLabel, Color color, double scale, VoidCallback onTap) {
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
            fontSize: 9 * scale,
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
              margin: EdgeInsets.only(top: 2 * scale),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black54, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Color(0xFFffffff),
                    blurRadius: 1,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 22 * scale,
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

  Widget _statBtn(String label, String subLabel, Color color, double scale, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 9 * scale,
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
              margin: EdgeInsets.only(top: 2 * scale),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black54, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Color(0xFFffffff),
                    blurRadius: 1,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 18 * scale,
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

  Widget _opBtn(String label, String subLabel, Color color, double scale, VoidCallback onTap) {
    final isOrange = color == Colors.orange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 9 * scale,
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
              margin: EdgeInsets.only(top: 2 * scale),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black54, width: 1),
                boxShadow: [
                  const BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(0, 3),
                  ),
                  BoxShadow(
                    color: isOrange ? Colors.orange.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
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
