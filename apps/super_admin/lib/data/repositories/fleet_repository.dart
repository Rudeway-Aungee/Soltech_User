import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/services/database_service.dart';
import '../models/fleet_application_model.dart';

class FleetRepository {
  final DatabaseService _database = DatabaseService();

  Stream<List<FleetApplicationModel>> fleetApplicationsStream() {
    return _database.stream(FirebasePaths.fleetApplications).map((event) {
      return _listFromSnapshot(event.snapshot);
    });
  }

  Stream<List<FleetApplicationModel>> applicationsByStatus(String status) {
    return fleetApplicationsStream().map((items) {
      return items.where((item) => item.status == status).toList();
    });
  }

  Future<void> approveFleet({
    required FleetApplicationModel application,
    required String adminUid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fleetId = application.fleetId;
    final ownerId = application.ownerId;

    final Map<String, Object?> updates = {
      '${FirebasePaths.fleetApplications}/$fleetId/status': 'approved',
      '${FirebasePaths.fleetApplications}/$fleetId/reviewedBy': adminUid,
      '${FirebasePaths.fleetApplications}/$fleetId/reviewedAt': now,
      '${FirebasePaths.fleetApplications}/$fleetId/rejectionReason': '',
      '${FirebasePaths.fleets}/$fleetId/status': 'active',
      '${FirebasePaths.fleets}/$fleetId/approvalStatus': 'approved',
      '${FirebasePaths.fleets}/$fleetId/approvedBy': adminUid,
      '${FirebasePaths.fleets}/$fleetId/approvedAt': now,
      '${FirebasePaths.fleets}/$fleetId/rejectionReason': '',
    };

    if (ownerId.isNotEmpty) {
      updates['${FirebasePaths.fleetOwners}/$ownerId/$fleetId/status'] =
          'active';
      updates['${FirebasePaths.fleetOwners}/$ownerId/$fleetId/updatedAt'] = now;
      updates['${FirebasePaths.users}/$ownerId/roles/fleetOwner'] = true;
      updates['${FirebasePaths.users}/$ownerId/defaultRole'] = 'fleetOwner';
      updates['${FirebasePaths.users}/$ownerId/fleetApprovalStatus'] = 'approved';
      updates['${FirebasePaths.users}/$ownerId/updatedAt'] = now;
    }

    await _database.update(updates);
  }

  Future<void> rejectFleet({
    required FleetApplicationModel application,
    required String adminUid,
    required String reason,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fleetId = application.fleetId;
    final ownerId = application.ownerId;

    final Map<String, Object?> updates = {
      '${FirebasePaths.fleetApplications}/$fleetId/status': 'rejected',
      '${FirebasePaths.fleetApplications}/$fleetId/reviewedBy': adminUid,
      '${FirebasePaths.fleetApplications}/$fleetId/reviewedAt': now,
      '${FirebasePaths.fleetApplications}/$fleetId/rejectionReason': reason,
      '${FirebasePaths.fleets}/$fleetId/status': 'rejected',
      '${FirebasePaths.fleets}/$fleetId/approvalStatus': 'rejected',
      '${FirebasePaths.fleets}/$fleetId/rejectionReason': reason,
    };

    if (ownerId.isNotEmpty) {
      updates['${FirebasePaths.fleetOwners}/$ownerId/$fleetId/status'] =
          'rejected';
      updates['${FirebasePaths.fleetOwners}/$ownerId/$fleetId/updatedAt'] = now;
      updates['${FirebasePaths.users}/$ownerId/fleetApprovalStatus'] =
          'rejected';
      updates['${FirebasePaths.users}/$ownerId/roles/fleetOwner'] = false;
      updates['${FirebasePaths.users}/$ownerId/updatedAt'] = now;
    }

    await _database.update(updates);
  }

  List<FleetApplicationModel> _listFromSnapshot(DataSnapshot snapshot) {
    if (snapshot.value is! Map) {
      return [];
    }

    final map = Map<Object?, Object?>.from(snapshot.value as Map);

    return map.entries.where((entry) => entry.value is Map).map((entry) {
      return FleetApplicationModel.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
    }).toList();
  }
}