import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_driver_app/auth/signup_page.dart';
import 'package:soltech_driver_app/global.dart';
import 'package:soltech_driver_app/model/driver_profile_model.dart';
import 'package:soltech_driver_app/pages/home_page.dart';
import 'package:soltech_driver_app/pages/pending_approval_page.dart';
import 'package:soltech_driver_app/widgets/loading_dialog.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController emailTxtEditingController =
      TextEditingController();
  final TextEditingController passwordTxtEditingController =
      TextEditingController();

  void validateSignInForm() {
    if (!emailTxtEditingController.text.contains('@')) {
      associateMethods.showSnackBarMsg('Invalid email address!', context);
    } else if (passwordTxtEditingController.text.trim().length < 6) {
      associateMethods.showSnackBarMsg(
        'Password must be at least 6 characters.',
        context,
      );
    } else {
      signInDriverNow();
    }
  }

  Future<void> signInDriverNow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const LoadingDialog(messageTxt: 'Signing in...'),
    );

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailTxtEditingController.text.trim(),
            password: passwordTxtEditingController.text.trim(),
          );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'No authenticated driver was returned.',
        );
      }

      final DatabaseEvent driverEvent = await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(firebaseUser.uid)
          .once();
      final DriverProfileModel? profile = DriverProfileModel.fromSnapshotValue(
        firebaseUser.uid,
        driverEvent.snapshot.value,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      if (profile == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) {
          return;
        }

        associateMethods.showSnackBarMsg(
          'No driver profile found for this account.',
          context,
        );
        return;
      }

      if (profile.isBlocked) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) {
          return;
        }

        associateMethods.showSnackBarMsg('Driver account blocked.', context);
        return;
      }

      _cacheDriverProfile(profile);

      if (profile.isApproved) {
        if (!mounted) {
          return;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => const HomePage(),
          ),
          (Route<dynamic> route) => false,
        );
        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) =>
              PendingApprovalPage(initialStatus: profile.approvalStatus),
        ),
        (Route<dynamic> route) => false,
      );
    } on FirebaseAuthException catch (e) {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      associateMethods.showSnackBarMsg(
        e.message ?? 'Unable to sign in right now.',
        context,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      associateMethods.showSnackBarMsg('Driver sign-in failed: $e', context);
    }
  }

  void _cacheDriverProfile(DriverProfileModel profile) {
    userName = profile.name;
    userPhone = profile.phone;
    driverVehicleModel = profile.vehicleModel;
    driverVehicleColor = profile.vehicleColor;
    driverPlateNumber = profile.plateNumber;
    driverApprovalStatus = profile.approvalStatus;
    driverOnlineStatus = profile.onlineStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Image.asset(
                    'assets/signin.webp',
                    width: MediaQuery.of(context).size.width * 0.42,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Driver Sign In',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Access live ride requests and manage your trips.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: emailTxtEditingController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordTxtEditingController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: validateSignInForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have a driver account? ",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (BuildContext context) =>
                                const SignUpPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
