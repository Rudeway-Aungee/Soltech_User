// CODE COMMENTS -------------------------------------------------------------
// Purpose: Starts the Soltech Flutter app, initializes Firebase, registers Provider state, and opens the app gateway.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Soltech application entry point.
// This file starts Firebase, registers app-wide providers, and opens the AppGateway.
// AppGateway then decides whether to show the unified login screen or the correct user dashboard.
// ---------------------------------------------------------------------------

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'core/app_state/app_info.dart';
import 'core/design_system/app_theme.dart';
import 'core/session/app_session.dart';
import 'features/gateway/app_gateway.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Web note:
  // permission_handler is mainly for mobile platform permissions.
  // Calling it during Flutter Web startup can stop the app before the
  // first screen renders, leaving Chrome on a blank white page.
  // For web, the browser asks for location permission only when a map/GPS
  // feature actually requests the current position.
  if (!kIsWeb) {
    try {
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }
    } catch (_) {
      // Do not block app startup if permission handling fails.
    }
  }

  runApp(const SoltechMasterApp());
}

class SoltechMasterApp extends StatelessWidget {
  const SoltechMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppInfo>(create: (_) => AppInfo()),
        ChangeNotifierProvider<AppSession>(
          create: (_) => AppSession()..bootstrap(),
        ),
      ],
      child: MaterialApp(
        title: 'Soltech',
        debugShowCheckedModeBanner: false,
        theme: SoltechTheme.light(),
        home: const AppGateway(),
      ),
    );
  }
}
