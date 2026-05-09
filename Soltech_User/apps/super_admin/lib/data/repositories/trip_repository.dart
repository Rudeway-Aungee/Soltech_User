import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/services/database_service.dart';
import '../models/trip_model.dart';

class TripRepository {
  final DatabaseService _database = DatabaseService();

  Stream<List<TripModel>> tripsStream() {
    return _database.stream(FirebasePaths.rideRequests).map((event) {
      return _tripsFromSnapshot(event.snapshot);
    });
  }

  List<TripModel> _tripsFromSnapshot(DataSnapshot snapshot) {
    if (snapshot.value is! Map) {
      return [];
    }

    final map = Map<Object?, Object?>.from(snapshot.value as Map);

    return map.entries.where((entry) => entry.value is Map).map((entry) {
      return TripModel.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
    }).toList();
  }
}