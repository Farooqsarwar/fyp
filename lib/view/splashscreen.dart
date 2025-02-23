import 'dart:async';
import 'package:flutter/material.dart';

import 'Login_screen.dart';


class Splas_screen extends StatefulWidget {
  const Splas_screen({super.key});
  @override
  _Splas_screenState createState() => _Splas_screenState();
}
class _Splas_screenState extends State<Splas_screen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
    );
  }
  @override
  Widget build(BuildContext context) {
    // print("built");
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child:  Column(
          children: [
            const SizedBox(height: 200,),
            Image.asset(
              "assets/logo.jpg", // New image with transparent background
              fit: BoxFit.cover,
              width: 268,
              height: 252,
            ),
            const SizedBox(height: 5),
            const Text('Bid smarter, Not harder',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22
            ),),
            const SizedBox(height: 20),
            SizedBox(
              width: 200, // Set the desired width here
              child:  LinearProgressIndicator(
                color:const Color(0xFFECD801),
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