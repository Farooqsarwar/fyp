import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class to handle user profile operations with seamless UI updates
/// Manages profile picture uploading, caching, and retrieval using local storage only
class UserService {
  // Core dependencies
  final ImagePicker _picker = ImagePicker();
  // In-memory cache to avoid repeated disk access
  String? _cachedProfilePicturePath;
  String? _cachedUserName;

  // Stream controller to notify UI components when profile picture changes
  final StreamController<String?> profilePictureStream = StreamController<String?>.broadcast();

  /// Constructor initializes the stream with current profile picture
  UserService() {
    fetchProfilePicture().then((path) => profilePictureStream.add(path));
  }

  /// Upload or take a new profile picture after asking user for the source (camera/gallery)
  Future<String?> uploadProfilePicture(BuildContext context) async {
    try {
      // Ask the user to choose Camera or Gallery
      ImageSource? source = await _getImageSource(context);
      if (source == null) return null; // User cancelled selection

      // Open image picker with specified source
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return null; // User cancelled selection

      // Copy the selected image to app's local storage with unique filename
      File file = File(pickedFile.path);
      Directory appDir = await getApplicationDocumentsDirectory();
      String filePath = '${appDir.path}/profile_picture_${DateTime.now().millisecondsSinceEpoch}.png';
      await file.copy(filePath);

      // Save to shared preferences for persistence across app restarts
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_picture_path', filePath);

      // Update in-memory cache
      _cachedProfilePicturePath = filePath;

      // Notify all listening UI components about the new image
      profilePictureStream.add(filePath);

      return filePath;
    } catch (e) {
      print("Error with profile image: $e");
      return null;
    }
  }

  /// Fetch user's name with caching for performance
  Future<String> fetchUserName() async {
    final supabase = Supabase.instance.client;
    final response = await supabase.auth.getUser();

    if (response.user == null) {
      print("User not logged in.");
      return "Guest User";
    }

    final userId = response.user!.id;

    try {
      final userData = await supabase
          .from('users') // ✅ Ensure you have this table in your database
          .select('name')
          .eq('id', userId)
          .maybeSingle(); // Avoids list handling

      if (userData != null && userData['name'] != null) {
        return userData['name'];
      } else {
        print("No username found for user ID: $userId");
        return "Guest User";
      }
    } catch (e) {
      print("Error fetching username from Supabase: $e");
      return "Guest User";
    }
  }

  /// Fetch profile picture using cache (memory -> local storage)
  Future<String?> fetchProfilePicture() async {
    if (_cachedProfilePicturePath != null) return _cachedProfilePicturePath;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? filePath = prefs.getString('profile_picture_path');

    if (filePath != null && File(filePath).existsSync()) {
      _cachedProfilePicturePath = filePath;
      return filePath;
    }

    return null;
  }

  /// Helper function to prompt user to select Camera or Gallery
  Future<ImageSource?> _getImageSource(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Image Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera),
                title: Text("Camera"),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text("Gallery"),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a circular avatar with profile picture or placeholder
  Widget getProfileImageWidget({String? filePath, double size = 150}) {
    if (filePath != null && File(filePath).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(filePath),
          fit: BoxFit.cover,
          height: size,
          width: size,
        ),
      );
    }
    return Icon(Icons.person, size: size, color: Colors.white);
  }

  /// Returns a widget that automatically updates when profile picture changes
  Widget getStreamedProfileImage({double size = 150}) {
    return StreamBuilder<String?>(
      stream: profilePictureStream.stream,
      initialData: _cachedProfilePicturePath,
      builder: (context, snapshot) {
        return getProfileImageWidget(filePath: snapshot.data, size: size);
      },
    );
  }

  /// Clears cached user data (useful for logout)
  Future<void> clearCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_picture_path');

    _cachedProfilePicturePath = null;
    _cachedUserName = null;

    profilePictureStream.add(null);
  }

  /// Release resources when service is no longer needed
  void dispose() {
    profilePictureStream.close();
  }
}
