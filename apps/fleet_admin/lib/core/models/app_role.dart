// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

enum AppRole {
  passenger,
  driver,
  fleetOwner;

  String get key {
    switch (this) {
      case AppRole.passenger:
        return 'passenger';
      case AppRole.driver:
        return 'driver';
      case AppRole.fleetOwner:
        return 'fleetOwner';
    }
  }

  String get title {
    switch (this) {
      case AppRole.passenger:
        return 'Passenger';
      case AppRole.driver:
        return 'Driver';
      case AppRole.fleetOwner:
        return 'Fleet Owner';
    }
  }

  String get shortAction {
    switch (this) {
      case AppRole.passenger:
        return 'Book rides';
      case AppRole.driver:
        return 'Drive trips';
      case AppRole.fleetOwner:
        return 'Manage fleet';
    }
  }

  static AppRole? fromKey(String? value) {
    switch ((value ?? '').trim()) {
      case 'passenger':
        return AppRole.passenger;
      case 'driver':
        return AppRole.driver;
      case 'fleetOwner':
        return AppRole.fleetOwner;
      default:
        return null;
    }
  }
}
