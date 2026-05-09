import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/services/database_service.dart';
import '../models/complaint_model.dart';

class ComplaintRepository {
  final DatabaseService _database = DatabaseService();

  Stream<List<ComplaintModel>> complaintsStream() {
    return _database.stream(FirebasePaths.complaints).map((event) {
      return _complaintsFromSnapshot(event.snapshot);
    });
  }

  Future<void> markResolved(String complaintId) async {
    await _database.update({
      '${FirebasePaths.complaints}/$complaintId/status': 'resolved',
      '${FirebasePaths.complaints}/$complaintId/resolvedAt':
          DateTime.now().millisecondsSinceEpoch,
    });
  }

  List<ComplaintModel> _complaintsFromSnapshot(DataSnapshot snapshot) {
    if (snapshot.value is! Map) {
      return [];
    }

    final map = Map<Object?, Object?>.from(snapshot.value as Map);

    return map.entries.where((entry) => entry.value is Map).map((entry) {
      return ComplaintModel.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
    }).toList();
  }
}