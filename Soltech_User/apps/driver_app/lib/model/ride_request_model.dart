import 'address_model.dart';

class RideRequestModel {
  RideRequestModel({
    required this.id,
    required this.passengerId,
    required this.assignedDriverId,
    required this.serviceType,
    required this.status,
    required this.pickup,
    required this.destination,
    required this.routeMeters,
    required this.routeSeconds,
    required this.routePolyline,
    required this.fareEstimate,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final String id;
  final String passengerId;
  final String? assignedDriverId;
  final String serviceType;
  final String status;
  final AddressModel pickup;
  final AddressModel destination;
  final int routeMeters;
  final int routeSeconds;
  final String routePolyline;
  final double fareEstimate;
  final int createdAt;
  final int? acceptedAt;
  final int? arrivedAt;
  final int? startedAt;
  final int? completedAt;
  final int? cancelledAt;

  bool get isTerminal => status == 'completed' || status == 'cancelled';

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
      serviceType: _stringFrom(rawMap['serviceType'], fallback: 'taxi'),
      status: _stringFrom(rawMap['status'], fallback: 'searching'),
      pickup: _addressFrom(rawMap['pickup']),
      destination: _addressFrom(rawMap['destination']),
      routeMeters: _intFrom(rawMap['routeMeters']),
      routeSeconds: _intFrom(rawMap['routeSeconds']),
      routePolyline: _stringFrom(rawMap['routePolyline']),
      fareEstimate: _doubleFrom(rawMap['fareEstimate']),
      createdAt: _intFrom(rawMap['createdAt']),
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
}
