import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:soltech_driver_app/methods/associate_methods.dart';

AssociateMethods associateMethods = AssociateMethods();

String userName = '';
String userPhone = '';
String driverVehicleModel = '';
String driverVehicleColor = '';
String driverPlateNumber = '';
String driverApprovalStatus = '';
String driverOnlineStatus = 'offline';

const String googleMapKey = 'AIzaSyDYKPWe1fKnfFGlagylNlh9egoUOOj0EB0';

const CameraPosition kGooglePlex = CameraPosition(
  target: LatLng(-9.4431, 147.1803),
  zoom: 14.4746,
);
