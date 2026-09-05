import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/earnings_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/rider_provider.dart';
import '../../services/location_service.dart';
import '../auth/login_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../deliveries/deliveries_screen.dart';
import '../messages/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

/// Bottom-navigation shell for the rider app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  Timer? _locationTimer;

  static const _screens = [
    DashboardScreen(),
    DeliveriesScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _preload();
    _startLocationHeartbeat();
    _redirectOnLogout();
  }

  void _redirectOnLogout() {
    context.read<AuthProvider>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (auth.status == AuthStatus.unauthenticated && mounted) {
      Navigator.of(
        context,
      ).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    _locationTimer?.cancel();
    super.dispose();
  }

  void _preload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RiderProvider>().loadDashboard();
      context.read<DeliveryProvider>().load();
      context.read<NotificationProvider>().load();
      context.read<EarningsProvider>().loadSummary();
      context.read<AuthProvider>().clearError();
    });
  }

  void _startLocationHeartbeat() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: AppConstants.locationUpdateInterval), (_) async {
      if (!mounted) return;
      final rider = context.read<RiderProvider>();
      if (!rider.isOnline) return;
      try {
        final auth = context.read<AuthProvider>();
        final svc = LocationService(auth.api);
        int? deliveryId;
        try {
          deliveryId = context.read<DeliveryProvider>().selected?.id;
        } catch (_) {}
        await svc.report(deliveryId: deliveryId);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoiz Rider'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (_, p, _) => Stack(
              children: [
                IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                if (p.unread > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                      child: Text('${p.unread}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 1) context.read<DeliveryProvider>().load();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Deliveries',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}