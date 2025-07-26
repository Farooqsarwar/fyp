import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fyp/services/auction_notification_services.dart';
import 'package:fyp/services/emailservices.dart'; // Import EmailService
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat/controller/chat_controller.dart';
import 'chat/controller/user_controller.dart';
import 'services/auction_services.dart';
import 'view/splashscreen.dart';
import 'view/Homescreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: "https://ejqogqnyskhakdlziesp.supabase.co",
      anonKey:
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqcW9ncW55c2toYWtkbHppZXNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcwMzQ3OTIsImV4cCI6MjA2MjYxMDc5Mn0.BzQpXwZuVBouTQB3bGZVg77SbKhtkrbeowN8ksiDn0k",
    );
    debugPrint("Supabase initialized");

    // Initialize GetX controllers
    Get.put(UserController()); // Initialize UserController
    Get.put(ChatController()); // Initialize ChatController

    // Initialize services
    final notificationService = AuctionNotificationServices();
    notificationService.initializeWithSupabase(supabase);

    final auctionService = AuctionService(supabase: supabase);
    auctionService.initialize();

    // Initialize EmailService with SMTP configuration
    final emailService = EmailService();
    emailService.initialize(
      smtpUsername: 'fypauction62@gmail.com', // e.g., 'your-email@gmail.com'
      smtpPassword: 'csxh pfif zjhb jbto', // e.g., Gmail App Password
      smtpServer: 'smtp.gmail.com', // e.g., 'smtp.gmail.com' for Gmail
      smtpPort: 587, // Common port for TLS
      smtpSsl: false, // Set to true if using SSL (port 465)
      fromEmail: 'your-email@gmail.com', // Sender email
      fromName: 'Your Auction App', // Sender name
    );
    debugPrint("EmailService initialized");

    // Initialize for current user if logged in
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await notificationService.initialize(userId);
      debugPrint("NotificationService initialized for user $userId");
    }

    // Set up auth state listener
    supabase.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (userId != null) {
        notificationService.initialize(userId);
        debugPrint('Initialized notifications for user $userId');
      }
    });

    // Start periodic auction monitoring
    startAuctionMonitoring(notificationService, auctionService);

    runApp(MyApp(
      auctionService: auctionService,
      notificationService: notificationService,
      emailService: emailService, // Pass EmailService to MyApp
    ));
  } catch (e, stack) {
    debugPrint("Initialization failed: $e\n$stack");
    runApp(const ErrorApp());
  }
}

void startAuctionMonitoring(
    AuctionNotificationServices notificationService,
    AuctionService auctionService,
    ) {
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      await auctionService.monitorAllAuctions(notificationService);
      debugPrint('Successfully monitored all auctions');
    } catch (e) {
      debugPrint('Error monitoring auctions: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  final AuctionService auctionService;
  final AuctionNotificationServices notificationService;
  final EmailService emailService; // Add EmailService

  const MyApp({
    super.key,
    required this.auctionService,
    required this.notificationService,
    required this.emailService, // Add to constructor
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
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: '/home', page: () => const Homescreen()),
        // Add other routes as GetPages
      ],
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 50),
              const SizedBox(height: 20),
              const Text(
                'Initialization Error',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => main(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}