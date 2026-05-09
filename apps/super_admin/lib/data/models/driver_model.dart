class DriverModel {
  DriverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.fleetId,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String fleetId;
  final String status;

  factory DriverModel.fromMap(String id, Map<Object?, Object?> map) {
    String text(String key, [String fallback = '']) {
      return (map[key] ?? fallback).toString();
    }

    return DriverModel(
      id: id,
      name: text('name', text('driverName', 'Unnamed Driver')),
      email: text('email'),
      phone: text('phone'),
      fleetId: text('fleetId'),
      status: text('status', 'active'),
    );
  }
}