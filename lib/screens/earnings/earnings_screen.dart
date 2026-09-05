import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/earnings_provider.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import 'history_screen.dart';

/// Rider earnings dashboard (daily / weekly / monthly).
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EarningsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadSummary,
        child: provider.loading && provider.summary == null
            ? const LoadingWidget(label: 'Loading earnings...')
            : provider.error != null && provider.summary == null
                ? ErrorView(
                    message: provider.error!,
                    onRetry: provider.loadSummary,
                  )
                : _buildContent(context, provider),
      ),
    );
  }

  Widget _buildContent(BuildContext context, EarningsProvider provider) {
    final summary = provider.summary;
    if (summary == null) return const LoadingWidget();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                FormatUtils.peso(summary.today),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DashboardCard(
                label: 'This Week',
                value: FormatUtils.peso(summary.thisWeek),
                icon: Icons.date_range_outlined,
                color: const Color(0xFF1D6FE0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardCard(
                label: 'This Month',
                value: FormatUtils.peso(summary.thisMonth),
                icon: Icons.calendar_month_outlined,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Last 30 Days',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HistoryScreen(),
                  ),
                );
              },
              child: const Text('View History'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (summary.history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No earnings recorded yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          ...summary.history.map((day) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.savings_outlined,
                      color: AppTheme.primary),
                ),
                title: Text(
                  FormatUtils.date(day.date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  day.deliveries == 1
                      ? '1 delivery'
                      : '${day.deliveries} deliveries',
                ),
                trailing: Text(
                  FormatUtils.peso(day.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}