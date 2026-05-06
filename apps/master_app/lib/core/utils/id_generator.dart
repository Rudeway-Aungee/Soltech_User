import 'dart:math';

class IdGenerator {
  static String generateFleetAdminId() {
    return 'FA-${_generateRandomCode()}';
  }

  static String generateDriverId() {
    return 'DR-${_generateRandomCode()}';
  }

  static String _generateRandomCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    return List<String>.generate(
      10,
      (int index) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
