//import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soltech_app/auth/signin_page.dart';
import 'package:soltech_app/pages/home_page.dart';
import 'package:soltech_app/firebase_options.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Use this for all platforms
    );

  await Permission.locationWhenInUse.isDenied.then((value)
  {
    if (value){
      Permission.locationWhenInUse.request();
    }
  });

  runApp(const MyApp());

            // options: const FirebaseOptions(
            // apiKey: "AIzaSyCTIKIyi_1oDxoBFnLobNV-QTJEt5TC100",
            // authDomain: "soltech-clone.firebaseapp.com",
            // projectId: "soltech-clone",
            // storageBucket: "soltech-clone.firebasedatabase.app",
            // messagingSenderId: "329921756016",
            // appId: "1:329921756016:web:a9492876b99074d4606db5",
            // measurementId: "G-5KR6WE0CXX",
            //databaseURL: "https://soltech-clone-default-rtdb.europe-west1.firebasedatabase.app/"

}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Users App',
      theme: ThemeData(

        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FirebaseAuth.instance.currentUser == null? SignInPage() : HomePage(),
    );
  }
}
