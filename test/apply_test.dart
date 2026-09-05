import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoize_rider/screens/apply/apply_screen.dart';

void main() {
  testWidgets('ApplyScreen builds without box error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ApplyScreen()));
    await tester.pumpAndSettle();
    // Wizard step 1 header (spec title).
    expect(find.text('Apply as a Rider'), findsWidgets);
    expect(find.text('Tell us about yourself'), findsOneWidget);
  });

  testWidgets('Wizard validates, navigates and updates requirements',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ApplyScreen()));
    await tester.pumpAndSettle();

    // Empty continue is blocked with a validation message.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your first name.'), findsOneWidget);
    // Let the snackbar expire so it never covers the nav bar.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Fill step 1 (personal).
    await tester.enterText(
        find.widgetWithText(TextField, 'First Name *'), 'Juan');
    await tester.enterText(
        find.widgetWithText(TextField, 'Last Name *'), 'Dela Cruz');
    await tester.enterText(
        find.widgetWithText(TextField, 'Email *'), 'juan.test@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Phone Number *  (+639 / 09)'),
        '09178881111');
    await tester.tap(find.text('Male'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Address *'), '123 Test St');
    // Date of birth via the date picker (defaults to 20 years ago).
    await tester.ensureVisible(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your Rider Type'), findsOneWidget);

    // Switch to part-time, requirements must follow the switch.
    await tester.tap(find.text('Part-time Rider'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle Information'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'License Plate *'), 'ABC1234');
    await tester.enterText(
        find.widgetWithText(TextField, 'License Number *'), 'L123456');
    await tester.enterText(
        find.widgetWithText(TextField, 'Vehicle Registration *'), 'REG-1');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Requirements step reflects part-time list.
    expect(find.text('Application Requirements'), findsOneWidget);
    expect(find.text('Barangay Clearance'), findsOneWidget);
    expect(find.text('Police or Barangay Clearance'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Documents step shows the dynamic upload cards.
    expect(find.text('Upload Documents'), findsOneWidget);
    expect(find.text("Driver's License"), findsWidgets);
    expect(find.text('OR/CR'), findsWidgets);
  });
}
