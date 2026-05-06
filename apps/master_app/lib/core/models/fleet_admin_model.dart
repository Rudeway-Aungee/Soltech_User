class FleetAdminProfile {
  const FleetAdminProfile({
    required this.id,
    required this.fleetAdminId,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fleetAdminId;
  final String name;
  final String email;
  final String phone;
  final String status;
  final int createdAt;
  final int updatedAt;

  bool get isActive => status == 'active';

  static FleetAdminProfile? fromSnapshotValue(String id, Object? value) {
    if (value is! Map) {
      return null;
    }

    final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
    return FleetAdminProfile(
      id: _stringFrom(raw['id'], fallback: id),
      fleetAdminId: _stringFrom(raw['fleetAdminId']),
      name: _stringFrom(raw['name']),
      email: _stringFrom(raw['email']),
      phone: _stringFrom(raw['phone']),
      status: _stringFrom(raw['status'], fallback: 'active'),
      createdAt: _intFrom(raw['createdAt']),
      updatedAt: _intFrom(raw['updatedAt']),
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
