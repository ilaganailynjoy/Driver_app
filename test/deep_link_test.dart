import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoize_rider/screens/auth/login_screen.dart';
import 'package:invoize_rider/services/deep_link_service.dart';
import 'package:invoize_rider/widgets/deep_link_broker.dart';

/// Test double for [DeepLinkService]: deterministic cold-start link and a
/// stream the test can drive by hand.
class _FakeDeepLinks implements DeepLinkService {
  _FakeDeepLinks() : _controller = StreamController<Uri>.broadcast();

  final StreamController<Uri> _controller;
  Uri? _initial;

  void setInitial(Uri? uri) => _initial = uri;
  void emit(Uri uri) => _controller.add(uri);

  @override
  Future<Uri?> get initialLink async => _initial;

  @override
  Stream<Uri> get loginLinks => _controller.stream;
}

Future<void> _pumpBroker(WidgetTester tester, _FakeDeepLinks service,
    GlobalKey<NavigatorState> navKey) async {
  final tracker = RouteNameTracker();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navKey,
    navigatorObservers: [tracker],
    onGenerateRoute: (settings) =>
        settings.name == DeepLinkService.loginRouteName
            ? MaterialPageRoute(
                settings: settings, builder: (_) => const LoginScreen())
            : null,
    builder: (context, child) => AppDeepLinkBroker(
      service: service,
      navKey: navKey,
      routeTracker: tracker,
      child: child,
    ),
    home: const Scaffold(body: Text('home')),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('DeepLinkService.isLoginLink', () {
    test('accepts invoizrider://login', () {
      expect(DeepLinkService.isLoginLink(Uri.parse('invoizrider://login')),
          isTrue);
    });

    test('rejects other schemes, hosts and null', () {
      expect(DeepLinkService.isLoginLink(Uri.parse('https://login')), isFalse);
      expect(DeepLinkService.isLoginLink(Uri.parse('invoizrider://other')),
          isFalse);
      expect(DeepLinkService.isLoginLink(null), isFalse);
    });
  });

  group('AppDeepLinkBroker', () {
    testWidgets('cold-start initial link opens the login screen',
        (tester) async {
      final service = _FakeDeepLinks()
        ..setInitial(Uri.parse('invoizrider://login'));
      final navKey = GlobalKey<NavigatorState>();
      await _pumpBroker(tester, service, navKey);

      expect(find.text('Rider Login'), findsOneWidget);
    });

    testWidgets('a live link while running opens the login screen',
        (tester) async {
      final service = _FakeDeepLinks();
      final navKey = GlobalKey<NavigatorState>();
      await _pumpBroker(tester, service, navKey);
      expect(find.text('home'), findsOneWidget);

      service.emit(Uri.parse('invoizrider://login'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Rider Login'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('links with other hosts are ignored', (tester) async {
      final service = _FakeDeepLinks()
        ..setInitial(Uri.parse('invoizrider://other'));
      final navKey = GlobalKey<NavigatorState>();
      await _pumpBroker(tester, service, navKey);

      expect(find.text('home'), findsOneWidget);
      expect(find.text('Rider Login'), findsNothing);
    });

    testWidgets('repeated links do not stack duplicate logins', (tester) async {
      final service = _FakeDeepLinks();
      final navKey = GlobalKey<NavigatorState>();
      await _pumpBroker(tester, service, navKey);

      service.emit(Uri.parse('invoizrider://login'));
      await tester.pumpAndSettle();
      expect(find.text('Rider Login'), findsOneWidget);

      // Second link while the login screen is already on top: no new route.
      final routesBefore = navKey.currentState!.widget.pages;
      service.emit(Uri.parse('invoizrider://login'));
      await tester.pumpAndSettle();
      expect(navKey.currentState!.widget.pages, same(routesBefore));
      expect(find.text('Rider Login'), findsOneWidget);
    });
  });

  group('platform wiring', () {
    test('Android manifest declares the invoizrider://login intent filter',
        () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:scheme="invoizrider"'));
      expect(manifest, contains('android:host="login"'));
      expect(manifest, contains('android.intent.action.VIEW'));
    });

    test('pubspec depends on app_links', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('app_links:'));
    });
  });
}
