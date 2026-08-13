// Smoke test for Tact's initial screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Shows the connect screen on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TactApp()));

    expect(find.text('Connect to Tact'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // laptop IP + OTP
  });
}