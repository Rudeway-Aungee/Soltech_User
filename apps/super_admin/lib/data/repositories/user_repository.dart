import 'package:firebase_database/firebase_database.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/services/database_service.dart';
import '../models/driver_model.dart';
import '../models/user_model.dart';

class UserRepository {
  final DatabaseService _database = DatabaseService();

  Stream<List<UserModel>> usersStream() {
    return _database.stream(FirebasePaths.users).map((event) {
      return _usersFromSnapshot(event.snapshot);
    });
  }

  Stream<List<DriverModel>> driversStream() {
    return _database.stream(FirebasePaths.drivers).map((event) {
      return _driversFromSnapshot(event.snapshot);
    });
  }

  Stream<List<UserModel>> superAdminsStream() {
    return _database.stream(FirebasePaths.superAdmins).map((event) {
      return _usersFromSnapshot(event.snapshot);
    });
  }

  List<UserModel> _usersFromSnapshot(DataSnapshot snapshot) {
    if (snapshot.value is! Map) {
      return <UserModel>[];
    }

    final Map<Object?, Object?> map = Map<Object?, Object?>.from(snapshot.value as Map);

    return map.entries.where((entry) => entry.value is Map).map((entry) {
      return UserModel.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
    }).toList();
  }

  List<DriverModel> _driversFromSnapshot(DataSnapshot snapshot) {
    if (snapshot.value is! Map) {
      return <DriverModel>[];
    }

    final Map<Object?, Object?> map = Map<Object?, Object?>.from(snapshot.value as Map);

    return map.entries.where((entry) => entry.value is Map).map((entry) {
      return DriverModel.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
    }).toList();
  }
}
