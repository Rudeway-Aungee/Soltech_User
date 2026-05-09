import 'package:flutter/material.dart';

import '../../core/widgets/admin_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/fleet_repository.dart';

class ApprovedFleetsPage extends StatelessWidget {
  const ApprovedFleetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FleetRepository().applicationsByStatus('approved'),
      builder: (context, snapshot) {
        final fleets = snapshot.data ?? [];

        if (fleets.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            title: 'No approved fleets',
            message: 'Approved fleet admins will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Approved Fleets',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            for (final fleet in fleets)
              AdminCard(
                child: ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(
                    fleet.fleetName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('${fleet.ownerName} • ${fleet.email}'),
                  trailing: StatusChip(status: fleet.status),
                ),
              ),
          ],
        );
      },
    );
  }
}