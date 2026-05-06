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
