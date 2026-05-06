import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soltech_master_app/driver_pages/home_page.dart' as driver;
import 'package:soltech_master_app/driver_pages/pending_approval_page.dart';
import 'package:soltech_master_app/pages/home_page.dart' as passenger;

import '../../core/design_system/app_theme.dart';
import '../../core/models/app_role.dart';
import '../../core/session/app_session.dart';
import '../fleet_owner/fleet_owner_home_page.dart';
import 'welcome_role_page.dart';

class AppGateway extends StatelessWidget {
  const AppGateway({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSession session = context.watch<AppSession>();

    if (session.isLoading) {
      return const _GatewayLoading();
    }

    if (session.status == AppSessionStatus.unauthorized) {
      return _UnauthorizedPage(message: session.message);
    }

    if (session.status == AppSessionStatus.driverPending) {
      return PendingApprovalPage(
        initialStatus: session.driverApprovalStatus ?? 'pending',
      );
    }

    final AppRole? role = session.selectedRole;
    if (session.currentUser == null) {
      return const WelcomeRolePage();
    }

    if (session.status != AppSessionStatus.ready || role == null) {
      return const WelcomeRolePage();
    }

    return _RoleNavigator(role: role);
  }
}

class _RoleNavigator extends StatelessWidget {
  const _RoleNavigator({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: ValueKey<String>('role-${role.key}'),
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) {
            switch (role) {
              case AppRole.passenger:
                return const passenger.HomePage();
              case AppRole.driver:
                return const driver.HomePage();
              case AppRole.fleetOwner:
                return const FleetOwnerHomePage();
            }
          },
        );
      },
    );
  }
}

class _GatewayLoading extends StatelessWidget {
  const _GatewayLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Starting Soltech...'),
          ],
        ),
      ),
    );
  }
}

class _UnauthorizedPage extends StatelessWidget {
  const _UnauthorizedPage({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SoltechColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 58, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'Mode not available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                message ?? 'This account does not have access to that mode.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: SoltechColors.muted),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.read<AppSession>().clearSelectedRole(),
                child: const Text('Choose Another Mode'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.read<AppSession>().signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
