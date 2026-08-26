import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Report a failed delivery with a reason + notes.
class FailedDeliveryScreen extends StatefulWidget {
  const FailedDeliveryScreen({super.key, required this.deliveryId});

  final int deliveryId;

  @override
  State<FailedDeliveryScreen> createState() => _FailedDeliveryScreenState();
}

class _FailedDeliveryScreenState extends State<FailedDeliveryScreen> {
  String? _reason;
  final _notesController = TextEditingController();

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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      _snack('Please select a failure reason.');
      return;
    }

    final provider = context.read<DeliveryProvider>();
    final ok = await provider.failed(
      widget.deliveryId,
      reason: _reason!,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      _snack('Failed delivery reported.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _snack(provider.error ?? 'Unable to report the failed delivery.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final delivery = provider.selected;

    if (provider.loading && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Failed Delivery')),
        body: const LoadingWidget(),
      );
    }

    if (delivery == null || delivery.id != widget.deliveryId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Failed Delivery')),
        body: ErrorView(
          message: provider.error ?? 'Unable to load the delivery.',
          onRetry: () => provider.loadDetail(widget.deliveryId),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Failed Delivery'),
        backgroundColor: AppTheme.danger,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      delivery.trackingNumber,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Why did the delivery fail?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: AppConstants.failureReasons
                    .map((reason) => RadioListTile<String>(
                          title: Text(reason),
                          value: reason,
                          dense: true,
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Add details about what happened...',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ElevatedButton.icon(
            onPressed: provider.actionBusy ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            icon: provider.actionBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.report_problem_outlined),
            label: Text(provider.actionBusy ? 'Submitting...' : 'Submit Failed Delivery'),
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}