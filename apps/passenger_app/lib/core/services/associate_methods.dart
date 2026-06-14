// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// AssociateMethods contains small shared helper functions used by UI screens.
// For example, it displays SnackBar messages and may contain reusable validation or helper logic.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

class AssociateMethods {
  /// Display a snackbar message to the user.
  /// Centralizes snackbar creation for consistent UX messaging across the app.
  void showSnackBarMsg(String msg, BuildContext cxt){
    // Centralized snackbar helper so UX messaging is consistent.
    // Snackbars appear at the bottom of the screen and auto-dismiss after a delay.
    final snackBar = SnackBar(
      content: Text(msg)
    );
    ScaffoldMessenger.of(cxt).showSnackBar(snackBar);
  }
}
