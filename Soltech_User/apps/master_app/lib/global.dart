// CODE COMMENTS -------------------------------------------------------------
// Purpose: Stores shared app-wide helper objects, map key, and temporary global values used by older screens.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Shared global values used by older parts of the project.
// These are kept for compatibility with the existing pages and map helpers.
// In a larger production app, many of these values would be moved into services or session state.
// ---------------------------------------------------------------------------

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:soltech_master_app/core/services/associate_methods.dart';

AssociateMethods associateMethods = AssociateMethods();
String userName = '';
String userPhone = '';
String driverVehicleModel = '';
String driverVehicleColor = '';
String driverPlateNumber = '';
String driverApprovalStatus = '';
String driverOnlineStatus = 'offline';

// Keep this key aligned with the AndroidManifest/iOS native Google Maps key.
// Using different keys for the map SDK and Places/Geocoding web services can
// make the map render while reverse geocoding or place search returns no data.
const String googleMapKey = 'AIzaSyDYKPWe1fKnfFGlagylNlh9egoUOOj0EB0';

const CameraPosition kGooglePlex = CameraPosition(
  target: LatLng(-9.4431, 147.1803),
  zoom: 14.4746,
);
