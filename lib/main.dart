import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp/services/auction_services.dart';
import 'package:fyp/view/splashscreen.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat/controller/chat_controller.dart';
import 'chat/controller/user_controller.dart';

// Define your global variables
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final supabase = Supabase.instance.client;
const String _oneSignalAppId = '948ea4ee-8e9f-417c-acce-871c020d315a';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: "https://ejqogqnyskhakdlziesp.supabase.co",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqcW9ncW55c2toYWtkbHppZXNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcwMzQ3OTIsImV4cCI6MjA2MjYxMDc5Mn0.BzQpXwZuVBouTQB3bGZVg77SbKhtkrbeowN8ksiDn0k",
  );

  // Get current user ID
  final userId = supabase.auth.currentUser?.id;

  if (userId != null) {
    // Initialize OneSignal with user context first
    await _initializeOneSignalWithUser(userId);
  }

  // Initialize controllers and services
  Get.put(ChatController(), permanent: true);
  Get.put(UserController(), permanent: true);

  final notificationService = AuctionNotificationServices();
  notificationService.initializeWithSupabase(supabase);

  if (userId != null) {
    await notificationService.initialize(userId);
  }

  runApp(MyApp(
    auctionService: AuctionService(supabase: supabase),
    notificationService: notificationService,
  ));
}

Future<void> _initializeOneSignalWithUser(String userId) async {
  try {
    // Configure OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // Initialize with app ID
     OneSignal.initialize(_oneSignalAppId);

    // Set the external user ID
    await _setOneSignalUser(userId);

    // Request notification permission
    final accepted = await OneSignal.Notifications.requestPermission(true);
    print('Notification permission granted: $accepted');

    // Setup notification handlers
    _setupNotificationHandlers();

  } catch (e) {
    print('Error initializing OneSignal: $e');
  }
}

Future<void> _setOneSignalUser(String userId) async {
  try {
    // First logout any existing user
    await OneSignal.logout();

    // Login with new user ID
    await OneSignal.login(userId);

    // Verify the user was set
    final oneSignalUserId = await OneSignal.User.pushSubscription.id;
    print('OneSignal User ID: $oneSignalUserId');
    print('External User ID set: $userId');

  } catch (e) {
    print('Error setting OneSignal user: $e');
  }
}

void _setupNotificationHandlers() {
  // Foreground handler
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print('Notification received in foreground: ${event.notification.jsonRepresentation()}');
    event.notification.display();
  });

  // Click handler
  OneSignal.Notifications.addClickListener((event) {
    print('Notification clicked: ${event.notification.jsonRepresentation()}');
    _handleNotificationClick(event.notification.additionalData);
  });
}

void _handleNotificationClick(Map<String, dynamic>? data) {
  final context = navigatorKey.currentContext;
  if (context == null || data == null) return;

  // Your navigation logic here
  // ...
}

class AuctionNotificationServices {
  static final AuctionNotificationServices _instance = AuctionNotificationServices._internal();
  factory AuctionNotificationServices() => _instance;

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  RealtimeChannel? _notificationChannel;

  AuctionNotificationServices._internal();

  void initializeWithSupabase(SupabaseClient supabase) {
    _supabase ??= supabase;
    print('Notification service initialized with Supabase');
  }

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    try {
      // Store Player ID
      await _storePlayerId(userId);

      // Setup realtime listeners
      _setupNotificationChannel(userId);

      _isInitialized = true;
      print('Notification service fully initialized for user $userId');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  Future<void> _storePlayerId(String userId) async {
    try {
      // Wait for OneSignal to be ready
      await Future.delayed(const Duration(seconds: 2));

      final playerId = await OneSignal.User.pushSubscription.id;
      if (playerId == null || playerId.isEmpty) {
        throw Exception('Player ID not available');
      }

      // Store in Supabase
      await _supabase?.from('user_devices').upsert({
        'user_id': userId,
        'player_id': playerId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      print('Successfully stored player ID $playerId for user $userId');
    } catch (e) {
      print('Error storing player ID: $e');
      // Implement retry logic if needed
    }
  }

  void _setupNotificationChannel(String userId) {
    try {
      _notificationChannel = _supabase?.channel('user_notifications_$userId');
      _notificationChannel?.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          _handleRealtimeNotification(payload as Map<String, dynamic>);
        },
      ).subscribe();

      print('Realtime channel setup for user $userId');
    } catch (e) {
      print('Error setting up notification channel: $e');
    }
  }

  void _handleRealtimeNotification(Map<String, dynamic> payload) {
    print('Received realtime notification: $payload');
    // Handle your notification here
  }

// Add your other notification methods here...
}

class MyApp extends StatelessWidget {
  final AuctionService auctionService;
  final AuctionNotificationServices notificationService;

  const MyApp({
    super.key,
    required this.auctionService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      // Add your routes here...
    );
  }
}
