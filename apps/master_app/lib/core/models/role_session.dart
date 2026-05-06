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
