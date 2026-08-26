import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/geolocation.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import 'proof_of_delivery_screen.dart';

/// Customer delivery screen: contact, navigate, COD collection, then proof.
class CustomerDeliveryScreen extends StatefulWidget {
  const CustomerDeliveryScreen({super.key, required this.deliveryId});

  final int deliveryId;

  @override
  State<CustomerDeliveryScreen> createState() => _CustomerDeliveryScreenState();
}

class _CustomerDeliveryScreenState extends State<CustomerDeliveryScreen> {
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
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final delivery = provider.selected;

    if (provider.loading && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Delivery')),
        body: const LoadingWidget(),
      );
    }

    if (delivery == null || delivery.id != widget.deliveryId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Delivery')),
        body: ErrorView(
          message: provider.error ?? 'Unable to load the delivery.',
          onRetry: () => provider.loadDetail(widget.deliveryId),
        ),
      );
    }

    final customer = delivery.customer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Delivery'),
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
                  Text(
                    customer.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  if (customer.phone != null &&
                      customer.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      customer.phone!,
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF4B5563)),
                    ),
                  ],
                  if (customer.address != null &&
                      customer.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      customer.address!,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF4B5563)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (customer.phone != null &&
                          customer.phone!.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _call(customer.phone!),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      if (customer.latitude != null &&
                          customer.longitude != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Geolocation.openNavigation(
                                customer.latitude!, customer.longitude!),
                            icon: const Icon(Icons.navigation_outlined),
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
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _labelRow(
                      'Payment', _paymentLabel(delivery.paymentMethod)),
                  const SizedBox(height: 8),
                  _labelRow(
                      'Order Total', FormatUtils.peso(delivery.total)),
                  if (delivery.isCashOnDelivery &&
                      delivery.amountToCollect != null) ...[
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount to Collect',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          FormatUtils.peso(delivery.amountToCollect!),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProofOfDeliveryScreen(deliveryId: delivery.id),
                ),
              );
            },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Proceed to Proof of Delivery'),
          ),
        ),
      ),
    );
  }

  Widget _labelRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
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

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the dialer.')),
      );
    }
  }
}