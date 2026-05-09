import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final DatabaseReference root = FirebaseDatabase.instance.ref();

  DatabaseReference ref(String path) {
    return root.child(path);
  }

  Stream<DatabaseEvent> stream(String path) {
    return ref(path).onValue;
  }

  Future<DataSnapshot> get(String path) async {
    final event = await ref(path).once();
    return event.snapshot;
  }

  Future<void> update(Map<String, Object?> values) {
    return root.update(values);
  }

  Future<void> set(String path, Object? value) {
    return ref(path).set(value);
  }
}