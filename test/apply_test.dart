import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoize_rider/screens/apply/apply_screen.dart';

void main() {
  testWidgets('ApplyScreen builds without box error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ApplyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Become a Rider'), findsOneWidget);
  });
}
