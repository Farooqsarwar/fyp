import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fyp/view/all_furniture_screen.dart';

import 'All_cars_screen.dart';
import 'Homescreen.dart';
import 'Uploading_Bid.dart';
import 'all_art_screen.dart';

class Navigationbar extends StatefulWidget {
  const Navigationbar({super.key});

  @override
  State<Navigationbar> createState() => _NavigationbarState();
}

class _NavigationbarState extends State<Navigationbar> {
  int currentIndex = 0; // State variable to track the selected index
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      // Fixed type for consistent layout
      backgroundColor: Colors.black,
      // Background color
      currentIndex: currentIndex,
      // Bind currentIndex to the state variable
      unselectedItemColor: Colors.white54,
      // Color for unselected items
      selectedItemColor: Color(0xFFECD801),
      // Color for selected item
      onTap: (index) {
        setState(() {
          currentIndex = index; // Update the selected index
        });
        // Navigate to the appropriate screen based on the tapped index
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Homescreen()),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AllCarsScreen()),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UploadingBid()),
          );
        } else if (index == 3) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AllFurnitureScreen()),
          );
        } else if (index == 4) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AllArtScreen()),
          );
        }
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home, color: Colors.white),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.car, color: Colors.white),
          label: 'Cars',
        ),
        BottomNavigationBarItem(
          icon: Container(
            width: 70,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFECD801),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 35),
          ),
          label: '',
        ),
        const BottomNavigationBarItem(
          icon: FaIcon(Icons.chair, color: Colors.white),
          label: 'Furniture',
        ),
        const BottomNavigationBarItem(
          icon: FaIcon(FontAwesomeIcons.paintbrush, color: Colors.white),
          label: 'Art',
        ),
      ],
    );
  }
}