import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/admin_card.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AdminCard(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 60, color: AppColors.danger),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This account is not registered as an active Super Admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () => AuthService().logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}