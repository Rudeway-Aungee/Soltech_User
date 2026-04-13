import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:soltech_app/methods/associate_methods.dart';

AssociateMethods associateMethods = AssociateMethods();
String userName  = "";
String userPhone = "";

String googleMapKey = "AIzaSyDYKPWe1fKnfFGlagylNlh9egoUOOj0EB0"; //"""AIzaSyBRhgFGsnf_YvaL6-zq_hJevUrggKmuQHM";
const CameraPosition kGooglePlex = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);