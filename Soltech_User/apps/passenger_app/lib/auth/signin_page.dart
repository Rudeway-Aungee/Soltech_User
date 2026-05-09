import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soltech_app/auth/signup_page.dart';
import 'package:soltech_app/methods/associate_methods.dart';
//import 'package:soltech_app/widgets/loading_dialog.dart;
import '../global.dart';
import '../pages/home_page.dart';
import '../widgets/loading_dialog.dart';


class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {

  TextEditingController emailTxtEditingController = TextEditingController();
  TextEditingController passwordTxtEditingController = TextEditingController();
  AssociateMethods associateMethods = AssociateMethods();
  //LoadingDialog loadingDialog = LoadingDialog(messageTxt: "Signing in...");

  void validateSignInForm() {
    // Fast client-side validation before hitting Firebase.
    // Checks if email contains @ symbol for basic email format validation.
    if(!emailTxtEditingController.text.contains("@")){
      associateMethods.showSnackBarMsg("Invalid email address!", context);

    }
    // Validates password has minimum 6 characters for security.
    else if(passwordTxtEditingController.text.trim().length < 5){
      associateMethods.showSnackBarMsg("Must be atleast 6 or more characters!", context);
    }
    else{
      // Proceed to server-side auth only when inputs look valid.
      signInUserNow();
    }
  }

  void signInUserNow() async
  {
    // Block UI to avoid double submission while auth is in progress.
    showDialog(
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageTxt: "Signing in..."),
    );
    try{
      // Authenticate user with Firebase Auth using email and password.
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailTxtEditingController.text.trim(),
        password: passwordTxtEditingController.text.trim(),
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        // Fetch user profile record from Realtime Database to enforce business rules (e.g., block status).
        DatabaseReference ref = FirebaseDatabase.instance.ref().child("users").child(firebaseUser.uid);
        await ref.once().then((dataSnapshot) {
          if(dataSnapshot.snapshot.value != null){
            // Check if user account is not blocked (blockStatus == "no").
            if ((dataSnapshot.snapshot.value as Map)["blockStatus"] == "no") {
              // Cache user fields used by the home drawer header for display.
              userName = (dataSnapshot.snapshot.value as Map)["name"];
              userPhone = (dataSnapshot.snapshot.value as Map)["phone"];

              if (!mounted) return;
              Navigator.pop(context);
              associateMethods.showSnackBarMsg("Login successfully!", context);
              // Navigate into the main map UI after successful authentication.
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
            }
            else{
              if(!mounted) return;
              Navigator.pop(context);
              // Immediately sign out blocked accounts to prevent access.
              FirebaseAuth.instance.signOut();
              associateMethods.showSnackBarMsg("Account blocked!", context);
            }

          }
          else
          {
            if(!mounted) return;
            Navigator.pop(context);
            // Auth exists but no matching DB record; sign out to keep state consistent.
            FirebaseAuth.instance.signOut();
            associateMethods.showSnackBarMsg("No record found!", context);
          }

        });
      }

    }
    on FirebaseAuthException catch (e) {
      // Ensure we don't keep a partial auth session on known auth errors.
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
                const SizedBox(height: 60),
                Center(
                  child: Image.asset(
                    'assets/signin.webp',
                    width: MediaQuery.of(context).size.width * 0.45,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Welcome Back",
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
                  "Login to your account to continue",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Email text field
                TextField(
                  controller: emailTxtEditingController,
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
                // Login button
                ElevatedButton(
                  onPressed: () {
                    validateSignInForm();
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
                    "Login",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sign Up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Sign Up",
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
