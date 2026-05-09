// CODE COMMENTS -------------------------------------------------------------
// Purpose: Reusable widget used by more than one screen in the Soltech app.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Reusable UI widget for selecting a role.
// The unified entry screen uses role cards/tabs for Passenger, Driver, and Fleet Control.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_role.dart';
import '../session/app_session.dart';

class RoleSwitcherButton extends StatelessWidget {
  const RoleSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppSession session = context.watch<AppSession>();
    final List<AppRole> roles = session.availableRoles.toList()
      ..sort((AppRole a, AppRole b) => a.index.compareTo(b.index));

    if (roles.length < 2) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.swap_horiz, color: Colors.black87),
      title: const Text('Switch Mode'),
      subtitle: Text('Current: ${session.selectedRole?.title ?? 'None'}'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showRoleSheet(context, session, roles),
    );
  }

  void _showRoleSheet(
    BuildContext context,
    AppSession session,
    List<AppRole> roles,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Switch Mode',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final AppRole role in roles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconFor(role)),
                    title: Text(role.title),
                    subtitle: Text(role.shortAction),
                    trailing: session.selectedRole == role
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final bool switched = await session.switchRole(role);
                      if (!context.mounted || switched) {
                        return;
                      }

                      final String message =
                          session.message ??
                          'Unable to switch modes right now.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(AppRole role) {
    switch (role) {
      case AppRole.passenger:
        return Icons.person_pin_circle_outlined;
      case AppRole.driver:
        return Icons.local_taxi_outlined;
      case AppRole.fleetOwner:
        return Icons.business_center_outlined;
    }
  }
}
