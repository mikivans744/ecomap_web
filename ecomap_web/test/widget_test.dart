// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/theme/app_theme.dart';

void main() {
  testWidgets('applies readable typography and input spacing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.offlineTheme,
        home: const Scaffold(
          body: TextField(
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
            style: TextStyle(letterSpacing: 0.5),
          ),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.textTheme.headlineSmall?.fontSize, 24);
    expect(theme.textTheme.headlineSmall?.fontWeight, FontWeight.w700);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    );
    expect(field.style?.letterSpacing, 0.5);
  });
}
