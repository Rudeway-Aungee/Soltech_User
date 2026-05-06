import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:soltech_app/methods/associate_methods.dart';

AssociateMethods associateMethods = AssociateMethods();
String userName = '';
String userPhone = '';

// Keep this key aligned with the AndroidManifest/iOS native Google Maps key.
// Using different keys for the map SDK and Places/Geocoding web services can
// make the map render while reverse geocoding or place search returns no data.
const String googleMapKey = 'AIzaSyDYKPWe1fKnfFGlagylNlh9egoUOOj0EB0';

const CameraPosition kGooglePlex = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);
