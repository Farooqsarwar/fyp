import "package:flutter/material.dart";

void showDialogueBox(BuildContext context, String titleText,
    {String? contextText}) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color.fromRGBO(51, 51, 51, 1),
        title: Text(
          titleText,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          contextText?? "",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
            child: const Text(
              "Close",
              style: TextStyle(color: Colors.black),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ],
      );
    },
  );
}
