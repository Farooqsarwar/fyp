import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'Live_Biding.dart';
import 'Login_screen.dart';
import 'bidwinscreen.dart';

class CustomDrawer extends StatelessWidget {
   CustomDrawer({super.key});

  final String imgurl = "https://freesvg.org/img/abstract-user-flat-4.png";
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 270,
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 27, 27, 27),
              ),
              child: Stack(
                children: [
                  // Positioned image
                  Align(
                    alignment: Alignment.topCenter, // Center the image
                    child: ClipOval(
                      child: Image.network(
                        imgurl,
                        fit: BoxFit.cover,
                        height: 150,
                      ),
                    ),
                  ),
                  // Positioned IconButton
                  Positioned(
                    top: -10,
                    right: 75,
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.add,
                        color: Colors.yellow,
                        size: 30,
                      ),
                    ),
                  ),
                  const Positioned(
                      top: 155,
                      left: 90,
                      child: Text(
                        "user name",
                        style: TextStyle(color: Colors.white,
                          fontSize: 20
                        ),
                      ))
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_rounded),
            title: const Text('Placed Bids'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.outbound_sharp),
            title: const Text('Ongoing Bids'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=>const LiveBidscreen()));
            },
          ),
          ListTile(
            leading:const FaIcon(
              FontAwesomeIcons.trophy,  // Trophy icon from Font Awesome
            ),
            title: const Text('Win Bids'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=>const BidWinScreen()));
            },
          ),
          ListTile(
            leading:const FaIcon(
              FontAwesomeIcons.circleInfo,  // Trophy icon from Font Awesome
            ),
            title: const Text('About Us'),
            onTap: () {
            },
          ),
          ListTile(
            leading:const FaIcon(
              Icons.exit_to_app,  // Trophy icon from Font Awesome
            ),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>const LoginScreen()));

            },
          ),
          const SizedBox(height: 150,),
          Container(
            color: Colors.black,
            child: Row(
              children: [
                const SizedBox(width: 10,),
                ClipOval(
                  child: Center(
                    child: Image.asset(
                      "assets/logo.jpg",
                      width: 50,
                      height: 50,
                    ),
                  ),
                ),
                const SizedBox(width: 10,),
                const Text("All Rights reserved",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold
                ),)
              ],
            ),
          )
        ],
      ),
    );
  }
}