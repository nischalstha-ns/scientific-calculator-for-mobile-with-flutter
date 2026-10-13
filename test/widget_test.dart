import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/main.dart';

void main() {
  testWidgets('Calculator app smoke test', (WidgetTester tester) async {
    // The app locks to portrait (see main.dart); exercise it with a
    // realistic portrait phone viewport instead of the 800x600 default.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CalculatorApp());
    expect(find.text('Next-Gen(NS)'), findsOneWidget);
  });
}
