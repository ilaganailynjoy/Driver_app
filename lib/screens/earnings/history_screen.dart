import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../models/earning.dart';
import '../../providers/earnings_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Delivery history with search + status filter.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EarningsProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload(EarningsProvider provider) async {
    await provider.loadHistory(
      search: _searchController.text.trim(),
      status: _status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EarningsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _reload(provider),
              decoration: InputDecoration(
                hintText: 'Search by tracking no., shop, customer...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _reload(provider);
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _status == '',
                  onPressed: () {
                    setState(() => _status = '');
                    _reload(provider);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Delivered',
                  selected: _status == 'delivered',
                  onPressed: () {
                    setState(() => _status = 'delivered');
                    _reload(provider);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Failed',
                  selected: _status == 'failed',
                  onPressed: () {
                    setState(() => _status = 'failed');
                    _reload(provider);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _reload(provider),
              child: _buildList(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(EarningsProvider provider) {
    if (provider.historyLoading && provider.history.isEmpty) {
      return const LoadingWidget(label: 'Loading history...');
    }

    if (provider.error != null && provider.history.isEmpty) {
      return ErrorView(
        message: provider.error!,
        onRetry: () => _reload(provider),
      );
    }

    if (provider.history.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.history, size: 56, color: Color(0xFF9AA3AF)),
          SizedBox(height: 16),
          Text(
            'No delivery history',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: provider.history.length,
      itemBuilder: (context, index) {
        return _HistoryCard(entry: provider.history[index]);
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPressed(),
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF4B5563),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDelivered = entry.status == 'delivered';
    final color = isDelivered ? const Color(0xFF2A9D8F) : const Color(0xFFE63946);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.trackingNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.statusLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${entry.shopName} → ${entry.customerName}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
            const SizedBox(height: 4),
            Text(
              FormatUtils.dateTime(entry.deliveredAt),
              style: const TextStyle(fontSize: 12, color: Color(0xFF9AA3AF)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _paymentLabel(entry.paymentMethod),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
                if (entry.earned != null)
                  Text(
                    'Earned ${FormatUtils.peso(entry.earned!)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.primary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _paymentLabel(String? method) {
    switch (method) {
      case 'cash_on_delivery':
        return 'COD';
      case 'gcash':
        return 'GCash';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return method ?? '—';
    }
  }
}