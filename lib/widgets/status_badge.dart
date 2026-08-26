import 'package:flutter/material.dart';

/// Colored status badge for delivery statuses.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  static Color colorFor(String status) {
    switch (status) {
      case 'assigned':
      case 'new':
        return const Color(0xFF1D6FE0);
      case 'accepted':
      case 'going_to_pickup':
      case 'arrived_at_shop':
      case 'pickup':
        return const Color(0xFFF29900);
      case 'picked_up':
      case 'out_for_delivery':
      case 'arrived_at_customer':
      case 'in_transit':
        return const Color(0xFF8A4BDF);
      case 'delivered':
        return const Color(0xFF2A9D8F);
      case 'delivery_failed':
      case 'failed':
        return const Color(0xFFE63946);
      case 'cancelled':
        return const Color(0xFF6B7280);
      case 'waiting_for_rider':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = label ?? _defaultLabel(status);
    final color = colorFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _defaultLabel(String status) {
    switch (status) {
      case 'waiting_for_rider':
        return 'Waiting for Rider';
      case 'assigned':
        return 'New Assignment';
      case 'accepted':
        return 'Accepted';
      case 'going_to_pickup':
        return 'Going to Pickup';
      case 'arrived_at_shop':
        return 'Arrived at Shop';
      case 'picked_up':
        return 'Picked Up';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'arrived_at_customer':
        return 'Arrived at Customer';
      case 'delivered':
        return 'Delivered';
      case 'delivery_failed':
        return 'Delivery Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }
}