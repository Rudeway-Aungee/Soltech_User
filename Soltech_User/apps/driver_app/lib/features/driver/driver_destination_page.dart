// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Driver destination/map page kept for driver-side navigation support.
// Some map selection functionality is shared with passenger flow but used differently by drivers.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:soltech_driver_app/global.dart';

import 'package:soltech_driver_app/core/app_state/app_info.dart';
import 'package:soltech_driver_app/core/services/google_map_methods.dart';
import 'package:soltech_driver_app/core/models/address_model.dart';
import 'package:soltech_driver_app/core/models/prediction_model.dart';
import 'package:soltech_driver_app/core/widgets/prediction_places_ui.dart';

class SelectDestinationPage extends StatefulWidget {
  const SelectDestinationPage({super.key});

  @override
  State<SelectDestinationPage> createState() => _SelectDestinationPageState();
}

class _SelectDestinationPageState extends State<SelectDestinationPage> {
  // ── Map state ─────────────────────────────────────────────────
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  LatLng? _cameraPosition;
  bool _isDragging = false;
  MapType _mapType = MapType.normal;

  // ── Stop state ────────────────────────────────────────────────
  final List<AddressModel> _selectedStops = [];
  final Set<Marker> _markers = {};

  // ── Current pin address ───────────────────────────────────────
  AddressModel? _pinnedAddress;
  bool _isFetchingAddress = false;

  // ── Text search state ─────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<PredictionModel> _predictions = [];
  int _searchToken = 0;
  bool _isResolvingPrediction = false;

  // ── Colors for stops ──────────────────────────────────────────
  static const List<double> _markerHues = [
    BitmapDescriptor.hueOrange,
    BitmapDescriptor.hueAzure,
    BitmapDescriptor.hueGreen,
    BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueRose,
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueMagenta,
    BitmapDescriptor.hueYellow,
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    _searchFocusNode.addListener(() {
      // When the field loses focus (e.g., user taps map), hide predictions
      if (!_searchFocusNode.hasFocus) {
        setState(() => _predictions = []);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────

  Future<void> _fetchUserLocation() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final LatLng latLng = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _cameraPosition = latLng);

      final GoogleMapController ctrl = await _mapController.future;
      ctrl.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15),
      ));
    } catch (_) {
      // Fallback — map stays at default LatLng
    }
  }

  // ── Geocoding (camera idle) ───────────────────────────────────

  Future<void> _geocodeCameraPosition(LatLng position) async {
    setState(() {
      _isFetchingAddress = true;
      _pinnedAddress = null;
    });

    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {'latlng': '${position.latitude},${position.longitude}', 'key': googleMapKey},
    );

    final dynamic resp = await GoogleMapMethods.sendRequestToAPI(uri.toString());
    if (!mounted) return;

    final AddressModel addr = AddressModel()
      ..latitudePosition = position.latitude
      ..longitudePosition = position.longitude;

    if (resp != 'error' && resp['status'] == 'OK' && (resp['results'] as List).isNotEmpty) {
      addr.humanReadableAddress = resp['results'][0]['formatted_address'] as String;
      final List comps = resp['results'][0]['address_components'] as List;
      addr.placeName = comps.isNotEmpty ? comps[0]['short_name'] as String : addr.humanReadableAddress;
    } else {
      addr.humanReadableAddress =
          'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      addr.placeName = 'Pinned Location';
    }

    setState(() {
      _pinnedAddress = addr;
      _isFetchingAddress = false;
    });
  }

  // ── Text search ───────────────────────────────────────────────

  Future<void> _searchPlace(String input) async {
    final String trimmed = input.trim();
    final int token = ++_searchToken;

    if (trimmed.length <= 1) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': trimmed, 'key': googleMapKey, 'components': 'country:PG'},
    );

    final dynamic resp = await GoogleMapMethods.sendRequestToAPI(uri.toString());
    if (!mounted || token != _searchToken) return;

    if (resp != 'error' && resp['status'] == 'OK') {
      final List<dynamic> raw = (resp['predictions'] as List<dynamic>?) ?? [];
      setState(() {
        _predictions = raw.map((e) => PredictionModel.fromJson(e as Map<String, dynamic>)).toList();
      });
    } else {
      setState(() {
        _predictions = [];
      });
    }
  }

  Future<void> _selectPrediction(PredictionModel pred) async {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() {
      _isResolvingPrediction = true;
      _predictions = [];
    });

    final AddressModel? addr = await GoogleMapMethods.getDestinationDetailsFromPlaceId(pred.placeId ?? '');
    if (!mounted) return;

    setState(() => _isResolvingPrediction = false);

    if (addr != null) {
      _addStopFromAddress(addr);

      // Animate camera to the selected place
      final GoogleMapController ctrl = await _mapController.future;
      ctrl.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(addr.latitudePosition!, addr.longitudePosition!), zoom: 15),
      ));
    }
  }

  // ── Stop management ───────────────────────────────────────────

  void _addStopFromAddress(AddressModel addr) {
    final int idx = _selectedStops.length;
    final double hue = _markerHues[idx % _markerHues.length];

    setState(() {
      _selectedStops.add(addr);
      _markers.add(Marker(
        markerId: MarkerId('stop_$idx'),
        position: LatLng(addr.latitudePosition!, addr.longitudePosition!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(title: 'Stop ${idx + 1}: ${addr.placeName ?? addr.humanReadableAddress}'),
      ));
    });
  }

  void _addPinnedStop() {
    if (_pinnedAddress == null) return;
    _addStopFromAddress(_pinnedAddress!);
    setState(() => _pinnedAddress = null);
  }

  void _removeStop(int index) {
    setState(() {
      _selectedStops.removeAt(index);
      // Rebuild markers from scratch to keep IDs in sync
      _markers.clear();
      for (int i = 0; i < _selectedStops.length; i++) {
        final AddressModel addr = _selectedStops[i];
        final double hue = _markerHues[i % _markerHues.length];
        _markers.add(Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(addr.latitudePosition!, addr.longitudePosition!),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}: ${addr.placeName ?? addr.humanReadableAddress}'),
        ));
      }
    });
  }

  // ── Route confirmation ────────────────────────────────────────

  void _confirmRoute() {
    if (_selectedStops.isEmpty) return;

    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);
    appInfo.clearIntermediateStops();

    // Last stop = final destination; everything before = intermediate
    for (int i = 0; i < _selectedStops.length - 1; i++) {
      appInfo.addIntermediateStop(_selectedStops[i]);
    }
    appInfo.updateDestinationLocationAddress(_selectedStops.last);

    Navigator.pop(context, 'route_confirmed');
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── 1. Full-screen Google Map ──────────────────────────
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition: CameraPosition(
              target: _cameraPosition ?? const LatLng(-9.4431, 147.1803),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            onMapCreated: (ctrl) => _mapController.complete(ctrl),
            onCameraMoveStarted: () => setState(() {
              _isDragging = true;
              _pinnedAddress = null;
            }),
            onCameraMove: (pos) => _cameraPosition = pos.target,
            onCameraIdle: () {
              setState(() => _isDragging = false);
              if (_cameraPosition != null) _geocodeCameraPosition(_cameraPosition!);
            },
          ),

          // ── 2. Crosshair pin ──────────────────────────────────
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(
                Icons.location_on,
                size: 42,
                color: _isDragging ? Colors.black45 : Colors.red,
              ),
            ),
          ),

          // ── 3. Top row: Back + Map-type selector ──────────────
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _floatingCircleButton(
                  onTap: () => Navigator.pop(context),
                  icon: Icons.arrow_back,
                ),
                _mapTypeButton(),
              ],
            ),
          ),

          // ── 4. Floating search card ───────────────────────────
          Positioned(
            top: topPadding + 72,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pickup (read-only)
                  Row(
                    children: [
                      const Icon(Icons.my_location, color: Colors.blue, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          Provider.of<AppInfo>(context, listen: true).userPickupLocation?.humanReadableAddress ??
                              Provider.of<AppInfo>(context, listen: true).userPickupLocation?.placeName ??
                              'Pickup Location',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 9),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(height: 18, child: VerticalDivider(color: Colors.grey, thickness: 1)),
                    ),
                  ),
                  // Search field
                  Row(
                    children: [
                      const Icon(Icons.search, color: Colors.red, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _searchPlace,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search for a destination...',
                            hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_isResolvingPrediction)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 5. Search autocomplete results overlay ────────────
          if (_predictions.isNotEmpty)
            Positioned(
              top: topPadding + 170,
              left: 16,
              right: 16,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => PredictionPlacesUi(
                      predictionPlacesData: _predictions[index],
                      onPressed: () => _selectPrediction(_predictions[index]),
                    ),
                  ),
                ),
              ),
            ),

          // ── 6. Stops list (collapsible chip list) ─────────────
          if (_selectedStops.isNotEmpty)
            Positioned(
              bottom: bottomPadding + 220,
              left: 16,
              right: 16,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _selectedStops.length,
                  itemBuilder: (context, i) {
                    final bool isLast = i == _selectedStops.length - 1;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isLast ? Icons.flag : Icons.radio_button_checked,
                        color: isLast ? Colors.red : Colors.orange,
                        size: 20,
                      ),
                      title: Text(
                        _selectedStops[i].humanReadableAddress ?? _selectedStops[i].placeName ?? 'Stop ${i + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(isLast ? 'Final Destination' : 'Stop ${i + 1}', style: const TextStyle(fontSize: 11)),
                      trailing: GestureDetector(
                        onTap: () => _removeStop(i),
                        child: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── 7. Bottom controls sheet ──────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + bottomPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 14),

                  // Current pin address
                  if (_isFetchingAddress)
                    const SizedBox(height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (_pinnedAddress != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pinnedAddress!.humanReadableAddress ?? 'Selected Location',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text('Drag the map or search to add a stop', style: TextStyle(color: Colors.grey, fontSize: 13)),

                  const SizedBox(height: 14),

                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: (_pinnedAddress == null || _isFetchingAddress) ? null : _addPinnedStop,
                            icon: const Icon(Icons.add_location_alt, size: 18),
                            label: const Text('Add Location', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedStops.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _confirmRoute,
                              icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                              label: Text(
                                'Confirm (${_selectedStops.length})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────

  Widget _floatingCircleButton({required VoidCallback onTap, required IconData icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1)],
        ),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }

  Widget _mapTypeButton() {
    return PopupMenuButton<MapType>(
      onSelected: (t) => setState(() => _mapType = t),
      itemBuilder: (_) => [
        const PopupMenuItem(value: MapType.normal, child: Row(children: [Icon(Icons.map), SizedBox(width: 10), Text('Normal')])),
        const PopupMenuItem(value: MapType.satellite, child: Row(children: [Icon(Icons.satellite), SizedBox(width: 10), Text('Satellite')])),
        const PopupMenuItem(value: MapType.terrain, child: Row(children: [Icon(Icons.terrain), SizedBox(width: 10), Text('Terrain')])),
        const PopupMenuItem(value: MapType.hybrid, child: Row(children: [Icon(Icons.layers), SizedBox(width: 10), Text('Hybrid')])),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1)],
        ),
        child: const Icon(Icons.layers_outlined, color: Colors.black, size: 22),
      ),
    );
  }
}
