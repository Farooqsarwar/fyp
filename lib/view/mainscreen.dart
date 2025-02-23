import "package:flutter/material.dart";

// ignore: must_be_immutable
class MainScreen extends StatelessWidget {
  Widget content;
  MainScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 27, 27, 27).withOpacity(0.7),
      body: SafeArea(
          child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset("assets/art.png")),
            const SizedBox(
              height: 20,
            ),
            content
          ],
        ),
      )),
    );
  }
}
