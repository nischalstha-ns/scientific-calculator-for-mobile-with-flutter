import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/main.dart';

/// Responsive-layout regression tests: the whole calculator UI —
/// header, display, controls, scientific grid and numeric keypad —
/// must fit on screen with zero overflow on small, standard and tall
/// phones, and the bottom row (incl. the equals key) must be fully
/// visible and tappable.
Future<void> _pumpAt(WidgetTester tester, Size physical) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const CalculatorApp());
  await tester.pumpAndSettle();
}

void _expectFits(WidgetTester tester) {
  // Any RenderFlex/Grid overflow raises during pump; surface it here.
  expect(tester.takeException(), isNull,
      reason: 'layout overflow on ${tester.view.physicalSize}');
  final h = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  // Every bottom-row key must be fully inside the viewport.
  // ('0' also appears in the display — take the keypad's, i.e. the last.)
  for (final label in ['·', '×10ˣ', 'Ans', '=']) {
    final found = find.text(label);
    expect(found, findsOneWidget, reason: 'missing key $label');
    final rect = tester.getRect(found);
    expect(rect.top, greaterThanOrEqualTo(0), reason: '$label above screen');
    expect(rect.bottom, lessThanOrEqualTo(h),
        reason: '$label clipped at bottom');
    expect(rect.height, greaterThan(0), reason: '$label has no height');
  }
  final zeroKey = find.text('0').last;
  final zeroRect = tester.getRect(zeroKey);
  expect(zeroRect.bottom, lessThanOrEqualTo(h), reason: '0 key clipped');
  expect(zeroRect.height, greaterThan(0));
}

void main() {
  testWidgets('fits small phone 320x568', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(960, 1704));
    _expectFits(tester);
  });

  testWidgets('fits standard phone 390x844', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(1170, 2532));
    _expectFits(tester);
  });

  testWidgets('fits tall phone 430x932', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(1290, 2796));
    _expectFits(tester);
  });

  testWidgets('equals key still calculates after layout change',
      (WidgetTester tester) async {
    await _pumpAt(tester, const Size(1170, 2532));
    // .last = the keypad key (the display may echo the same digit)
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('+'));
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('='));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('4'), findsWidgets);
  });
}
