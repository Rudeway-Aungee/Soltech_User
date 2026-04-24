import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http show Response, get;
import 'package:provider/provider.dart' show Provider;
import 'package:soltech_app/appinfo/app_info.dart' show AppInfo;
import 'package:soltech_app/global.dart';
import 'package:soltech_app/model/address_model.dart';

class GoogleMapMethods {
  /// Generic HTTP GET wrapper for Google API calls.
  /// Handles JSON parsing and error normalization.
  static Future<dynamic> sendRequestToAPI(String apiUrl) async {
    try {
      // Perform a simple GET call to the Google API endpoint.
      final http.Response responseFromAPI = await http.get(Uri.parse(apiUrl));

      if (responseFromAPI.statusCode != 200) {
        // Non-200 responses are treated uniformly by callers.
        return 'error';
      }

      final String dataFromApi = responseFromAPI.body;
      // Decode JSON into dynamic map/list structure.
      final dynamic dataDecoded = jsonDecode(dataFromApi);

      return dataDecoded;
    } catch (_) {
      // Network failures / parse failures are normalized as 'error'.
      return 'error';
    }
  }

  /// Resolve a Google Places place ID into a normalized destination model.
  static Future<AddressModel?> getDestinationDetailsFromPlaceId(
    String placeId,
  ) async {
    final String normalizedPlaceId = placeId.trim();

    if (normalizedPlaceId.isEmpty) {
      return null;
    }

    final Uri placeDetailsUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      <String, String>{
        'place_id': normalizedPlaceId,
        'fields': 'place_id,name,formatted_address,geometry',
        'key': googleMapKey,
      },
    );

    final dynamic responseFromAPI = await sendRequestToAPI(
      placeDetailsUri.toString(),
    );

    if (responseFromAPI == 'error') {
      return null;
    }

    final String status = (responseFromAPI['status'] ?? '').toString();
    final Map<String, dynamic>? result =
        responseFromAPI['result'] as Map<String, dynamic>?;

    if (status != 'OK' || result == null || result.isEmpty) {
      return null;
    }

    return _buildAddressModelFromPlaceDetails(result);
  }

  /// Resolve a typed destination query into a normalized destination model.
  static Future<AddressModel?> getDestinationDetailsFromSearchQuery(
    String searchQuery,
  ) async {
    final String normalizedQuery = searchQuery.trim();

    if (normalizedQuery.isEmpty) {
      return null;
    }

    final Uri geoCodingUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{
        'address': normalizedQuery,
        'components': 'country:PG',
        'key': googleMapKey,
      },
    );

    final dynamic responseFromAPI = await sendRequestToAPI(
      geoCodingUri.toString(),
    );

    if (responseFromAPI == 'error') {
      return null;
    }

    final String status = (responseFromAPI['status'] ?? '').toString();
    final List<dynamic> results =
        (responseFromAPI['results'] as List<dynamic>?) ?? <dynamic>[];

    if (status != 'OK' || results.isEmpty) {
      return null;
    }

    return _buildAddressModelFromGeocodeResult(
      results.first as Map<String, dynamic>,
    );
  }

  /// Reverse geocoding: get address from latitude and longitude.
  /// Converts GPS coordinates into a human-readable address and updates Provider state.
  static Future<String> convertGeoGraphicCoOrdinatesIntoHumanReadableAddress(
    Position position,
    BuildContext context,
  ) async {
    String humanReadableAddress = '';

    // Construct the reverse-geocoding URL using Uri helpers.
    final Uri geoCodingUri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      <String, String>{
        'latlng': '${position.latitude},${position.longitude}',
        'key': googleMapKey,
      },
    );

    // Call the geocoding API.
    final dynamic responseFromAPI = await sendRequestToAPI(
      geoCodingUri.toString(),
    );

    if (!context.mounted) {
      return 'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }

    if (responseFromAPI == 'error') {
      // API failed - use coordinates as fallback
      humanReadableAddress =
          'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      _updatePickupLocationWithAddress(context, humanReadableAddress, position);
      return humanReadableAddress;
    }

    // Validate and parse response shape.
    final String status = (responseFromAPI['status'] ?? '').toString();
    final List<dynamic> results =
        (responseFromAPI['results'] as List<dynamic>?) ?? <dynamic>[];

    if (status != 'OK' || results.isEmpty) {
      // No results from API - use coordinates as fallback
      humanReadableAddress =
          'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      _updatePickupLocationWithAddress(context, humanReadableAddress, position);
      return humanReadableAddress;
    }

    // Try each result in order (first is closest/most relevant)
    for (final dynamic resultItem in results) {
      final Map<String, dynamic> result = resultItem as Map<String, dynamic>;
      humanReadableAddress = (result['formatted_address'] ?? '')
          .toString()
          .trim();

      // If we found a formatted address, use it
      if (humanReadableAddress.isNotEmpty) {
        _updatePickupLocationWithAddress(
          context,
          humanReadableAddress,
          position,
        );
        return humanReadableAddress;
      }

      // Try to build from address_components
      final List<dynamic> addressComponents =
          (result['address_components'] as List<dynamic>?) ?? <dynamic>[];

      if (addressComponents.isNotEmpty) {
        humanReadableAddress = _buildAddressFromComponents(addressComponents);

        if (humanReadableAddress.isNotEmpty) {
          _updatePickupLocationWithAddress(
            context,
            humanReadableAddress,
            position,
          );
          return humanReadableAddress;
        }
      }
    }

    // Final fallback: use coordinates if we still have nothing
    if (humanReadableAddress.isEmpty) {
      humanReadableAddress =
          'Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }

    _updatePickupLocationWithAddress(context, humanReadableAddress, position);
    return humanReadableAddress;
  }

  static AddressModel? _buildAddressModelFromPlaceDetails(
    Map<String, dynamic> placeDetails,
  ) {
    final Map<String, dynamic> geometry =
        (placeDetails['geometry'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final Map<String, dynamic> location =
        (geometry['location'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final double? latitude = _parseCoordinate(location['lat']);
    final double? longitude = _parseCoordinate(location['lng']);

    if (latitude == null || longitude == null) {
      return null;
    }

    final String formattedAddress = (placeDetails['formatted_address'] ?? '')
        .toString()
        .trim();
    final String placeName = (placeDetails['name'] ?? '').toString().trim();
    final String resolvedPlaceId = (placeDetails['place_id'] ?? '')
        .toString()
        .trim();

    return AddressModel(
      humanReadableAddress: formattedAddress.isNotEmpty
          ? formattedAddress
          : placeName,
      latitudePosition: latitude,
      longitudePosition: longitude,
      placeID: resolvedPlaceId.isNotEmpty ? resolvedPlaceId : null,
      placeName: placeName.isNotEmpty ? placeName : formattedAddress,
    );
  }

  static AddressModel? _buildAddressModelFromGeocodeResult(
    Map<String, dynamic> geocodeResult,
  ) {
    final Map<String, dynamic> geometry =
        (geocodeResult['geometry'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final Map<String, dynamic> location =
        (geometry['location'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final double? latitude = _parseCoordinate(location['lat']);
    final double? longitude = _parseCoordinate(location['lng']);

    if (latitude == null || longitude == null) {
      return null;
    }

    final String formattedAddress = (geocodeResult['formatted_address'] ?? '')
        .toString()
        .trim();
    final String resolvedPlaceId = (geocodeResult['place_id'] ?? '')
        .toString()
        .trim();
    final List<dynamic> addressComponents =
        (geocodeResult['address_components'] as List<dynamic>?) ?? <dynamic>[];
    final String placeName = _buildAddressFromComponents(addressComponents);

    return AddressModel(
      humanReadableAddress: formattedAddress.isNotEmpty
          ? formattedAddress
          : placeName,
      latitudePosition: latitude,
      longitudePosition: longitude,
      placeID: resolvedPlaceId.isNotEmpty ? resolvedPlaceId : null,
      placeName: placeName.isNotEmpty ? placeName : formattedAddress,
    );
  }

  static double? _parseCoordinate(dynamic coordinateValue) {
    if (coordinateValue is num) {
      return coordinateValue.toDouble();
    }

    return double.tryParse(coordinateValue?.toString() ?? '');
  }

  /// Helper: Build address string from address components
  static String _buildAddressFromComponents(List<dynamic> addressComponents) {
    String? street;
    String? city;
    String? state;
    String? country;

    for (final dynamic component in addressComponents) {
      final Map<String, dynamic> comp = component as Map<String, dynamic>;
      final List<dynamic> types =
          (comp['types'] as List<dynamic>?) ?? <dynamic>[];
      final String longName = (comp['long_name'] ?? '').toString().trim();

      if (types.contains('street_number')) {
        street = longName;
      } else if (types.contains('route')) {
        if (street != null) {
          street = '$street $longName';
        } else {
          street = longName;
        }
      } else if (types.contains('locality')) {
        city = longName;
      } else if (types.contains('administrative_area_level_1')) {
        state = longName;
      } else if (types.contains('country')) {
        country = longName;
      }
    }

    // Build address from components, using only non-empty parts
    final List<String> parts = <String>[
      if (street != null && street.isNotEmpty) street,
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
      if (country != null && country.isNotEmpty) country,
    ];

    return parts.isNotEmpty ? parts.join(', ') : '';
  }

  /// Helper method to update pickup location in Provider state.
  static void _updatePickupLocationWithAddress(
    BuildContext context,
    String address,
    Position position,
  ) {
    final AddressModel userCurrentAddress = AddressModel();
    userCurrentAddress.humanReadableAddress = address;
    userCurrentAddress.placeName = address;
    userCurrentAddress.latitudePosition = position.latitude;
    userCurrentAddress.longitudePosition = position.longitude;

    if (context.mounted) {
      Provider.of<AppInfo>(
        context,
        listen: false,
      ).updatePickupLocationAddress(userCurrentAddress);
    }
  }

  /// Fetch direction details from Directions API including intermediate waypoints.
  static Future<dynamic> getDirectionDetails(
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) async {
    String waypointsStr = "";
    if (waypoints.isNotEmpty) {
      waypointsStr = "&waypoints=optimize:true";
      for (LatLng point in waypoints) {
        waypointsStr += "|${point.latitude},${point.longitude}";
      }
    }

    String urlDirectionDetails =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}$waypointsStr&key=$googleMapKey";

    var responseFromDirectionAPI = await sendRequestToAPI(urlDirectionDetails);

    if (responseFromDirectionAPI == "error") {
      return null;
    }

    return responseFromDirectionAPI;
  }

  /// Decode Google Maps overview_polyline into a List of LatLng
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return poly;
  }
}
