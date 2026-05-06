import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:soltech_master_app/appinfo/app_info.dart';
import 'package:soltech_master_app/global.dart';
import 'package:soltech_master_app/methods/google_map_methods.dart';
import 'package:soltech_master_app/model/address_model.dart';
import 'package:soltech_master_app/model/prediction_model.dart';
import 'package:soltech_master_app/widgets/prediction_places_ui.dart';

class SelectDestinationPage extends StatefulWidget {
  const SelectDestinationPage({super.key});

  @override
  State<SelectDestinationPage> createState() => _SelectDestinationPageState();
}

class _SelectDestinationPageState extends State<SelectDestinationPage> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  LatLng? _cameraPosition;
  MapType _mapType = MapType.normal;
  bool _isPinMode = false;
  bool _isDraggingMap = false;
  bool _isFetchingPinnedAddress = false;
  bool _isResolvingPrediction = false;
  int _searchToken = 0;

  AddressModel? _pinnedAddress;
  final List<AddressModel> _selectedStops = <AddressModel>[];
  final Set<Marker> _markers = <Marker>{};
  List<PredictionModel> _predictions = <PredictionModel>[];

  static const List<double> _markerHues = <double>[
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
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() => _predictions = <PredictionModel>[]);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLocation() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final LatLng userLatLng = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _cameraPosition = userLatLng);
      }

      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 15),
        ),
      );
    } catch (_) {
      // Keep the default map position if location permission or network fails.
    }
  }

  Future<void> _geocodeCameraPosition(LatLng position) async {
    if (!_isPinMode) {
      return;
    }

    setState(() {
      _isFetchingPinnedAddress = true;
      _pinnedAddress = null;
    });

    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{
        'latlng': '${position.latitude},${position.longitude}',
        'key': googleMapKey,
      },
    );

    final dynamic response = await GoogleMapMethods.sendRequestToAPI(
      uri.toString(),
    );
    if (!mounted) {
      return;
    }

    final AddressModel address = AddressModel()
      ..latitudePosition = position.latitude
      ..longitudePosition = position.longitude;

    if (response != 'error' &&
        response['status'] == 'OK' &&
        (response['results'] as List).isNotEmpty) {
      address.humanReadableAddress =
          response['results'][0]['formatted_address'] as String;
      final List<dynamic> components =
          response['results'][0]['address_components'] as List<dynamic>;
      address.placeName = components.isNotEmpty
          ? components[0]['short_name'] as String
          : address.humanReadableAddress;
    } else {
      address.humanReadableAddress =
          'Pinned Location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
      address.placeName = 'Pinned Location';
    }

    setState(() {
      _pinnedAddress = address;
      _isFetchingPinnedAddress = false;
    });
  }

  Future<void> _searchPlace(String input) async {
    final String trimmed = input.trim();
    final int token = ++_searchToken;

    if (trimmed.length <= 1) {
      setState(() => _predictions = <PredictionModel>[]);
      return;
    }

    final Uri uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      <String, String>{
        'input': trimmed,
        'key': googleMapKey,
        'components': 'country:PG',
      },
    );

    final dynamic response = await GoogleMapMethods.sendRequestToAPI(
      uri.toString(),
    );
    if (!mounted || token != _searchToken) {
      return;
    }

    if (response != 'error' && response['status'] == 'OK') {
      final List<dynamic> rawPredictions =
          (response['predictions'] as List<dynamic>?) ?? <dynamic>[];
      setState(() {
        _predictions = rawPredictions
            .map((dynamic item) =>
                PredictionModel.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } else {
      setState(() => _predictions = <PredictionModel>[]);
    }
  }

  Future<void> _selectPrediction(PredictionModel prediction) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isResolvingPrediction = true;
      _predictions = <PredictionModel>[];
    });

    final AddressModel? address =
        await GoogleMapMethods.getDestinationDetailsFromPlaceId(
      prediction.placeId ?? '',
    );

    if (!mounted) {
      return;
    }

    setState(() => _isResolvingPrediction = false);

    if (address == null ||
        address.latitudePosition == null ||
        address.longitudePosition == null) {
      associateMethods.showSnackBarMsg(
        'Unable to select that location. Please try another place.',
        context,
      );
      return;
    }

    _searchController.clear();
    _addStop(address);

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(address.latitudePosition!, address.longitudePosition!),
          zoom: 15,
        ),
      ),
    );
  }

  void _togglePinMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isPinMode = !_isPinMode;
      _predictions = <PredictionModel>[];
      _pinnedAddress = null;
    });

    if (_isPinMode && _cameraPosition != null) {
      _geocodeCameraPosition(_cameraPosition!);
    }
  }

  void _addPinnedLocation() {
    if (_pinnedAddress == null) {
      associateMethods.showSnackBarMsg(
        'Move the map to the exact destination first.',
        context,
      );
      return;
    }

    _addStop(_pinnedAddress!);
    setState(() {
      _isPinMode = false;
      _pinnedAddress = null;
    });
  }

  void _addStop(AddressModel address) {
    if (_selectedStops.length >= 4) {
      associateMethods.showSnackBarMsg(
        'Maximum of 4 locations allowed for one ride.',
        context,
      );
      return;
    }

    final int index = _selectedStops.length;
    final double hue = _markerHues[index % _markerHues.length];

    setState(() {
      _selectedStops.add(address);
      _markers.add(
        Marker(
          markerId: MarkerId('passenger_stop_$index'),
          position: LatLng(address.latitudePosition!, address.longitudePosition!),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: index == _selectedStops.length - 1
                ? 'Destination'
                : 'Stop ${index + 1}',
            snippet: address.placeName ?? address.humanReadableAddress,
          ),
        ),
      );
    });
  }

  void _removeStop(int index) {
    setState(() {
      _selectedStops.removeAt(index);
      _rebuildStopMarkers();
    });
  }

  void _rebuildStopMarkers() {
    _markers.clear();
    for (int i = 0; i < _selectedStops.length; i++) {
      final AddressModel stop = _selectedStops[i];
      if (stop.latitudePosition == null || stop.longitudePosition == null) {
        continue;
      }
      _markers.add(
        Marker(
          markerId: MarkerId('passenger_stop_$i'),
          position: LatLng(stop.latitudePosition!, stop.longitudePosition!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _markerHues[i % _markerHues.length],
          ),
          infoWindow: InfoWindow(
            title: i == _selectedStops.length - 1
                ? 'Destination'
                : 'Stop ${i + 1}',
            snippet: stop.placeName ?? stop.humanReadableAddress,
          ),
        ),
      );
    }
  }

  void _confirmRoute() {
    if (_selectedStops.isEmpty) {
      associateMethods.showSnackBarMsg(
        'Please select a destination first.',
        context,
      );
      _searchFocusNode.requestFocus();
      return;
    }

    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: false);
    appInfo.clearIntermediateStops();

    for (int i = 0; i < _selectedStops.length - 1; i++) {
      appInfo.addIntermediateStop(_selectedStops[i]);
    }
    appInfo.updateDestinationLocationAddress(_selectedStops.last);

    Navigator.pop(context, 'route_confirmed');
  }

  String _addressLabel(AddressModel? address, String fallback) {
    final String label =
        (address?.humanReadableAddress ?? address?.placeName ?? '').trim();
    if (label.isEmpty) {
      return fallback;
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition: CameraPosition(
              target: _cameraPosition ?? const LatLng(-5.2247, 145.7853),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            onCameraMoveStarted: () {
              if (_isPinMode) {
                setState(() {
                  _isDraggingMap = true;
                  _pinnedAddress = null;
                });
              }
            },
            onCameraMove: (CameraPosition position) {
              _cameraPosition = position.target;
            },
            onCameraIdle: () {
              if (_isPinMode) {
                setState(() => _isDraggingMap = false);
                if (_cameraPosition != null) {
                  _geocodeCameraPosition(_cameraPosition!);
                }
              }
            },
          ),
          if (_isPinMode)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: Icon(
                  Icons.location_on,
                  size: 50,
                  color: _isDraggingMap ? Colors.black45 : Colors.red,
                ),
              ),
            ),
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _circleButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                _mapTypeButton(),
              ],
            ),
          ),
          if (_predictions.isNotEmpty)
            Positioned(
              top: topPadding + 154,
              left: 16,
              right: 16,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.34,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) =>
                        PredictionPlacesUi(
                      predictionPlacesData: _predictions[index],
                      onPressed: () => _selectPrediction(_predictions[index]),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isPinMode
                  ? _buildPinDestinationSheet(bottomPadding)
                  : _buildDestinationSheet(bottomPadding),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationSheet(double bottomPadding) {
    final AppInfo appInfo = Provider.of<AppInfo>(context, listen: true);

    return Container(
      key: const ValueKey<String>('destination_sheet'),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomPadding),
      decoration: _sheetDecoration(),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _grabHandle(),
              const SizedBox(height: 16),
              const Text(
                'Where are you going?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: <Widget>[
                    _locationRow(
                      icon: Icons.my_location,
                      iconColor: Colors.blue,
                      title: 'Current Location',
                      value: _addressLabel(
                        appInfo.userPickupLocation,
                        'Location detected by GPS',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 9),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 22,
                          child: VerticalDivider(
                            color: Colors.grey,
                            thickness: 1,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _searchPlace,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Destination',
                              hintText: 'Search destination here',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_isResolvingPrediction)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildStopsPreview(),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _searchFocusNode.requestFocus();
                        associateMethods.showSnackBarMsg(
                          'Search and select another location to add a stop.',
                          context,
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Stop'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _togglePinMode,
                      icon: const Icon(Icons.push_pin_outlined, size: 18),
                      label: const Text('Pin on Map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirmRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    _selectedStops.isEmpty
                        ? 'Search Destination'
                        : 'Confirm Destination',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDestinationSheet(double bottomPadding) {
    return Container(
      key: const ValueKey<String>('pin_sheet'),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomPadding),
      decoration: _sheetDecoration(),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _grabHandle(),
            const SizedBox(height: 14),
            const Text(
              'Pin destination on map',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Move the map until the pin is exactly on the pickup, stop, or destination point.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: _isFetchingPinnedAddress
                  ? const Row(
                      children: <Widget>[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Detecting selected location...'),
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _addressLabel(
                              _pinnedAddress,
                              'Move the map to choose location',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _togglePinMode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Back to Search'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isFetchingPinnedAddress ? null : _addPinnedLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Use This Pin',
                      style: TextStyle(
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
      ),
    );
  }

  Widget _buildStopsPreview() {
    if (_selectedStops.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.18)),
        ),
        child: const Text(
          'Tip: Add more than one location for multiple stops. The last location becomes the final destination.',
          style: TextStyle(color: Colors.black87, fontSize: 13),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 172),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _selectedStops.length,
        separatorBuilder: (BuildContext context, int index) =>
            const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final bool isFinalDestination = index == _selectedStops.length - 1;
          final AddressModel stop = _selectedStops[index];
          return ListTile(
            dense: true,
            leading: Icon(
              isFinalDestination ? Icons.flag : Icons.more_horiz,
              color: isFinalDestination ? Colors.red : Colors.orange,
            ),
            title: Text(
              _addressLabel(stop, 'Selected location'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              isFinalDestination ? 'Final Destination' : 'Stop ${index + 1}',
            ),
            trailing: IconButton(
              onPressed: () => _removeStop(index),
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
            ),
          );
        },
      ),
    );
  }

  Widget _locationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }

  Widget _mapTypeButton() {
    return PopupMenuButton<MapType>(
      onSelected: (MapType type) => setState(() => _mapType = type),
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<MapType>>[
        PopupMenuItem(
          value: MapType.normal,
          child: Row(children: <Widget>[Icon(Icons.map), SizedBox(width: 10), Text('Normal')]),
        ),
        PopupMenuItem(
          value: MapType.satellite,
          child: Row(children: <Widget>[Icon(Icons.satellite), SizedBox(width: 10), Text('Satellite')]),
        ),
        PopupMenuItem(
          value: MapType.terrain,
          child: Row(children: <Widget>[Icon(Icons.terrain), SizedBox(width: 10), Text('Terrain')]),
        ),
        PopupMenuItem(
          value: MapType.hybrid,
          child: Row(children: <Widget>[Icon(Icons.layers), SizedBox(width: 10), Text('Hybrid')]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.layers_outlined, color: Colors.black, size: 22),
      ),
    );
  }

  Widget _grabHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  BoxDecoration _sheetDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(26),
        topRight: Radius.circular(26),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 18,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }
}
