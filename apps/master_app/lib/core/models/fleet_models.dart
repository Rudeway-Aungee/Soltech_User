// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

class FleetProfile {
  const FleetProfile({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.phone,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final String phone;
  final String email;
  final String status;
  final int createdAt;
  final int updatedAt;

  bool get isActive => status == 'active';

  static FleetProfile? fromSnapshotValue(String id, Object? value) {
    if (value is! Map) {
      return null;
    }

    final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
    return FleetProfile(
      id: _stringFrom(raw['id'], fallback: id),
      name: _stringFrom(raw['name']),
      ownerId: _stringFrom(raw['ownerId']),
      phone: _stringFrom(raw['phone']),
      email: _stringFrom(raw['email']),
      status: _stringFrom(raw['status'], fallback: 'active'),
      createdAt: _intFrom(raw['createdAt']),
      updatedAt: _intFrom(raw['updatedAt']),
    );
  }
}

class FleetVehicle {
  const FleetVehicle({
    required this.id,
    required this.fleetId,
    required this.make,
    required this.model,
    required this.color,
    required this.plateNumber,
    required this.serviceType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fleetId;
  final String make;
  final String model;
  final String color;
  final String plateNumber;
  final String serviceType;
  final String status;
  final int createdAt;
  final int updatedAt;

  String get displayName => '$color $make $model'.trim();

  static FleetVehicle? fromSnapshotValue(
    String id,
    String fleetId,
    Object? value,
  ) {
    if (value is! Map) {
      return null;
    }

    final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
    return FleetVehicle(
      id: _stringFrom(raw['id'], fallback: id),
      fleetId: _stringFrom(raw['fleetId'], fallback: fleetId),
      make: _stringFrom(raw['make']),
      model: _stringFrom(raw['model']),
      color: _stringFrom(raw['color']),
      plateNumber: _stringFrom(raw['plateNumber']),
      serviceType: _stringFrom(raw['serviceType'], fallback: 'taxi'),
      status: _stringFrom(raw['status'], fallback: 'active'),
      createdAt: _intFrom(raw['createdAt']),
      updatedAt: _intFrom(raw['updatedAt']),
    );
  }
}

class FleetInvite {
  const FleetInvite({
    required this.code,
    required this.fleetId,
    required this.vehicleId,
    required this.email,
    required this.phone,
    required this.status,
    required this.claimedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String code;
  final String fleetId;
  final String vehicleId;
  final String email;
  final String phone;
  final String status;
  final String claimedBy;
  final int createdAt;
  final int updatedAt;

  bool get isPending => status == 'pending';

  static FleetInvite? fromSnapshotValue(String code, Object? value) {
    if (value is! Map) {
      return null;
    }

    final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
    return FleetInvite(
      code: _stringFrom(raw['code'], fallback: code),
      fleetId: _stringFrom(raw['fleetId']),
      vehicleId: _stringFrom(raw['vehicleId']),
      email: _stringFrom(raw['email']),
      phone: _stringFrom(raw['phone']),
      status: _stringFrom(raw['status'], fallback: 'pending'),
      claimedBy: _stringFrom(raw['claimedBy']),
      createdAt: _intFrom(raw['createdAt']),
      updatedAt: _intFrom(raw['updatedAt']),
    );
  }
}

class FleetDriverLink {
  const FleetDriverLink({
    required this.driverId,
    required this.fleetId,
    required this.vehicleId,
    required this.approvalStatus,
    required this.blockStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String driverId;
  final String fleetId;
  final String vehicleId;
  final String approvalStatus;
  final String blockStatus;
  final int createdAt;
  final int updatedAt;

  static FleetDriverLink? fromSnapshotValue(
    String driverId,
    String fleetId,
    Object? value,
  ) {
    if (value is! Map) {
      return null;
    }

    final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
    return FleetDriverLink(
      driverId: _stringFrom(raw['driverId'], fallback: driverId),
      fleetId: _stringFrom(raw['fleetId'], fallback: fleetId),
      vehicleId: _stringFrom(raw['vehicleId']),
      approvalStatus: _stringFrom(
        raw['approvalStatus'],
        fallback: 'pending',
      ),
      blockStatus: _stringFrom(raw['blockStatus'], fallback: 'no'),
      createdAt: _intFrom(raw['createdAt']),
      updatedAt: _intFrom(raw['updatedAt']),
    );
  }
}

String _stringFrom(Object? value, {String fallback = ''}) {
  final String parsed = (value ?? '').toString().trim();
  if (parsed.isEmpty || parsed == 'null') {
    return fallback;
  }

  return parsed;
}

int _intFrom(Object? value) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse((value ?? '').toString()) ?? 0;
}
