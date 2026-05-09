// CODE COMMENTS -------------------------------------------------------------
// Purpose: Creates driver accounts for Fleet Control without logging out the Fleet Admin.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// DriverManagementService contains Fleet Control logic for creating driver accounts.
// It uses a secondary Firebase app instance so creating a driver does not log out the Fleet Admin.
// Driver accounts are created by Fleet Control only; drivers do not self-register.
// ---------------------------------------------------------------------------

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../firebase_options.dart';
import '../utils/id_generator.dart';

// Service class used by Fleet Control to create driver accounts safely.
class DriverManagementService {
  static final DriverManagementService _instance = DriverManagementService._internal();

  factory DriverManagementService() {
    return _instance;
  }

  DriverManagementService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<Map<String, String>> addDriverToFleet({
    required String fleetId,
    required String driverName,
    required String email,
    required String phone,
    required String vehicleModel,
    required String vehicleColor,
    required String plateNumber,
    String licenseNumber = '',
    String vehicleId = '',
  }) async {
    final String driverId = IdGenerator.generateDriverId();
    final String tempPassword = _generateTempPassword();
    final int now = DateTime.now().millisecondsSinceEpoch;

    // Important: use a secondary Firebase app for creating driver Auth users.
    // Otherwise FirebaseAuth.instance switches from the Fleet Owner to the new
    // Driver account, which forces the Fleet Owner to log in again.
    final FirebaseApp secondaryApp = await _createSecondaryApp();
    final FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: tempPassword,
      );
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Unable to create driver account.');
      }

      await _database.ref('users/${user.uid}').set(<String, dynamic>{
        'id': user.uid,
        'name': driverName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'blockStatus': 'no',
        'roles': <String, bool>{'driver': true},
        'defaultRole': 'driver',
        'createdAt': now,
        'updatedAt': now,
      });

      await _database.ref('drivers/${user.uid}').set(<String, dynamic>{
        'id': user.uid,
        'name': driverName.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'licenseNumber': licenseNumber.trim(),
        'vehicleModel': vehicleModel.trim(),
        'vehicleColor': vehicleColor.trim(),
        'plateNumber': plateNumber.trim().toUpperCase(),
        'serviceType': 'taxi',
        'blockStatus': 'no',
        'approvalStatus': 'approved',
        'onlineStatus': 'offline',
        'fleetId': fleetId,
        'vehicleId': vehicleId,
        'createdByFleetOwner': true,
        'createdAt': now,
        'updatedAt': now,
      });

      await _database.ref('driverCredentials/$driverId').set(<String, dynamic>{
        'driverId': driverId,
        'email': email.trim(),
        'uid': user.uid,
        'fleetId': fleetId,
        'vehicleId': vehicleId,
        'driverName': driverName.trim(),
        'phone': phone.trim(),
        'status': 'active',
        'createdAt': now,
        'updatedAt': now,
      });

      await _database.ref('fleetDrivers/$fleetId/${user.uid}').set(<String, dynamic>{
        'driverId': user.uid,
        'externalDriverId': driverId,
        'fleetId': fleetId,
        'vehicleId': vehicleId,
        'approvalStatus': 'approved',
        'blockStatus': 'no',
        'createdAt': now,
        'updatedAt': now,
      });

      await secondaryAuth.signOut();

      return {
        'driverId': driverId,
        'password': tempPassword,
        'uid': user.uid,
      };
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  Future<void> removeDriverFromFleet({
    required String fleetId,
    required String uid,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;

    await _database.ref('fleetDrivers/$fleetId/$uid').remove();
    await _database.ref('drivers/$uid').update(<String, dynamic>{
      'fleetId': '',
      'updatedAt': now,
    });
  }

  Future<FirebaseApp> _createSecondaryApp() async {
    final String appName = 'driver-creator-${DateTime.now().microsecondsSinceEpoch}';
    return Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  String _generateTempPassword() {
    return 'TempPass${DateTime.now().millisecondsSinceEpoch % 10000}';
  }
}
