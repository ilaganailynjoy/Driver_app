import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/delivery.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/rider_provider.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/delivery_card.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../deliveries/deliveries_screen.dart';
import '../deliveries/delivery_detail_screen.dart';

/// Rider dashboard: greeting, availability switch, stats, earnings,
/// current delivery and recent completions.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final riderProvider = context.watch<RiderProvider>();
    final deliveryProvider = context.watch<DeliveryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await riderProvider.loadDashboard();
          await deliveryProvider.load();
        },
        child: riderProvider.loading && riderProvider.dashboard == null
            ? const LoadingWidget(label: 'Loading dashboard...')
            : riderProvider.error != null && riderProvider.dashboard == null
                ? ErrorView(
                    message: riderProvider.error!,
                    onRetry: riderProvider.loadDashboard,
                  )
                : _buildContent(context, riderProvider, deliveryProvider),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RiderProvider riderProvider,
      DeliveryProvider deliveryProvider) {
    final dashboard = riderProvider.dashboard;
    final rider = dashboard?.rider ?? riderProvider.rider;

    if (rider == null) {
      return const LoadingWidget();
    }

    final firstName = rider.name.split(' ').first;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _Header(
          name: firstName,
          isOnline: rider.isOnline,
          busy: riderProvider.statusBusy,
          onToggle: () => riderProvider.toggleOnline(),
        ),
        const SizedBox(height: 20),
        const Text(
          "Today's Deliveries",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                label: 'Assigned',
                value: '${dashboard?.stats['assigned'] ?? 0}',
                icon: Icons.assignment_outlined,
                color: const Color(0xFF1D6FE0),
                onTap: () => _goToFiltered(context, 'new'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardCard(
                label: 'To Pick Up',
                value: '${dashboard?.stats['to_pick_up'] ?? 0}',
                icon: Icons.storefront_outlined,
                color: const Color(0xFFF29900),
                onTap: () => _goToFiltered(context, 'pickup'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                label: 'In Transit',
                value: '${dashboard?.stats['in_transit'] ?? 0}',
                icon: Icons.delivery_dining_outlined,
                color: const Color(0xFF8A4BDF),
                onTap: () => _goToFiltered(context, 'in_transit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardCard(
                label: 'Completed',
                value: '${dashboard?.stats['completed'] ?? 0}',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2A9D8F),
                onTap: () => _goToFiltered(context, 'delivered'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _EarningsBanner(amount: dashboard?.todayEarnings ?? 0),
        const SizedBox(height: 16),
        if (dashboard?.currentDelivery != null) ...[
          const Text(
            'Current Delivery',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DeliveryCard(
            delivery: dashboard!.currentDelivery!,
            onTap: () => _openDelivery(context, dashboard.currentDelivery!),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9AA3AF)),
          ),
          const SizedBox(height: 8),
        ],
        if (dashboard?.upcomingPickup != null) ...[
          const Text(
            'Upcoming Pickup',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DeliveryCard(
            delivery: dashboard!.upcomingPickup!,
            onTap: () => _openDelivery(context, dashboard.upcomingPickup!),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9AA3AF)),
          ),
          const SizedBox(height: 8),
        ],
        if (dashboard != null && dashboard.recentCompleted.isNotEmpty) ...[
          const Text(
            'Recent Completed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...dashboard.recentCompleted.take(3).map(
                (d) => DeliveryCard(
                  delivery: d,
                  onTap: () => _openDelivery(context, d),
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF9AA3AF)),
                ),
              ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _goToDeliveriesTab(context),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('View Deliveries'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _goToDeliveriesTab(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DeliveriesScreen()));
  }

  void _goToFiltered(BuildContext context, String filter) {
    final provider = context.read<DeliveryProvider>();
    provider.setFilter(filter);
    _goToDeliveriesTab(context);
  }

  void _openDelivery(BuildContext context, Delivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeliveryDetailScreen(deliveryId: delivery.id),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.isOnline,
    required this.busy,
    required this.onToggle,
  });

  final String name;
  final bool isOnline;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primary,
          child: Icon(Icons.person, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? AppTheme.success : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isOnline,
          onChanged: busy ? null : (_) => onToggle(),
          activeThumbColor: Colors.white,
          activeTrackColor: AppTheme.success,
        ),
      ],
    );
  }
}

class _EarningsBanner extends StatelessWidget {
  const _EarningsBanner({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Earnings",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            FormatUtils.peso(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep delivering to earn more!',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}