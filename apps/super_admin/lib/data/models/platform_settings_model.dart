class PlatformSettingsModel {
  PlatformSettingsModel({
    required this.commissionPercent,
    required this.baseFare,
    required this.minimumFare,
    required this.supportPhone,
  });

  final double commissionPercent;
  final double baseFare;
  final double minimumFare;
  final String supportPhone;

  factory PlatformSettingsModel.fromMap(Map<Object?, Object?> map) {
    double number(String key, double fallback) {
      return double.tryParse((map[key] ?? fallback).toString()) ?? fallback;
    }

    return PlatformSettingsModel(
      commissionPercent: number('commissionPercent', 10),
      baseFare: number('baseFare', 5),
      minimumFare: number('minimumFare', 10),
      supportPhone: (map['supportPhone'] ?? '').toString(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'commissionPercent': commissionPercent,
      'baseFare': baseFare,
      'minimumFare': minimumFare,
      'supportPhone': supportPhone,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }
}