import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;
import 'package:soltech_driver_app/appinfo/app_info.dart' show AppInfo;
import 'package:soltech_driver_app/auth/signin_page.dart';
import 'package:soltech_driver_app/firebase_options.dart';
import 'package:soltech_driver_app/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Permission.locationWhenInUse.isDenied.then((bool value) {
    if (value) {
      Permission.locationWhenInUse.request();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (BuildContext context) => AppInfo(),
      child: MaterialApp(
        title: 'Soltech Driver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        ),
        home: FirebaseAuth.instance.currentUser == null
            ? const SignInPage()
            : const HomePage(),
      ),
    );
  }
}
