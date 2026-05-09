class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.roles,
    required this.fleetApprovalStatus,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final Map<String, bool> roles;
  final String fleetApprovalStatus;

  factory UserModel.fromMap(String id, Map<Object?, Object?> map) {
    String text(String key, [String fallback = '']) {
      return (map[key] ?? fallback).toString();
    }

    Map<String, bool> readRoles() {
      final Object? rawRoles = map['roles'];

      if (rawRoles is! Map) {
        return <String, bool>{};
      }

      final Map<Object?, Object?> roleMap = Map<Object?, Object?>.from(rawRoles);
      final Map<String, bool> result = <String, bool>{};

      for (final MapEntry<Object?, Object?> entry in roleMap.entries) {
        result[entry.key.toString()] = entry.value == true;
      }

      return result;
    }

    return UserModel(
      id: id,
      name: text(
        'name',
        text(
          'fullName',
          text(
            'ownerName',
            text('driverName', 'Unnamed User'),
          ),
        ),
      ),
      email: text('email'),
      phone: text('phone'),
      role: text(
        'role',
        text(
          'defaultRole',
          text('accountType', 'user'),
        ),
      ).toLowerCase(),
      status: text('status', 'active').toLowerCase(),
      roles: readRoles(),
      fleetApprovalStatus: text('fleetApprovalStatus').toLowerCase(),
    );
  }

  bool hasRole(String key) {
    return roles[key] == true;
  }

  bool get isPassenger {
    return role.contains('passenger') || hasRole('passenger');
  }

  bool get isDriver {
    return role.contains('driver') || hasRole('driver');
  }

  bool get isFleetAdmin {
    return role.contains('fleet') ||
        role.contains('fleetowner') ||
        role.contains('fleet_admin') ||
        role.contains('fleetadmin') ||
        hasRole('fleetOwner') ||
        hasRole('fleetAdmin');
  }

  bool get isSuperAdmin {
    return role.contains('super') || hasRole('superAdmin');
  }

  String get displayRole {
    if (isSuperAdmin) {
      return 'Super Admin';
    }

    if (isFleetAdmin) {
      return 'Fleet Admin';
    }

    if (isDriver) {
      return 'Driver';
    }

    if (isPassenger) {
      return 'Passenger';
    }

    return role.isEmpty ? 'User' : role;
  }
}
