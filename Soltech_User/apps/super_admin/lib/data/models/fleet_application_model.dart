class FleetApplicationModel {
  FleetApplicationModel({
    required this.id,
    required this.fleetId,
    required this.ownerId,
    required this.ownerName,
    required this.fleetName,
    required this.email,
    required this.phone,
    required this.status,
    required this.rejectionReason,
    required this.reviewedBy,
    required this.submittedAt,
  });

  final String id;
  final String fleetId;
  final String ownerId;
  final String ownerName;
  final String fleetName;
  final String email;
  final String phone;
  final String status;
  final String rejectionReason;
  final String reviewedBy;
  final int submittedAt;

  factory FleetApplicationModel.fromMap(String id, Map<Object?, Object?> map) {
    String text(String key, [String fallback = '']) {
      return (map[key] ?? fallback).toString();
    }

    int integer(String key) {
      return int.tryParse((map[key] ?? 0).toString()) ?? 0;
    }

    return FleetApplicationModel(
      id: id,
      fleetId: text('fleetId', id),
      ownerId: text('ownerId', text('ownerUid')),
      ownerName: text('ownerName'),
      fleetName: text('fleetName', text('name', 'Unnamed Fleet')),
      email: text('email'),
      phone: text('phone'),
      status: text('status', 'pending').toLowerCase(),
      rejectionReason: text('rejectionReason'),
      reviewedBy: text('reviewedBy'),
      submittedAt: integer('submittedAt'),
    );
  }
}