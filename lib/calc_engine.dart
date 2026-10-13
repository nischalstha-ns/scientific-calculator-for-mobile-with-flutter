import 'dart:math' as math;
import 'package:math_expressions/math_expressions.dart';

enum CalculatorMode {
  comp,
  stat,
  table,
  complex,
  baseN,
  matrix,
  vector,
  equation,
}

/// Thrown internally to abort evaluation with a clean "Math ERROR".
class _MathError implements Exception {
  @override
  String toString() => 'Math ERROR';
}

class CalcEngine {
  /// Evaluates [expression] and returns the result as a display string,
  /// or 'Math ERROR' when the expression is invalid.
  ///
  /// [lastResult] feeds the Ans key. [degrees] selects degree mode
  /// (Casio default) vs radian mode for sin/cos/tan and asin/acos/atan.
  /// [eng] selects engineering notation (exponent always a multiple of 3).
  static String evaluate(String expression, String? lastResult,
      {bool degrees = true, bool eng = false}) {
    try {
      if (expression.isEmpty) return '';

      String expr = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('Ans', lastResult ?? '0')
          .replaceAll('π', '${math.pi}')
          // Euler's number: standalone 'e' only (word boundary), so we never
          // corrupt identifiers or scientific notation like 1.5e15.
          .replaceAllMapped(RegExp(r'\be\b'), (_) => '${math.e}')
          .replaceAll('Ran#', '${math.Random().nextDouble()}');
      expr = _replaceRanInt(expr);
      expr = _handlePercent(expr);
      expr = _handleFactorial(expr);
      expr = _autoCloseBrackets(expr);
      _checkTanUndefined(expr, lastResult, degrees);

      // Inverse trig / hyperbolic have no parser support: evaluate in Dart.
      expr = _evalSpecialFuncs(expr, lastResult, degrees);

      // Degree-mode wrapping for sin/cos/tan.
      expr = _wrapTrigDeg(expr, degrees);

      // Roots — specific forms BEFORE the generic √(
      expr = expr.replaceAllMapped(
        RegExp(r'³√\(([^()]+)\)'),
        (m) => '((${m[1]})^(1/3))',
      );
      expr = expr.replaceAllMapped(
        RegExp(r'ⁿ√\(([^,()]+),([^()]+)\)'),
        (m) => '((${m[2]})^(1/(${m[1]})))',
      );
      expr = expr.replaceAll('√(', 'sqrt(');

      // log10(x) -> ln(x)/ln(10).  ln( is native to the parser: keep as-is.
      expr = expr.replaceAllMapped(
        RegExp(r'log10\(([^()]+)\)'),
        (m) => '(ln(${m[1]})/ln(10))',
      );

      // Expand scientific notation (1.5e15 -> (1.5*10^15)): the parser
      // cannot read e-notation, and our own results/Ans feed it back in.
      expr = expr.replaceAllMapped(
        RegExp(r'(\d+\.?\d*)e([+-]?\d+)'),
        (m) => '(${m[1]}*10^${m[2]})',
      );

      // ignore: deprecated_member_use
      Parser p = Parser();
      // ignore: deprecated_member_use
      Expression e = p.parse(expr);
      ContextModel cm = ContextModel();

      double result = e.evaluate(EvaluationType.REAL, cm);

      if (result.isNaN || result.isInfinite) throw _MathError();
      return formatResult(result, eng: eng);
    } on _MathError {
      return 'Math ERROR';
    } catch (_) {
      return 'Math ERROR';
    }
  }

  /// Public formatter so the UI can re-format a raw double (ENG / S-D toggle).
  static String formatResult(double v, {bool eng = false}) {
    if (v == 0) return '0';
    final a = v.abs();
    // Plain integers up to 10 digits.
    if (v == v.truncateToDouble() && a < 1e10) {
      return v.toInt().toString();
    }
    // Ordinary decimals.
    if (!eng && a < 1e10 && a >= 1e-9) {
      return _trimZeros(v.toStringAsFixed(10));
    }
    // Scientific notation, 10 significant digits.
    final parts = v.toStringAsExponential(9).split('e');
    String mant = _trimZeros(parts[0]);
    int exp = int.parse(parts[1]);
    if (eng) {
      final e3 = (exp / 3).floor() * 3;
      final m = v / math.pow(10, e3);
      mant = _trimZeros(m.toStringAsPrecision(10));
      return '${mant}e$e3';
    }
    return '${mant}e$exp';
  }

  static String _trimZeros(String s) {
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  static String _replaceRanInt(String expr) {
    return expr.replaceAllMapped(
      RegExp(r'RanInt\(([^,]+),\s*([^)]+)\)'),
      (m) {
        int min = int.tryParse(m[1]!.trim()) ?? 0;
        int max = int.tryParse(m[2]!.trim()) ?? 0;
        if (max < min) throw _MathError();
        return '${math.Random().nextInt(max - min + 1) + min}';
      },
    );
  }

  static String _handlePercent(String expr) {
    return expr.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)%'),
      (m) => '(${m[1]}/100)',
    );
  }

  static String _handleFactorial(String expr) {
    return expr.replaceAllMapped(
      RegExp(r'(\d+)!'),
      (m) {
        final n = int.tryParse(m[1]!) ?? 0;
        if (n > 170) throw _MathError(); // beyond double range
        if (n <= 20) {
          // Exact integer arithmetic (20! fits in 64 bits).
          int r = 1;
          for (int i = 2; i <= n; i++) {
            r *= i;
          }
          return r.toString();
        }
        double r = 1;
        for (int i = 2; i <= n; i++) {
          r *= i;
        }
        return r.toString(); // scientific; expanded before parsing
      },
    );
  }

  static String _autoCloseBrackets(String expr) {
    final open = '('.allMatches(expr).length;
    final close = ')'.allMatches(expr).length;
    for (int i = 0; i < open - close; i++) {
      expr += ')';
    }
    return expr;
  }

  /// Throws [_MathError] if any tan() call is undefined:
  /// degree mode: argument ≡ 90° (mod 180°); radian mode: argument/π ≡ 0.5 (mod 1).
  static void _checkTanUndefined(
      String expr, String? lastResult, bool degrees) {
    for (final m in RegExp(r'tan\(([^()]+)\)').allMatches(expr)) {
      final val = evaluate(m.group(1)!, lastResult, degrees: degrees);
      final d = double.tryParse(val);
      if (d == null) throw _MathError();
      if (degrees) {
        final mod = ((d - 90) % 180 + 180) % 180;
        final dist = mod > 90 ? 180 - mod : mod;
        if (dist < 1e-9) throw _MathError();
      } else {
        final ratio = d / math.pi - 0.5;
        if ((ratio - ratio.round()).abs() < 1e-9) throw _MathError();
      }
    }
  }

  /// Evaluates asin/acos/atan/asinh/acosh/atanh/sinh/cosh/tanh in Dart
  /// (the expression parser has none of these) and substitutes the
  /// numeric results back into the expression. Handles nesting via
  /// recursive evaluation of each argument.
  static String _evalSpecialFuncs(
      String expr, String? lastResult, bool degrees) {
    const funcs = [
      'asinh',
      'acosh',
      'atanh',
      'asin',
      'acos',
      'atan',
      'sinh',
      'cosh',
      'tanh'
    ];
    bool changed = true;
    while (changed) {
      changed = false;
      for (final fn in funcs) {
        final buf = StringBuffer();
        int i = 0;
        while (i < expr.length) {
          final isIdentChar =
              i > 0 && RegExp(r'[A-Za-z]').hasMatch(expr[i - 1]);
          if (!isIdentChar && expr.startsWith('$fn(', i)) {
            int j = i + fn.length + 1;
            int depth = 1;
            final start = j;
            while (j < expr.length && depth > 0) {
              if (expr[j] == '(') depth++;
              if (expr[j] == ')') depth--;
              if (depth > 0) j++;
            }
            if (depth != 0) {
              buf.write(expr[i]);
              i++;
              continue; // unbalanced; leave as-is (will error later)
            }
            final arg = expr.substring(start, j);
            j++; // skip ')'
            final argVal = evaluate(arg, lastResult, degrees: degrees);
            final x = double.tryParse(argVal);
            if (x == null) throw _MathError();
            buf.write(_applySpecial(fn, x, degrees).toString());
            i = j;
            changed = true;
          } else {
            buf.write(expr[i]);
            i++;
          }
        }
        expr = buf.toString();
      }
    }
    return expr;
  }

  static double _applySpecial(String fn, double x, bool degrees) {
    switch (fn) {
      case 'asin':
        if (x.abs() > 1) throw _MathError();
        final r = math.asin(x);
        return degrees ? r * 180 / math.pi : r;
      case 'acos':
        if (x.abs() > 1) throw _MathError();
        final r = math.acos(x);
        return degrees ? r * 180 / math.pi : r;
      case 'atan':
        final r = math.atan(x);
        return degrees ? r * 180 / math.pi : r;
      case 'sinh':
        return (math.exp(x) - math.exp(-x)) / 2;
      case 'cosh':
        return (math.exp(x) + math.exp(-x)) / 2;
      case 'tanh':
        final e2x = math.exp(2 * x);
        return (e2x - 1) / (e2x + 1);
      case 'asinh':
        return math.log(x + math.sqrt(x * x + 1));
      case 'acosh':
        if (x < 1) throw _MathError();
        return math.log(x + math.sqrt(x * x - 1));
      case 'atanh':
        if (x.abs() >= 1) throw _MathError();
        return 0.5 * math.log((1 + x) / (1 - x));
      default:
        throw _MathError();
    }
  }

  /// Wraps sin/cos/tan arguments with degree-to-radian conversion.
  /// Single left-to-right pass: nested calls (e.g. sin(cos(30))) are
  /// converted inside-out and never double-wrapped.
  static String _wrapTrigDeg(String expr, bool degrees) {
    if (!degrees) return expr;
    const fns = ['sin', 'cos', 'tan'];
    final result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      bool matched = false;
      for (final fn in fns) {
        // Match fn( only when not part of a longer identifier.
        final isIdentChar =
            i > 0 && RegExp(r'[A-Za-z]').hasMatch(expr[i - 1]);
        if (!isIdentChar && expr.startsWith('$fn(', i)) {
          i += fn.length + 1; // skip "fn("
          int depth = 1;
          final start = i;
          while (i < expr.length && depth > 0) {
            if (expr[i] == '(') depth++;
            if (expr[i] == ')') depth--;
            if (depth > 0) i++;
          }
          final arg = expr.substring(start, i);
          i++; // skip ')'
          // Convert nested trig first, then wrap this call.
          result.write('$fn(${_wrapTrigDeg(arg, degrees)}*${math.pi}/180)');
          matched = true;
          break;
        }
      }
      if (!matched) {
        result.write(expr[i]);
        i++;
      }
    }
    return result.toString();
  }
}
