// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

import 'app_role.dart';
import 'app_user_profile.dart';

class RoleSession {
  const RoleSession({
    required this.uid,
    required this.activeRole,
    required this.availableRoles,
    required this.profile,
    this.activeFleetId,
  });

  final String uid;
  final AppRole activeRole;
  final Set<AppRole> availableRoles;
  final AppUserProfile? profile;
  final String? activeFleetId;
}
