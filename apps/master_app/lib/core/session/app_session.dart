import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_role.dart';
import '../models/app_user_profile.dart';
import '../models/role_session.dart';

enum AppSessionStatus {
  loading,
  signedOut,
  ready,
  driverPending,
  fleetPending,
  unauthorized,
}

class AppSession extends ChangeNotifier {
  static const String _lastSelectedRoleKey = 'lastSelectedRole';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  AppSessionStatus status = AppSessionStatus.loading;
  AppRole? selectedRole;
  Set<AppRole> availableRoles = <AppRole>{};
  AppUserProfile? profile;
  RoleSession? roleSession;
  String? activeFleetId;
  String? message;
  String? driverApprovalStatus;
  String? fleetApprovalStatus;

  bool get isLoading => status == AppSessionStatus.loading;
  bool get isSignedOut => _auth.currentUser == null;
  User? get currentUser => _auth.currentUser;

  Future<void> bootstrap() async {
    status = AppSessionStatus.loading;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    selectedRole = AppRole.fromKey(prefs.getString(_lastSelectedRoleKey));
    await _refreshSession();
  }

  Future<void> selectRole(AppRole role) async {
    selectedRole = role;
    await _persistSelectedRole(role, syncDatabase: false);

    if (_auth.currentUser == null) {
      status = AppSessionStatus.signedOut;
      message = null;
      notifyListeners();
      return;
    }

    await validateSelectedRole();
  }

  Future<void> clearSelectedRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSelectedRoleKey);
    selectedRole = null;
    status = AppSessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> completeAuthentication(AppRole role) async {
    selectedRole = role;
    await _persistSelectedRole(role, syncDatabase: false);
    await validateSelectedRole();
  }

  Future<void> validateSelectedRole() async {
    status = AppSessionStatus.loading;
    notifyListeners();
    await _refreshSession(forceSelectedRole: selectedRole);
  }

  Future<bool> switchRole(AppRole role) async {
    if (selectedRole == AppRole.driver && role != AppRole.driver) {
      final bool hasActiveRide = await _driverHasActiveRide();
      if (hasActiveRide) {
        message = 'Complete the active trip before switching modes.';
        notifyListeners();
        return false;
      }

      await _setDriverOffline();
    }

    await selectRole(role);
    return true;
  }

  Future<void> signOut() async {
    if (selectedRole == AppRole.driver) {
      await _setDriverOffline();
    }

    await _auth.signOut();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSelectedRoleKey);
    selectedRole = null;
    profile = null;
    roleSession = null;
    availableRoles = <AppRole>{};
    activeFleetId = null;
    driverApprovalStatus = null;
    fleetApprovalStatus = null;
    status = AppSessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> _refreshSession({AppRole? forceSelectedRole}) async {
    final User? user = _auth.currentUser;
    message = null;
    driverApprovalStatus = null;
    fleetApprovalStatus = null;
    activeFleetId = null;
    roleSession = null;

    if (user == null) {
      availableRoles = <AppRole>{};
      profile = null;
      status = AppSessionStatus.signedOut;
      notifyListeners();
      return;
    }

    profile = await _loadUserProfile(user.uid);
    availableRoles = await _loadAvailableRoles(user.uid, profile);

    if (profile?.isBlocked == true) {
      await _auth.signOut();
      status = AppSessionStatus.unauthorized;
      message = 'This account is blocked.';
      notifyListeners();
      return;
    }

    AppRole? role = forceSelectedRole ?? selectedRole;
    if (forceSelectedRole != null &&
        !availableRoles.contains(forceSelectedRole)) {
      selectedRole = forceSelectedRole;
      status = AppSessionStatus.unauthorized;
      message = 'This account is not registered as a ${forceSelectedRole.title}.';
      notifyListeners();
      return;
    }

    if (role == null || !availableRoles.contains(role)) {
      final AppRole? defaultRole = profile?.defaultRole;
      if (defaultRole != null && availableRoles.contains(defaultRole)) {
        role = defaultRole;
      } else if (availableRoles.length == 1) {
        role = availableRoles.first;
      } else {
        selectedRole = null;
        status = AppSessionStatus.signedOut;
        notifyListeners();
        return;
      }
    }

    selectedRole = role;
    await _persistSelectedRole(role, syncDatabase: false);

    final bool canUseRole = await _validateRole(user.uid, role);
    if (!canUseRole) {
      notifyListeners();
      return;
    }

    await _persistSelectedRole(role);

    roleSession = RoleSession(
      uid: user.uid,
      activeRole: role,
      availableRoles: availableRoles,
      profile: profile,
      activeFleetId: activeFleetId,
    );
    status = AppSessionStatus.ready;
    notifyListeners();
  }

  Future<AppUserProfile?> _loadUserProfile(String uid) async {
    final DatabaseEvent event = await _database.ref('users/$uid').once();
    return AppUserProfile.fromSnapshotValue(uid, event.snapshot.value);
  }

  Future<Set<AppRole>> _loadAvailableRoles(
    String uid,
    AppUserProfile? userProfile,
  ) async {
    final Set<AppRole> roles = Set<AppRole>.from(
      userProfile?.roles ?? <AppRole>{},
    );

    final DatabaseEvent driverEvent = await _database.ref('drivers/$uid').once();
    if (driverEvent.snapshot.value is Map) {
      roles.add(AppRole.driver);
    }

    final DatabaseEvent ownerEvent = await _database
        .ref('fleetOwners/$uid')
        .once();
    if (ownerEvent.snapshot.value is Map) {
      final Map<Object?, Object?> ownerMap = Map<Object?, Object?>.from(
        ownerEvent.snapshot.value as Map,
      );
      for (final MapEntry<Object?, Object?> entry in ownerMap.entries) {
        if (entry.value is! Map) {
          continue;
        }

        final Map<Object?, Object?> membership = Map<Object?, Object?>.from(
          entry.value as Map,
        );
        final String membershipStatus = (membership['status'] ?? 'pending').toString();
        if (membershipStatus == 'active' ||
            membershipStatus == 'pending' ||
            membershipStatus == 'rejected') {
          roles.add(AppRole.fleetOwner);
          activeFleetId ??= entry.key.toString();
        }
      }
    }

    return roles;
  }

  Future<bool> _validateRole(String uid, AppRole role) async {
    switch (role) {
      case AppRole.passenger:
        if (!availableRoles.contains(AppRole.passenger)) {
          status = AppSessionStatus.unauthorized;
          message = 'This account is not registered as a passenger.';
          return false;
        }
        return true;
      case AppRole.driver:
        return _validateDriverRole(uid);
      case AppRole.fleetOwner:
        return _validateFleetOwnerRole(uid);
    }
  }

  Future<bool> _validateDriverRole(String uid) async {
    final DatabaseEvent event = await _database.ref('drivers/$uid').once();
    if (event.snapshot.value is! Map) {
      status = AppSessionStatus.unauthorized;
      message = 'This account is not registered as a driver.';
      return false;
    }

    final Map<Object?, Object?> driver = Map<Object?, Object?>.from(
      event.snapshot.value as Map,
    );
    if ((driver['blockStatus'] ?? 'no').toString() != 'no') {
      await _auth.signOut();
      status = AppSessionStatus.unauthorized;
      message = 'This driver account is blocked.';
      return false;
    }

    final String approvalStatus = (driver['approvalStatus'] ?? 'pending')
        .toString();
    if (approvalStatus != 'approved') {
      status = AppSessionStatus.driverPending;
      driverApprovalStatus = approvalStatus;
      return false;
    }

    return true;
  }

  Future<bool> _validateFleetOwnerRole(String uid) async {
    final DatabaseEvent event = await _database.ref('fleetOwners/$uid').once();
    if (event.snapshot.value is! Map) {
      status = AppSessionStatus.unauthorized;
      message = 'This account is not registered as a fleet owner.';
      return false;
    }

    final Map<Object?, Object?> ownerMap = Map<Object?, Object?>.from(
      event.snapshot.value as Map,
    );
    String? firstFleetId;
    String firstStatus = 'pending';

    for (final MapEntry<Object?, Object?> entry in ownerMap.entries) {
      if (entry.value is! Map) {
        continue;
      }

      final Map<Object?, Object?> membership = Map<Object?, Object?>.from(
        entry.value as Map,
      );
      final String membershipStatus = (membership['status'] ?? 'pending').toString();
      firstFleetId ??= entry.key.toString();
      firstStatus = membershipStatus;

      if (membershipStatus == 'active') {
        activeFleetId = entry.key.toString();
        return true;
      }
    }

    if (firstFleetId != null) {
      activeFleetId = firstFleetId;
      fleetApprovalStatus = firstStatus;
      status = AppSessionStatus.fleetPending;
      message = firstStatus == 'rejected'
          ? 'Your Fleet Control application was rejected. Please update your documents and resubmit.'
          : 'Your Fleet Control application is waiting for Super Admin approval.';
      return false;
    }

    status = AppSessionStatus.unauthorized;
    message = 'No fleet was found for this owner account.';
    return false;
  }

  Future<void> _persistSelectedRole(
    AppRole role, {
    bool syncDatabase = true,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedRoleKey, role.key);

    final User? user = _auth.currentUser;
    if (user != null && syncDatabase) {
      await _database.ref('users/${user.uid}').update(<String, dynamic>{
        'defaultRole': role.key,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<bool> _driverHasActiveRide() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }

    final DatabaseEvent event = await _database
        .ref('rideRequests')
        .orderByChild('assignedDriverId')
        .equalTo(user.uid)
        .once();
    if (event.snapshot.value is! Map) {
      return false;
    }

    final Map<Object?, Object?> rides = Map<Object?, Object?>.from(
      event.snapshot.value as Map,
    );
    for (final Object? value in rides.values) {
      if (value is! Map) {
        continue;
      }

      final Map<Object?, Object?> ride = Map<Object?, Object?>.from(value);
      final String status = (ride['status'] ?? '').toString();
      if (status != 'completed' && status != 'cancelled') {
        return true;
      }
    }

    return false;
  }

  Future<void> _setDriverOffline() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    await _database.ref('drivers/${user.uid}').update(<String, dynamic>{
      'onlineStatus': 'offline',
      'updatedAt': now,
    });
    await _database.ref('onlineDrivers/${user.uid}').remove();
  }
}
