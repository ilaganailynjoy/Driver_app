import 'package:flutter/material.dart';

/// Loading indicator with optional label.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }
}