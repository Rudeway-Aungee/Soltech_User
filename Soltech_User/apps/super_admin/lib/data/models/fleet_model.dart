class FleetModel {
  FleetModel({
    required this.id,
    required this.fleetName,
    required this.ownerId,
    required this.status,
    required this.approvalStatus,
    required this.email,
    required this.phone,
  });

  final String id;
  final String fleetName;
  final String ownerId;
  final String status;
  final String approvalStatus;
  final String email;
  final String phone;

  factory FleetModel.fromMap(String id, Map<Object?, Object?> map) {
    String text(String key, [String fallback = '']) {
      return (map[key] ?? fallback).toString();
    }

    return FleetModel(
      id: id,
      fleetName: text('fleetName', text('name', 'Unnamed Fleet')),
      ownerId: text('ownerId', text('ownerUid')),
      status: text('status'),
      approvalStatus: text('approvalStatus'),
      email: text('email'),
      phone: text('phone'),
    );
  }
}