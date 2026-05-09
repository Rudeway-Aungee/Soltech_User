import 'package:firebase_database/firebase_database.dart';

class AdminPermissionService {
  Future<bool> isActiveSuperAdmin(String uid) async {
    final ref = FirebaseDatabase.instance.ref();

    final event = await ref.child('superAdmins/$uid').once();
    if (event.snapshot.value is Map) {
      final data = Map<Object?, Object?>.from(event.snapshot.value as Map);
      return (data['status'] ?? '').toString() == 'active';
    }

    final userEvent = await ref.child('users/$uid').once();
    if (userEvent.snapshot.value is Map) {
      final data = Map<Object?, Object?>.from(userEvent.snapshot.value as Map);
      final roles = data['roles'];
      if (roles is Map && Map<Object?, Object?>.from(roles)['superAdmin'] == true) {
        return (data['blockStatus'] ?? 'no').toString() == 'no';
      }
    }

    return false;
  }
}
