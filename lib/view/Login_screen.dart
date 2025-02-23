import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fyp/view/regestration_screen.dart';
import 'Forgetpassword.dart';
import 'Homescreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

bool isObscured = true;
final _formKey = GlobalKey<FormState>();
DatabaseReference userref = FirebaseDatabase.instance.ref().child("users");
final TextEditingController emailController = TextEditingController();
final TextEditingController passwordController = TextEditingController();

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.only(left: 25),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                const CircleAvatar(
                  backgroundColor: Colors.transparent,
                  backgroundImage: AssetImage("assets/logo.jpg"),
                  radius: 60,
                ),
                const SizedBox(height: 40),
                const Text(
                  "Welcome back",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Hello there, Sign in to continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 320,
                  height: 50,
                  child: TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Your email',
                      labelStyle: const TextStyle(color: Colors.white),
                      suffixIcon: const Icon(Icons.email),
                      suffixIconColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      } else if (!value.contains("@")) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 320,
                  height: 50,
                  child: TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: isObscured,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white),
                      suffixIcon: GestureDetector(
                        child: Icon(
                          isObscured ? Icons.visibility : Icons.visibility_off,
                        ),
                        onTap: () {
                          setState(() {
                            isObscured = !isObscured;
                          });
                        },
                      ),
                      suffixIconColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 200),
                  child: TextButton(
                    onPressed: () {
                      emailController.clear();
                      passwordController.clear();
                      _formKey.currentState?.reset();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => Forgetpassword()));
                    },
                    child: const Text(
                      "Forget password?",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      loginUser(context);
                    }
                  },
                  child: Container(
                    width: 320,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.yellow.shade600,
                    ),
                    child: const Center(
                      child: Text(
                        "Login now",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 100),
                  child: Text(
                    "Haven't signed up yet?",
                    style: TextStyle(
                      color: Colors.white24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 105),
                  child: TextButton(
                    onPressed: () {
                      emailController.clear();
                      passwordController.clear();
                      _formKey.currentState?.reset();

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegistrationScreen()),
                      );
                    },
                    child: const Text(
                      "Create account?",
                      style: TextStyle(
                        color: Colors.yellowAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  void loginUser(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Close loading indicator
        if (context.mounted) {
          Navigator.pop(context);
        }

        if (userCredential.user != null) {
          // Clear the form
          emailController.clear();
          passwordController.clear();
          _formKey.currentState?.reset();

          if (context.mounted) {
            // Show success message using ScaffoldMessenger
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Successfully logged in'),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate to home screen using pushReplacement
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => const Homescreen())
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        // Close loading indicator if showing
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        emailController.clear();
        passwordController.clear();
        if (context.mounted) {
          String message = '';
          switch (e.code) {
            case 'user-not-found':
              message = 'No user found with this email';
              break;
            case 'wrong-password':
              message = 'Wrong password provided';
              break;
            case 'invalid-email':
              message = 'Invalid email address';
              break;
            case 'user-disabled':
              message = 'This user account has been disabled';
              break;
            default:
              message = 'An error occurred: ${e.message}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
