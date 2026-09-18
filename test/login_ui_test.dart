import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:invoize_rider/core/network/api_client.dart';
import 'package:invoize_rider/core/storage/token_storage.dart';
import 'package:invoize_rider/providers/auth_provider.dart';
import 'package:invoize_rider/providers/delivery_provider.dart';
import 'package:invoize_rider/providers/rider_provider.dart';
import 'package:invoize_rider/screens/auth/login_screen.dart';
import 'package:invoize_rider/screens/dashboard/dashboard_screen.dart';
import 'package:invoize_rider/services/delivery_service.dart';
import 'package:invoize_rider/services/rider_service.dart';
import 'package:invoize_rider/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stub HTTP client so login can be exercised without a server.
class _StubClient extends http.BaseClient {
  _StubClient({this.statusCode = 401, this.body, this.latency = Duration.zero});

  int statusCode;
  Object? body;
  final Duration latency;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final payload = utf8.encode(jsonEncode(body ?? {}));
    return http.StreamedResponse(
      Stream<List<int>>.value(Uint8List.fromList(payload)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<void> _pumpLogin(WidgetTester tester, _StubClient client) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: AuthProvider(
        api: ApiClient(client: client),
        storage: TokenStorage(),
      ),
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void _setSurface(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Login responsive layout', () {
    for (final (width, height) in [
      (320.0, 568.0),
      (360.0, 640.0),
      (375.0, 667.0),
      (412.0, 915.0),
      (640.0, 360.0), // landscape
    ]) {
      testWidgets(
        'login fits ${width.toInt()}x${height.toInt()} without overflow',
        (tester) async {
          _setSurface(tester, width, height);
          await _pumpLogin(tester, _StubClient());

          final scrollable = find.byType(SingleChildScrollView);
          await tester.fling(scrollable, const Offset(0, -1200), 2500);
          await tester.pumpAndSettle();
          await tester.fling(scrollable, const Offset(0, 1200), 2500);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Rider Login'), findsOneWidget);
          expect(find.text('Sign in to Rider Center'), findsOneWidget);
        },
      );
    }
  });

  group('Rider secondary actions', () {
    for (final width in [320.0, 360.0, 375.0, 412.0]) {
      testWidgets('borderless actions share one row at ${width.toInt()}px', (
        tester,
      ) async {
        _setSurface(tester, width, 800);
        await _pumpLogin(tester, _StubClient());

        expect(find.byType(TextButton), findsNWidgets(2));
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.text('Apply as a Rider'), findsOneWidget);
        expect(find.text('Check Application Status'), findsOneWidget);

        // Both actions sit on the same horizontal line (single Row).
        final rowOfActions = find.ancestor(
          of: find.text('Check Application Status'),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(
            of: rowOfActions,
            matching: find.text('Apply as a Rider'),
          ),
          findsOneWidget,
        );

        await tester.fling(
          find.byType(SingleChildScrollView),
          const Offset(0, -1200),
          2500,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the primary submit button visually dominant', (
      tester,
    ) async {
      _setSurface(tester, 412, 915);
      await _pumpLogin(tester, _StubClient());

      final submit = find.widgetWithText(
        ElevatedButton,
        'Sign in to Rider Center',
      );
      final submitHeight = tester.getSize(submit).height;

      // Full-height (52px) filled button vs. compact borderless TextButtons —
      // the primary action must stay the largest element on the page.
      expect(submitHeight, greaterThanOrEqualTo(52));
      expect(submitHeight, greaterThan(40));
      expect(find.byType(TextButton), findsNWidgets(2));
    });

    testWidgets('Logistics Center actions are not exposed on Rider login', (
      tester,
    ) async {
      _setSurface(tester, 412, 915);
      await _pumpLogin(tester, _StubClient());

      expect(find.text('Open a Logistics Center'), findsNothing);
      expect(
        find.text('Check a logistics center application status'),
        findsNothing,
      );

      // Rider-only secondary actions remain.
      expect(find.text('Apply as a Rider'), findsOneWidget);
      expect(find.text('Check Application Status'), findsOneWidget);
    });
  });

  group('Login validation', () {
    testWidgets('shows messages for empty required fields', (tester) async {
      _setSurface(tester, 390, 844);
      await _pumpLogin(tester, _StubClient());

      await tester.tap(find.text('Sign in to Rider Center'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('rejects an invalid email and a short password', (
      tester,
    ) async {
      _setSurface(tester, 390, 844);
      await _pumpLogin(tester, _StubClient());

      await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextField).at(1), '123');
      await tester.tap(find.text('Sign in to Rider Center'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
    });
  });

  group('Login submission guard', () {
    testWidgets('only sends one request when the button is tapped repeatedly', (
      tester,
    ) async {
      _setSurface(tester, 390, 844);
      final client = _StubClient(
        statusCode: 401,
        latency: const Duration(milliseconds: 200),
        body: {'message': 'Invalid credentials.'},
      );
      await _pumpLogin(tester, client);

      await tester.enterText(find.byType(TextField).at(0), 'rider@invoiz.test');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign in to Rider Center'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(client.requestCount, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Login failure feedback', () {
    testWidgets('shows an inline error banner with the server message', (
      tester,
    ) async {
      _setSurface(tester, 390, 844);
      final client = _StubClient(
        statusCode: 401,
        body: {'message': 'Invalid credentials.'},
      );
      await _pumpLogin(tester, client);

      await tester.enterText(find.byType(TextField).at(0), 'rider@invoiz.test');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign in to Rider Center'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('falls back to a friendly message when the server gives none', (
      tester,
    ) async {
      _setSurface(tester, 390, 844);
      final client = _StubClient(
        statusCode: 500,
        body: {'message': 'Something went wrong. Please try again.'},
      );
      await _pumpLogin(tester, client);

      await tester.enterText(find.byType(TextField).at(0), 'rider@invoiz.test');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign in to Rider Center'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to log in'), findsOneWidget);
    });
  });

  group('Password visibility toggle', () {
    testWidgets('icons expose accessibility tooltips', (tester) async {
      _setSurface(tester, 390, 844);
      await _pumpLogin(tester, _StubClient());

      final hidden = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.visibility_off_outlined),
      );
      expect(hidden.tooltip, 'Show password');

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      final shown = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.visibility_outlined),
      );
      expect(shown.tooltip, 'Hide password');
    });
  });

  group('Dashboard responsive', () {
    testWidgets('loading and error states fit a small screen', (tester) async {
      _setSurface(tester, 320, 568);
      final api = ApiClient(client: _StubClient());
      final rider = RiderProvider(RiderService(api));
      final deliveries = DeliveryProvider(DeliveryService(api));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RiderProvider>.value(value: rider),
            ChangeNotifierProvider<DeliveryProvider>.value(value: deliveries),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      final load = rider.loadDashboard();
      await tester.pump(const Duration(milliseconds: 300));
      await load;
      await tester.pump();

      expect(find.text('Try Again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
