// Async operations (Completer for map controller)
import 'dart:async';

// Flutter UI framewoimport 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Location services
import 'package:geolocator/geolocator.dart';

// Google Maps widget
import 'package:google_maps_flutter/google_maps_flutter.dart';

// State management (Provider)
import 'package:provider/provider.dart' show Provider;

// App-specific imports
import '../appinfo/app_info.dart';
import 'package:soltech_app/global.dart';
import 'package:soltech_app/methods/google_map_methods.dart' show GoogleMapMethods;

import '../auth/signin_page.dart';

/// Home page displaying map and location search UI
///
/// Shows:
/// - Google Map with user's current location
/// - Search container for pickup and destination addresses
/// - Real-time location updates via Geolocator
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Map controller for programmatic map control (zoom, pan, etc.)
  final Completer<GoogleMapController> googleMapCompleterController =
      Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;

  // User's current GPS position
  Position? currentPositionOfUser;

  // Padding at bottom of map to avoid overlapping with search container
  double bottomMapPadding = 0;

  // Height of the search container (pickup/destination UI)
  double searchContainerHeight = 276;
  GlobalKey<ScaffoldState> sKey = GlobalKey<ScaffoldState>();


  @override
  void initState() {
    super.initState();
    // IMPORTANT: Set bottomMapPadding after first frame so MediaQuery is available
    // This prevents map from being covered by the search container
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        bottomMapPadding = searchContainerHeight +
            MediaQuery.of(context).viewPadding.bottom;
      });
    });
  }

  /// Get user's current location and update map + address
  ///
  /// Flow:
  /// 1. Request current position from device GPS
  /// 2. Animate map camera to user location
  /// 3. Call reverse geocoding to get human-readable address
  void getCurrentLocation() async {
    try {
      // Request current GPS position with high accuracy
      Position userPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      currentPositionOfUser = userPosition;

      // Create LatLng from position
      LatLng userLatLng =
          LatLng(userPosition.latitude, userPosition.longitude);

      // Create camera position at user location
      CameraPosition positionCamera =
          CameraPosition(target: userLatLng, zoom: 14);

      // Animate map camera to user's location
      controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(positionCamera));


      // Call reverse geocoding to get address and update provider

      await GoogleMapMethods.convertGeoGraphicCoOrdinatesIntoHumanReadableAddress(currentPositionOfUser!, context);

      } catch (e) {
      if (kDebugMode) {
        print("\n\nError: \n$e\n\n");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get bottom navigation bar height to properly position UI elements
    final double navBarHeight = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      key: sKey,
      drawer: SizedBox(
          width: 256,
          child: Drawer(
            child: ListView(
              children: [
                //Header
                SizedBox(
                  height:  160,
                  child: DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Image.asset("assets/avatar.webp", height: 65.0, width: 65.0),

                        const SizedBox(width:16,),

                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("John Doe",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),),

                            SizedBox(height: 6,),

                            Text(
                                "Profile",
                              style:  TextStyle(
                                color: Colors.grey,
                              ),

                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                //Body of the drawer
                GestureDetector(
                  onTap: () {},
                  child: const ListTile(
                    leading: Icon(Icons.history, color: Colors.black,),
                    title: Text("History", style: TextStyle(fontSize: 16, color: Colors.grey),),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const ListTile(
                    leading: Icon(Icons.info, color: Colors.black,),
                    title: Text("About", style: TextStyle(fontSize: 16, color: Colors.grey),),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    FirebaseAuth.instance.signOut();

                    Navigator.push(context, MaterialPageRoute(builder: (c) => const SignInPage()));
                  },
                  child: const ListTile(
                    leading: Icon(Icons.logout, color: Colors.black,),
                    title: Text("Logout", style: TextStyle(fontSize: 16, color: Colors.grey),),
                  ),
                )
              ],
            ),
          )
      ),
      body: Stack(
        children: [
          // Google Maps display with user's current location
          GoogleMap(
            // Add padding to map bottom so search container doesn't cover it
            padding: EdgeInsets.only(top: 26, bottom: bottomMapPadding),
            mapType: MapType.normal,
            myLocationEnabled: true, // Show user location on map
            initialCameraPosition: kGooglePlex, // Default camera position (Google HQ)
            onMapCreated: (GoogleMapController mapController) {
              // Called when map is ready - store controller and get location
              controllerGoogleMap = mapController;
              googleMapCompleterController.complete(mapController);
              // Fetch user's current location after map loads
              getCurrentLocation();
            },
          ),

          //Drawer button
          Positioned(
            top: 37,
            left: 20,
            child: GestureDetector(
              onTap: () {
                sKey.currentState!.openDrawer();
              },
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow:  [
                    BoxShadow(
                      color: Colors.grey,
                      blurRadius: 6,
                      spreadRadius: 0.5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: Icon(
                    Icons.menu,
                    color: Colors.black,
                  ),
              ),
            ),
          ),
          ),

          // Search container for pickup and destination addresses
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSize(
              curve: Curves.easeInOut,
              duration: const Duration(milliseconds: 122),
              child: Container(
                // Extend container to cover nav bar area
                height: searchContainerHeight + navBarHeight,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(21),
                    topRight: Radius.circular(21),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 18,
                    // Push content above nav bar
                    bottom: 18 + navBarHeight,
                  ),
                  child: Column(
                    children: [
                      // === PICKUP LOCATION SECTION ===
                      Row(
                        children: [
                          const Icon(
                            Icons.add_location_alt_outlined,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 13),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "From ", style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              // Listen to AppInfo changes to display pickup location
                              // Using Provider.of with listen: true to rebuild on location change
                              Text(
                                Provider.of<AppInfo>(context, listen: true).userPickupLocation == null
                                    ? "pickup location null, please wait..."
                                    : "${(Provider.of<AppInfo>(context, listen: true).userPickupLocation!.placeName!).substring(0, 50)}...",
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Colors.grey),
                      const SizedBox(height: 16),

                      // === DESTINATION LOCATION SECTION ===
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 13),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "To ",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey),
                              ),
                              Text(
                                "Search Destination Here ",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Colors.grey),
                      const SizedBox(height: 16),

                      // === ACTION BUTTON ===
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          "Select Destination",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}