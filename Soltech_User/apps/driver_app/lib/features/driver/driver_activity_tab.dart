// CODE COMMENTS -------------------------------------------------------------
// Purpose: Shows driver trip history and earnings from Firebase.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Driver activity and earnings tab.
// It shows completed/cancelled trips and calculates driver earnings from recorded Firebase trip data.
// ---------------------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_driver_app/core/models/ride_request_model.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  List<RideRequestModel> _buildTrips(Object? snapshotValue) {
    if (snapshotValue is! Map) {
      return <RideRequestModel>[];
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
      snapshotValue,
    );
    final List<RideRequestModel> rides = <RideRequestModel>[];

    rawMap.forEach((Object? key, Object? value) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(
        key.toString(),
        value,
      );

      if (ride == null) {
        return;
      }

      if (ride.status == 'completed' || ride.status == 'cancelled') {
        rides.add(ride);
      }
    });

    rides.sort((RideRequestModel a, RideRequestModel b) {
      final int aTimestamp = a.completedAt ?? a.cancelledAt ?? a.createdAt;
      final int bTimestamp = b.completedAt ?? b.cancelledAt ?? b.createdAt;
      return bTimestamp.compareTo(aTimestamp);
    });

    return rides;
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) {
      return 'Unknown time';
    }

    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
    ).toLocal();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view trip history.')),
      );
    }

    final Query rideHistoryQuery = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .orderByChild('assignedDriverId')
        .equalTo(currentUser.uid);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Trip History',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: rideHistoryQuery.onValue,
        builder: (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<RideRequestModel> rides = _buildTrips(
            snapshot.data?.snapshot.value,
          );

          final double totalEarnings = rides
              .where((RideRequestModel ride) => ride.status == 'completed')
              .fold<double>(
                0,
                (double total, RideRequestModel ride) =>
                    total + (ride.driverEarnings > 0 ? ride.driverEarnings : ride.fareEstimate),
              );
          final int completedTrips = rides
              .where((RideRequestModel ride) => ride.status == 'completed')
              .length;
          final int cancelledTrips = rides
              .where((RideRequestModel ride) => ride.status == 'cancelled')
              .length;

          if (rides.isEmpty) {
            return const Center(
              child: Text(
                'No completed or cancelled trips yet.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      title: 'Earnings',
                      value: 'K${totalEarnings.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      title: 'Completed',
                      value: completedTrips.toString(),
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _summaryCard(
                      title: 'Cancelled',
                      value: cancelledTrips.toString(),
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...rides.map((RideRequestModel ride) {
                final bool completed = ride.status == 'completed';
                final int timestamp =
                    ride.completedAt ?? ride.cancelledAt ?? ride.createdAt;

                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: completed
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                completed ? 'Completed' : 'Cancelled',
                                style: TextStyle(
                                  color: completed
                                      ? Colors.green[800]
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.my_location,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ride.pickup.humanReadableAddress ??
                                    ride.pickup.placeName ??
                                    'Pickup',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 7),
                          child: SizedBox(
                            height: 18,
                            child: VerticalDivider(
                              color: Colors.grey,
                              thickness: 1,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ride.destination.humanReadableAddress ??
                                    ride.destination.placeName ??
                                    'Destination',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${(ride.routeMeters / 1000).toStringAsFixed(1)} km • ${ride.paymentMethod.toUpperCase()} • ${ride.serviceType}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            Text(
                              completed
                                  ? 'K${(ride.driverEarnings > 0 ? ride.driverEarnings : ride.fareEstimate).toStringAsFixed(2)}'
                                  : 'No earnings',
                              style: TextStyle(
                                color: completed
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
