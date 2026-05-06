// CODE COMMENTS -------------------------------------------------------------
// Purpose: Reusable widget used by more than one screen in the Soltech app.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Reusable loading dialog widget.
// It is shown while the app is waiting for Firebase, map, or authentication operations to finish.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  // Message to display to the user (e.g., "Signing in...", "Signing up...").
  final String messageTxt;

  const LoadingDialog({super.key, required this.messageTxt});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.white,
      child: Container(
        margin: const EdgeInsets.all(15),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Spacer for visual breathing room.
              const SizedBox(width: 5,),

              // Progress indicator communicates a blocking async operation.
              // The green color indicates a positive/loading state.
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green)),

              const SizedBox(width: 8,),

              // Caller-specified message (e.g., "Signing in...", "Signing up...").
              // Informs the user what operation is in progress.
              Text(
                messageTxt,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              )
            ]
        ),
      ),
      )
    );
  }
}
