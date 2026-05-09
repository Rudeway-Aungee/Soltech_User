import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/models/app_role.dart';
import '../../core/session/app_session.dart';
import 'fleet_admin_entry_page.dart';
import 'fleet_control_home_page.dart';
import 'fleet_control_pending_approval_page.dart';

class FleetAdminGateway extends StatelessWidget {
  const FleetAdminGateway({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSession session = context.watch<AppSession>();

    if (session.isLoading) {
      return const _LoadingPage(message: 'Starting FleetAdmin...');
    }

    if (session.currentUser == null || session.status == AppSessionStatus.signedOut) {
      return const FleetAdminEntryPage();
    }

    if (session.status == AppSessionStatus.fleetPending) {
      return FleetControlPendingApprovalPage(
        initialStatus: session.fleetApprovalStatus ?? 'pending',
      );
    }

    if (session.status == AppSessionStatus.ready &&
        session.selectedRole == AppRole.fleetOwner) {
      return const FleetControlHomePage();
    }

    return _WrongAppPage(
      message: session.message ??
          'This account is not allowed to use this app. Please sign in with the correct fleetOwner account.',
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _WrongAppPage extends StatelessWidget {
  const _WrongAppPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoltechColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 58, color: Colors.redAccent),
                  const SizedBox(height: 20),
                  const Text(
                    'Wrong app for this account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SoltechColors.muted),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.read<AppSession>().signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
