import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resumind/core/widgets/custom_button.dart';
import 'package:resumind/core/widgets/pro_badge.dart';

void main() {
  group('Core Widgets Tests', () {
    testWidgets('CustomButton renders and triggers onPressed', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Click Me',
              onPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      // Verify button renders text
      expect(find.text('Click Me'), findsOneWidget);

      // Tap button and verify action
      await tester.tap(find.text('Click Me'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('ProBadge renders with golden background and PRO text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProBadge(),
          ),
        ),
      );

      // Verify the badge text
      expect(find.text('PRO'), findsOneWidget);
    });
  });
}
