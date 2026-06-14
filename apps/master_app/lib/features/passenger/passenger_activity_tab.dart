// CODE COMMENTS -------------------------------------------------------------
// Purpose: Shows passenger ride history from Firebase instead of dummy text.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Passenger activity/history tab.
// It reads completed ride history from Firebase and shows past trips, fares, payment method,
// driver details, vehicle details, and route information.
// ---------------------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_master_app/core/models/ride_request_model.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  List<RideRequestModel> _buildTrips(Object? snapshotValue) {
    if (snapshotValue is! Map) {
      return <RideRequestModel>[];
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(snapshotValue);
    final List<RideRequestModel> rides = <RideRequestModel>[];

    rawMap.forEach((Object? key, Object? value) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(key.toString(), value);
      if (ride == null) return;
      if (ride.status == 'completed' || ride.status == 'cancelled') {
        rides.add(ride);
      }
    });

    rides.sort((RideRequestModel a, RideRequestModel b) {
      final int aTime = a.completedAt ?? a.cancelledAt ?? a.createdAt;
      final int bTime = b.completedAt ?? b.cancelledAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return rides;
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Unknown time';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    const List<String> months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final int hour12 = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour12:$minute $period';
  }

  String _locationLabel(RideRequestModel ride, bool pickup) {
    final location = pickup ? ride.pickup : ride.destination;
    return location.humanReadableAddress ?? location.placeName ?? (pickup ? 'Pickup' : 'Destination');
  }

  String _driverName(RideRequestModel ride) {
    final String name = (ride.assignedDriver['name'] ?? '').toString().trim();
    return name.isEmpty ? 'Driver not available' : name;
  }

  String _vehicleLabel(RideRequestModel ride) {
    final String color = (ride.assignedDriver['vehicleColor'] ?? '').toString().trim();
    final String model = (ride.assignedDriver['vehicleModel'] ?? '').toString().trim();
    final String plate = (ride.assignedDriver['plateNumber'] ?? '').toString().trim();
    final List<String> parts = <String>[color, model, plate].where((String item) => item.isNotEmpty).toList();
    return parts.isEmpty ? ride.serviceType : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Sign in to view your activity.')));
    }

    final Query rideHistoryQuery = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .orderByChild('passengerId')
        .equalTo(currentUser.uid);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Your Activity', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

          final List<RideRequestModel> rides = _buildTrips(snapshot.data?.snapshot.value);

          if (rides.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No completed trips yet. Your completed rides and receipts will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            itemBuilder: (BuildContext context, int index) {
              final RideRequestModel ride = rides[index];
              final bool completed = ride.status == 'completed';
              final int timestamp = ride.completedAt ?? ride.cancelledAt ?? ride.createdAt;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: completed ? const Color(0xFFF6FAF2) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _formatTimestamp(timestamp),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          Text(
                            completed ? 'K${ride.fareEstimate.toStringAsFixed(2)}' : 'Cancelled',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: completed ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1),
                      _locationRow(Icons.circle, Colors.blue, _locationLabel(ride, true), size: 12),
                      const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: SizedBox(height: 20, child: VerticalDivider(color: Colors.grey, thickness: 1)),
                      ),
                      _locationRow(Icons.location_on, Colors.red, _locationLabel(ride, false), size: 16),
                      if (ride.stops.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          'Stops: ${ride.stops.length}',
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(child: _infoChip(Icons.route, '${(ride.routeMeters / 1000).toStringAsFixed(1)} km')),
                          const SizedBox(width: 8),
                          Expanded(child: _infoChip(Icons.payments_outlined, ride.paymentMethod.toUpperCase())),
                          const SizedBox(width: 8),
                          Expanded(child: _infoChip(Icons.local_taxi, ride.serviceType)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: <Widget>[
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.black12,
                              child: Icon(Icons.person, color: Colors.black54),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(_driverName(ride), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(_vehicleLabel(ride), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: completed ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                completed ? 'Receipt' : 'Cancelled',
                                style: TextStyle(
                                  color: completed ? Colors.green[800] : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String text, {double size = 16}) {
    return Row(
      children: <Widget>[
        Icon(icon, size: size, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
