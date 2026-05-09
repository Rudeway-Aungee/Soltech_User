// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

import 'app_role.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.blockStatus,
    required this.roles,
    this.defaultRole,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String blockStatus;
  final Set<AppRole> roles;
  final AppRole? defaultRole;

  bool get isBlocked => blockStatus != 'no';

  bool hasRole(AppRole role) => roles.contains(role);

  static AppUserProfile? fromSnapshotValue(String id, Object? value) {
    if (value is! Map) {
      return null;
    }

    final Map<Object?, Object?> raw = Map<Object?, Object?>.from(value);
    final Set<AppRole> parsedRoles = <AppRole>{};
    final Object? rolesValue = raw['roles'];

    if (rolesValue is Map) {
      final Map<Object?, Object?> roleMap = Map<Object?, Object?>.from(
        rolesValue,
      );
      roleMap.forEach((Object? key, Object? value) {
        final AppRole? role = AppRole.fromKey(key?.toString());
        if (role != null && value == true) {
          parsedRoles.add(role);
        }
      });
    }

    if (parsedRoles.isEmpty && raw.containsKey('name')) {
      parsedRoles.add(AppRole.passenger);
    }

    return AppUserProfile(
      id: _stringFrom(raw['id'], fallback: id),
      name: _stringFrom(raw['name']),
      phone: _stringFrom(raw['phone']),
      email: _stringFrom(raw['email']),
      blockStatus: _stringFrom(raw['blockStatus'], fallback: 'no'),
      roles: parsedRoles,
      defaultRole: AppRole.fromKey(raw['defaultRole']?.toString()),
    );
  }

  static String _stringFrom(Object? value, {String fallback = ''}) {
    final String parsed = (value ?? '').toString().trim();
    if (parsed.isEmpty || parsed == 'null') {
      return fallback;
    }

    return parsed;
  }
}
