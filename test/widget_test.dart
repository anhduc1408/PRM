import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixue_manager/main.dart';

void main() {
  testWidgets('MixueApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MixueApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
