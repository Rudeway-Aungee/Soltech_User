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
