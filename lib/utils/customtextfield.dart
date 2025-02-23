// ignore_for_file: file_names

import "package:flutter/material.dart";

// ignore: must_be_immutable
class CustomTextField extends StatelessWidget{
  String text;
  CustomTextField({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        decoration: InputDecoration(
            hintText: text,
            hintStyle: const TextStyle(color: Colors.white),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
            focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.yellow))),
      ),
    );
  }
}
