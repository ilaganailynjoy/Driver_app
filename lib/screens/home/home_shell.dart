import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/earnings_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/rider_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../deliveries/deliveries_screen.dart';
import '../earnings/earnings_screen.dart';
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

  static const _screens = [
    DashboardScreen(),
    DeliveriesScreen(),
    EarningsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _preload();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 1) context.read<DeliveryProvider>().load();
          if (i == 3) context.read<NotificationProvider>().load();
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
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
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