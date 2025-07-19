import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fyp/view/Login_screen.dart';
import 'package:fyp/view/wining%20and%20registered%20list.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/views/chat_screen.dart';
import '../models/fetching user data.dart';
import '../physical auction/physical auction.dart';
import '../services/auction_services.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({Key? key}) : super(key: key);

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final SupabaseClient supabase = Supabase.instance.client;
  final UserService _userService = UserService();
  final AuctionService auctionService =
      AuctionService(supabase: Supabase.instance.client);

  User? _user;
  String _userName = "Guest User";
  String? _userPhotoPath;
  bool _isLoading = false;
  bool _hasFetchedData = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data from Supabase
  Future<void> _loadUserData() async {
    if (_isLoading || _hasFetchedData) return;
    setState(() => _isLoading = true);

    _user = supabase.auth.currentUser;
    print("Current User: ${_user?.id}"); // Debugging log

    if (_user != null) {
      try {
        String name = await _userService.fetchUserName();
        print("Fetched User Name: $name"); // Debugging log

        String? photoPath = await _userService.fetchProfilePicture();

        if (mounted) {
          setState(() {
            _userName = name;
            _userPhotoPath = photoPath;
            _hasFetchedData = true;
          });
        }
      } catch (e) {
        print("Error loading user data: $e");
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Upload and save user profile picture
  Future<void> _updateProfilePicture() async {
    String? newPhotoPath = await _userService.uploadProfilePicture(context);
    if (newPhotoPath != null && mounted) {
      setState(() {
        _userPhotoPath = newPhotoPath;
      });
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          _buildDrawerOptions(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: DrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFF1B1B1B)),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: _userService.getProfileImageWidget(
                          filePath: _userPhotoPath,
                          size: 150,
                        ),
                      ),
                      Positioned(
                        top: -15,
                        right: 0,
                        child: IconButton(
                          onPressed: _updateProfilePicture,
                          icon: const Icon(Icons.add,
                              color: Colors.yellow, size: 30),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDrawerOptions() {
    return Expanded(
      child: ListView(
        children: [
          _buildDrawerItem(
            Icons.location_on_sharp,
            "Auctions in city",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PhysicalAuctions()),
              );
            },
          ),
          _buildDrawerItem(Icons.outbound_sharp, "registered Bids", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      RegisteredAuctionsList(auctionService: auctionService)),
            );
          }),
          _buildDrawerItem(
              Icons.chat,
              "chat",
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ChatScreen()))),
          _buildDrawerItem(FontAwesomeIcons.trophy, "Win Bids", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      WonAuctionsList(auctionService: auctionService)),
            );
          }),
          _buildDrawerItem(Icons.info_outline, "About Us", () {}),
          _buildDrawerItem(Icons.exit_to_app, "Logout", _signOut),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: FaIcon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.asset("assets/logo.jpg", width: 50, height: 50),
          ),
          const SizedBox(width: 10),
          const Text(
            "All Rights Reserved",
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
