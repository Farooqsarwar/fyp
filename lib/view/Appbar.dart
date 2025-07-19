import 'package:flutter/material.dart';
class Appbar extends StatelessWidget implements PreferredSizeWidget {

  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // Disable default leading widget
      leading: CircleAvatar(
    backgroundColor: Colors.transparent,
    child: Image.asset("assets/logo.jpg",width: 150,fit: BoxFit.fitWidth,),),
      backgroundColor: Colors.black, // Set your desired color here
      centerTitle: true, // Center the title
      elevation: 2, // Adjust the shadow effect
      actions: [
        IconButton(
          icon: const Icon(Icons.menu_sharp, color: Colors.white,size: 30,), // 3-line hamburger icon
          onPressed: () {
            // Open the drawer when tapped
            Scaffold.of(context).openEndDrawer();
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60); // Default AppBar height
}
