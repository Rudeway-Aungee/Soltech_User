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
    if(!emailTxtEditingController.text.contains("@")){
      associateMethods.showSnackBarMsg("Invalid email address!", context);

    }
    else if(passwordTxtEditingController.text.trim().length < 5){
      associateMethods.showSnackBarMsg("Must be atleast 6 or more characters!", context);
    }
    else{
      //associateMethods.showSnackBarMsg("All good!", context);
      signInUserNow();
    }
  }

  void signInUserNow() async
  {
    showDialog(
      context: context,
      builder: (BuildContext context) => LoadingDialog(
        messageTxt: "Signing in..."),
    );
    try{
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailTxtEditingController.text.trim(),
        password: passwordTxtEditingController.text.trim(),
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        DatabaseReference ref = FirebaseDatabase.instance.ref().child("users").child(firebaseUser.uid);
        await ref.once().then((dataSnapshot) {
          if(dataSnapshot.snapshot.value != null){
            if ((dataSnapshot.snapshot.value as Map)["blockStatus"] == "no") {
              userName = (dataSnapshot.snapshot.value as Map)["name"];
              userPhone = (dataSnapshot.snapshot.value as Map)["phone"];

              if (!mounted) return;
              Navigator.pop(context);
              associateMethods.showSnackBarMsg("Login successfully!", context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
            }
            else{
              if(!mounted) return;
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
              associateMethods.showSnackBarMsg("Account blocked!", context);
            }

          }
          else
          {
            if(!mounted) return;
            Navigator.pop(context);
            FirebaseAuth.instance.signOut();
            associateMethods.showSnackBarMsg("No record found!", context);
          }

        });
      }

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
                'assets/signin.webp',
                width: MediaQuery.of(context).size.width * 0.45,
                //height: MediaQuery.of(context).size.height * 0.4,
                ),

              const SizedBox(height: 20,),

              const Text(
                "Login to Your Account",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    //Email text field
                    TextField(
                      controller: emailTxtEditingController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "User email",
                        labelStyle: TextStyle(fontSize: 14),

                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 22,),
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
                        validateSignInForm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 80 , vertical: 10 )
                      ),
                      child: const Text("Login", style: TextStyle(color:  Colors.black, fontSize: 20),),
                    ),
                  ],
                ),

              ),

              const SizedBox(height: 22,),

              TextButton(
                onPressed: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage()));
                },
                child: const Text(
                  "Don't have an account? SignUp here",
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
