// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Legacy sign-up page kept for compatibility.
// Passenger and Fleet Control registration now happens on the unified WelcomeRolePage.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import 'package:soltech_master_app/features/gateway/welcome_role_page.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeRolePage();
  }
}
