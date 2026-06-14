import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/widgets/metric_card.dart';
import '../../data/repositories/trip_repository.dart';

class ReportsLedgerPage extends StatelessWidget {
  const ReportsLedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: TripRepository().tripsStream(),
      builder: (context, snapshot) {
        final trips = snapshot.data ?? [];
        final totalFare = trips.fold<double>(0, (sum, trip) => sum + trip.fare);
        final commission = totalFare * 0.10;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Reports / Ledger',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'View fare totals, platform commission, and trip financial records.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  title: 'Total Fare Value',
                  value: 'K${totalFare.toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: AppColors.info,
                ),
                MetricCard(
                  title: 'Platform Commission',
                  value: 'K${commission.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
                MetricCard(
                  title: 'Completed Trips',
                  value: '${trips.where((t) => t.status == 'completed').length}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}