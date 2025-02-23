import "package:flutter/material.dart";

// ignore: must_be_immutable
class CustomListTile extends StatelessWidget {
  Image image;
  String titleText;
  String trailingText;
  CustomListTile(
      {super.key,
      required this.image,
      required this.titleText,
      required this.trailingText});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: const Color.fromRGBO(51, 51, 51, 1),
      leading: CircleAvatar(child: image),
      title: Text(titleText, style: const TextStyle(color: Colors.white, fontSize: 20)),
      trailing: Text(trailingText, style: const TextStyle(color: Colors.yellow, fontSize: 20)),
    );
  }
}
