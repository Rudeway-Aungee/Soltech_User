import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:soltech_master_app/core/session/app_session.dart';
import 'package:soltech_master_app/global.dart';
import 'package:soltech_master_app/core/services/google_map_methods.dart';
import 'package:soltech_master_app/core/models/driver_profile_model.dart';
import 'package:soltech_master_app/core/models/ride_request_model.dart';
import 'package:soltech_master_app/features/driver/driver_account_tab.dart';
import 'package:soltech_master_app/features/driver/driver_activity_tab.dart';
import 'package:soltech_master_app/features/driver/driver_pending_approval_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> googleMapCompleterController =
      Completer<GoogleMapController>();

  GoogleMapController? controllerGoogleMap;
  MapType selectedMapType = MapType.normal;
  Set<Marker> homeMapMarkers = <Marker>{};
  Set<Polyline> homeMapPolylines = <Polyline>{};

  int _selectedIndex = 0;
  bool _didBootstrap = false;
  bool _isLoading = true;
  bool _isOnline = false;
  bool _isTogglingOnline = false;
  bool _isProcessingRideAction = false;
  double _bottomMapPadding = 320;

  Position? _currentPosition;
  DriverProfileModel? _driverProfile;
  RideRequestModel? _activeRideRequest;
  String? _lastActiveRideStatus;
  List<RideRequestModel> _openRideRequests = <RideRequestModel>[];

  Timer? _locationTimer;
  StreamSubscription<DatabaseEvent>? _openRidesSubscription;
  StreamSubscription<DatabaseEvent>? _activeRideSubscription;

  @override
  void dispose() {
    _locationTimer?.cancel();
    _openRidesSubscription?.cancel();
    _activeRideSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDriverSession() async {
    if (_didBootstrap) {
      return;
    }

    _didBootstrap = true;

    try {
      await _refreshCurrentLocation(animateCamera: true);
      await _loadDriverProfileAndState();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      associateMethods.showSnackBarMsg(
        'Unable to start driver session: $e',
        context,
      );
    }
  }

  Future<void> _loadDriverProfileAndState() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _goToSignIn();
      return;
    }

    final DatabaseEvent driverEvent = await FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(currentUser.uid)
        .once();
    final DriverProfileModel? profile = DriverProfileModel.fromSnapshotValue(
      currentUser.uid,
      driverEvent.snapshot.value,
    );

    if (!mounted) {
      return;
    }

    if (profile == null) {
      await FirebaseAuth.instance.signOut();
      _goToSignIn();
      return;
    }

    if (profile.isBlocked) {
      associateMethods.showSnackBarMsg('Driver account blocked.', context);
      await FirebaseAuth.instance.signOut();
      if (!mounted) {
        return;
      }

      _goToSignIn();
      return;
    }

    if (!profile.isApproved) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) =>
              DriverPendingApprovalPage(initialStatus: profile.approvalStatus),
        ),
        (Route<dynamic> route) => false,
      );
      return;
    }

    final RideRequestModel? activeRide = await _findActiveRide(currentUser.uid);
    final bool shouldBeOnline =
        profile.onlineStatus != 'offline' || activeRide != null;

    _cacheDriverProfile(profile);

    setState(() {
      _driverProfile = profile;
      _activeRideRequest = activeRide;
      _isOnline = shouldBeOnline;
      _isLoading = false;
      _bottomMapPadding = activeRide != null ? 350 : 320;
    });

    if (_isOnline) {
      await _publishCurrentLocation();
      _startLocationUpdates();
    }

    if (activeRide != null) {
      _listenToActiveRide(activeRide.id);
      await _drawRouteForRide(activeRide, animateCamera: true);
      await _setDriverAvailability('busy');
    } else if (_isOnline) {
      await _setDriverAvailability('available');
      _listenForOpenRideRequests();
    }
  }

  Future<RideRequestModel?> _findActiveRide(String driverId) async {
    final DatabaseEvent rideEvent = await FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .orderByChild('assignedDriverId')
        .equalTo(driverId)
        .once();

    if (rideEvent.snapshot.value is! Map) {
      return null;
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
      rideEvent.snapshot.value as Map,
    );
    RideRequestModel? mostRecentRide;

    rawMap.forEach((Object? key, Object? value) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(
        key.toString(),
        value,
      );

      if (ride == null || ride.isTerminal) {
        return;
      }

      if (mostRecentRide == null ||
          ride.createdAt > mostRecentRide!.createdAt) {
        mostRecentRide = ride;
      }
    });

    return mostRecentRide;
  }

  Future<void> _refreshCurrentLocation({bool animateCamera = false}) async {
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentPosition = position;
    });

    if (animateCamera) {
      controllerGoogleMap?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14,
          ),
        ),
      );
    }
  }

  void _listenForOpenRideRequests() {
    _openRidesSubscription?.cancel();

    final Query rideQuery = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .orderByChild('status')
        .equalTo('searching');

    _openRidesSubscription = rideQuery.onValue.listen((DatabaseEvent event) {
      if (!mounted) {
        return;
      }

      final List<RideRequestModel> rides = _parseSearchingRides(
        event.snapshot.value,
      );

      rides.sort((RideRequestModel a, RideRequestModel b) {
        final double distanceToA = _distanceToRidePickup(a);
        final double distanceToB = _distanceToRidePickup(b);
        return distanceToA.compareTo(distanceToB);
      });

      setState(() {
        _openRideRequests = rides;
      });

      if (_activeRideRequest == null) {
        _renderOpenRideMarkers(rides);
      }
    });
  }

  List<RideRequestModel> _parseSearchingRides(Object? snapshotValue) {
    if (snapshotValue is! Map) {
      return <RideRequestModel>[];
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
      snapshotValue,
    );
    final List<RideRequestModel> rides = <RideRequestModel>[];

    rawMap.forEach((Object? key, Object? value) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(
        key.toString(),
        value,
      );
      if (ride == null) {
        return;
      }

      // Passenger requests may store service labels such as "City Ride",
      // "Intercity", "Rental", or "Hire". Do not restrict this list to
      // serviceType == "taxi", otherwise drivers will not see passenger rides
      // created from the new passenger UI.
      if (ride.status == 'searching') {
        rides.add(ride);
      }
    });

    return rides;
  }

  double _distanceToRidePickup(RideRequestModel ride) {
    if (_currentPosition == null ||
        ride.pickup.latitudePosition == null ||
        ride.pickup.longitudePosition == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      ride.pickup.latitudePosition!,
      ride.pickup.longitudePosition!,
    );
  }

  void _renderOpenRideMarkers(List<RideRequestModel> rides) {
    final Set<Marker> markers = <Marker>{};

    for (int i = 0; i < rides.length; i++) {
      final RideRequestModel ride = rides[i];
      if (ride.pickup.latitudePosition == null ||
          ride.pickup.longitudePosition == null) {
        continue;
      }

      markers.add(
        Marker(
          markerId: MarkerId('openRide_$i'),
          position: LatLng(
            ride.pickup.latitudePosition!,
            ride.pickup.longitudePosition!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: 'Taxi Request',
            snippet: 'K${ride.fareEstimate.toStringAsFixed(2)}',
          ),
        ),
      );
    }

    setState(() {
      homeMapMarkers = markers;
      homeMapPolylines = <Polyline>{};
    });
  }

  Future<void> _toggleOnlineStatus(bool shouldBeOnline) async {
    if (_activeRideRequest != null && !shouldBeOnline) {
      associateMethods.showSnackBarMsg(
        'Finish the active ride before going offline.',
        context,
      );
      return;
    }

    setState(() {
      _isTogglingOnline = true;
    });

    if (shouldBeOnline) {
      await _goOnline();
    } else {
      await _goOffline();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isTogglingOnline = false;
    });
  }

  Future<void> _goOnline() async {
    await _refreshCurrentLocation(animateCamera: false);
    setState(() {
      _isOnline = true;
      driverOnlineStatus = 'available';
    });

    await _setDriverAvailability('available');
    await _publishCurrentLocation();
    _startLocationUpdates();
    _listenForOpenRideRequests();
  }

  Future<void> _goOffline() async {
    _locationTimer?.cancel();
    _openRidesSubscription?.cancel();

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(currentUser.uid)
          .update(<String, dynamic>{
            'onlineStatus': 'offline',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });
      await FirebaseDatabase.instance
          .ref()
          .child('onlineDrivers')
          .child(currentUser.uid)
          .remove();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isOnline = false;
      driverOnlineStatus = 'offline';
      _openRideRequests = <RideRequestModel>[];
      if (_activeRideRequest == null) {
        homeMapMarkers = <Marker>{};
        homeMapPolylines = <Polyline>{};
      }
    });
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      _publishCurrentLocation();
    });
  }

  Future<void> _publishCurrentLocation() async {
    if (!_isOnline) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    await _refreshCurrentLocation(animateCamera: false);

    if (_currentPosition == null) {
      return;
    }

    final String availabilityStatus = _activeRideRequest == null
        ? 'available'
        : 'busy';
    final int now = DateTime.now().millisecondsSinceEpoch;

    await FirebaseDatabase.instance
        .ref()
        .child('onlineDrivers')
        .child(currentUser.uid)
        .set(<String, dynamic>{
          'driverId': currentUser.uid,
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'heading': _currentPosition!.heading,
          'serviceType': 'taxi',
          'availabilityStatus': availabilityStatus,
          'fleetId': _driverProfile?.fleetId ?? '',
          'vehicleId': _driverProfile?.vehicleId ?? '',
          'updatedAt': now,
        });

    await FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(currentUser.uid)
        .update(<String, dynamic>{
          'onlineStatus': availabilityStatus,
          'updatedAt': now,
        });

    if (!mounted) {
      return;
    }

    setState(() {
      driverOnlineStatus = availabilityStatus;
    });
  }

  Future<void> _setDriverAvailability(String status) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;

    await FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(currentUser.uid)
        .update(<String, dynamic>{'onlineStatus': status, 'updatedAt': now});

    if (_isOnline && _currentPosition != null) {
      await FirebaseDatabase.instance
          .ref()
          .child('onlineDrivers')
          .child(currentUser.uid)
          .update(<String, dynamic>{
            'availabilityStatus': status,
            'updatedAt': now,
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
            'heading': _currentPosition!.heading,
            'fleetId': _driverProfile?.fleetId ?? '',
            'vehicleId': _driverProfile?.vehicleId ?? '',
          });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      driverOnlineStatus = status;
    });
  }

  Future<void> _acceptRideRequest(RideRequestModel ride) async {
    if (_activeRideRequest != null || _isProcessingRideAction) {
      return;
    }

    setState(() {
      _isProcessingRideAction = true;
    });

    final DatabaseReference requestRef = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .child(ride.id);
    final int acceptedAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final TransactionResult result = await requestRef.runTransaction((
        Object? currentValue,
      ) {
        if (currentValue is! Map) {
          return Transaction.abort();
        }

        final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
          currentValue,
        );
        final String status = (rawMap['status'] ?? '').toString();
        final String assignedDriverId = (rawMap['assignedDriverId'] ?? '')
            .toString()
            .trim();

        if (status != 'searching' || assignedDriverId.isNotEmpty) {
          return Transaction.abort();
        }

        rawMap['status'] = 'accepted';
        rawMap['assignedDriverId'] = FirebaseAuth.instance.currentUser!.uid;
        rawMap['fleetId'] = _driverProfile?.fleetId ?? '';
        rawMap['vehicleId'] = _driverProfile?.vehicleId ?? '';
        rawMap['assignedDriver'] = <String, dynamic>{
          'id': FirebaseAuth.instance.currentUser!.uid,
          'name': _driverProfile?.name ?? '',
          'phone': _driverProfile?.phone ?? '',
          'vehicleModel': _driverProfile?.vehicleModel ?? '',
          'vehicleColor': _driverProfile?.vehicleColor ?? '',
          'plateNumber': _driverProfile?.plateNumber ?? '',
        };
        rawMap['acceptedAt'] = acceptedAt;
        return Transaction.success(rawMap);
      });

      if (!result.committed) {
        if (!mounted) {
          return;
        }

        associateMethods.showSnackBarMsg(
          'Another driver accepted this ride first.',
          context,
        );
        return;
      }

      await _setDriverAvailability('busy');
      _openRidesSubscription?.cancel();
      setState(() {
        _openRideRequests = <RideRequestModel>[];
      });
      _listenToActiveRide(ride.id);
    } catch (e) {
      if (!mounted) {
        return;
      }

      associateMethods.showSnackBarMsg('Unable to accept ride: $e', context);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRideAction = false;
        });
      }
    }
  }

  void _listenToActiveRide(String requestId) {
    _activeRideSubscription?.cancel();

    final DatabaseReference requestRef = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .child(requestId);

    _activeRideSubscription = requestRef.onValue.listen((DatabaseEvent event) {
      final RideRequestModel? ride = RideRequestModel.fromSnapshotValue(
        requestId,
        event.snapshot.value,
      );

      if (!mounted || ride == null) {
        return;
      }

      if (ride.isTerminal) {
        _handleFinishedRide(ride);
        return;
      }

      _handleActiveRideUpdate(ride);
    });
  }

  void _handleActiveRideUpdate(RideRequestModel ride) {
    final bool statusChanged = _lastActiveRideStatus != ride.status;

    setState(() {
      _activeRideRequest = ride;
      _lastActiveRideStatus = ride.status;
      _bottomMapPadding = 350;
    });

    if (statusChanged) {
      _showRideStatusMessage(ride.status);
    }

    _drawRouteForRide(ride, animateCamera: statusChanged);
  }

  Future<void> _handleFinishedRide(RideRequestModel ride) async {
    _activeRideSubscription?.cancel();

    setState(() {
      _activeRideRequest = null;
      _lastActiveRideStatus = ride.status;
      homeMapPolylines = <Polyline>{};
      homeMapMarkers = <Marker>{};
      _bottomMapPadding = 320;
    });

    if (ride.status == 'completed') {
      associateMethods.showSnackBarMsg('Trip completed.', context);
    } else {
      associateMethods.showSnackBarMsg('Ride cancelled.', context);
    }

    if (_isOnline) {
      await _setDriverAvailability('available');
      _listenForOpenRideRequests();
    }
  }

  void _showRideStatusMessage(String status) {
    const Map<String, String> messages = <String, String>{
      'accepted': 'Ride accepted. Head to the pickup point.',
      'arrived': 'Passenger pickup marked as arrived.',
      'in_progress': 'Trip started.',
    };

    final String? message = messages[status];
    if (message != null) {
      associateMethods.showSnackBarMsg(message, context);
    }
  }

  Future<void> _drawRouteForRide(
    RideRequestModel ride, {
    bool animateCamera = false,
  }) async {
    final Set<Marker> markers = <Marker>{
      if (ride.pickup.latitudePosition != null &&
          ride.pickup.longitudePosition != null)
        Marker(
          markerId: const MarkerId('pickupMarker'),
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
          markerId: const MarkerId('destinationMarker'),
          position: LatLng(
            ride.destination.latitudePosition!,
            ride.destination.longitudePosition!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
    };

    List<LatLng> routePoints = <LatLng>[];

    if (ride.status == 'in_progress' && ride.routePolyline.isNotEmpty) {
      routePoints = GoogleMapMethods.decodePolyline(ride.routePolyline);
    } else if (_currentPosition != null &&
        ride.pickup.latitudePosition != null &&
        ride.pickup.longitudePosition != null) {
      final dynamic directionDetails =
          await GoogleMapMethods.getDirectionDetails(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            LatLng(
              ride.pickup.latitudePosition!,
              ride.pickup.longitudePosition!,
            ),
            <LatLng>[],
          );

      if (_activeRideRequest?.id != ride.id || !mounted) {
        return;
      }

      if (directionDetails != null &&
          directionDetails['routes'] != null &&
          (directionDetails['routes'] as List<dynamic>).isNotEmpty) {
        final String encodedPolyline =
            ((directionDetails['routes'][0]['overview_polyline']
                        as Map<String, dynamic>?)?['points'] ??
                    '')
                .toString();
        routePoints = encodedPolyline.isEmpty
            ? <LatLng>[]
            : GoogleMapMethods.decodePolyline(encodedPolyline);
      }
    }

    final Set<Polyline> polylines = routePoints.isEmpty
        ? <Polyline>{}
        : <Polyline>{
            Polyline(
              polylineId: const PolylineId('activeRidePolyline'),
              color: ride.status == 'in_progress'
                  ? Colors.green
                  : Colors.blueAccent,
              width: 5,
              geodesic: true,
              points: routePoints,
            ),
          };

    setState(() {
      homeMapMarkers = markers;
      homeMapPolylines = polylines;
    });

    if (animateCamera && routePoints.isNotEmpty) {
      _fitCameraToPoints(routePoints);
    }
  }

  Future<void> _advanceRideStatus(String nextStatus) async {
    final RideRequestModel? ride = _activeRideRequest;
    if (ride == null || _isProcessingRideAction) {
      return;
    }

    setState(() {
      _isProcessingRideAction = true;
    });

    final int now = DateTime.now().millisecondsSinceEpoch;
    final double fare = ride.fareEstimate;
    final double platformCommission = double.parse((fare * 0.10).toStringAsFixed(2));
    final double driverEarnings = nextStatus == 'completed'
        ? double.parse((fare - platformCommission).toStringAsFixed(2))
        : 0;
    final double fleetEarnings = nextStatus == 'completed' ? fare : 0;

    final Map<String, dynamic> updates = <String, dynamic>{
      'status': nextStatus,
      'updatedAt': now,
    };

    switch (nextStatus) {
      case 'arrived':
        updates['arrivedAt'] = now;
        break;
      case 'in_progress':
        updates['startedAt'] = now;
        break;
      case 'completed':
        updates.addAll(<String, dynamic>{
          'completedAt': now,
          'finalFare': fare,
          'paymentStatus': 'paid',
          'driverEarnings': driverEarnings,
          'fleetEarnings': fleetEarnings,
          'platformCommission': platformCommission,
          'completedDateKey': _dateKey(now),
        });
        break;
      case 'cancelled':
        updates.addAll(<String, dynamic>{
          'cancelledAt': now,
          'paymentStatus': 'not_required',
          'driverEarnings': 0,
          'fleetEarnings': 0,
          'platformCommission': 0,
        });
        break;
    }

    final DatabaseReference rideRef = FirebaseDatabase.instance
        .ref()
        .child('rideRequests')
        .child(ride.id);

    try {
      await rideRef.update(updates);

      if (nextStatus == 'completed' || nextStatus == 'cancelled') {
        final DatabaseEvent updatedEvent = await rideRef.once();
        final RideRequestModel? updatedRide = RideRequestModel.fromSnapshotValue(
          ride.id,
          updatedEvent.snapshot.value,
        );
        if (updatedRide != null) {
          await _recordRideHistoryAndEarnings(updatedRide);
        }
        await _setDriverAvailability('available');
      } else {
        await _setDriverAvailability('busy');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      associateMethods.showSnackBarMsg(
        'Unable to update ride status: $e',
        context,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingRideAction = false;
        });
      }
    }
  }

  String _dateKey(int timestamp) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _recordRideHistoryAndEarnings(RideRequestModel ride) async {
    final String driverId = ride.assignedDriverId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (driverId.isEmpty) {
      return;
    }

    final int closedAt = ride.completedAt ?? ride.cancelledAt ?? DateTime.now().millisecondsSinceEpoch;
    final double fare = ride.status == 'completed' ? ride.fareEstimate : 0;
    final double platformCommission = ride.status == 'completed'
        ? double.parse((fare * 0.10).toStringAsFixed(2))
        : 0;
    final double driverEarnings = ride.status == 'completed'
        ? double.parse((fare - platformCommission).toStringAsFixed(2))
        : 0;
    final String paymentMethod = ride.paymentMethod.toLowerCase().trim().isEmpty
        ? 'cash'
        : ride.paymentMethod.toLowerCase().trim();

    final Map<String, dynamic> historyPayload = ride.toHistoryMap()
      ..addAll(<String, dynamic>{
        'closedAt': closedAt,
        'dateKey': _dateKey(closedAt),
        'fare': fare,
        'driverEarnings': driverEarnings,
        'fleetEarnings': fare,
        'platformCommission': platformCommission,
        'paymentMethod': paymentMethod,
        'paymentStatus': ride.status == 'completed' ? 'paid' : 'not_required',
      });

    final Map<String, dynamic> updates = <String, dynamic>{
      'tripHistory/passengers/${ride.passengerId}/${ride.id}': historyPayload,
      'tripHistory/drivers/$driverId/${ride.id}': historyPayload,
      'earnings/drivers/$driverId/${ride.id}': <String, dynamic>{
        'rideId': ride.id,
        'status': ride.status,
        'grossFare': fare,
        'platformCommission': platformCommission,
        'driverEarnings': driverEarnings,
        'paymentMethod': paymentMethod,
        'dateKey': _dateKey(closedAt),
        'closedAt': closedAt,
      },
    };

    if (ride.fleetId.isNotEmpty) {
      updates['tripHistory/fleets/${ride.fleetId}/${ride.id}'] = historyPayload;
      updates['earnings/fleets/${ride.fleetId}/${ride.id}'] = <String, dynamic>{
        'rideId': ride.id,
        'driverId': driverId,
        'vehicleId': ride.vehicleId,
        'status': ride.status,
        'grossFare': fare,
        'platformCommission': platformCommission,
        'fleetEarnings': fare,
        'paymentMethod': paymentMethod,
        'dateKey': _dateKey(closedAt),
        'closedAt': closedAt,
      };
      updates['ledgers/fleets/${ride.fleetId}/${ride.id}'] = <String, dynamic>{
        'rideId': ride.id,
        'driverId': driverId,
        'vehicleId': ride.vehicleId,
        'paymentMethod': paymentMethod,
        'cashCollected': paymentMethod == 'cash' && ride.status == 'completed' ? fare : 0,
        'digitalAmount': paymentMethod != 'cash' && ride.status == 'completed' ? fare : 0,
        'platformCommission': platformCommission,
        'driverCashDebt': paymentMethod == 'cash' && ride.status == 'completed' ? platformCommission : 0,
        'status': ride.status,
        'dateKey': _dateKey(closedAt),
        'closedAt': closedAt,
      };
    }

    await FirebaseDatabase.instance.ref().update(updates);
  }

  void _cacheDriverProfile(DriverProfileModel profile) {
    userName = profile.name;
    userPhone = profile.phone;
    driverVehicleModel = profile.vehicleModel;
    driverVehicleColor = profile.vehicleColor;
    driverPlateNumber = profile.plateNumber;
    driverApprovalStatus = profile.approvalStatus;
    driverOnlineStatus = profile.onlineStatus;
  }

  void _goToSignIn() {
    if (!mounted) {
      return;
    }

    context.read<AppSession>().signOut();
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
      if (point.latitude < minLat) {
        minLat = point.latitude;
      }
      if (point.latitude > maxLat) {
        maxLat = point.latitude;
      }
      if (point.longitude < minLng) {
        minLng = point.longitude;
      }
      if (point.longitude > maxLng) {
        maxLng = point.longitude;
      }
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

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp == 0) {
      return 'Unknown time';
    }

    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
    ).toLocal();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$month-$day $hour:$minute';
  }

  Widget _buildOnlineSwitchCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _isOnline ? Colors.green[700] : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: _isOnline,
            onChanged: _isTogglingOnline ? null : _toggleOnlineStatus,
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineSheet() {
    return _bottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You are Offline',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go online to receive ride requests assigned to approved drivers in your fleet.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isTogglingOnline
                  ? null
                  : () => _toggleOnlineStatus(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Go Online',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingSheet() {
    return _bottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${_driverProfile?.name ?? 'Driver'}, you are online. New ride requests will appear here automatically.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _metricRow(
            icon: Icons.circle,
            iconColor: Colors.green,
            label: 'Status',
            value: driverOnlineStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildOpenRequestsSheet() {
    return _bottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_openRideRequests.length} ride request${_openRideRequests.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accept a ride request to navigate to the passenger pickup location.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 280,
            child: ListView.separated(
              itemCount: _openRideRequests.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final RideRequestModel ride = _openRideRequests[index];
                final double pickupDistanceKm =
                    _distanceToRidePickup(ride) / 1000;

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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'K${ride.fareEstimate.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            pickupDistanceKm.isFinite
                                ? '${pickupDistanceKm.toStringAsFixed(1)} km away'
                                : 'Distance unavailable',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _metricRow(
                        icon: Icons.my_location,
                        iconColor: Colors.blue,
                        label: 'Pickup',
                        value:
                            ride.pickup.humanReadableAddress ??
                            ride.pickup.placeName ??
                            'Pickup',
                      ),
                      const SizedBox(height: 10),
                      _metricRow(
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        label: 'Destination',
                        value:
                            ride.destination.humanReadableAddress ??
                            ride.destination.placeName ??
                            'Destination',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${(ride.routeMeters / 1000).toStringAsFixed(1)} km • ${_formatTimestamp(ride.createdAt)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isProcessingRideAction
                                ? null
                                : () => _acceptRideRequest(ride),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideSheet() {
    final RideRequestModel ride = _activeRideRequest!;
    final String rideTitle = switch (ride.status) {
      'accepted' => 'Drive to Pickup',
      'arrived' => 'Passenger Ready',
      'in_progress' => 'Trip in Progress',
      _ => 'Active Ride',
    };

    return _bottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rideTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            ride.status == 'accepted'
                ? 'Head to the pickup point and mark arrived when you get there.'
                : ride.status == 'arrived'
                ? 'Passenger pickup confirmed. Start the trip when ready.'
                : 'Follow the destination route and complete the trip at dropoff.',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _metricRow(
            icon: Icons.my_location,
            iconColor: Colors.blue,
            label: 'Pickup',
            value:
                ride.pickup.humanReadableAddress ??
                ride.pickup.placeName ??
                'Pickup',
          ),
          const SizedBox(height: 10),
          _metricRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            label: 'Destination',
            value:
                ride.destination.humanReadableAddress ??
                ride.destination.placeName ??
                'Destination',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryPill(
                  icon: Icons.payments_outlined,
                  label: 'K${ride.fareEstimate.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryPill(
                  icon: Icons.route,
                  label: '${(ride.routeMeters / 1000).toStringAsFixed(1)} km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessingRideAction
                      ? null
                      : () => _advanceRideStatus('cancelled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessingRideAction
                      ? null
                      : ride.status == 'accepted'
                      ? () => _advanceRideStatus('arrived')
                      : ride.status == 'arrived'
                      ? () => _advanceRideStatus('in_progress')
                      : () => _advanceRideStatus('completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    ride.status == 'accepted'
                        ? 'Arrived'
                        : ride.status == 'arrived'
                        ? 'Start Trip'
                        : 'Complete Trip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _bottomSheet({required Widget child}) {
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHomeMap() {
    return Stack(
      children: [
        GoogleMap(
          padding: EdgeInsets.only(top: 26, bottom: _bottomMapPadding),
          mapType: selectedMapType,
          myLocationEnabled: true,
          polylines: homeMapPolylines,
          markers: homeMapMarkers,
          initialCameraPosition: kGooglePlex,
          onMapCreated: (GoogleMapController mapController) {
            controllerGoogleMap = mapController;
            googleMapCompleterController.complete(mapController);
            _initializeDriverSession();
          },
        ),
        Positioned(
          top: 40,
          left: 18,
          child: PopupMenuButton<MapType>(
            onSelected: (MapType mapType) {
              setState(() {
                selectedMapType = mapType;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
              const PopupMenuItem<MapType>(
                value: MapType.normal,
                child: Text('Normal'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.satellite,
                child: Text('Satellite'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.terrain,
                child: Text('Terrain'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.hybrid,
                child: Text('Hybrid'),
              ),
            ],
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
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
                child: Icon(Icons.layers_outlined, color: Colors.black),
              ),
            ),
          ),
        ),
        Positioned(top: 32, right: 18, child: _buildOnlineSwitchCard()),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: _isLoading
                ? _bottomSheet(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : _activeRideRequest != null
                ? _buildActiveRideSheet()
                : !_isOnline
                ? _buildOfflineSheet()
                : _openRideRequests.isEmpty
                ? _buildWaitingSheet()
                : _buildOpenRequestsSheet(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_activity),
            label: 'Trips',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildHomeMap(), const ActivityTab(), const AccountTab()],
      ),
    );
  }
}
