// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Legacy sign-in page kept for compatibility.
// Normal users should now enter through the unified WelcomeRolePage.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import 'package:soltech_master_app/features/gateway/welcome_role_page.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeRolePage();
  }
}
