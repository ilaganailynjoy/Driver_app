import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/geolocation.dart';
import '../../models/delivery.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/status_badge.dart';
import 'customer_delivery_screen.dart';
import 'failed_delivery_screen.dart';
import 'pickup_screen.dart';

/// Full delivery detail: shop, order items, customer and workflow actions.
class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.deliveryId});

  final int deliveryId;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().loadDetail(widget.deliveryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final delivery = provider.selected;

    if (provider.loading && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery')),
        body: const LoadingWidget(label: 'Loading delivery...'),
      );
    }

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery')),
        body: ErrorView(
          message: provider.error ?? 'Delivery not found.',
          onRetry: () =>
              provider.loadDetail(widget.deliveryId),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(delivery.trackingNumber),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE6E9EF), height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadDetail(widget.deliveryId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _StatusHeader(delivery: delivery),
            const SizedBox(height: 16),
            _ShopSection(delivery: delivery),
            const SizedBox(height: 16),
            _OrderSection(delivery: delivery),
            const SizedBox(height: 16),
            _CustomerSection(delivery: delivery),
            const SizedBox(height: 16),
            if (delivery.statusLogs.isNotEmpty)
              _TimelineSection(logs: delivery.statusLogs),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _ActionBar(
        delivery: delivery,
        busy: provider.actionBusy,
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 40, color: AppTheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    delivery.trackingNumber,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #${delivery.orderId ?? delivery.trackingNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: delivery.status, label: delivery.statusLabel),
          ],
        ),
      ),
    );
  }
}

class _ShopSection extends StatelessWidget {
  const _ShopSection({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final shop = delivery.shop;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.storefront_outlined,
              title: 'Shop Information',
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Shop', value: shop.name),
            if (shop.phone != null && shop.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Phone', value: shop.phone!),
            ],
            if (shop.address != null && shop.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Address', value: shop.address!),
            ],
            if (shop.latitude != null && shop.longitude != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Geolocation.openNavigation(
                      shop.latitude!, shop.longitude!),
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Navigate to Shop'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OrderSection extends StatelessWidget {
  const _OrderSection({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.receipt_long_outlined,
              title: 'Order Information',
            ),
            const SizedBox(height: 8),
            if (delivery.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No item details available.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
              )
            else
              ...delivery.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (item.variantLabel != null)
                              Text(
                                item.variantLabel!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text('x${item.quantity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 80,
                        child: Text(
                          FormatUtils.peso(item.subtotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 20),
            _TotalRow(label: 'Subtotal', value: delivery.subtotal),
            if (delivery.deliveryFee != null)
              _TotalRow(label: 'Delivery Fee', value: delivery.deliveryFee!),
            const SizedBox(height: 4),
            _TotalRow(label: 'Total', value: delivery.total, bold: true),
            const Divider(height: 20),
            _InfoRow(
              label: 'Payment',
              value: _paymentLabel(delivery.paymentMethod),
            ),
            if (delivery.isCashOnDelivery && delivery.amountToCollect != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _InfoRow(
                  label: 'Amount to Collect',
                  value: FormatUtils.peso(delivery.amountToCollect!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _paymentLabel(String? method) {
    switch (method) {
      case 'cash_on_delivery':
        return 'Cash on Delivery';
      case 'gcash':
        return 'GCash';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method ?? '—';
    }
  }
}

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.delivery});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final customer = delivery.customer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.person_outline,
              title: 'Customer Information',
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Customer', value: customer.name),
            if (customer.phone != null && customer.phone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Phone', value: customer.phone!),
            ],
            if (customer.address != null && customer.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Address', value: customer.address!),
            ],
            if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Instructions', value: delivery.notes!),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (customer.phone != null && customer.phone!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _call(customer.phone!, context),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                if (customer.latitude != null && customer.longitude != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Geolocation.openNavigation(
                          customer.latitude!, customer.longitude!),
                      icon: const Icon(Icons.navigation_outlined, size: 18),
                      label: const Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone, BuildContext context) async {
    final uri = Uri.parse('tel:$phone');
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the dialer.')),
      );
    }
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.logs});

  final List<StatusLog> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              icon: Icons.history,
              title: 'Status History',
            ),
            const SizedBox(height: 8),
            ...logs.map((log) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: StatusBadge.colorFor(log.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.status.toUpperCase().replaceAll('_', ' '),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (log.notes != null)
                            Text(
                              log.notes!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          Text(
                            FormatUtils.dateTime(log.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9AA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.delivery, required this.busy});

  final Delivery delivery;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isDone = const ['delivered', 'delivery_failed', 'cancelled']
        .contains(delivery.status);

    if (isDone) {
      return const SizedBox.shrink();
    }

    final action = _nextAction(delivery.status);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: ElevatedButton.icon(
          onPressed: busy
              ? null
              : () => _onAction(context),
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Icon(action.icon, size: 20),
          label: Text(busy ? 'Working...' : action.label),
        ),
      ),
    );
  }

  _Action _nextAction(String status) {
    switch (status) {
      case 'assigned':
        return _Action('Accept Delivery', Icons.check_circle_outline);
      case 'accepted':
      case 'going_to_pickup':
        return _Action('I Arrived at Shop', Icons.storefront_outlined);
      case 'arrived_at_shop':
        return _Action('Confirm Pickup', Icons.inventory_2_outlined);
      case 'picked_up':
        return _Action('Out for Delivery', Icons.delivery_dining_outlined);
      case 'out_for_delivery':
        return _Action('I Arrived at Customer', Icons.location_on_outlined);
      case 'arrived_at_customer':
        return _Action('Complete Delivery', Icons.check_circle_outline);
      default:
        return _Action('Next Step', Icons.arrow_forward);
    }
  }

  void _onAction(BuildContext context) {
    final provider = context.read<DeliveryProvider>();

    switch (delivery.status) {
      case 'assigned':
        _confirmThen(context,
            title: 'Accept this delivery?',
            message:
                'Once accepted, you are responsible for completing this delivery.',
            onConfirm: () async {
              final ok = await provider.accept(delivery.id);
              if (!context.mounted) return;
              if (ok) {
                provider.loadDetail(delivery.id);
                _snack(context, 'Delivery accepted.');
              } else {
                _snack(context, provider.error ?? 'Unable to accept.');
              }
            });
        break;
      case 'accepted':
      case 'going_to_pickup':
        _update(context, 'going_to_pickup', 'Heading to the shop...');
        break;
      case 'arrived_at_shop':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PickupScreen(deliveryId: delivery.id),
          ),
        );
        break;
      case 'picked_up':
        _update(context, 'out_for_delivery', 'Out for delivery.');
        break;
      case 'out_for_delivery':
        _update(context, 'arrived_at_customer', 'Arrived at the customer.');
        break;
      case 'arrived_at_customer':
        _showDeliveryChoices(context);
        break;
    }
  }

  void _update(BuildContext context, String status, String message) async {
    final provider = context.read<DeliveryProvider>();
    final ok = await provider.updateStatus(delivery.id, status);
    if (!context.mounted) return;
    if (ok) {
      provider.loadDetail(delivery.id);
      _snack(context, message);
    } else {
      _snack(context, provider.error ?? 'Unable to update delivery.');
    }
  }

  void _showDeliveryChoices(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle_outline,
                      color: AppTheme.success),
                  title: const Text('Complete Delivery'),
                  subtitle: const Text('Collect COD and provide proof.'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openProof(context);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.error_outline, color: AppTheme.danger),
                  title: const Text('Report Failed Delivery'),
                  subtitle: const Text('Customer unavailable or other issue.'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openFailed(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openProof(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDeliveryScreen(deliveryId: delivery.id),
      ),
    );
  }

  void _openFailed(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FailedDeliveryScreen(deliveryId: delivery.id),
      ),
    );
  }

  void _confirmThen(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B1F24),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? const Color(0xFF1B1F24) : const Color(0xFF6B7280),
            ),
          ),
          Text(
            FormatUtils.peso(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? AppTheme.primary : const Color(0xFF1B1F24),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action(this.label, this.icon);

  final String label;
  final IconData icon;
}