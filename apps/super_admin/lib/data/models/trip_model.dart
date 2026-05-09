class TripModel {
  TripModel({
    required this.id,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.passengerName,
    required this.driverName,
    required this.status,
    required this.fare,
  });

  final String id;
  final String pickupAddress;
  final String destinationAddress;
  final String passengerName;
  final String driverName;
  final String status;
  final double fare;

  factory TripModel.fromMap(String id, Map<Object?, Object?> map) {
    String text(String key, [String fallback = '']) {
      return (map[key] ?? fallback).toString();
    }

    double number(String key) {
      return double.tryParse((map[key] ?? 0).toString()) ?? 0;
    }

    return TripModel(
      id: id,
      pickupAddress: text('pickupAddress', 'Pickup'),
      destinationAddress: text('destinationAddress', 'Destination'),
      passengerName: text('passengerName'),
      driverName: text('driverName'),
      status: text('status', 'unknown').toLowerCase(),
      fare: number('fareAmount') == 0 ? number('fare') : number('fareAmount'),
    );
  }
}