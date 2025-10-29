import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentalapp/main.dart';

void main() {
  testWidgets('RentalApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RentalApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}