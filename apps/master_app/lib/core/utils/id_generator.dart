// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Utility for generating readable IDs such as Driver IDs.
// These IDs are easier for Fleet Admins and Drivers to use than raw Firebase UIDs.
// ---------------------------------------------------------------------------

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
