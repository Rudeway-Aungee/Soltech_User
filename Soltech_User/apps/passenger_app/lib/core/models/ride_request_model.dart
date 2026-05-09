// CODE COMMENTS -------------------------------------------------------------
// Purpose: Data model that converts Firebase map data into safer Dart objects for the UI.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Data model file.
// Models convert Firebase/database map data into Dart objects so the UI can use typed values safely.
// ---------------------------------------------------------------------------

import 'package:soltech_app/core/models/address_model.dart';

class RideRequestModel {
  RideRequestModel({
    required this.id,
    required this.passengerId,
    required this.assignedDriverId,
    this.passengerName = '',
    this.passengerPhone = '',
    required this.serviceType,
    required this.status,
    required this.pickup,
    required this.destination,
    required this.routeMeters,
    required this.routeSeconds,
    required this.routePolyline,
    required this.fareEstimate,
    required this.createdAt,
    this.paymentMethod = 'cash',
    this.serviceTypeKey = '',
    this.stops = const <AddressModel>[],
    this.fleetId = '',
    this.vehicleId = '',
    this.assignedDriver = const <String, dynamic>{},
    this.driverEarnings = 0,
    this.fleetEarnings = 0,
    this.platformCommission = 0,
    this.paymentStatus = '',
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final String id;
  final String passengerId;
  final String? assignedDriverId;
  final String passengerName;
  final String passengerPhone;
  final String serviceType;
  final String serviceTypeKey;
  final String status;
  final AddressModel pickup;
  final AddressModel destination;
  final List<AddressModel> stops;
  final int routeMeters;
  final int routeSeconds;
  final String routePolyline;
  final double fareEstimate;
  final String paymentMethod;
  final int createdAt;
  final String fleetId;
  final String vehicleId;
  final Map<String, dynamic> assignedDriver;
  final double driverEarnings;
  final double fleetEarnings;
  final double platformCommission;
  final String paymentStatus;
  final int? acceptedAt;
  final int? arrivedAt;
  final int? startedAt;
  final int? completedAt;
  final int? cancelledAt;

  bool get isTerminal => status == 'completed' || status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  static RideRequestModel? fromSnapshotValue(String id, Object? snapshotValue) {
    if (snapshotValue is! Map) {
      return null;
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(
      snapshotValue,
    );

    return RideRequestModel(
      id: id,
      passengerId: _stringFrom(rawMap['passengerId']),
      assignedDriverId: _nullableStringFrom(rawMap['assignedDriverId']),
      passengerName: _stringFrom(rawMap['passengerName']),
      passengerPhone: _stringFrom(rawMap['passengerPhone']),
      serviceType: _stringFrom(rawMap['serviceType'], fallback: 'City Ride'),
      serviceTypeKey: _stringFrom(rawMap['serviceTypeKey']),
      status: _stringFrom(rawMap['status'], fallback: 'searching'),
      pickup: _addressFrom(rawMap['pickup']),
      destination: _addressFrom(rawMap['destination']),
      stops: _addressListFrom(rawMap['stops']),
      routeMeters: _intFrom(rawMap['routeMeters']),
      routeSeconds: _intFrom(rawMap['routeSeconds']),
      routePolyline: _stringFrom(rawMap['routePolyline']),
      fareEstimate: _doubleFrom(rawMap['fareEstimate']),
      paymentMethod: _stringFrom(rawMap['paymentMethod'], fallback: 'cash'),
      createdAt: _intFrom(rawMap['createdAt']),
      fleetId: _stringFrom(rawMap['fleetId']),
      vehicleId: _stringFrom(rawMap['vehicleId']),
      assignedDriver: _stringMapFrom(rawMap['assignedDriver']),
      driverEarnings: _doubleFrom(rawMap['driverEarnings']),
      fleetEarnings: _doubleFrom(rawMap['fleetEarnings']),
      platformCommission: _doubleFrom(rawMap['platformCommission']),
      paymentStatus: _stringFrom(rawMap['paymentStatus']),
      acceptedAt: _nullableIntFrom(rawMap['acceptedAt']),
      arrivedAt: _nullableIntFrom(rawMap['arrivedAt']),
      startedAt: _nullableIntFrom(rawMap['startedAt']),
      completedAt: _nullableIntFrom(rawMap['completedAt']),
      cancelledAt: _nullableIntFrom(rawMap['cancelledAt']),
    );
  }

  static AddressModel _addressFrom(Object? value) {
    if (value is! Map) {
      return AddressModel();
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(value);

    return AddressModel(
      humanReadableAddress: _nullableStringFrom(rawMap['address']),
      latitudePosition: _nullableDoubleFrom(rawMap['latitude']),
      longitudePosition: _nullableDoubleFrom(rawMap['longitude']),
      placeName: _nullableStringFrom(rawMap['name']),
    );
  }

  static List<AddressModel> _addressListFrom(Object? value) {
    if (value == null) {
      return const <AddressModel>[];
    }

    final List<AddressModel> stops = <AddressModel>[];

    if (value is List) {
      for (final Object? item in value) {
        if (item != null) {
          stops.add(_addressFrom(item));
        }
      }
    } else if (value is Map) {
      final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(value);
      final List<MapEntry<Object?, Object?>> entries = rawMap.entries.toList()
        ..sort((MapEntry<Object?, Object?> a, MapEntry<Object?, Object?> b) {
          final int aIndex = int.tryParse((a.key ?? '').toString()) ?? 0;
          final int bIndex = int.tryParse((b.key ?? '').toString()) ?? 0;
          return aIndex.compareTo(bIndex);
        });

      for (final MapEntry<Object?, Object?> entry in entries) {
        stops.add(_addressFrom(entry.value));
      }
    }

    return stops;
  }

  Map<String, dynamic> toHistoryMap() {
    return <String, dynamic>{
      'rideId': id,
      'passengerId': passengerId,
      'assignedDriverId': assignedDriverId ?? '',
      'fleetId': fleetId,
      'vehicleId': vehicleId,
      'serviceType': serviceType,
      'serviceTypeKey': serviceTypeKey,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'status': status,
      'pickup': _addressToMap(pickup),
      'destination': _addressToMap(destination),
      'stops': stops.map(_addressToMap).toList(),
      'routeMeters': routeMeters,
      'routeSeconds': routeSeconds,
      'fareEstimate': fareEstimate,
      'driverEarnings': driverEarnings,
      'fleetEarnings': fleetEarnings,
      'platformCommission': platformCommission,
      'assignedDriver': assignedDriver,
      'createdAt': createdAt,
      'acceptedAt': acceptedAt,
      'arrivedAt': arrivedAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
      'cancelledAt': cancelledAt,
    };
  }

  static Map<String, dynamic> _addressToMap(AddressModel address) {
    return <String, dynamic>{
      'address': address.humanReadableAddress ?? address.placeName ?? '',
      'name': address.placeName ?? address.humanReadableAddress ?? '',
      'latitude': address.latitudePosition,
      'longitude': address.longitudePosition,
    };
  }

  static String _stringFrom(Object? value, {String fallback = ''}) {
    final String? parsed = _nullableStringFrom(value);
    if (parsed == null || parsed.isEmpty) {
      return fallback;
    }

    return parsed;
  }

  static String? _nullableStringFrom(Object? value) {
    final String parsed = (value ?? '').toString().trim();
    if (parsed.isEmpty || parsed == 'null') {
      return null;
    }

    return parsed;
  }

  static int _intFrom(Object? value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static int? _nullableIntFrom(Object? value) {
    if (value == null) {
      return null;
    }

    return _intFrom(value);
  }

  static double _doubleFrom(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  static double? _nullableDoubleFrom(Object? value) {
    if (value == null) {
      return null;
    }

    return _doubleFrom(value);
  }

  static Map<String, dynamic> _stringMapFrom(Object? value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }

    final Map<Object?, Object?> rawMap = Map<Object?, Object?>.from(value);
    return rawMap.map(
      (Object? key, Object? value) =>
          MapEntry<String, dynamic>((key ?? '').toString(), value),
    );
  }
}
