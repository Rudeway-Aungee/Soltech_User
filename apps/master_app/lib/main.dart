import 'package:firebase_core/firebase_core.dart';
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

  if (await Permission.locationWhenInUse.isDenied) {
    await Permission.locationWhenInUse.request();
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
