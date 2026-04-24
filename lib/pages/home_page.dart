import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart' show Provider;
import 'package:soltech_app/global.dart';
import 'package:soltech_app/methods/google_map_methods.dart' show GoogleMapMethods;
import 'package:soltech_app/pages/select_destination_page.dart';

import '../appinfo/app_info.dart';
import '../auth/signin_page.dart';
import '../model/address_model.dart';
import 'account_tab.dart';
import 'activity_tab.dart';
import 'services_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> googleMapCompleterController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  MapType selectedMapType = MapType.normal;
  
  Set<Marker> homeMapMarkers = <Marker>{};
  Set<Polyline> homeMapPolylines = <Polyline>{};

  Position? currentPositionOfUser;
  double bottomMapPadding = 0;
  double searchContainerHeight = 360;

  int _selectedIndex = 0;
  bool isTripRouteConfirmed = false;
  bool isSearchingForTaxi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        bottomMapPadding = searchContainerHeight;
      });
    });
  }

  Future<void> getCurrentLocation() async {
    final Position userPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    );

    currentPositionOfUser = userPosition;
    final LatLng userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
    final CameraPosition positionCamera = CameraPosition(target: userLatLng, zoom: 14);

    controllerGoogleMap?.animateCamera(CameraUpdate.newCameraPosition(positionCamera));

    if (!mounted) return;

    await GoogleMapMethods.convertGeoGraphicCoOrdinatesIntoHumanReadableAddress(currentPositionOfUser!, context);
    await getUserInfoAndBlockStatus();
  }

  Future<void> getUserInfoAndBlockStatus() async {
    final DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users').child(FirebaseAuth.instance.currentUser!.uid);
    final DatabaseEvent dataSnap = await userRef.once();

    if (!mounted) return;

    final Object? userData = dataSnap.snapshot.value;

    if (userData != null) {
      final Map<Object?, Object?> userMap = userData as Map<Object?, Object?>;
      if (userMap['blockStatus'] == 'no') {
        setState(() {
          userName = (userMap['name'] ?? '').toString();
          userPhone = (userMap['phone'] ?? '').toString();
        });
      } else {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
        associateMethods.showSnackBarMsg('You are blocked, contact admin', context);
      }
    } else {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
    }
  }

  Future<void> _openDestinationSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectDestinationPage()),
    );

    if (!mounted || result != "route_confirmed") return;

    await _drawRouteOnMap();
  }

  Future<void> _drawRouteOnMap() async {
    final appInfo = Provider.of<AppInfo>(context, listen: false);
    final AddressModel? pickup = appInfo.userPickupLocation;
    final AddressModel? dropoff = appInfo.userDestinationLocation;
    final List<AddressModel> stops = appInfo.intermediateStops;

    if (pickup == null || dropoff == null || pickup.latitudePosition == null || dropoff.latitudePosition == null) return;

    setState(() {
      isTripRouteConfirmed = true;
      bottomMapPadding = 250;
      homeMapMarkers.clear();
      homeMapPolylines.clear();
    });

    List<LatLng> waypoints = stops.where((s) => s.latitudePosition != null && s.longitudePosition != null)
                                  .map((s) => LatLng(s.latitudePosition!, s.longitudePosition!))
                                  .toList();

    var directionDetails = await GoogleMapMethods.getDirectionDetails(
      LatLng(pickup.latitudePosition!, pickup.longitudePosition!),
      LatLng(dropoff.latitudePosition!, dropoff.longitudePosition!),
      waypoints,
    );

    if (directionDetails == null || directionDetails["routes"].isEmpty) return;

    List<LatLng> pLineCoordinates = GoogleMapMethods.decodePolyline(directionDetails["routes"][0]["overview_polyline"]["points"]);

    setState(() {
      Polyline polyline = Polyline(
        polylineId: const PolylineId("PolylineID"),
        color: Colors.blue,
        jointType: JointType.round,
        points: pLineCoordinates,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      );
      homeMapPolylines.add(polyline);

      // Add Markers
      homeMapMarkers.add(Marker(
        markerId: const MarkerId("pickupID"),
        position: LatLng(pickup.latitudePosition!, pickup.longitudePosition!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));

      homeMapMarkers.add(Marker(
        markerId: const MarkerId("dropoffID"),
        position: LatLng(dropoff.latitudePosition!, dropoff.longitudePosition!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

      for (int i = 0; i < waypoints.length; i++) {
        homeMapMarkers.add(Marker(
          markerId: MarkerId("waypointID_$i"),
          position: waypoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
      }
    });

    // Animate camera to fit route bounds
    LatLngBounds bounds;
    double minLat = pLineCoordinates[0].latitude;
    double maxLat = pLineCoordinates[0].latitude;
    double minLng = pLineCoordinates[0].longitude;
    double maxLng = pLineCoordinates[0].longitude;

    for (var point in pLineCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    controllerGoogleMap?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 65));
  }

  void _lookForAvailableTaxi() {
    setState(() {
      isSearchingForTaxi = true;
    });
    
    // Simulate searching
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isSearchingForTaxi = false;
        });
        associateMethods.showSnackBarMsg("No taxis available at the moment. Please try again.", context);
      }
    });
  }

  void _cancelRoute() {
    setState(() {
      isTripRouteConfirmed = false;
      homeMapMarkers.clear();
      homeMapPolylines.clear();
      bottomMapPadding = searchContainerHeight;
    });
    
    if (currentPositionOfUser != null) {
       controllerGoogleMap?.animateCamera(
         CameraUpdate.newCameraPosition(
           CameraPosition(target: LatLng(currentPositionOfUser!.latitude, currentPositionOfUser!.longitude), zoom: 14)
         )
       );
    }
  }

  String _buildLocationLabel(AddressModel? location, {required String emptyFallback}) {
    final String locationLabel = (location?.humanReadableAddress ?? location?.placeName ?? '').trim();
    if (locationLabel.isEmpty) return emptyFallback;
    return locationLabel.length <= 50 ? locationLabel : '${locationLabel.substring(0, 50)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: isTripRouteConfirmed ? null : BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Services'),
          BottomNavigationBarItem(icon: Icon(Icons.local_activity), label: 'Your Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Stack(
            children: [
              GoogleMap(
                padding: EdgeInsets.only(top: 26, bottom: bottomMapPadding),
                mapType: selectedMapType,
                myLocationEnabled: true,
                polylines: homeMapPolylines,
                markers: homeMapMarkers,
                initialCameraPosition: kGooglePlex,
                onMapCreated: (GoogleMapController mapController) {
                  controllerGoogleMap = mapController;
                  googleMapCompleterController.complete(mapController);
                  getCurrentLocation();
                },
              ),
              // Map type selector — always visible
              Positioned(
                top: 37,
                left: 20,
                child: PopupMenuButton<MapType>(
                  onSelected: (MapType mapType) {
                    setState(() {
                      selectedMapType = mapType;
                    });
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
                    const PopupMenuItem<MapType>(value: MapType.normal, child: Row(children: [Icon(Icons.map, color: Colors.black), SizedBox(width: 10), Text('Normal')])),
                    const PopupMenuItem<MapType>(value: MapType.satellite, child: Row(children: [Icon(Icons.satellite, color: Colors.black), SizedBox(width: 10), Text('Satellite')])),
                    const PopupMenuItem<MapType>(value: MapType.terrain, child: Row(children: [Icon(Icons.terrain, color: Colors.black), SizedBox(width: 10), Text('Terrain')])),
                    const PopupMenuItem<MapType>(value: MapType.hybrid, child: Row(children: [Icon(Icons.layers, color: Colors.black), SizedBox(width: 10), Text('Hybrid')])),
                  ],
                  child: Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 6, spreadRadius: 0.5, offset: Offset(0, 2))],
                    ),
                    child: const CircleAvatar(backgroundColor: Colors.white, radius: 20, child: Icon(Icons.layers_outlined, color: Colors.black)),
                  ),
                ),
              ),
              if (!isTripRouteConfirmed) ...[
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSize(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 122),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, -3))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                            const SizedBox(height: 20),
                            const Align(alignment: Alignment.centerLeft, child: Text('Where are you going?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87))),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.my_location, color: Colors.blue, size: 20),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Current Location', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                            Text(_buildLocationLabel(Provider.of<AppInfo>(context, listen: true).userPickupLocation, emptyFallback: 'Getting pickup location...'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(padding: EdgeInsets.only(left: 9.0), child: Align(alignment: Alignment.centerLeft, child: SizedBox(height: 24, child: VerticalDivider(color: Colors.grey, thickness: 1)))),
                                  GestureDetector(
                                    onTap: _openDestinationSelection,
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Destination', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                              Text(_buildLocationLabel(Provider.of<AppInfo>(context, listen: true).userDestinationLocation, emptyFallback: 'Search Destination Here'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _openDestinationSelection,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                                child: const Text('Search Destination', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Positioned(
                  top: 50,
                  left: 20,
                  child: GestureDetector(
                    onTap: _cancelRoute,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1)]),
                      child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSize(
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 122),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, -3))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Trip Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              "${Provider.of<AppInfo>(context, listen: false).intermediateStops.length} stops + Final Destination",
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: isSearchingForTaxi ? null : _lookForAvailableTaxi,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isSearchingForTaxi 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('Look for Available Taxi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const ServicesTab(),
          const ActivityTab(),
          const AccountTab(),
        ],
      ),
    );
  }
}
