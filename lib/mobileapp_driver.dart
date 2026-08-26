import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/earnings_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/rider_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/delivery_service.dart';
import 'services/earnings_service.dart';
import 'services/notification_service.dart';
import 'services/rider_service.dart';

void mainFromDriver() {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final storage = TokenStorage();
  final authProvider = AuthProvider(api: api, storage: storage);

  runApp(InvoizeRiderApp(authProvider: authProvider));
}

class InvoizeRiderApp extends StatelessWidget {
  const InvoizeRiderApp({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<RiderProvider>(
          create: (_) => RiderProvider(RiderService(authProvider.api)),
        ),
        ChangeNotifierProvider<DeliveryProvider>(
          create: (_) => DeliveryProvider(DeliveryService(authProvider.api)),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) =>
              NotificationProvider(NotificationService(authProvider.api)),
        ),
        ChangeNotifierProvider<EarningsProvider>(
          create: (_) =>
              EarningsProvider(EarningsService(authProvider.api)),
        ),
      ],
      child: MaterialApp(
        title: 'Invoize Rider',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AppGate(),
      ),
    );
  }
}

/// Routes to the splash, which restores the session and redirects.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
