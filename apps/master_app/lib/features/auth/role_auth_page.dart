// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Legacy role authentication page.
// The app now uses WelcomeRolePage as the main unified entry screen.
// This file is kept only to prevent old imports/routes from breaking.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../core/models/app_role.dart';
import '../gateway/welcome_role_page.dart';

/// Legacy compatibility wrapper.
///
/// The project now uses one unified entry screen for Passenger, Driver, and
/// Fleet Control authentication. Any old navigation that still points to
/// RoleAuthPage is redirected here so the app never shows a second login page.
class RoleAuthPage extends StatelessWidget {
  const RoleAuthPage({super.key, required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return const WelcomeRolePage();
  }
}
