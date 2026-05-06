import 'package:flutter/material.dart';

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data to represent user activities
    final List<RideActivity> activities = [
      RideActivity(
        driverName: 'John Doe',
        carType: 'Toyota Camry (Soltech Go)',
        rating: 4.8,
        date: 'Oct 24, 2026 - 10:30 AM',
        pickupAddress: '123 Main St, New York',
        dropoffAddress: '456 Market St, New York',
        price: '\$15.50',
      ),
      RideActivity(
        driverName: 'Sarah Smith',
        carType: 'Honda Accord (Soltech Premium)',
        rating: 5.0,
        date: 'Oct 23, 2026 - 5:15 PM',
        pickupAddress: 'JFK Airport',
        dropoffAddress: 'Times Square',
        price: '\$45.00',
      ),
      RideActivity(
        driverName: 'Michael Brown',
        carType: 'Nissan Altima (Soltech Go)',
        rating: 4.5,
        date: 'Oct 20, 2026 - 8:00 AM',
        pickupAddress: 'Brooklyn Navy Yard',
        dropoffAddress: 'Wall Street',
        price: '\$22.30',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Your Activity', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Date and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activity.date,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        activity.price,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1),
                  // Locations
                  Row(
                    children: [
                      const Icon(Icons.circle, size: 12, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activity.pickupAddress,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 5.0),
                    child: SizedBox(
                      height: 20,
                      child: VerticalDivider(color: Colors.grey, thickness: 1),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activity.dropoffAddress,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Driver Info & Rating
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.black12,
                          child: Icon(Icons.person, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.driverName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activity.carType,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.yellow[700]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.yellow[700]),
                              const SizedBox(width: 4),
                              Text(
                                activity.rating.toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
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
      ),
    );
  }
}

class RideActivity {
  final String driverName;
  final String carType;
  final double rating;
  final String date;
  final String pickupAddress;
  final String dropoffAddress;
  final String price;

  RideActivity({
    required this.driverName,
    required this.carType,
    required this.rating,
    required this.date,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.price,
  });
}
