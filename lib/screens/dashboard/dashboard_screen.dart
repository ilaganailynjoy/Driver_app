import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/delivery.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/rider_provider.dart';
import '../../services/rider_service.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/delivery_card.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../deliveries/deliveries_screen.dart';
import '../deliveries/delivery_detail_screen.dart';
import '../earnings/earnings_screen.dart';

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

  Widget _buildContent(
    BuildContext context,
    RiderProvider riderProvider,
    DeliveryProvider deliveryProvider,
  ) {
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
                color: AppColors.secondary,
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
                color: AppColors.success,
                onTap: () => _goToFiltered(context, 'delivered'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_isEmptyDashboard(dashboard)) ...[
          const _NoActiveDeliveries(),
          const SizedBox(height: 16),
        ],
        _EarningsBanner(
          amount: dashboard?.todayEarnings ?? 0,
          onTap: () => _openEarnings(context),
        ),
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
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
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
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (dashboard != null && dashboard.recentCompleted.isNotEmpty) ...[
          const Text(
            'Recent Completed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...dashboard.recentCompleted
              .take(3)
              .map(
                (d) => DeliveryCard(
                  delivery: d,
                  onTap: () => _openDelivery(context, d),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
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

  bool _isEmptyDashboard(DashboardSummary? dashboard) {
    if (dashboard == null) return false;
    final stats = dashboard.stats;
    final anyStats = [
      'assigned',
      'to_pick_up',
      'in_transit',
      'completed',
    ].any((k) => (stats[k] ?? 0) > 0);
    return !anyStats &&
        dashboard.currentDelivery == null &&
        dashboard.upcomingPickup == null &&
        dashboard.recentCompleted.isEmpty;
  }

  void _goToDeliveriesTab(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeliveriesScreen()));
  }

  void _openEarnings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EarningsScreen()));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  const SizedBox(height: 4),
                  _StatusPill(isOnline: isOnline),
                ],
              ),
            ),
            Semantics(
              label: busy
                  ? 'Updating availability'
                  : (isOnline ? 'Go offline' : 'Go online'),
              child: Switch(
                value: isOnline,
                onChanged: busy ? null : (_) => onToggle(),
                activeThumbColor: Colors.white,
                activeTrackColor: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            isOnline
                ? 'Available for new assignments'
                : 'Not taking new assignments — you can still finish current deliveries',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Explicit online/offline indicator: icon + text + color, so status is never
/// communicated by color alone. Broadcasts to screen readers on change.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final online = isOnline;
    return Semantics(
      liveRegion: true,
      label: online ? 'You are online' : 'You are offline',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (online ? AppTheme.success : AppColors.textSecondary)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              online ? Icons.power_outlined : Icons.power_off_outlined,
              size: 14,
              color: online ? AppTheme.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              online ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: online ? AppTheme.success : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly card shown when there is nothing to deliver right now.
class _NoActiveDeliveries extends StatelessWidget {
  const _NoActiveDeliveries();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active deliveries',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'New assignments will appear here.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsBanner extends StatelessWidget {
  const _EarningsBanner({required this.amount, this.onTap});

  final double amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
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
                      'Tap to view your earnings & delivery history',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
