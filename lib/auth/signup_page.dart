import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_app/auth/signin_page.dart';
import 'package:soltech_app/global.dart';
import '../pages/home_page.dart';
import '../widgets/loading_dialog.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {

  TextEditingController emailTxtEditingController = TextEditingController();
  TextEditingController passwordTxtEditingController = TextEditingController();
  TextEditingController userNameTxtEditingController = TextEditingController();
  TextEditingController userPhoneTxtEditingController = TextEditingController();

  void validateSignUpForm(){
    // Fast client-side validation to avoid unnecessary network calls.
    // Ensures username has minimum 3 characters for meaningful user identification.
    if(userNameTxtEditingController.text.trim().length < 3){
      associateMethods.showSnackBarMsg("Must be atleast 3 or more characters!", context);
    }
    // Validates phone number has minimum 7 characters for valid phone format.
    else if(userPhoneTxtEditingController.text.trim().length < 7){
      associateMethods.showSnackBarMsg("Must be atleast 7 or more characters!", context);
    }
    // Checks if email contains @ symbol for basic email format validation.
    else if(!emailTxtEditingController.text.contains("@")){
      associateMethods.showSnackBarMsg("Invalid email address!", context);
    }
    // Validates password has minimum 6 characters for security.
    else if(passwordTxtEditingController.text.trim().length < 6){
      associateMethods.showSnackBarMsg("Must be atleast 6 or more characters!", context);
    }
    else{
      // Inputs are valid enough to proceed with account creation.
      signUpUserNow();
      //associateMethods.showSnackBarMsg("All good!", context);
    }
  }

  void signUpUserNow() async
  {
    // Block UI during account creation to avoid duplicate submissions.
    showDialog(
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageTxt: "Signing up..."),
      );
    try{
      // Create the account in Firebase Auth using email and password.
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTxtEditingController.text.trim(),
        password: passwordTxtEditingController.text.trim(),
      );

      final User? firebaseUser = userCredential.user;

       // Build the profile record stored in Realtime Database.
       // This data is retrieved on sign-in to populate user info and check block status.
       Map userDataMap = { //Save user data
         "name": userNameTxtEditingController.text.trim(),
         "phone": userPhoneTxtEditingController.text.trim(),
         "email": emailTxtEditingController.text.trim(),
         "password": passwordTxtEditingController.text.trim(),
         "id": firebaseUser!.uid,
         // blockStatus: "no" means account is active; "yes" means account is blocked.
         "blockStatus": "no",
       };

      // Persist the profile record so the app can load user data on sign-in.
      await FirebaseDatabase.instance.ref().child("users").child(firebaseUser.uid).set(userDataMap).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      associateMethods.showSnackBarMsg("Account created successfully!", context);
      // Navigate directly into the main app after successful registration.
      Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
    }
    on FirebaseAuthException catch (e) {
      // Clean up auth session on account-creation errors.
      FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      associateMethods.showSnackBarMsg("Error: $e", context);
    }
    catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      // Catch-all for database/network issues.
      associateMethods.showSnackBarMsg("Database error: $e", context);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Image.asset(
                    'assets/signup.webp',
                    width: MediaQuery.of(context).size.width * 0.4,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sign up to get started",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                // Form field
                // Name text field
                TextField(
                  controller: userNameTxtEditingController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                // Phone text field
                TextField(
                  controller: userPhoneTxtEditingController,
                  obscureText: false,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                // Email text field
                TextField(
                  controller: emailTxtEditingController,
                  obscureText: false,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                // Password text field
                TextField(
                  controller: passwordTxtEditingController,
                  obscureText: true,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                // Sign up button
                ElevatedButton(
                  onPressed: () {
                    validateSignUpForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignInPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Login",
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
