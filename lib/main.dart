// Firebase and authentication packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Flutter core packages
import 'package:flutter/material.dart';
// Permission handling for location access
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;
// App pages and navigation
import 'package:soltech_app/auth/signin_page.dart';
import 'package:soltech_app/pages/home_page.dart';
import 'package:soltech_app/firebase_options.dart';
import 'appinfo/app_info.dart' show AppInfo;

/// Main entry point for the Soltech App
///
/// Initializes:
/// - Firebase for authentication and data management
/// - Location permissions for map-based services
/// - Routes to SignIn or Home page based on auth state
void main() async {
  // Ensure Flutter binding is initialized before async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific configuration
  // (automatically selects correct settings for Android/iOS/Web)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Request location permission on app startup
  // - Check if permission is already denied
  // - If denied, request permission from user
  await Permission.locationWhenInUse.isDenied.then((value) {
    if (value) {
      Permission.locationWhenInUse.request();
    }
  });

  // Start the Flutter app after all initialization is complete
  runApp(const MyApp());}

/// Root widget for the Soltech App
///
/// Configures:
/// - Material Design theme
/// - Initial route based on authentication state
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppInfo(),
      child: MaterialApp(
        title: 'Users App',
        theme: ThemeData(
          // Use deep purple as the primary color scheme
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        // Route to SignInPage if user is not authenticated, otherwise HomePage
        home: FirebaseAuth.instance.currentUser == null
            ? const SignInPage()
            : const HomePage(),
      ),
    );
  }
}
