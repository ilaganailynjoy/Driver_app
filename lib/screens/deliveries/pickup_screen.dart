import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Shop pickup screen: verify items, enter pickup PIN if required, confirm.
class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key, required this.deliveryId});

  final int deliveryId;

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeliveryProvider>();
      if (provider.selected?.id != widget.deliveryId) {
        provider.loadDetail(widget.deliveryId);
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _confirmPickup() async {
    final provider = context.read<DeliveryProvider>();
    final delivery = provider.selected;
    if (delivery == null) return;

    String? pin;
    if (delivery.pickupPinRequired) {
      pin = _pinController.text.trim();
      if (pin.length != 4) {
        _snack('Please enter the 4-digit pickup PIN.');
        return;
      }
    }

    final ok = await provider.pickup(delivery.id, pickupPin: pin);

    if (!mounted) return;

    if (ok) {
      _snack('Pickup confirmed. Proceed with the delivery.');
      Navigator.of(context).pop();
    } else {
      _snack(provider.error ?? 'Unable to confirm pickup.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final delivery = provider.selected;

    if (provider.loading && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shop Pickup')),
        body: const LoadingWidget(),
      );
    }

    if (delivery == null || delivery.id != widget.deliveryId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shop Pickup')),
        body: ErrorView(
          message: provider.error ?? 'Unable to load the delivery.',
          onRetry: () => provider.loadDetail(widget.deliveryId),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Pickup'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delivery.trackingNumber,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    delivery.shop.name,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Items to Pick Up',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: delivery.items.isEmpty
                    ? const [
                        Text(
                          'No items listed.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ]
                    : delivery.items
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: AppTheme.success, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${item.name} x${item.quantity}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    FormatUtils.peso(item.subtotal),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
              ),
            ),
          ),
          if (delivery.pickupPinRequired) ...[
            const SizedBox(height: 20),
            const Text(
              'Pickup Verification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter the pickup PIN provided by the shop.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 12),
              decoration: const InputDecoration(
                hintText: '0000',
                counterText: '',
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ElevatedButton.icon(
            onPressed: provider.actionBusy ? null : _confirmPickup,
            icon: provider.actionBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.inventory_2_outlined),
            label: Text(provider.actionBusy ? 'Confirming...' : 'Confirm Pickup'),
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}