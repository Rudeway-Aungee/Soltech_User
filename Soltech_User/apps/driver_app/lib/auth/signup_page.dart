import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_driver_app/auth/signin_page.dart';
import 'package:soltech_driver_app/global.dart';
import 'package:soltech_driver_app/pages/pending_approval_page.dart';
import 'package:soltech_driver_app/widgets/loading_dialog.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailTxtEditingController =
      TextEditingController();
  final TextEditingController passwordTxtEditingController =
      TextEditingController();
  final TextEditingController userNameTxtEditingController =
      TextEditingController();
  final TextEditingController userPhoneTxtEditingController =
      TextEditingController();
  final TextEditingController vehicleModelController = TextEditingController();
  final TextEditingController vehicleColorController = TextEditingController();
  final TextEditingController plateNumberController = TextEditingController();

  void validateSignUpForm() {
    if (userNameTxtEditingController.text.trim().length < 3) {
      associateMethods.showSnackBarMsg(
        'Full name must be at least 3 characters.',
        context,
      );
    } else if (userPhoneTxtEditingController.text.trim().length < 7) {
      associateMethods.showSnackBarMsg(
        'Phone number must be at least 7 characters.',
        context,
      );
    } else if (!emailTxtEditingController.text.contains('@')) {
      associateMethods.showSnackBarMsg('Invalid email address!', context);
    } else if (passwordTxtEditingController.text.trim().length < 6) {
      associateMethods.showSnackBarMsg(
        'Password must be at least 6 characters.',
        context,
      );
    } else if (vehicleModelController.text.trim().length < 2) {
      associateMethods.showSnackBarMsg('Vehicle model is required.', context);
    } else if (vehicleColorController.text.trim().length < 2) {
      associateMethods.showSnackBarMsg('Vehicle color is required.', context);
    } else if (plateNumberController.text.trim().length < 4) {
      associateMethods.showSnackBarMsg('Plate number is required.', context);
    } else {
      signUpDriverNow();
    }
  }

  Future<void> signUpDriverNow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const LoadingDialog(messageTxt: 'Creating driver account...'),
    );

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailTxtEditingController.text.trim(),
            password: passwordTxtEditingController.text.trim(),
          );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Unable to create the driver account.',
        );
      }

      final int now = DateTime.now().millisecondsSinceEpoch;

      await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(firebaseUser.uid)
          .set(<String, dynamic>{
            'id': firebaseUser.uid,
            'name': userNameTxtEditingController.text.trim(),
            'phone': userPhoneTxtEditingController.text.trim(),
            'email': emailTxtEditingController.text.trim(),
            'vehicleModel': vehicleModelController.text.trim(),
            'vehicleColor': vehicleColorController.text.trim(),
            'plateNumber': plateNumberController.text.trim().toUpperCase(),
            'serviceType': 'taxi',
            'blockStatus': 'no',
            'approvalStatus': 'pending',
            'onlineStatus': 'offline',
            'createdAt': now,
            'updatedAt': now,
          });

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) =>
              const PendingApprovalPage(initialStatus: 'pending'),
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
        e.message ?? 'Unable to create the driver account.',
        context,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      associateMethods.showSnackBarMsg('Driver sign-up failed: $e', context);
    }
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
      style: const TextStyle(color: Colors.black87, fontSize: 15),
    );
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
              vertical: 36.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Image.asset(
                    'assets/signup.webp',
                    width: MediaQuery.of(context).size.width * 0.36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create Driver Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set up your driver profile and wait for admin approval.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _textField(
                  controller: userNameTxtEditingController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 18),
                _textField(
                  controller: userPhoneTxtEditingController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 18),
                _textField(
                  controller: emailTxtEditingController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
                _textField(
                  controller: passwordTxtEditingController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 18),
                _textField(
                  controller: vehicleModelController,
                  label: 'Vehicle Model',
                  icon: Icons.directions_car_outlined,
                ),
                const SizedBox(height: 18),
                _textField(
                  controller: vehicleColorController,
                  label: 'Vehicle Color',
                  icon: Icons.palette_outlined,
                ),
                const SizedBox(height: 18),
                _textField(
                  controller: plateNumberController,
                  label: 'Plate Number',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.visiblePassword,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: validateSignUpForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
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
                      'Already have an account? ',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (BuildContext context) =>
                                const SignInPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Login',
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
