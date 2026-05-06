// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

class DriverProfileModel {
  DriverProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.plateNumber,
    required this.serviceType,
    required this.blockStatus,
    required this.approvalStatus,
    required this.onlineStatus,
    required this.createdAt,
    required this.updatedAt,
    this.fleetId = '',
    this.vehicleId = '',
    this.inviteCode = '',
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String vehicleModel;
  final String vehicleColor;
  final String plateNumber;
  final String serviceType;
  final String blockStatus;
  final String approvalStatus;
  final String onlineStatus;
  final int createdAt;
  final int updatedAt;
  final String fleetId;
  final String vehicleId;
  final String inviteCode;

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isBlocked => blockStatus != 'no';

  static DriverProfileModel? fromSnapshotValue(
    String id,
    Object? snapshotValue,
  ) {
    if (snapshotValue is! Map) {
      return null;
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
      snapshotValue,
    );

    return DriverProfileModel(
      id: _stringFrom(rawMap['id'], fallback: id),
      name: _stringFrom(rawMap['name']),
      phone: _stringFrom(rawMap['phone']),
      email: _stringFrom(rawMap['email']),
      vehicleModel: _stringFrom(rawMap['vehicleModel']),
      vehicleColor: _stringFrom(rawMap['vehicleColor']),
      plateNumber: _stringFrom(rawMap['plateNumber']),
      serviceType: _stringFrom(rawMap['serviceType'], fallback: 'taxi'),
      blockStatus: _stringFrom(rawMap['blockStatus'], fallback: 'no'),
      approvalStatus: _stringFrom(
        rawMap['approvalStatus'],
        fallback: 'pending',
      ),
      onlineStatus: _stringFrom(rawMap['onlineStatus'], fallback: 'offline'),
      createdAt: _intFrom(rawMap['createdAt']),
      updatedAt: _intFrom(rawMap['updatedAt']),
      fleetId: _stringFrom(rawMap['fleetId']),
      vehicleId: _stringFrom(rawMap['vehicleId']),
      inviteCode: _stringFrom(rawMap['inviteCode']),
    );
  }

  static String _stringFrom(Object? value, {String fallback = ''}) {
    final String parsed = (value ?? '').toString().trim();
    if (parsed.isEmpty || parsed == 'null') {
      return fallback;
    }

    return parsed;
  }

  static int _intFrom(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
