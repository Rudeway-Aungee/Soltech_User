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
