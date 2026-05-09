import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'core/app_state/app_info.dart';
import 'core/design_system/app_theme.dart';
import 'core/session/app_session.dart';
import 'firebase_options.dart';
import 'features/passenger/passenger_app_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    try {
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }
    } catch (_) {}
  }

  runApp(const SoltechPassengerApp());
}

class SoltechPassengerApp extends StatelessWidget {
  const SoltechPassengerApp({super.key});

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
        title: 'Soltech Passenger',
        debugShowCheckedModeBanner: false,
        theme: SoltechTheme.light(),
        home: const PassengerAppGateway(),
      ),
    );
  }
}
