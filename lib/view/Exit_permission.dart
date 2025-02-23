import 'package:flutter/material.dart';

class ExitConfirmation {
  static Future<bool> showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Black background for the dialog box
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), // Rounded corners
          ),
          title: const Text(
            "Exit Confirmation",
            style: TextStyle(color: Colors.white), // White title text color
          ),
          content: const Text(
            "Are you sure you want to exit the app?",
            style: TextStyle(color: Colors.white54), // Grey content text color
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Return false
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFFECD801)), // Yellow button text
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Return true
              child: const Text(
                "Exit",
                style: TextStyle(color: Color(0xFFECD801)), // Yellow button text
              ),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if no option is selected
  }
}
