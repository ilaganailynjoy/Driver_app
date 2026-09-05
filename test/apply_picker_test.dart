import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoize_rider/screens/apply/apply_screen.dart';

/// Picker-boundary tests for the Documents step.
///
/// The native file picker cannot run in widget tests, so these drive the
/// real wizard UI with a fake [DocFilePicker]: pick success (all four
/// formats), cancel silence, picker failure message, replace and remove.
class FakeDocPicker extends DocFilePicker {
  PickedDoc? next;
  Object? error;
  List<String>? lastAllowed;

  @override
  Future<PickedDoc?> pickSingle(List<String> allowedExtensions) async {
    lastAllowed = List.of(allowedExtensions);
    if (error != null) throw error!;
    return next;
  }
}

PickedDoc docOf(String name, [int size = 1500]) => PickedDoc(
      name: name,
      readBytes: () async =>
          Uint8List.fromList(List.filled(size, 7)),
    );

/// Drives Personal (valid) → Rider Type (default full-time) → Vehicle
/// (default own) → Requirements → Documents. Ownership `own` keeps the
/// required set to the trio + clearance card.
Future<void> driveToDocuments(
    WidgetTester tester, FakeDocPicker picker) async {
  await tester.pumpWidget(MaterialApp(home: ApplyScreen(picker: picker)));
  await tester.pumpAndSettle();

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
  await tester.ensureVisible(find.text('Select date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Select date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continue')); // → rider type
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue')); // → vehicle (full-time default)
  await tester.pumpAndSettle();
  await tester.enterText(
      find.widgetWithText(TextField, 'License Plate *'), 'ABC1234');
  await tester.enterText(
      find.widgetWithText(TextField, 'License Number *'), 'L123456');
  await tester.enterText(
      find.widgetWithText(TextField, 'Vehicle Registration *'), 'REG-1');
  await tester.tap(find.text('Continue')); // → requirements
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue')); // → documents
  await tester.pumpAndSettle();
  expect(find.text('Upload Documents'), findsOneWidget);
}

void main() {
  testWidgets('tapping upload stages file: name, size, replace, remove',
      (tester) async {
    final picker = FakeDocPicker()
      ..next = docOf('license.pdf');
    await driveToDocuments(tester, picker);

    await tester.tap(find.text('Upload file').first);
    await tester.pumpAndSettle();

    // Picker received the supported filter and the real filename is shown.
    expect(
      picker.lastAllowed,
      containsAll(['pdf', 'jpg', 'jpeg', 'png']),
    );
    expect(find.textContaining('license.pdf'), findsOneWidget);
    expect(find.textContaining('1.5 KB'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(
      find.textContaining('will be uploaded when you submit'),
      findsOneWidget,
    );
  });

  testWidgets('pdf, jpg, jpeg and png are all accepted with names kept',
      (tester) async {
    final picker = FakeDocPicker();
    await driveToDocuments(tester, picker);

    const names = [
      'clearance.pdf',
      'photo.jpg',
      'scan.jpeg',
      'id.png',
    ];
    for (final name in names) {
      picker.next = docOf(name);
      await tester.ensureVisible(find.text('Upload file').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload file').first);
      await tester.pumpAndSettle();
    }
    for (final name in names) {
      expect(find.textContaining(name), findsOneWidget);
    }
  });

  testWidgets('oversized files are rejected with a clear message',
      (tester) async {
    final picker = FakeDocPicker()
      ..next = docOf('huge.pdf', 6 * 1024 * 1024);
    await driveToDocuments(tester, picker);

    await tester.tap(find.text('Upload file').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('huge.pdf'), findsNothing);
    expect(find.textContaining('over 5 MB'), findsOneWidget);
    // Card stays in pick state so the user can try another file.
    expect(find.text('Upload file'), findsWidgets);
  });

  testWidgets('canceling the picker shows no error', (tester) async {
    final picker = FakeDocPicker()..next = null; // user pressed back
    await driveToDocuments(tester, picker);

    await tester.tap(find.text('Upload file').first);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    // Nothing staged: the card is still in pick state.
    expect(find.text('Upload file'), findsWidgets);
  });

  testWidgets('picker failure shows a meaningful message', (tester) async {
    final picker = FakeDocPicker()
      ..error = MissingPluginException(
          'No implementation found for method pickFile');
    await driveToDocuments(tester, picker);

    await tester.tap(find.text('Upload file').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not available in this app build'),
      findsOneWidget,
    );
  });

  testWidgets('replace swaps the staged file', (tester) async {
    final picker = FakeDocPicker()..next = docOf('old.pdf');
    await driveToDocuments(tester, picker);

    await tester.tap(find.text('Upload file').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('old.pdf'), findsOneWidget);

    picker.next = docOf('new.pdf');
    await tester.tap(find.text('Replace').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('new.pdf'), findsOneWidget);
    expect(find.textContaining('old.pdf'), findsNothing);
  });

  testWidgets('remove clears the staged file', (tester) async {
    final picker = FakeDocPicker()..next = docOf('license.pdf');
    await driveToDocuments(tester, picker);

    final uploadCount =
        find.text('Upload file').evaluate().length;
    await tester.tap(find.text('Upload file').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('license.pdf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('license.pdf'), findsNothing);
    expect(find.text('Upload file').evaluate().length, uploadCount);
  });
}
