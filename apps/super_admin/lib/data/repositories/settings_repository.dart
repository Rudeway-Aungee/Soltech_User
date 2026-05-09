import '../../core/constants/firebase_paths.dart';
import '../../core/services/database_service.dart';
import '../models/platform_settings_model.dart';

class SettingsRepository {
  final DatabaseService _database = DatabaseService();

  Future<PlatformSettingsModel> getSettings() async {
    final snapshot = await _database.get(
      '${FirebasePaths.platformSettings}/global',
    );

    if (snapshot.value is! Map) {
      return PlatformSettingsModel(
        commissionPercent: 10,
        baseFare: 5,
        minimumFare: 10,
        supportPhone: '',
      );
    }

    return PlatformSettingsModel.fromMap(
      Map<Object?, Object?>.from(snapshot.value as Map),
    );
  }

  Future<void> saveSettings(PlatformSettingsModel settings) {
    return _database.set(
      '${FirebasePaths.platformSettings}/global',
      settings.toMap(),
    );
  }
}