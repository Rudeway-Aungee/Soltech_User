import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/widgets/metric_card.dart';
import '../../data/repositories/complaint_repository.dart';
import '../../data/repositories/fleet_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/repositories/user_repository.dart';

class DashboardOverviewPage extends StatelessWidget {
  const DashboardOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fleetRepository = FleetRepository();
    final userRepository = UserRepository();
    final tripRepository = TripRepository();
    final complaintRepository = ComplaintRepository();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Platform Overview',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Monitor approvals, users, trips, complaints, and platform activity.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        StreamBuilder(
          stream: fleetRepository.fleetApplicationsStream(),
          builder: (context, fleetSnapshot) {
            final fleets = fleetSnapshot.data ?? [];
            final pending = fleets.where((item) => item.status == 'pending').length;
            final approved = fleets.where((item) => item.status == 'approved').length;
            final rejected = fleets.where((item) => item.status == 'rejected').length;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  title: 'Pending Fleet Applications',
                  value: '$pending',
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                ),
                MetricCard(
                  title: 'Approved Fleets',
                  value: '$approved',
                  icon: Icons.verified_outlined,
                  color: AppColors.primary,
                ),
                MetricCard(
                  title: 'Rejected Fleets',
                  value: '$rejected',
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                ),
                StreamBuilder(
                  stream: userRepository.usersStream(),
                  builder: (context, usersSnapshot) {
                    final users = usersSnapshot.data ?? [];
                    final passengers = users.where((u) {
                      return u.isPassenger;
                    }).length;
                    final fleetAdmins = approved;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        MetricCard(
                          title: 'Total Passengers',
                          value: '$passengers',
                          icon: Icons.person_outline,
                          color: AppColors.info,
                        ),
                        MetricCard(
                          title: 'Approved Fleet Admins',
                          value: '$fleetAdmins',
                          icon: Icons.business_center_outlined,
                          color: AppColors.info,
                        ),
                      ],
                    );
                  },
                ),
                StreamBuilder(
                  stream: userRepository.driversStream(),
                  builder: (context, driverSnapshot) {
                    final drivers = driverSnapshot.data ?? [];

                    return MetricCard(
                      title: 'Total Drivers',
                      value: '${drivers.length}',
                      icon: Icons.drive_eta_outlined,
                      color: AppColors.primary,
                    );
                  },
                ),
                StreamBuilder(
                  stream: tripRepository.tripsStream(),
                  builder: (context, tripSnapshot) {
                    final trips = tripSnapshot.data ?? [];
                    final active = trips.where((t) {
                      return t.status == 'searching' ||
                          t.status == 'accepted' ||
                          t.status == 'arrived' ||
                          t.status == 'in_progress';
                    }).length;
                    final completed = trips.where((t) {
                      return t.status == 'completed';
                    }).length;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        MetricCard(
                          title: 'Active Trips',
                          value: '$active',
                          icon: Icons.route_outlined,
                          color: AppColors.warning,
                        ),
                        MetricCard(
                          title: 'Completed Trips',
                          value: '$completed',
                          icon: Icons.check_circle_outline,
                          color: AppColors.primary,
                        ),
                      ],
                    );
                  },
                ),
                StreamBuilder(
                  stream: complaintRepository.complaintsStream(),
                  builder: (context, complaintSnapshot) {
                    final complaints = complaintSnapshot.data ?? [];
                    final open = complaints.where((c) {
                      return c.status == 'open' || c.status == 'pending';
                    }).length;

                    return MetricCard(
                      title: 'Open Complaints / Disputes',
                      value: '$open',
                      icon: Icons.report_problem_outlined,
                      color: AppColors.danger,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}