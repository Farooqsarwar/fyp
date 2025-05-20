import "package:flutter/material.dart";

// ignore: must_be_immutable
class CustomTextField extends StatelessWidget {
  final String text;
  final TextEditingController controller;
  final TextInputType keyboardType;

  CustomTextField({
    super.key,
    required this.text,
    required this.controller,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white, // Input text color
        ),
        decoration: InputDecoration(
          hintText: text,
          hintStyle: const TextStyle(color: Colors.yellow), // Hint text color
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.yellow),
          ),
        ),
      ),
    );
  }
}