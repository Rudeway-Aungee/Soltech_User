import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/design_system/app_theme.dart';
import 'firebase_options.dart';
import 'super_admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SoltechSuperAdminApp());
}

class SoltechSuperAdminApp extends StatelessWidget {
  const SoltechSuperAdminApp({super.key});  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soltech Super Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SuperAdminApp(),
    );
  }
}
