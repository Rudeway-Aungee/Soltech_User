import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/widgets/admin_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/fleet_application_model.dart';
import '../../data/repositories/fleet_repository.dart';
import 'fleet_review_page.dart';

class PendingFleetApplicationsPage extends StatelessWidget {
  const PendingFleetApplicationsPage({
    super.key,
    required this.adminUid,
  });

  final String adminUid;

  @override
  Widget build(BuildContext context) {
    final repository = FleetRepository();

    return StreamBuilder<List<FleetApplicationModel>>(
      stream: repository.applicationsByStatus('pending'),
      builder: (context, snapshot) {
        final applications = snapshot.data ?? [];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (applications.isEmpty) {
          return const EmptyState(
            icon: Icons.pending_actions,
            title: 'No pending fleet applications',
            message: 'New fleet admin registrations will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Pending Fleet Applications',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Review fleet owners and approve or reject their applications.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            for (final application in applications)
              AdminCard(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAF7EF),
                    child: Icon(Icons.business_outlined, color: AppColors.primary),
                  ),
                  title: Text(
                    application.fleetName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${application.ownerName} • ${application.email} • ${application.phone}',
                  ),
                  trailing: Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusChip(status: application.status),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FleetReviewPage(
                                application: application,
                                adminUid: adminUid,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Review'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}