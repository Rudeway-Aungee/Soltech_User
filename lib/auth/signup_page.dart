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
    if(userNameTxtEditingController.text.trim().length < 3){
      associateMethods.showSnackBarMsg("Must be atleast 3 or more characters!", context);
    }
    else if(userPhoneTxtEditingController.text.trim().length < 7){
      associateMethods.showSnackBarMsg("Must be atleast 7 or more characters!", context);
    }
    else if(!emailTxtEditingController.text.contains("@")){
      associateMethods.showSnackBarMsg("Invalid email address!", context);
    }
    else if(passwordTxtEditingController.text.trim().length < 6){
      associateMethods.showSnackBarMsg("Must be atleast 6 or more characters!", context);
    }
    else{
      signUpUserNow();
      //associateMethods.showSnackBarMsg("All good!", context);
    }
  }

  void signUpUserNow() async
  {
    showDialog(
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageTxt: "Signing up..."),
      );
    try{
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailTxtEditingController.text.trim(),
        password: passwordTxtEditingController.text.trim(),
      );

      final User? firebaseUser = userCredential.user;

       Map userDataMap = { //Save user data
         "name": userNameTxtEditingController.text.trim(),
         "phone": userPhoneTxtEditingController.text.trim(),
         "email": emailTxtEditingController.text.trim(),
         "password": passwordTxtEditingController.text.trim(),
         "id": firebaseUser!.uid,
         "blockStatus": "no",
       };

      await FirebaseDatabase.instance.ref().child("users").child(firebaseUser.uid).set(userDataMap).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      associateMethods.showSnackBarMsg("Account created successfully!", context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
    }
    on FirebaseAuthException catch (e) {
      FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pop(context);

      if (!mounted) return;
      associateMethods.showSnackBarMsg("Error: $e", context);
    }
    catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      associateMethods.showSnackBarMsg("Database error: $e", context);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 122,),

              Image.asset(
                'assets/signup.webp',
                width: MediaQuery.of(context).size.width * 0.4,
                //height: MediaQuery.of(context).size.height * 0.4,
              ),

              const SizedBox(height: 20,),

              const Text(
                "Register New Account",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),

              ),

              //const SizedBox(height: 15,),

              //Form field
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    //Email text field
                    TextField(
                      controller: userNameTxtEditingController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: "User name",
                        labelStyle: TextStyle(fontSize: 14),

                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 22,),

                    TextField(
                      controller: userPhoneTxtEditingController,
                      obscureText: false,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "User Phone number",
                        labelStyle: TextStyle(fontSize: 14),

                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 32,),

                    TextField(
                      controller: emailTxtEditingController,
                      obscureText: false,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "User email",
                        labelStyle: TextStyle(fontSize: 14),

                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 32,),

                    //Password text field
                    TextField(
                      controller: passwordTxtEditingController,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: "User password",
                        labelStyle: TextStyle(fontSize: 14),

                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 32,),
                    //Login button
                    ElevatedButton(
                      onPressed: (){
                        validateSignUpForm();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 80 , vertical: 10 )
                      ),
                      child: const Text("SignUp", style: TextStyle(color:  Colors.black, fontSize: 20),),
                    ),
                  ],
                ),

              ),

              const SizedBox(height: 22,),

              TextButton(
                onPressed: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInPage()));
                },
                child: const Text(
                  "Already have an account? Login here",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
