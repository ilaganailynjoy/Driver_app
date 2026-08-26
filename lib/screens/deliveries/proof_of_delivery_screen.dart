import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/geolocation.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Proof of delivery: photo + customer verification + COD settlement.
class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({super.key, required this.deliveryId});

  final int deliveryId;

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();

  Uint8List? _photoBytes;
  String? _photoName;
  bool _collectingGps = false;

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
    _amountController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 70,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoName = image.name;
    });
  }

  double? _getReceived() {
    if (_amountController.text.trim().isEmpty) return null;
    return double.tryParse(_amountController.text.trim());
  }

  Future<void> _submit() async {
    final provider = context.read<DeliveryProvider>();
    final delivery = provider.selected;
    if (delivery == null) return;

    // COD: amount received is required and must not be negative.
    double? received;
    if (delivery.isCashOnDelivery) {
      received = _getReceived();
      if (received == null) {
        _snack('Please enter the amount received from the customer.');
        return;
      }
      if (received < 0) {
        _snack('Amount received cannot be negative.');
        return;
      }
    }

    final signatureName =
        _nameController.text.trim().isEmpty ? delivery.customer.name : _nameController.text.trim();

    setState(() => _collectingGps = true);
    final pos = await Geolocation.currentPosition();
    setState(() => _collectingGps = false);

    final ok = await provider.complete(
      delivery.id,
      proofType: _photoBytes != null
          ? 'photo'
          : (_otpController.text.trim().isNotEmpty ? 'otp' : 'signature'),
      photoBytes: _photoBytes,
      photoFilename: _photoName,
      signatureName: _otpController.text.trim().isNotEmpty ? null : signatureName,
      otp: _otpController.text.trim().isEmpty ? null : _otpController.text.trim(),
      amountReceived: received,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
    );

    if (!mounted) return;

    if (ok) {
      _snack('Delivery completed. Thank you!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _snack(provider.error ?? 'Unable to complete the delivery.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final delivery = provider.selected;

    if (provider.loading && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proof of Delivery')),
        body: const LoadingWidget(),
      );
    }

    if (delivery == null || delivery.id != widget.deliveryId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proof of Delivery')),
        body: ErrorView(
          message: provider.error ?? 'Unable to load the delivery.',
          onRetry: () => provider.loadDetail(widget.deliveryId),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (delivery.isCashOnDelivery) ...[
            _Section(
              title: 'Cash on Delivery',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount to Collect',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        FormatUtils.peso(delivery.amountToCollect ?? 0),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received',
                      prefixText: '₱ ',
                      hintText: '0.00',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _ChangeRow(amountToCollect: delivery.amountToCollect ?? 0, received: _getReceived()),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _Section(
            title: 'Delivery Photo',
            child: Column(
              children: [
                if (_photoBytes == null)
                  OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take Photo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_photoBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake Photo'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Customer Verification',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Customer name (signature)',
                    hintText: delivery.customer.name,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Customer OTP (optional)',
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ElevatedButton.icon(
            onPressed: (provider.actionBusy || _collectingGps)
                ? null
                : _submit,
            icon: provider.actionBusy || _collectingGps
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(provider.actionBusy
                ? 'Submitting...'
                : _collectingGps
                    ? 'Getting location...'
                    : 'Complete Delivery'),
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.amountToCollect, required this.received});

  final double amountToCollect;
  final double? received;

  @override
  Widget build(BuildContext context) {
    if (received == null) {
      return const SizedBox.shrink();
    }

    final change = received! - amountToCollect;
    final color = change < 0 ? AppTheme.danger : AppTheme.success;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Change',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        Text(
          FormatUtils.peso(change),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}