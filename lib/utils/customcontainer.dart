import "package:flutter/material.dart";

// ignore: must_be_immutable
class CustomContainer extends StatelessWidget {
  String number;
  CustomContainer({super.key, required this.number});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const  Color.fromRGBO(51, 51, 51, 1),
        borderRadius: BorderRadius.circular(12)
      ),
      padding: const EdgeInsets.all(5),
      child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 20)),
    );
  }
}
