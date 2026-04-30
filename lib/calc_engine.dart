import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

class CalcEngine {
  static String evaluate(String expression, String? lastResult) {
    try {
      if (expression.isEmpty) return '';

      String expr = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('Ans', lastResult ?? '0')
          .replaceAll('π', '${math.pi}')
          .replaceAll('^', '^');

      // Auto-close brackets
      int open = '('.allMatches(expr).length;
      int close = ')'.allMatches(expr).length;
      for (int i = 0; i < open - close; i++) {
        expr += ')';
      }

      // Convert degree trig to radian trig for math_expressions
      // sin(x) -> sin(x*pi/180), etc.
      expr = _wrapTrigDeg(expr);

      // ln -> log (math_expressions uses log for natural log)
      expr = expr.replaceAll('ln(', 'log(');

      // log10(x) -> log(x)/log(10)
      expr = expr.replaceAllMapped(
        RegExp(r'log10\(([^()]+)\)'),
        (m) => '(log(${m[1]})/log(10))',
      );

      // √( -> sqrt(
      expr = expr.replaceAll('√(', 'sqrt(');

      // ignore: deprecated_member_use
      Parser p = Parser();
      // ignore: deprecated_member_use
      Expression e = p.parse(expr);
      ContextModel cm = ContextModel();
      double result = e.evaluate(EvaluationType.REAL, cm);

      if (result.isNaN || result.isInfinite) return 'Math ERROR';

      if (result == result.truncateToDouble() && result.abs() < 1e15) {
        return result.toInt().toString();
      }
      String formatted = result.toStringAsFixed(10);
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
      return formatted;
    } catch (_) {
      return 'Math ERROR';
    }
  }

  // Wrap sin/cos/tan arguments with degree-to-radian conversion
  // but NOT asin/acos/atan
  static String _wrapTrigDeg(String expr) {
    // Process asin/acos/atan first (inverse - output in degrees, input is ratio)
    // math_expressions asin/acos/atan return radians, convert to degrees
    expr = _wrapFunc(expr, 'asin', (arg) => '(asin($arg)*180/${math.pi})');
    expr = _wrapFunc(expr, 'acos', (arg) => '(acos($arg)*180/${math.pi})');
    expr = _wrapFunc(expr, 'atan', (arg) => '(atan($arg)*180/${math.pi})');
    // Now wrap sin/cos/tan to convert degrees to radians
    expr = _wrapFunc(expr, 'sin', (arg) => 'sin($arg*${math.pi}/180)');
    expr = _wrapFunc(expr, 'cos', (arg) => 'cos($arg*${math.pi}/180)');
    expr = _wrapFunc(expr, 'tan', (arg) => 'tan($arg*${math.pi}/180)');
    return expr;
  }

  static String _wrapFunc(String expr, String fn, String Function(String) wrapper) {
    final result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      if (expr.startsWith('$fn(', i)) {
        i += fn.length + 1; // skip "fn("
        // Find matching closing paren
        int depth = 1;
        int start = i;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') depth++;
          if (expr[i] == ')') depth--;
          if (depth > 0) i++;
        }
        final arg = expr.substring(start, i);
        i++; // skip ')'
        result.write(wrapper(arg));
      } else {
        result.write(expr[i]);
        i++;
      }
    }
    return result.toString();
  }
}
