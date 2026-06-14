import 'package:flutter/material.dart';

import '../../core/utils/money_formatter.dart';
import '../../core/widgets/admin_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/repositories/trip_repository.dart';

class TripsMonitoringPage extends StatelessWidget {
  const TripsMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: TripRepository().tripsStream(),
      builder: (context, snapshot) {
        final trips = snapshot.data ?? [];

        if (trips.isEmpty) {
          return const EmptyState(
            icon: Icons.route_outlined,
            title: 'No trips found',
            message: 'Active and completed trips will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Trips Monitoring',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            for (final trip in trips)
              AdminCard(
                child: ListTile(
                  leading: const Icon(Icons.local_taxi_outlined),
                  title: Text(
                    '${trip.pickupAddress} → ${trip.destinationAddress}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Passenger: ${trip.passengerName} • Driver: ${trip.driverName} • Fare: ${MoneyFormatter.kina(trip.fare)}',
                  ),
                  trailing: StatusChip(status: trip.status),
                ),
              ),
          ],
        );
      },
    );
  }
}