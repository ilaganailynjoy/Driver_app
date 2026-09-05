import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment-aware application configuration.
///
/// - `development`: points at the local Laravel server.
///   * Android emulator: `http://10.0.2.2:8000/api`
///   * Physical phone (USB): `http://192.168.1.22:8000/api`
///   * Desktop / web: `http://localhost:8000/api`
class AppConfig {
  AppConfig._();

  /// The environment: `development`, `testing` or `production`.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  /// LAN IP of this PC — used by physical phones connected via USB or Wi-Fi.
  /// If the PC gets a different DHCP address, update this (or pass
  /// `API_BASE_URL` via dart-define at build time).
  static const String lanHost = 'http://192.168.1.17:8000/api';

  /// Base URL used while running locally (override via dart-define).
  static const String devHost = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.17:8000/api',
  );

  /// Base URL for a production Laravel deployment.
  static const String prodHost = String.fromEnvironment(
    'API_PRODUCTION_URL',
    defaultValue: 'https://api.invoize.example/api',
  );

  /// The resolved API base URL.
  static String get apiBaseUrl {
    if (kIsWeb) return 'http://localhost:8000/api';
    if (Platform.isAndroid) {
      if (environment == 'production') return prodHost;
      // For physical devices: the dart-define overrides the default.
      // Default devHost is the emulator address; physical devices use LAN IP.
      return devHost;
    }
    // iOS simulator, Windows, Linux, macOS
    return environment == 'production'
        ? prodHost
        : 'http://localhost:8000/api';
  }

  /// Convenience getter for the physical-device LAN address.
  /// Use this when running on a real phone via USB or Wi-Fi.
  static String get physicalDeviceUrl => lanHost;
}
