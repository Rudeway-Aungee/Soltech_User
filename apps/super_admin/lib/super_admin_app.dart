import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'core/services/admin_permission_service.dart';
import 'features/auth/access_denied_page.dart';
import 'features/auth/login_page.dart';
import 'features/shell/super_admin_shell.dart';

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<bool>(
          future: AdminPermissionService().isActiveSuperAdmin(user.uid),
          builder: (context, permissionSnapshot) {
            if (permissionSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (permissionSnapshot.data != true) {
              return const AccessDeniedPage();
            }

            return SuperAdminShell(currentUser: user);
          },
        );
      },
    );
  }
}