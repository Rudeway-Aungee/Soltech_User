// CODE COMMENTS -------------------------------------------------------------
// Purpose: Main passenger map and booking workflow: Get a Ride, route summary, booking, searching, and active ride tracking.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Passenger Home screen and main booking workflow.
// This screen shows the map, starts the Get a Ride process, confirms ride summaries,
// creates ride requests, listens for driver assignment, and displays live ride status.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart' show Provider;
import 'package:soltech_master_app/core/app_state/app_info.dart';
import 'package:soltech_master_app/core/session/app_session.dart';
import 'package:soltech_master_app/global.dart';
import 'package:soltech_master_app/core/services/google_map_methods.dart'
    show GoogleMapMethods;
import 'package:soltech_master_app/core/models/address_model.dart';
import 'package:soltech_master_app/core/models/ride_request_model.dart';
import 'package:soltech_master_app/features/passenger/passenger_destination_page.dart';

import 'package:soltech_master_app/features/passenger/passenger_account_tab.dart';
import 'package:soltech_master_app/features/passenger/passenger_activity_tab.dart';
import 'package:soltech_master_app/features/passenger/passenger_services_tab.dart';

enum PassengerBookingStage { overview, planning, routeSummary }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// This State class stores the live map, booking state, selected route, and active ride subscription.
class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> googleMapCompleterController =
      Completer<GoogleMapController>();

  GoogleMapController? controllerGoogleMap;
  Position? currentPositionOfUser;

  MapType selectedMapType = MapType.normal;
  Set<Marker> homeMapMarkers = <Marker>{};
  Set<Polyline> homeMapPolylines = <Polyline>{};
  Set<Marker> nearbyDriverMarkers = <Marker>{};

  PassengerBookingStage _bookingStage = PassengerBookingStage.overview;
  int _selectedIndex = 0;
  double bottomMapPadding = 260;

  RideRequestModel? _activeRideRequest;
  String? _lastObservedRideStatus;
  String _confirmedEncodedPolyline = '';
  int _confirmedRouteMeters = 0;
  int _confirmedRouteSeconds = 0;
  LatLng? _assignedDriverLatLng;
  Map<Object?, Object?>? _assignedDriverProfile;

  String _selectedServiceType = 'City Ride';
  String _selectedPaymentMethod = 'Cash';

  final Map<String, bool> _driverApprovalCache = <String, bool>{};
  StreamSubscription<DatabaseEvent>? _activeRideRequestSubscription;
  StreamSubscription<DatabaseEvent>? _driverLocationSubscription;
  StreamSubscription<DatabaseEvent>? _nearbyDriversSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        bottomMapPadding = _currentBottomSheetHeight;
      });
    });
  }

  @override
  void dispose() {
    _activeRideRequestSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _nearbyDriversSubscription?.cancel();
    super.dispose();
  }

  // Chooses how much bottom padding the Google Map needs depending on the current booking stage.
  double get _currentBottomSheetHeight {
    if (_activeRideRequest != null) {
      return 430;
    }

    switch (_bookingStage) {
      case PassengerBookingStage.overview:
        return 255;
      case PassengerBookingStage.planning:
        return 310;
      case PassengerBookingStage.routeSummary:
        return 430;
    }
  }

  bool get _showBackButton =>
      _bookingStage != PassengerBookingStage.overview || _activeRideRequest != null;

  bool get _hideBottomNav =>
      _selectedIndex == 0 &&
      (_bookingStage == PassengerBookingStage.routeSummary || _activeRideRequest != null);


  // Gets the passenger's current GPS position, moves the map camera there,
  // converts the coordinates into a readable address, and restores any active ride.
  // Step 1: Get the passenger current GPS position and store it as the pickup location.
  Future<void> getCurrentLocation() async {
    final Position userPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );

    currentPositionOfUser = userPosition;
    final LatLng userLatLng = LatLng(
      userPosition.latitude,
      userPosition.longitude,
    );
    final CameraPosition positionCamera = CameraPosition(
      target: userLatLng,
      zoom: 15,
    );

    controllerGoogleMap?.animateCamera(
      CameraUpdate.newCameraPosition(positionCamera),
    );

    if (!mounted) return;

    await GoogleMapMethods.convertGeoGraphicCoOrdinatesIntoHumanReadableAddress(
      currentPositionOfUser!,
      context,
    );
    await getUserInfoAndBlockStatus();
    _listenToNearbyAvailableDrivers();
    await _restoreActiveRideRequestIfNeeded();
  }

  Future<void> getUserInfoAndBlockStatus() async {
    final DatabaseReference userRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(FirebaseAuth.instance.currentUser!.uid);
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
        await Provider.of<AppSession>(context, listen: false).signOut();
        if (!mounted) return;
        associateMethods.showSnackBarMsg(
          'You are blocked, contact admin',
          context,
        );
      }
    } else {
      await Provider.of<AppSession>(context, listen: false).signOut();
    }
  }

  Future<void> _restoreActiveRideRequestIfNeeded() async {
    final DatabaseEvent event = await FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .orderByChild('passengerId')
        .equalTo(FirebaseAuth.instance.currentUser!.uid)
        .once();

    if (!mounted || event.snapshot.value == null) {
      return;
    }

    final Map<Object?, Object?> requests = Map<Object?, Object?>.from(
      event.snapshot.value as Map,
    );

    RideRequestModel? mostRecentActiveRide;

    requests.forEach((Object? key, Object? value) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(
        key.toString(),
        value,
      );

      if (ride == null || ride.isTerminal) {
        return;
      }

      if (mostRecentActiveRide == null ||
          ride.createdAt > mostRecentActiveRide!.createdAt) {
        mostRecentActiveRide = ride;
      }
    });

    if (mostRecentActiveRide != null) {
      _listenToRideRequest(mostRecentActiveRide!.id);
    }
  }

  void _listenToNearbyAvailableDrivers() {
    _nearbyDriversSubscription?.cancel();
    _nearbyDriversSubscription = FirebaseDatabase.instance
        .ref()
        .child('onlineDrivers')
        .onValue
        .listen((DatabaseEvent event) async {
          final Set<Marker> markers = <Marker>{};

          if (event.snapshot.value is Map) {
            final Map<Object?, Object?> rawDrivers =
                Map<Object?, Object?>.from(event.snapshot.value as Map);

            for (final MapEntry<Object?, Object?> entry in rawDrivers.entries) {
              final String driverId = (entry.key ?? '').toString();
              final Map<Object?, Object?> driverMap = entry.value is Map
                  ? Map<Object?, Object?>.from(entry.value as Map)
                  : <Object?, Object?>{};

              if (driverId.isEmpty) {
                continue;
              }

              final String availabilityStatus =
                  (driverMap['availabilityStatus'] ?? '').toString();
              final int updatedAt = _intFrom(driverMap['updatedAt']);
              final int ageMs = DateTime.now().millisecondsSinceEpoch - updatedAt;

              if (availabilityStatus != 'available' || ageMs > 20000) {
                continue;
              }

              final bool isApproved = await _isDriverApproved(driverId);
              if (!isApproved) {
                continue;
              }

              final double latitude = _doubleFrom(driverMap['latitude']);
              final double longitude = _doubleFrom(driverMap['longitude']);

              if (latitude == 0 && longitude == 0) {
                continue;
              }

              markers.add(
                Marker(
                  markerId: MarkerId('nearby_driver_$driverId'),
                  position: LatLng(latitude, longitude),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: const InfoWindow(
                    title: 'Available Driver',
                    snippet: 'Approved and online',
                  ),
                ),
              );
            }
          }

          if (!mounted) {
            return;
          }

          setState(() {
            nearbyDriverMarkers = markers;
          });
        });
  }

  Future<bool> _isDriverApproved(String driverId) async {
    if (_driverApprovalCache.containsKey(driverId)) {
      return _driverApprovalCache[driverId] ?? false;
    }

    final DatabaseEvent driverEvent = await FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(driverId)
        .once();

    bool approved = false;
    if (driverEvent.snapshot.value is Map) {
      final Map<Object?, Object?> driverMap = Map<Object?, Object?>.from(
        driverEvent.snapshot.value as Map,
      );
      final String approvalStatus =
          (driverMap['approvalStatus'] ?? '').toString();
      final String blockStatus = (driverMap['blockStatus'] ?? '').toString();
      approved = approvalStatus == 'approved' && blockStatus == 'no';
    }

    _driverApprovalCache[driverId] = approved;
    return approved;
  }


  // Opens the destination selection screen.
  // The user can search, add stops, or pin a destination on the map.
  // Step 2: Open the destination picker screen for search, pin destination, and multiple stops.
  Future<void> _openDestinationSelection() async {
    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);

    if (appInfo.userPickupLocation == null ||
        appInfo.userPickupLocation!.latitudePosition == null ||
        appInfo.userPickupLocation!.longitudePosition == null) {
      associateMethods.showSnackBarMsg(
        'Please wait while we get your current location.',
        context,
      );
      return;
    }

    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectDestinationPage()),
    );

    if (!mounted || result != 'route_confirmed') {
      return;
    }

    await _drawRouteOnMap();
  }




  // Builds the route after the passenger confirms destination/stops.
  // It asks the map service for directions, then draws markers and polylines on the map.
  // Step 3: After destination confirmation, calculate/draw the route and show the ride summary.
  Future<void> _drawRouteOnMap() async {
    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);
    final AddressModel? pickup = appInfo.userPickupLocation;
    final AddressModel? dropoff = appInfo.userDestinationLocation;
    final List<AddressModel> stops = appInfo.intermediateStops;

    if (pickup == null ||
        pickup.latitudePosition == null ||
        pickup.longitudePosition == null) {
      if (!mounted) return;
      associateMethods.showSnackBarMsg(
        'Pickup location not available. Please wait.',
        context,
      );
      return;
    }

    if (dropoff == null ||
        dropoff.latitudePosition == null ||
        dropoff.longitudePosition == null) {
      if (!mounted) return;
      associateMethods.showSnackBarMsg(
        'Destination not set properly.',
        context,
      );
      return;
    }

    final List<LatLng> waypoints = stops
        .where(
          (AddressModel stop) =>
              stop.latitudePosition != null && stop.longitudePosition != null,
        )
        .map(
          (AddressModel stop) =>
              LatLng(stop.latitudePosition!, stop.longitudePosition!),
        )
        .toList();

    final dynamic directionDetails = await GoogleMapMethods.getDirectionDetails(
      LatLng(pickup.latitudePosition!, pickup.longitudePosition!),
      LatLng(dropoff.latitudePosition!, dropoff.longitudePosition!),
      waypoints,
    );

    if (directionDetails == null) {
      _applyApproximateRouteFallback(
        pickup: pickup,
        dropoff: dropoff,
        waypoints: waypoints,
        reason: 'Google route service is unavailable. Using an approximate route for now.',
      );
      return;
    }

    final String apiStatus = (directionDetails['status'] ?? '').toString();
    if (apiStatus != 'OK') {
      final String apiMessage = (directionDetails['error_message'] ?? '').toString();
      final String reason = apiStatus == 'REQUEST_DENIED'
          ? 'Google Directions API key issue. Using an approximate route for testing.'
          : apiStatus == 'OVER_QUERY_LIMIT'
              ? 'Google route quota reached. Using an approximate route for now.'
              : apiStatus == 'ZERO_RESULTS'
                  ? 'No road route was returned. Using an approximate route for now.'
                  : 'Unable to calculate the road route. Using an approximate route for now.';
      debugPrint('Google Directions API status: $apiStatus $apiMessage');
      _applyApproximateRouteFallback(
        pickup: pickup,
        dropoff: dropoff,
        waypoints: waypoints,
        reason: reason,
      );
      return;
    }

    final List<dynamic> routes =
        (directionDetails['routes'] as List<dynamic>?) ?? <dynamic>[];
    if (routes.isEmpty) {
      _applyApproximateRouteFallback(
        pickup: pickup,
        dropoff: dropoff,
        waypoints: waypoints,
        reason: 'No route was returned. Using an approximate route for now.',
      );
      return;
    }

    final Map<String, dynamic> route = routes[0] as Map<String, dynamic>;
    final String encodedPolyline =
        ((route['overview_polyline'] as Map<String, dynamic>?)?['points'] ?? '')
            .toString();
    final List<LatLng> pLineCoordinates = GoogleMapMethods.decodePolyline(
      encodedPolyline,
    );

    if (pLineCoordinates.isEmpty) {
      _applyApproximateRouteFallback(
        pickup: pickup,
        dropoff: dropoff,
        waypoints: waypoints,
        reason: 'Route drawing failed. Using an approximate route for now.',
      );
      return;
    }

    final List<dynamic> routeLegs =
        (route['legs'] as List<dynamic>?) ?? <dynamic>[];
    final int totalMeters = _sumLegMetric(routeLegs, 'distance');
    final int totalSeconds = _sumLegMetric(routeLegs, 'duration');

    if (!mounted) return;

    setState(() {
      _bookingStage = PassengerBookingStage.routeSummary;
      _activeRideRequest = null;
      _lastObservedRideStatus = null;
      _confirmedEncodedPolyline = encodedPolyline;
      _confirmedRouteMeters = totalMeters;
      _confirmedRouteSeconds = totalSeconds;
      bottomMapPadding = _currentBottomSheetHeight;
    });

    _renderConfirmedRoute(
      pickup: pickup,
      dropoff: dropoff,
      waypoints: waypoints,
      points: pLineCoordinates,
      animateCamera: true,
    );
  }

  void _applyApproximateRouteFallback({
    required AddressModel pickup,
    required AddressModel dropoff,
    required List<LatLng> waypoints,
    required String reason,
  }) {
    if (!mounted ||
        pickup.latitudePosition == null ||
        pickup.longitudePosition == null ||
        dropoff.latitudePosition == null ||
        dropoff.longitudePosition == null) {
      return;
    }

    final List<LatLng> approximatePoints = <LatLng>[
      LatLng(pickup.latitudePosition!, pickup.longitudePosition!),
      ...waypoints,
      LatLng(dropoff.latitudePosition!, dropoff.longitudePosition!),
    ];

    int totalMeters = 0;
    for (int i = 0; i < approximatePoints.length - 1; i++) {
      totalMeters += Geolocator.distanceBetween(
        approximatePoints[i].latitude,
        approximatePoints[i].longitude,
        approximatePoints[i + 1].latitude,
        approximatePoints[i + 1].longitude,
      ).round();
    }

    // Add a small road-factor because straight-line distance is shorter than an actual road route.
    totalMeters = (totalMeters * 1.25).round();

    // Estimate time using about 30 km/h city driving speed.
    final int totalSeconds = totalMeters == 0 ? 0 : ((totalMeters / 1000) / 30 * 3600).round();

    setState(() {
      _bookingStage = PassengerBookingStage.routeSummary;
      _activeRideRequest = null;
      _lastObservedRideStatus = null;
      _confirmedEncodedPolyline = '';
      _confirmedRouteMeters = totalMeters;
      _confirmedRouteSeconds = totalSeconds;
      bottomMapPadding = _currentBottomSheetHeight;
    });

    _renderConfirmedRoute(
      pickup: pickup,
      dropoff: dropoff,
      waypoints: waypoints,
      points: approximatePoints,
      animateCamera: true,
    );

    associateMethods.showSnackBarMsg(reason, context);
  }

  int _sumLegMetric(List<dynamic> routeLegs, String metricKey) {
    int total = 0;

    for (final dynamic leg in routeLegs) {
      final Map<String, dynamic> legMap =
          (leg as Map<String, dynamic>?) ?? <String, dynamic>{};
      final Map<String, dynamic> metric =
          (legMap[metricKey] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final dynamic value = metric['value'];
      if (value is num) {
        total += value.toInt();
      }
    }

    return total;
  }


  // Creates a ride request in Firebase.
  // Drivers listen for rideRequests with status "searching" and can accept them.
  // Step 4: Save the passenger ride request to Firebase so online drivers can see it.
  Future<void> _createRideRequest() async {
    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);
    final AddressModel? pickup = appInfo.userPickupLocation;
    final AddressModel? dropoff = appInfo.userDestinationLocation;

    if (pickup == null ||
        dropoff == null ||
        pickup.latitudePosition == null ||
        pickup.longitudePosition == null ||
        dropoff.latitudePosition == null ||
        dropoff.longitudePosition == null ||
        _confirmedRouteMeters <= 0) {
      associateMethods.showSnackBarMsg(
        'Select a route before requesting a taxi.',
        context,
      );
      return;
    }

    final DatabaseReference requestRef = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .push();
    final String? requestId = requestRef.key;

    if (requestId == null) {
      associateMethods.showSnackBarMsg(
        'Unable to create a ride request right now.',
        context,
      );
      return;
    }

    final double fareEstimate = _estimateFare(_confirmedRouteMeters);
    final int createdAt = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> stopsPayload = appInfo.intermediateStops
        .where((AddressModel stop) =>
            stop.latitudePosition != null && stop.longitudePosition != null)
        .map((AddressModel stop) => <String, dynamic>{
              'address': stop.humanReadableAddress ?? stop.placeName ?? '',
              'name': stop.placeName ?? stop.humanReadableAddress ?? '',
              'latitude': stop.latitudePosition,
              'longitude': stop.longitudePosition,
            })
        .toList();

    try {
      final String passengerName = userName.trim().isNotEmpty ? userName.trim() : 'Passenger';
      final String passengerPhone = userPhone.trim();

      await requestRef.set(<String, dynamic>{
        'passengerId': FirebaseAuth.instance.currentUser!.uid,
        'passengerName': passengerName,
        'passengerPhone': passengerPhone,
        'assignedDriverId': '',
        'serviceType': _selectedServiceType,
        'paymentMethod': _selectedPaymentMethod,
        'serviceTypeKey': _selectedServiceType.toLowerCase().replaceAll(' ', '_'),
        'status': 'searching',
        'pickup': <String, dynamic>{
          'address': pickup.humanReadableAddress ?? pickup.placeName ?? '',
          'name': pickup.placeName ?? pickup.humanReadableAddress ?? '',
          'latitude': pickup.latitudePosition,
          'longitude': pickup.longitudePosition,
        },
        'destination': <String, dynamic>{
          'address': dropoff.humanReadableAddress ?? dropoff.placeName ?? '',
          'name': dropoff.placeName ?? dropoff.humanReadableAddress ?? '',
          'latitude': dropoff.latitudePosition,
          'longitude': dropoff.longitudePosition,
        },
        'stops': stopsPayload,
        'routeMeters': _confirmedRouteMeters,
        'routeSeconds': _confirmedRouteSeconds,
        'routePolyline': _confirmedEncodedPolyline,
        'fareEstimate': fareEstimate,
        'createdAt': createdAt,
        'acceptedAt': null,
        'arrivedAt': null,
        'startedAt': null,
        'completedAt': null,
        'cancelledAt': null,
      });

      _listenToRideRequest(requestId);

      if (!mounted) return;
      associateMethods.showSnackBarMsg(
        'Ride request created. Looking for drivers...',
        context,
      );
    } catch (e) {
      if (!mounted) return;
      associateMethods.showSnackBarMsg('Unable to request a taxi: $e', context);
    }
  }


  // Starts listening to this ride request so the passenger screen updates immediately
  // when a driver accepts, arrives, starts, completes, or cancels the trip.
  // Step 5: Listen in real time for driver acceptance, arrival, trip start, completion, or cancellation.
  void _listenToRideRequest(String requestId) {
    _activeRideRequestSubscription?.cancel();

    final DatabaseReference requestRef = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .child(requestId);

    _activeRideRequestSubscription = requestRef.onValue.listen((
      DatabaseEvent event,
    ) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(
        requestId,
        event.snapshot.value,
      );

      if (!mounted || ride == null) {
        return;
      }

      _handleRideRequestUpdate(ride);
    });
  }


  // Updates the passenger UI whenever Firebase changes the ride status.
  // This is what connects the passenger screen to driver actions in real time.
  // Updates the passenger UI whenever the driver changes the trip status in Firebase.
  void _handleRideRequestUpdate(RideRequestModel ride) {
    final bool statusChanged = _lastObservedRideStatus != ride.status;

    setState(() {
      _activeRideRequest = ride;
      _lastObservedRideStatus = ride.status;
      bottomMapPadding = _currentBottomSheetHeight;
    });

    _renderActiveRide(ride, animateCamera: statusChanged);

    final String? driverId = ride.assignedDriverId;
    if (driverId != null && driverId.isNotEmpty) {
      _loadAssignedDriver(driverId);
      _listenToAssignedDriverLocation(driverId);
    } else {
      _driverLocationSubscription?.cancel();
      _assignedDriverLatLng = null;
      _assignedDriverProfile = null;
      _renderActiveRide(ride);
    }

    if (statusChanged) {
      _showRideStatusMessage(ride.status);
    }
  }

  void _showRideStatusMessage(String status) {
    if (!mounted) return;

    const Map<String, String> statusMessages = <String, String>{
      'searching': 'Looking for a nearby approved driver.',
      'accepted': 'A driver accepted your ride.',
      'arrived': 'Your driver has arrived.',
      'in_progress': 'Your trip is now in progress.',
      'completed': 'Your trip has been completed.',
      'cancelled': 'This ride request was cancelled.',
    };

    final String? message = statusMessages[status];
    if (message != null) {
      associateMethods.showSnackBarMsg(message, context);
    }
  }

  // Loads the assigned driver profile so passenger can see driver/vehicle details.
  Future<void> _loadAssignedDriver(String driverId) async {
    if (_assignedDriverProfile != null &&
        (_assignedDriverProfile!['id'] ?? '').toString() == driverId) {
      return;
    }

    final DatabaseEvent driverEvent = await FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(driverId)
        .once();

    if (!mounted || driverEvent.snapshot.value == null) {
      return;
    }

    setState(() {
      _assignedDriverProfile = Map<Object?, Object?>.from(
        driverEvent.snapshot.value as Map,
      );
    });
  }

  // Listens to the accepted driver live location from onlineDrivers for passenger tracking.
  void _listenToAssignedDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = FirebaseDatabase.instance
        .ref()
        .child('onlineDrivers')
        .child(driverId)
        .onValue
        .listen((DatabaseEvent event) {
          if (!mounted) {
            return;
          }

          if (event.snapshot.value == null) {
            setState(() {
              _assignedDriverLatLng = null;
            });
            if (_activeRideRequest != null) {
              _renderActiveRide(_activeRideRequest!);
            }
            return;
          }

          final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
            event.snapshot.value as Map,
          );
          final int updatedAt = _intFrom(rawMap['updatedAt']);
          final int ageMs = DateTime.now().millisecondsSinceEpoch - updatedAt;

          if (ageMs > 15000) {
            setState(() {
              _assignedDriverLatLng = null;
            });
            if (_activeRideRequest != null) {
              _renderActiveRide(_activeRideRequest!);
            }
            return;
          }

          final double latitude = _doubleFrom(rawMap['latitude']);
          final double longitude = _doubleFrom(rawMap['longitude']);

          setState(() {
            _assignedDriverLatLng = LatLng(latitude, longitude);
          });

          if (_activeRideRequest != null) {
            _renderActiveRide(_activeRideRequest!);
          }
        });
  }

  double _estimateFare(int routeMeters) {
    final double distanceKm = routeMeters / 1000;
    final double fare = 10 + (3 * distanceKm);
    return double.parse(fare.toStringAsFixed(2));
  }

  // Allows cancellation only while the system is still searching for a driver.
  Future<void> _cancelSearchingRideRequest() async {
    final RideRequestModel? ride = _activeRideRequest;
    if (ride == null || ride.status != 'searching') {
      return;
    }

    await FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .child(ride.id)
        .update(<String, dynamic>{
          'status': 'cancelled',
          'cancelledAt': DateTime.now().millisecondsSinceEpoch,
        });
  }

  void _clearPassengerTripState() {
    _activeRideRequestSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _activeRideRequestSubscription = null;
    _driverLocationSubscription = null;

    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);
    appInfo.clearTripSelection();

    setState(() {
      _bookingStage = PassengerBookingStage.overview;
      _activeRideRequest = null;
      _lastObservedRideStatus = null;
      _assignedDriverLatLng = null;
      _assignedDriverProfile = null;
      _confirmedEncodedPolyline = '';
      _confirmedRouteMeters = 0;
      _confirmedRouteSeconds = 0;
      homeMapMarkers = <Marker>{};
      homeMapPolylines.clear();
      bottomMapPadding = _currentBottomSheetHeight;
      _selectedServiceType = 'City Ride';
      _selectedPaymentMethod = 'Cash';
    });

    if (currentPositionOfUser != null) {
      controllerGoogleMap?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              currentPositionOfUser!.latitude,
              currentPositionOfUser!.longitude,
            ),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _handleBackAction() {
    if (_activeRideRequest != null) {
      if (_activeRideRequest!.status == 'searching') {
        _cancelSearchingRideRequest();
        return;
      }

      if (_activeRideRequest!.isTerminal) {
        _clearPassengerTripState();
        return;
      }

      associateMethods.showSnackBarMsg(
        'This ride is already assigned to a driver.',
        context,
      );
      return;
    }

    if (_bookingStage == PassengerBookingStage.routeSummary) {
      setState(() {
        _bookingStage = PassengerBookingStage.planning;
        bottomMapPadding = _currentBottomSheetHeight;
      });
      return;
    }

    if (_bookingStage == PassengerBookingStage.planning) {
      final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);
      appInfo.clearTripSelection();
      setState(() {
        _bookingStage = PassengerBookingStage.overview;
        homeMapMarkers.clear();
        homeMapPolylines.clear();
        _confirmedEncodedPolyline = '';
        _confirmedRouteMeters = 0;
        _confirmedRouteSeconds = 0;
        bottomMapPadding = _currentBottomSheetHeight;
      });
    }
  }

  void _renderConfirmedRoute({
    required AddressModel pickup,
    required AddressModel dropoff,
    required List<LatLng> waypoints,
    required List<LatLng> points,
    bool animateCamera = false,
  }) {
    final Set<Marker> markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickupID'),
        position: LatLng(pickup.latitudePosition!, pickup.longitudePosition!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      Marker(
        markerId: const MarkerId('dropoffID'),
        position: LatLng(dropoff.latitudePosition!, dropoff.longitudePosition!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    };

    for (int i = 0; i < waypoints.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId('waypointID_$i'),
          position: waypoints[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
        ),
      );
    }

    final Set<Polyline> polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('PolylineID'),
        color: Colors.blue,
        jointType: JointType.round,
        points: points,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      ),
    };

    setState(() {
      homeMapMarkers = markers;
      homeMapPolylines = polylines;
    });

    if (animateCamera) {
      _fitCameraToPoints(points);
    }
  }

  void _renderActiveRide(RideRequestModel ride, {bool animateCamera = false}) {
    final List<LatLng> routePoints = ride.routePolyline.isEmpty
        ? <LatLng>[]
        : GoogleMapMethods.decodePolyline(ride.routePolyline);

    final Set<Marker> markers = <Marker>{
      if (ride.pickup.latitudePosition != null &&
          ride.pickup.longitudePosition != null)
        Marker(
          markerId: const MarkerId('ridePickupMarker'),
          position: LatLng(
            ride.pickup.latitudePosition!,
            ride.pickup.longitudePosition!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (ride.destination.latitudePosition != null &&
          ride.destination.longitudePosition != null)
        Marker(
          markerId: const MarkerId('rideDestinationMarker'),
          position: LatLng(
            ride.destination.latitudePosition!,
            ride.destination.longitudePosition!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      if (_assignedDriverLatLng != null)
        Marker(
          markerId: const MarkerId('assignedDriverMarker'),
          position: _assignedDriverLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
    };

    final Set<Polyline> polylines = routePoints.isEmpty
        ? <Polyline>{}
        : <Polyline>{
            Polyline(
              polylineId: const PolylineId('activeRideRoute'),
              color: ride.status == 'completed'
                  ? Colors.green
                  : Colors.blueAccent,
              width: 5,
              points: routePoints,
              geodesic: true,
            ),
          };

    setState(() {
      homeMapMarkers = markers;
      homeMapPolylines = polylines;
    });

    if (animateCamera && routePoints.isNotEmpty) {
      final List<LatLng> cameraPoints = <LatLng>[
        ...routePoints,
        if (_assignedDriverLatLng != null) _assignedDriverLatLng!,
      ];
      _fitCameraToPoints(cameraPoints);
    }
  }

  void _fitCameraToPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    controllerGoogleMap?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        65,
      ),
    );
  }

  Future<void> _recenterToCurrentLocation() async {
    if (currentPositionOfUser == null) {
      await getCurrentLocation();
      return;
    }

    controllerGoogleMap?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            currentPositionOfUser!.latitude,
            currentPositionOfUser!.longitude,
          ),
          zoom: 15,
        ),
      ),
    );
  }

  String _buildLocationLabel(
    AddressModel? location, {
    required String emptyFallback,
  }) {
    final String locationLabel =
        (location?.humanReadableAddress ?? location?.placeName ?? '').trim();
    if (locationLabel.isEmpty) {
      return emptyFallback;
    }

    return locationLabel.length <= 54
        ? locationLabel
        : '${locationLabel.substring(0, 54)}...';
  }

  String _rideStatusTitle(String status) {
    switch (status) {
      case 'searching':
        return 'Looking for Available Taxi';
      case 'accepted':
        return 'Driver Assigned';
      case 'arrived':
        return 'Driver Arrived';
      case 'in_progress':
        return 'Trip in Progress';
      case 'completed':
        return 'Trip Completed';
      case 'cancelled':
        return 'Ride Cancelled';
      default:
        return 'Ride Status';
    }
  }

  String _rideStatusSubtitle(RideRequestModel ride) {
    switch (ride.status) {
      case 'searching':
        return 'We are notifying nearby approved available drivers.';
      case 'accepted':
        return 'Your driver is on the way to pickup.';
      case 'arrived':
        return 'Meet your driver at the pickup point.';
      case 'in_progress':
        return 'Sit back, your trip is underway.';
      case 'completed':
        return 'Thanks for riding with Soltech.';
      case 'cancelled':
        return 'This request is no longer active.';
      default:
        return '';
    }
  }

  Set<Marker> get _visibleMapMarkers {
    final Set<Marker> markers = <Marker>{...homeMapMarkers};
    if (_activeRideRequest == null && _bookingStage != PassengerBookingStage.routeSummary) {
      markers.addAll(nearbyDriverMarkers);
    }
    return markers;
  }

  Widget _buildTopLeftControl() {
    if (_showBackButton) {
      return _circleButton(
        icon: Icons.arrow_back,
        onTap: _handleBackAction,
      );
    }

    return PopupMenuButton<MapType>(
      onSelected: (MapType mapType) {
        setState(() {
          selectedMapType = mapType;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
        const PopupMenuItem<MapType>(
          value: MapType.normal,
          child: Row(
            children: [
              Icon(Icons.map, color: Colors.black),
              SizedBox(width: 10),
              Text('Normal'),
            ],
          ),
        ),
        const PopupMenuItem<MapType>(
          value: MapType.satellite,
          child: Row(
            children: [
              Icon(Icons.satellite, color: Colors.black),
              SizedBox(width: 10),
              Text('Satellite'),
            ],
          ),
        ),
        const PopupMenuItem<MapType>(
          value: MapType.terrain,
          child: Row(
            children: [
              Icon(Icons.terrain, color: Colors.black),
              SizedBox(width: 10),
              Text('Terrain'),
            ],
          ),
        ),
        const PopupMenuItem<MapType>(
          value: MapType.hybrid,
          child: Row(
            children: [
              Icon(Icons.layers, color: Colors.black),
              SizedBox(width: 10),
              Text('Hybrid'),
            ],
          ),
        ),
      ],
      child: _circleButton(icon: Icons.layers_outlined),
    );
  }

  Widget _buildDriverInfoCard() {
    if (_assignedDriverProfile == null) {
      return const SizedBox.shrink();
    }

    final String driverName = (_assignedDriverProfile!['name'] ?? '').toString();
    final String driverPhone = (_assignedDriverProfile!['phone'] ?? '').toString();
    final String vehicleModel =
        (_assignedDriverProfile!['vehicleModel'] ?? '').toString();
    final String vehicleColor =
        (_assignedDriverProfile!['vehicleColor'] ?? '').toString();
    final String plateNumber =
        (_assignedDriverProfile!['plateNumber'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Driver',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            driverName.isEmpty ? 'Waiting for driver details' : driverName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          if (vehicleModel.isNotEmpty || plateNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [vehicleColor, vehicleModel, plateNumber]
                  .where((String part) => part.trim().isNotEmpty)
                  .join(' • '),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          if (driverPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              driverPhone,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }


  // Bottom sheet used after the ride request is created.
  // It shows searching, driver assigned, arrived, trip progress, completed, or cancelled states.
  // Active ride sheet: searching, driver found, arrived, in-progress, completed, or cancelled.
  Widget _buildRideStatusSheet() {
    final RideRequestModel ride = _activeRideRequest!;

    return _bottomSheetScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _sheetHandle()),
          const SizedBox(height: 18),
          Text(
            _rideStatusTitle(ride.status),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _rideStatusSubtitle(ride),
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _locationPairCard(
            pickupText:
                ride.pickup.humanReadableAddress ?? ride.pickup.placeName ?? 'Pickup',
            destinationText:
                ride.destination.humanReadableAddress ??
                ride.destination.placeName ??
                'Destination',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryPill(
                  icon: Icons.route,
                  label: '${(ride.routeMeters / 1000).toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryPill(
                  icon: Icons.payments_outlined,
                  label: 'K${ride.fareEstimate.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDriverInfoCard(),
          if (ride.status != 'searching' && !ride.isTerminal) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _quickTripAction(
                    icon: Icons.call,
                    label: 'Call',
                    onTap: () => associateMethods.showSnackBarMsg(
                      'Call driver feature will be connected to phone dialer.',
                      context,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickTripAction(
                    icon: Icons.message_outlined,
                    label: 'Message',
                    onTap: () => associateMethods.showSnackBarMsg(
                      'In-app messaging will be available during active trips.',
                      context,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickTripAction(
                    icon: Icons.share_location,
                    label: 'Share',
                    onTap: () => associateMethods.showSnackBarMsg(
                      'Share trip link feature will be added for safety.',
                      context,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickTripAction(
                    icon: Icons.sos,
                    label: 'SOS',
                    foregroundColor: Colors.redAccent,
                    onTap: () => associateMethods.showSnackBarMsg(
                      'Emergency alert feature will notify the admin/support team.',
                      context,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (ride.status == 'searching')
            _primaryButton(
              label: 'Cancel Request',
              onPressed: _cancelSearchingRideRequest,
              backgroundColor: Colors.redAccent,
            )
          else if (ride.isTerminal)
            _primaryButton(
              label: 'Done',
              onPressed: _clearPassengerTripState,
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewSheet() {
    return _bottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _sheetHandle()),
          const SizedBox(height: 18),
          const Text(
            'Get a ride',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Map view shows your current location and nearby approved available drivers.',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.my_location, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildLocationLabel(
                          Provider.of<AppInfo>(context, listen: true)
                              .userPickupLocation,
                          emptyFallback: 'Getting pickup location...',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniInfoCard(
                  icon: Icons.local_taxi,
                  title: '${nearbyDriverMarkers.length}',
                  subtitle: 'Drivers nearby',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfoCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Approved',
                  subtitle: 'Only verified drivers',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _primaryButton(
            label: 'Get a Ride',
            onPressed: () {
              setState(() {
                _bookingStage = PassengerBookingStage.planning;
                bottomMapPadding = _currentBottomSheetHeight;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningSheet() {
    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: true);

    return _bottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _sheetHandle()),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Where are you going?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 18),
          _locationPairCard(
            pickupText: _buildLocationLabel(
              appInfo.userPickupLocation,
              emptyFallback: 'Location detected by GPS',
            ),
            destinationText: _buildLocationLabel(
              appInfo.userDestinationLocation,
              emptyFallback: 'Search destination here',
            ),
          ),
          if (appInfo.intermediateStops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Stops added: ${appInfo.intermediateStops.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tip: open the map search screen to search, pin, and adjust the destination precisely. Multiple stops are supported.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          _primaryButton(
            label: 'Search Destination',
            onPressed: _openDestinationSelection,
          ),
        ],
      ),
    );
  }


  // Bottom sheet shown after route confirmation.
  // It displays distance, estimated time, fare, service type, payment method, and booking button.
  // Ride summary sheet: final review before pressing Book Ride.
  Widget _buildConfirmedRouteSheet() {
    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: true);

    return _bottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _sheetHandle()),
          const SizedBox(height: 18),
          const Text(
            'Ride Summary',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _detailRow(
            'Pickup',
            _buildLocationLabel(
              appInfo.userPickupLocation,
              emptyFallback: 'Current Location',
            ),
          ),
          _detailRow(
            'Destination',
            _buildLocationLabel(
              appInfo.userDestinationLocation,
              emptyFallback: 'Selected Destination',
            ),
          ),
          _detailRow(
            'Distance',
            '${(_confirmedRouteMeters / 1000).toStringAsFixed(1)} km',
          ),
          _detailRow(
            'Estimated Time',
            '${(_confirmedRouteSeconds / 60).ceil()} minutes',
          ),
          _detailRow(
            'Estimated Fare',
            'K${_estimateFare(_confirmedRouteMeters).toStringAsFixed(2)}',
          ),
          _detailRow('Stops', '${appInfo.intermediateStops.length}'),
          const SizedBox(height: 14),
          const Text(
            'Service Type',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <String>['City Ride', 'Intercity', 'Rental', 'Hire']
                .map(
                  (String item) => ChoiceChip(
                    label: Text(item),
                    selected: _selectedServiceType == item,
                    onSelected: (_) {
                      setState(() {
                        _selectedServiceType = item;
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment Method',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: <String>['Cash', 'Digital'].map((String item) {
              final bool selected = _selectedPaymentMethod == item;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: item == 'Cash' ? 8 : 0),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedPaymentMethod = item;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected ? Colors.black : Colors.white,
                      foregroundColor: selected ? Colors.white : Colors.black,
                      side: BorderSide(
                        color: selected ? Colors.black : Colors.grey.shade400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(item),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _openDestinationSelection,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Edit Route'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _primaryButton(
                  label: 'Book Ride',
                  onPressed: _createRideRequest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87, size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _locationPairCard({
    required String pickupText,
    required String destinationText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Colors.blue, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      pickupText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 24,
                child: VerticalDivider(color: Colors.grey, thickness: 1),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destination',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      destinationText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickTripAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color foregroundColor = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foregroundColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.black,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _bottomSheetScaffold({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: child,
        ),
      ),
    );
  }

  Widget _circleButton({IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }

  // Builds the main passenger Home tab with Google Map and the correct bottom sheet.
  Widget _buildHomeMap() {
    return Stack(
      children: [
        GoogleMap(
          padding: EdgeInsets.only(top: 26, bottom: bottomMapPadding),
          mapType: selectedMapType,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          polylines: homeMapPolylines,
          markers: _visibleMapMarkers,
          initialCameraPosition: kGooglePlex,
          onMapCreated: (GoogleMapController mapController) {
            controllerGoogleMap = mapController;
            googleMapCompleterController.complete(mapController);
            getCurrentLocation();
          },
        ),
        Positioned(
          top: 42,
          left: 20,
          child: _buildTopLeftControl(),
        ),
        Positioned(
          top: 42,
          right: 20,
          child: _circleButton(
            icon: Icons.my_location,
            onTap: _recenterToCurrentLocation,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedSize(
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 180),
            child: _activeRideRequest != null
                ? _buildRideStatusSheet()
                : _bookingStage == PassengerBookingStage.overview
                ? _buildOverviewSheet()
                : _bookingStage == PassengerBookingStage.planning
                ? _buildPlanningSheet()
                : _buildConfirmedRouteSheet(),
          ),
        ),
      ],
    );
  }

  int _intFrom(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  double _doubleFrom(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _hideBottomNav
          ? null
          : BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_activity),
                  label: 'Your Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Account',
                ),
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
          _buildHomeMap(),
          const ServicesTab(),
          const ActivityTab(),
          const AccountTab(),
        ],
      ),
    );
  }
}
