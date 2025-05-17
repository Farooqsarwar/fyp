import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp/view/Homescreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    await Future.delayed(const Duration(seconds: 3));

    if (user != null) {
      // User is logged in, navigate to Home Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homescreen()),
      );
    } else {
      // User is not logged in, navigate to Login Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            const SizedBox(height: 200),
            Image.asset(
              "assets/logo.jpg",
              fit: BoxFit.cover,
              width: 268,
              height: 252,
            ),
            const SizedBox(height: 5),
            const Text(
              'Bid smarter, Not harder',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                color: const Color(0xFFECD801),
                minHeight: 4,
                backgroundColor: Colors.black,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
